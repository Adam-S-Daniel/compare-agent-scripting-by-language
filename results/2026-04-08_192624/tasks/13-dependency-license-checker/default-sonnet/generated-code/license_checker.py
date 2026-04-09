"""
Dependency License Checker

Parses dependency manifests (package.json, requirements.txt), checks each
dependency's license against configurable allow/deny lists, and generates a
compliance report.

License lookups are mocked for testing — in production, integrate with
PyPI's JSON API or the npm registry.
"""

import json
import os
import re
import sys
from typing import Callable, Optional


# ---------------------------------------------------------------------------
# Manifest Parsing
# ---------------------------------------------------------------------------

def parse_package_json(data: dict) -> list[dict]:
    """
    Extract production dependencies from a parsed package.json dict.

    Only 'dependencies' are included; 'devDependencies' are skipped.
    Returns a list of {"name": str, "version": str}.
    """
    deps = data.get("dependencies", {})
    return [{"name": name, "version": version} for name, version in deps.items()]


def parse_requirements_txt(content: str) -> list[dict]:
    """
    Parse requirements.txt content into a list of dependencies.

    Skips blank lines and comment lines (starting with #).
    Lines without a version specifier get version="*".
    Handles: package==1.0.0, package>=1.0,<2.0, package~=1.0, package
    """
    results = []
    for raw_line in content.splitlines():
        # Strip inline comments and surrounding whitespace
        line = raw_line.split("#")[0].strip()
        if not line:
            continue

        # Match package name and optional version specifier
        # Version specifiers: ==, >=, <=, !=, ~=, >, < (possibly combined)
        match = re.match(r"^([A-Za-z0-9_\-\.]+)\s*(.*)\s*$", line)
        if match:
            name = match.group(1)
            version = match.group(2).strip() or "*"
            results.append({"name": name, "version": version})

    return results


def parse_manifest(file_path: str) -> list[dict]:
    """
    Auto-detect manifest format from filename and parse it.

    Supported: package.json, requirements.txt
    Raises FileNotFoundError if the file doesn't exist.
    Raises ValueError for unsupported manifest formats.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Manifest not found: {file_path}")

    filename = os.path.basename(file_path)

    if filename == "package.json":
        with open(file_path) as f:
            data = json.load(f)
        return parse_package_json(data)

    if filename == "requirements.txt":
        with open(file_path) as f:
            content = f.read()
        return parse_requirements_txt(content)

    raise ValueError(
        f"Unsupported manifest format: '{filename}'. "
        "Supported formats: package.json, requirements.txt"
    )


# ---------------------------------------------------------------------------
# License Configuration
# ---------------------------------------------------------------------------

def load_license_config(data: dict) -> dict:
    """
    Build a license config from a dict with 'allow' and 'deny' lists.

    Returns {"allow": set, "deny": set}.
    Missing keys default to empty sets.
    """
    return {
        "allow": set(data.get("allow", [])),
        "deny": set(data.get("deny", [])),
    }


def load_license_config_file(file_path: str) -> dict:
    """Load and parse a license config JSON file."""
    with open(file_path) as f:
        data = json.load(f)
    return load_license_config(data)


# ---------------------------------------------------------------------------
# License Classification
# ---------------------------------------------------------------------------

def classify_license(license_id: Optional[str], config: dict) -> str:
    """
    Classify a license string against the config.

    Returns:
      "approved"  - license is in the allow-list (and NOT in deny-list)
      "denied"    - license is in the deny-list (deny takes priority)
      "unknown"   - license is None or not in either list
    """
    if license_id is None:
        return "unknown"
    if license_id in config["deny"]:
        return "denied"
    if license_id in config["allow"]:
        return "approved"
    return "unknown"


# ---------------------------------------------------------------------------
# Mocked License Lookup
# ---------------------------------------------------------------------------

# Default mock database used when running in mock mode.
# In production, replace mock_license_lookup with calls to PyPI/npm APIs.
DEFAULT_MOCK_DB = {
    "express": "MIT",
    "lodash": "MIT",
    "axios": "MIT",
    "react": "MIT",
    "gpl-package": "GPL-3.0",
    "unknown-package": None,
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "django": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "pandas": "BSD-3-Clause",
    "gpl-lib": "GPL-2.0",
    "agpl-service": "AGPL-3.0",
}


def mock_license_lookup(package_name: str, mock_db: dict) -> Optional[str]:
    """
    Return the license for a package from the mock database.

    Returns None if the package is not in the database OR if its value is None.
    This simulates a license lookup that might fail for unknown packages.
    """
    return mock_db.get(package_name)


def make_mock_lookup_fn(mock_db: dict) -> Callable[[str], Optional[str]]:
    """Return a closure that looks up licenses from the given mock DB."""
    def lookup(name: str) -> Optional[str]:
        return mock_license_lookup(name, mock_db)
    return lookup


# ---------------------------------------------------------------------------
# Report Generation
# ---------------------------------------------------------------------------

def generate_report(
    deps: list[dict],
    lookup_fn: Callable[[str], Optional[str]],
    config: dict,
) -> dict:
    """
    Generate a compliance report for the given dependencies.

    lookup_fn: callable(name) -> Optional[str] (the license string)
    config: {"allow": set, "deny": set}

    Returns:
      {
        "summary": {"total": int, "approved": int, "denied": int, "unknown": int},
        "results": [
          {"name": str, "version": str, "license": str|None, "status": str},
          ...
        ]
      }
    """
    results = []
    counts = {"approved": 0, "denied": 0, "unknown": 0}

    for dep in deps:
        name = dep["name"]
        version = dep["version"]
        license_id = lookup_fn(name)
        status = classify_license(license_id, config)
        counts[status] += 1
        results.append({
            "name": name,
            "version": version,
            "license": license_id,
            "status": status,
        })

    return {
        "summary": {
            "total": len(deps),
            "approved": counts["approved"],
            "denied": counts["denied"],
            "unknown": counts["unknown"],
        },
        "results": results,
    }


# ---------------------------------------------------------------------------
# Report Formatting
# ---------------------------------------------------------------------------

def format_report_text(report: dict) -> str:
    """
    Format a compliance report as human-readable text for CI output.

    Includes per-dependency status lines and a summary.
    Overall status: COMPLIANT (no denied) or NON-COMPLIANT (any denied).
    """
    lines = []
    lines.append("=" * 60)
    lines.append("DEPENDENCY LICENSE COMPLIANCE REPORT")
    lines.append("=" * 60)

    for result in report["results"]:
        name = result["name"]
        version = result["version"]
        license_id = result["license"] or "unknown"
        status = result["status"].upper()
        lines.append(f"  {name}@{version}: {license_id} [{status}] ({result['status']})")

    summary = report["summary"]
    lines.append("-" * 60)
    lines.append(
        f"Total: {summary['total']}  "
        f"Approved: {summary['approved']}  "
        f"Denied: {summary['denied']}  "
        f"Unknown: {summary['unknown']}"
    )

    overall = "COMPLIANT" if summary["denied"] == 0 else "NON-COMPLIANT"
    lines.append(f"Overall Status: {overall}")
    lines.append("=" * 60)

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI Entry Point
# ---------------------------------------------------------------------------

def main():
    """
    CLI: python license_checker.py --manifest <file> --config <file> [--mock-db <file>]

    Exits with code 1 if any denied licenses are found.
    """
    import argparse

    parser = argparse.ArgumentParser(description="Dependency License Checker")
    parser.add_argument("--manifest", required=True, help="Path to manifest file")
    parser.add_argument("--config", required=True, help="Path to license config JSON")
    parser.add_argument(
        "--mock-db",
        default=None,
        help="Path to mock license DB JSON (for testing; uses built-in DB if omitted)",
    )
    parser.add_argument(
        "--output-json",
        default=None,
        help="Path to write JSON report (optional)",
    )
    args = parser.parse_args()

    # Load manifest
    try:
        deps = parse_manifest(args.manifest)
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(2)

    # Load config
    try:
        config = load_license_config_file(args.config)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR loading config: {e}", file=sys.stderr)
        sys.exit(2)

    # Set up lookup function (mock DB)
    if args.mock_db:
        try:
            with open(args.mock_db) as f:
                mock_db = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"ERROR loading mock DB: {e}", file=sys.stderr)
            sys.exit(2)
    else:
        mock_db = DEFAULT_MOCK_DB

    lookup_fn = make_mock_lookup_fn(mock_db)

    # Generate and display report
    report = generate_report(deps, lookup_fn, config)
    text = format_report_text(report)
    print(text)

    # Optionally write JSON report
    if args.output_json:
        with open(args.output_json, "w") as f:
            json.dump(report, f, indent=2)
        print(f"\nJSON report written to: {args.output_json}")

    # Exit 1 if non-compliant (denied licenses found)
    if report["summary"]["denied"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
