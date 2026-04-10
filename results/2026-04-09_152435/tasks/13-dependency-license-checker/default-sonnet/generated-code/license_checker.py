"""
Dependency License Checker
==========================
Parses dependency manifests (package.json, requirements.txt), looks up each
dependency's license against a mock license database, checks each license
against configurable allow/deny lists, and generates a compliance report.

TDD implementation: each function was added to satisfy a failing test.

Usage:
    python3 license_checker.py --manifest fixtures/package.json \
        --config config.json --db fixtures/mock_licenses.json
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Round 1: parse_manifest raises FileNotFoundError for missing file
# ---------------------------------------------------------------------------

def parse_manifest(path: str) -> list[dict]:
    """
    Dispatch to the correct parser based on the manifest filename.

    Raises:
        FileNotFoundError: if the path does not exist.
        ValueError: if the file format is not supported.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Manifest file not found: {path}")

    # Round 4: dispatch by filename
    if p.name == "package.json":
        return parse_package_json(path)
    elif p.name == "requirements.txt":
        return parse_requirements_txt(path)
    else:
        raise ValueError(f"Unsupported manifest format: {p.name} (supported: package.json, requirements.txt)")


# ---------------------------------------------------------------------------
# Round 2: parse_package_json
# ---------------------------------------------------------------------------

def parse_package_json(path: str) -> list[dict]:
    """
    Extract dependency names and versions from a package.json file.

    Reads both 'dependencies' and 'devDependencies' sections.
    Version prefix characters (^, ~, >, =, <) are stripped so that
    ''^18.2.0' becomes '18.2.0'.
    """
    with open(path) as f:
        data = json.load(f)

    deps: list[dict] = []
    for section in ("dependencies", "devDependencies"):
        for name, version_spec in data.get(section, {}).items():
            # Strip leading non-digit, non-dot characters (^, ~, >=, etc.)
            version = re.sub(r"^[^0-9]*", "", str(version_spec)) or version_spec
            deps.append({"name": name, "version": version})
    return deps


# ---------------------------------------------------------------------------
# Round 3: parse_requirements_txt
# ---------------------------------------------------------------------------

def parse_requirements_txt(path: str) -> list[dict]:
    """
    Extract dependency names and versions from a requirements.txt file.

    Handles pinned (==), minimum (>=), approximate (~=) versions.
    Lines starting with '#' or blank lines are ignored.
    """
    deps: list[dict] = []
    with open(path) as f:
        for raw_line in f:
            line = raw_line.strip()
            # Skip comments and blank lines
            if not line or line.startswith("#"):
                continue
            # Strip inline comments
            line = line.split("#")[0].strip()
            if not line:
                continue
            # Match "package_name[extra]<op>version" patterns
            match = re.match(
                r"^([A-Za-z0-9_\-\.]+)(?:\[.*?\])?\s*[><=~!]{1,2}\s*([A-Za-z0-9_.]+)",
                line,
            )
            if match:
                deps.append({"name": match.group(1), "version": match.group(2)})
            else:
                # No version specifier — record "unknown" version
                name = re.match(r"^([A-Za-z0-9_\-\.]+)", line)
                if name:
                    deps.append({"name": name.group(1), "version": "unknown"})
    return deps


# ---------------------------------------------------------------------------
# Round 5-8: check_compliance
# ---------------------------------------------------------------------------

def check_compliance(license_id: Optional[str], config: dict) -> str:
    """
    Check whether a license is approved, denied, or unknown.

    Rules (in priority order):
      1. None license (package not found in DB) -> 'unknown'
      2. License in deny list -> 'denied'  (deny takes precedence over allow)
      3. License in allow list -> 'approved'
      4. Otherwise -> 'unknown'

    Comparison is case-insensitive.
    """
    if license_id is None:
        return "unknown"

    upper = license_id.upper()
    deny_set = {l.upper() for l in config.get("deny", [])}
    allow_set = {l.upper() for l in config.get("allow", [])}

    if upper in deny_set:
        return "denied"
    if upper in allow_set:
        return "approved"
    return "unknown"


# ---------------------------------------------------------------------------
# Helpers: load config / mock DB
# ---------------------------------------------------------------------------

def load_config(path: str) -> dict:
    """Load the license allow/deny configuration from a JSON file."""
    with open(path) as f:
        return json.load(f)


def load_license_db(path: str) -> dict:
    """Load the mock license database (name -> SPDX identifier)."""
    with open(path) as f:
        return json.load(f)


def lookup_license(name: str, db: dict) -> Optional[str]:
    """Return the license for a package, or None if not found in the DB."""
    return db.get(name)


# ---------------------------------------------------------------------------
# Round 9-10: generate_report
# ---------------------------------------------------------------------------

def generate_report(manifest_path: str, config_path: str, db_path: str) -> list[dict]:
    """
    Parse the manifest, look up each dependency's license, and return a
    list of compliance entries.

    Each entry is a dict with keys: name, version, license, status.
    """
    deps = parse_manifest(manifest_path)
    config = load_config(config_path)
    db = load_license_db(db_path)

    report = []
    for dep in deps:
        name = dep["name"]
        version = dep["version"]
        lic = lookup_license(name, db)
        status = check_compliance(lic, config)
        report.append({
            "name": name,
            "version": version,
            "license": lic if lic is not None else "UNKNOWN",
            "status": status,
        })
    return report


# ---------------------------------------------------------------------------
# Round 11-13: format_report
# ---------------------------------------------------------------------------

def format_report(entries: list[dict]) -> str:
    """
    Format the compliance report as a human-readable string.

    Each dependency is listed as:
        name==version: LICENSE [status]

    Followed by a summary line and a COMPLIANCE PASSED / COMPLIANCE FAILED
    verdict.
    """
    lines = ["Dependency License Compliance Report", "=" * 40]

    for entry in entries:
        lines.append(
            f"{entry['name']}=={entry['version']}: {entry['license']} [{entry['status']}]"
        )

    approved = [e for e in entries if e["status"] == "approved"]
    denied = [e for e in entries if e["status"] == "denied"]
    unknown = [e for e in entries if e["status"] == "unknown"]

    lines.append("")
    lines.append(
        f"Summary: {len(approved)} approved, {len(denied)} denied, {len(unknown)} unknown"
    )

    if denied:
        lines.append(
            f"COMPLIANCE FAILED: {len(denied)} denied license(s) found: "
            + ", ".join(e["name"] for e in denied)
        )
    else:
        lines.append("COMPLIANCE PASSED")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check dependency licenses for compliance",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--manifest", required=True, help="Path to manifest file (package.json or requirements.txt)")
    parser.add_argument("--config", required=True, help="Path to license allow/deny config JSON")
    parser.add_argument("--db", default="fixtures/mock_licenses.json", help="Path to mock license database JSON")
    args = parser.parse_args()

    try:
        entries = generate_report(args.manifest, args.config, args.db)
        report = format_report(entries)
        print(report)
        # Return non-zero exit code when denied licenses are found
        return 1 if any(e["status"] == "denied" for e in entries) else 0
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
