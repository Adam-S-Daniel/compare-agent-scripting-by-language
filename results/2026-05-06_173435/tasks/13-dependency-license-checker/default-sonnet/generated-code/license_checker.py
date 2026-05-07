"""
Dependency License Checker

Parses package.json or requirements.txt, checks each dependency's license
against an allow-list/deny-list from a config file, and generates a
compliance report.  License lookups are performed against a mock DB so the
tool works in CI without network access.

Usage:
    python3 license_checker.py <manifest> <config.json> [--mock-db <db.json>]

Exit codes:
    0  — no denied packages (compliant or only unknowns)
    1  — at least one denied package found
"""
import json
import re
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Manifest parsers
# ---------------------------------------------------------------------------

def parse_package_json(manifest_path: str) -> list[dict]:
    """Return [{name, version}, ...] from a package.json file."""
    with open(manifest_path) as f:
        data = json.load(f)

    deps: list[dict] = []
    for section in ("dependencies", "devDependencies", "peerDependencies"):
        for name, version_spec in data.get(section, {}).items():
            # Strip leading range operators: ^, ~, >=, <=, >, <, =
            clean = re.sub(r"^[\^~>=<\s]+", "", str(version_spec)).strip()
            deps.append({"name": name, "version": clean})
    return deps


def parse_requirements_txt(manifest_path: str) -> list[dict]:
    """Return [{name, version}, ...] from a requirements.txt file."""
    deps: list[dict] = []
    with open(manifest_path) as f:
        for raw in f:
            line = raw.strip()
            # Skip blank lines, comments, and pip option flags (-r, --index-url…)
            if not line or line.startswith("#") or line.startswith("-"):
                continue
            # Match:  PackageName[extras]  <op>  version
            m = re.match(
                r"^([A-Za-z0-9_\-\.]+)(?:\[.*?\])?\s*[=<>!~]+\s*([^\s#,;]+)",
                line,
            )
            if m:
                deps.append({"name": m.group(1), "version": m.group(2)})
            else:
                # Package listed without version (e.g. "requests")
                name = re.split(r"[\s\[;#]", line)[0]
                deps.append({"name": name, "version": "unspecified"})
    return deps


def parse_manifest(manifest_path: str) -> list[dict]:
    """Auto-detect manifest format by filename/extension and delegate to the right parser."""
    path = Path(manifest_path)
    # Any .json file is treated as a package.json-style manifest
    if path.suffix == ".json" or path.name == "package.json":
        return parse_package_json(manifest_path)
    # requirements.txt or any plain-text file
    if path.name == "requirements.txt" or path.suffix == ".txt":
        return parse_requirements_txt(manifest_path)
    raise ValueError(
        f"Unsupported manifest format: '{path.name}'. "
        "Supported formats: *.json (package.json), requirements.txt / *.txt"
    )


# ---------------------------------------------------------------------------
# License lookup (mock)
# ---------------------------------------------------------------------------

def lookup_license(dep_name: str, license_db: dict) -> Optional[str]:
    """Return the SPDX license ID for *dep_name*, or None if not found."""
    return license_db.get(dep_name)


# ---------------------------------------------------------------------------
# Compliance checker
# ---------------------------------------------------------------------------

def check_compliance(
    deps: list[dict],
    license_db: dict,
    config: dict,
) -> list[dict]:
    """
    Classify each dependency as 'approved', 'denied', or 'unknown'.

    Rules (evaluated in order):
      1. License in deny_list  → denied
      2. License in allow_list → approved
      3. License unknown or not in either list → unknown
    """
    allow_set = set(config.get("allow_list", []))
    deny_set  = set(config.get("deny_list", []))

    results: list[dict] = []
    for dep in deps:
        license_id = lookup_license(dep["name"], license_db)

        if license_id is None:
            status = "unknown"
            license_display = "UNKNOWN"
        elif license_id in deny_set:
            status = "denied"
            license_display = license_id
        elif license_id in allow_set:
            status = "approved"
            license_display = license_id
        else:
            # License known but neither explicitly allowed nor denied
            status = "unknown"
            license_display = license_id

        results.append(
            {
                "name": dep["name"],
                "version": dep["version"],
                "license": license_display,
                "status": status,
            }
        )
    return results


# ---------------------------------------------------------------------------
# Report generator
# ---------------------------------------------------------------------------

def generate_report(compliance_results: list[dict], manifest_path: str = "") -> str:
    """Return a human-readable compliance report as a string."""
    approved = [r for r in compliance_results if r["status"] == "approved"]
    denied   = [r for r in compliance_results if r["status"] == "denied"]
    unknown  = [r for r in compliance_results if r["status"] == "unknown"]

    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("DEPENDENCY LICENSE COMPLIANCE REPORT")
    if manifest_path:
        lines.append(f"Manifest: {manifest_path}")
    lines.append("=" * 60)
    lines.append(
        f"\nSummary: {len(approved)} approved, {len(denied)} denied, {len(unknown)} unknown\n"
    )
    lines.append("-" * 60)
    lines.append(f"{'Package':<30} {'Version':<15} {'License':<20} Status")
    lines.append("-" * 60)
    for r in compliance_results:
        lines.append(
            f"{r['name']:<30} {r['version']:<15} {r['license']:<20} {r['status'].upper()}"
        )
    lines.append("-" * 60)

    if denied:
        lines.append("\nDENIED PACKAGES:")
        for r in denied:
            lines.append(f"  - {r['name']}@{r['version']}: {r['license']}")

    if unknown:
        lines.append("\nUNKNOWN LICENSES:")
        for r in unknown:
            lines.append(f"  - {r['name']}@{r['version']}")

    overall = "NON-COMPLIANT" if denied else "COMPLIANT"
    lines.append(f"\nOverall Status: {overall}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 3:
        print(
            "Usage: license_checker.py <manifest> <config.json> [--mock-db <db.json>]",
            file=sys.stderr,
        )
        sys.exit(1)

    manifest_path = sys.argv[1]
    config_path   = sys.argv[2]
    mock_db_path: Optional[str] = None

    # Parse optional --mock-db flag
    for i, arg in enumerate(sys.argv[3:], start=3):
        if arg == "--mock-db" and i + 1 < len(sys.argv):
            mock_db_path = sys.argv[i + 1]

    try:
        with open(config_path) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in config: {exc}", file=sys.stderr)
        sys.exit(1)

    license_db: dict = {}
    if mock_db_path:
        try:
            with open(mock_db_path) as f:
                license_db = json.load(f)
        except FileNotFoundError:
            print(f"Error: mock DB file not found: {mock_db_path}", file=sys.stderr)
            sys.exit(1)

    try:
        deps = parse_manifest(manifest_path)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    results = check_compliance(deps, license_db, config)
    print(generate_report(results, manifest_path))

    # Non-zero exit when violations exist so CI pipelines can gate on this
    if any(r["status"] == "denied" for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
