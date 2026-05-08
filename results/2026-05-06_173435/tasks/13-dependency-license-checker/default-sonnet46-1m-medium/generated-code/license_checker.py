#!/usr/bin/env python3
"""Dependency license compliance checker.

Parses package.json or requirements.txt, looks up each dependency's license
(via a mock database for testing), checks against allow/deny lists, and
generates a human-readable compliance report.

Exit codes:
  0 - all licenses are approved or unknown (no denied licenses found)
  1 - one or more denied licenses found
  2 - usage/input error
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def parse_package_json(path: str, include_dev: bool = False) -> list[tuple[str, str]]:
    """Extract (name, version) pairs from a package.json file.

    Args:
        path: Path to package.json.
        include_dev: If True, also include devDependencies.

    Returns:
        List of (package_name, version_constraint) tuples.

    Raises:
        FileNotFoundError: If the file does not exist.
        ValueError: If the file is not valid JSON.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")

    try:
        with open(p) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e

    deps: list[tuple[str, str]] = []
    for name, version in data.get("dependencies", {}).items():
        deps.append((name, version))

    if include_dev:
        for name, version in data.get("devDependencies", {}).items():
            deps.append((name, version))

    return deps


def parse_requirements_txt(path: str) -> list[tuple[str, str]]:
    """Extract (name, version) pairs from a requirements.txt file.

    Handles pinned (==), range (>=, ~=, >, <), and bare package names.
    Skips comment lines and blank lines.

    Args:
        path: Path to requirements.txt.

    Returns:
        List of (package_name, version) tuples. Version is "" when omitted.

    Raises:
        FileNotFoundError: If the file does not exist.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")

    deps: list[tuple[str, str]] = []
    with open(p) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # Strip inline comments
            line = line.split("#")[0].strip()
            # Match package name and optional version specifier
            # Handles ==, >=, <=, ~=, !=, >, <
            m = re.match(r"^([A-Za-z0-9_\-\.]+)\s*([><=!~]+\s*[\w\.\*]+)?", line)
            if m:
                name = m.group(1)
                spec = (m.group(2) or "").strip()
                # Extract just the version number from pinned constraints
                if spec.startswith("=="):
                    version = spec[2:].strip()
                elif spec:
                    # For ranges like >=2.0.0, store the constraint as-is
                    version = spec
                else:
                    version = ""
                deps.append((name, version))

    return deps


# ---------------------------------------------------------------------------
# License lookup (mock-able)
# ---------------------------------------------------------------------------

def lookup_license(package_name: str, mock_db: dict[str, Optional[str]]) -> Optional[str]:
    """Look up the license for a package using the provided database.

    In production this would call a real license API (e.g. libraries.io).
    For testing, a mock_db dict is injected instead.

    Args:
        package_name: The package name (case-insensitive lookup).
        mock_db: Dict mapping package names to SPDX license strings (or None).

    Returns:
        SPDX license string, or None if the package/license is unknown.
    """
    # Case-insensitive lookup
    lower_name = package_name.lower()
    for key, value in mock_db.items():
        if key.lower() == lower_name:
            return value
    return None


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

def classify_license(license_id: Optional[str], config: dict) -> str:
    """Classify a license as 'approved', 'denied', or 'unknown'.

    Args:
        license_id: SPDX identifier string, or None.
        config: Dict with 'allow' and 'deny' lists of SPDX identifiers.

    Returns:
        One of: 'approved', 'denied', 'unknown'.
    """
    if license_id is None:
        return "unknown"

    if license_id in config.get("deny", []):
        return "denied"

    if license_id in config.get("allow", []):
        return "approved"

    return "unknown"


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(
    deps: list[tuple[str, str]],
    mock_db: dict[str, Optional[str]],
    config: dict,
) -> dict:
    """Build a structured compliance report for a list of dependencies.

    Args:
        deps: List of (package_name, version) tuples.
        mock_db: License lookup database (see lookup_license).
        config: License allow/deny configuration.

    Returns:
        Dict with keys:
            - dependencies: list of per-dep dicts
            - summary: {approved, denied, unknown, total}
            - passed: True if no denied licenses were found
    """
    results = []
    counts = {"approved": 0, "denied": 0, "unknown": 0}

    for name, version in deps:
        license_id = lookup_license(name, mock_db)
        status = classify_license(license_id, config)
        counts[status] += 1
        results.append({
            "name": name,
            "version": version,
            "license": license_id,
            "status": status,
        })

    return {
        "dependencies": results,
        "summary": {**counts, "total": len(deps)},
        "passed": counts["denied"] == 0,
    }


# ---------------------------------------------------------------------------
# Report formatting
# ---------------------------------------------------------------------------

def format_report(report: dict) -> str:
    """Format a compliance report as a human-readable string.

    Args:
        report: Output of generate_report().

    Returns:
        Multi-line string suitable for printing to stdout.
    """
    lines = []
    lines.append("=== Dependency License Compliance Report ===")
    lines.append("")

    # Group by status
    by_status: dict[str, list] = {"approved": [], "denied": [], "unknown": []}
    for dep in report["dependencies"]:
        by_status[dep["status"]].append(dep)

    for status in ("approved", "denied", "unknown"):
        group = by_status[status]
        if not group:
            continue
        lines.append(f"[{status.upper()}]")
        for dep in group:
            lic = dep["license"] or "unknown"
            lines.append(f"  {dep['name']}@{dep['version']} - {lic}")
        lines.append("")

    s = report["summary"]
    lines.append(
        f"Summary: {s['approved']} approved, {s['denied']} denied, {s['unknown']} unknown "
        f"(total: {s['total']})"
    )

    verdict = "PASSED" if report["passed"] else "FAILED"
    lines.append(f"Result: {verdict}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entrypoint
# ---------------------------------------------------------------------------

def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check dependency licenses against an allow/deny list."
    )
    parser.add_argument(
        "--manifest", required=True,
        help="Path to package.json or requirements.txt",
    )
    parser.add_argument(
        "--config", required=True,
        help="Path to JSON config with 'allow' and 'deny' license lists",
    )
    parser.add_argument(
        "--mock-db", required=False, default=None,
        help="Path to JSON file mapping package names to SPDX license strings (for testing)",
    )
    parser.add_argument(
        "--include-dev", action="store_true",
        help="Include devDependencies from package.json",
    )
    parser.add_argument(
        "--format", choices=["text", "json"], default="text",
        help="Output format (default: text)",
    )
    args = parser.parse_args(argv)

    # Load config
    try:
        with open(args.config) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: Config file not found: {args.config}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid config JSON: {e}", file=sys.stderr)
        return 2

    # Load mock license DB (if provided; otherwise use an empty dict)
    mock_db: dict[str, Optional[str]] = {}
    if args.mock_db:
        try:
            with open(args.mock_db) as f:
                mock_db = json.load(f)
        except FileNotFoundError:
            print(f"ERROR: Mock DB file not found: {args.mock_db}", file=sys.stderr)
            return 2
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid mock DB JSON: {e}", file=sys.stderr)
            return 2

    # Parse manifest
    manifest_path = args.manifest
    try:
        if manifest_path.endswith("package.json") or manifest_path.endswith(".json"):
            deps = parse_package_json(manifest_path, include_dev=args.include_dev)
        else:
            deps = parse_requirements_txt(manifest_path)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    if not deps:
        print("No dependencies found in manifest.", file=sys.stderr)

    # Generate report
    report = generate_report(deps, mock_db, config)

    # Output
    if args.format == "json":
        print(json.dumps(report, indent=2))
    else:
        print(format_report(report))

    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
