"""
Dependency License Checker

Parses package.json or requirements.txt, looks up each dependency's license
against a mock database, checks it against allow/deny lists from a config file,
and prints a compliance report.

Usage:
  python3 license_checker.py <manifest> <config> [license_db]

  manifest:    path to package.json or requirements.txt
  config:      path to JSON file with {"allow": [...], "deny": [...]}
  license_db:  path to mock license database JSON (optional; defaults to empty)
"""
import json
import sys
from pathlib import Path
from typing import Optional

# Status constants — used throughout report generation
APPROVED = "approved"
DENIED = "denied"
UNKNOWN = "unknown"


# ============================================================
# Manifest parsers
# ============================================================

def parse_package_json(path: str) -> dict[str, str]:
    """Extract dependencies and devDependencies from package.json.

    Strips semver range prefixes (^, ~, >=, <=) from version strings so that
    the version stored is always a plain semver like "18.2.0".
    """
    with open(path) as f:
        data = json.load(f)

    if not isinstance(data, dict):
        raise ValueError(f"Invalid package.json at {path}: expected JSON object")

    deps: dict[str, str] = {}
    for section in ("dependencies", "devDependencies"):
        section_data = data.get(section, {})
        if not isinstance(section_data, dict):
            raise ValueError(f"Invalid package.json: {section} must be a JSON object")
        for name, version in section_data.items():
            # Strip leading range operators; take the first version token
            clean = str(version).lstrip("^~>=<").split(" ")[0].split(",")[0]
            deps[name] = clean
    return deps


def parse_requirements_txt(path: str) -> dict[str, str]:
    """Extract package names and versions from a requirements.txt file.

    Supports ==, >=, <=, ~=, !=, > and < specifiers.
    Lines without a specifier receive version '*'.
    Comments and blank lines are skipped.
    """
    deps: dict[str, str] = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            # Skip blanks, comments, and pip options (-r, -c, --index-url, …)
            if not line or line.startswith("#") or line.startswith("-"):
                continue
            # Try each specifier from longest to shortest to avoid partial matches
            for sep in ("==", ">=", "~=", "<=", "!=", ">", "<"):
                if sep in line:
                    name, rest = line.split(sep, 1)
                    # Keep only the first version in a multi-constraint spec
                    version = rest.strip().split(",")[0].strip()
                    deps[name.strip()] = version
                    break
            else:
                # No specifier — accept any version
                deps[line] = "*"
    return deps


def parse_manifest(path: str) -> dict[str, str]:
    """Auto-detect the manifest format by filename and delegate to the right parser.

    Raises ValueError for unsupported formats so callers get a helpful message.
    """
    name = Path(path).name
    if name == "package.json":
        return parse_package_json(path)
    elif name == "requirements.txt":
        return parse_requirements_txt(path)
    else:
        raise ValueError(
            f"Unsupported manifest format: '{name}'. "
            "Supported: package.json, requirements.txt"
        )


# ============================================================
# License lookup and status classification
# ============================================================

def lookup_license(name: str, version: str, license_db: dict) -> Optional[str]:
    """Look up a package's license in the mock database.

    Tries 'name@version' first (exact pin), then 'name' alone (any version).
    Returns None if the package is not in the database at all.
    """
    exact_key = f"{name}@{version}"
    if exact_key in license_db:
        return license_db[exact_key]
    return license_db.get(name)


def check_license_status(
    license: Optional[str],
    allow_list: list,
    deny_list: list,
) -> str:
    """Classify a license as approved, denied, or unknown.

    Deny list wins over allow list (defensive default).
    None (lookup failed) → unknown.
    """
    if license is None:
        return UNKNOWN
    if license in deny_list:
        return DENIED
    if license in allow_list:
        return APPROVED
    return UNKNOWN


# ============================================================
# Report generation
# ============================================================

def check_dependencies(
    deps: dict[str, str],
    allow_list: list,
    deny_list: list,
    license_db: dict,
) -> list[dict]:
    """Check every dependency and return a sorted list of result dicts.

    Each result: {name, version, license (str), status}.
    """
    results = []
    for name, version in sorted(deps.items()):
        lic = lookup_license(name, version, license_db)
        status = check_license_status(lic, allow_list, deny_list)
        results.append({
            "name": name,
            "version": version,
            # Store "unknown" string rather than None for cleaner output
            "license": lic if lic is not None else "unknown",
            "status": status,
        })
    return results


def generate_report(
    manifest_path: str,
    config_path: str,
    license_db: dict,
) -> list[dict]:
    """Full pipeline: load config → parse manifest → check each dependency."""
    with open(config_path) as f:
        config = json.load(f)

    allow_list: list = config.get("allow", [])
    deny_list: list = config.get("deny", [])

    deps = parse_manifest(manifest_path)
    return check_dependencies(deps, allow_list, deny_list, license_db)


def format_report(results: list[dict]) -> str:
    """Render results as a human-readable compliance report."""
    lines = [
        "Dependency License Compliance Report",
        "=" * 44,
    ]

    for r in results:
        lines.append(
            f"  {r['name']}@{r['version']}: {r['license']} [{r['status'].upper()}]"
        )

    counts = {APPROVED: 0, DENIED: 0, UNKNOWN: 0}
    for r in results:
        counts[r["status"]] += 1

    lines.append("=" * 44)
    lines.append(
        f"Summary: {counts[APPROVED]} approved, "
        f"{counts[DENIED]} denied, "
        f"{counts[UNKNOWN]} unknown"
    )

    if counts[DENIED] > 0:
        lines.append("COMPLIANCE CHECK FAILED: denied licenses found")
    else:
        lines.append("COMPLIANCE CHECK PASSED")

    return "\n".join(lines)


# ============================================================
# CLI entry point
# ============================================================

def main(argv: Optional[list] = None) -> int:
    """Parse args, run the checker, print the report. Returns an exit code."""
    if argv is None:
        argv = sys.argv[1:]

    if len(argv) < 2:
        print(
            "Usage: license_checker.py <manifest> <config> [license_db]\n"
            "  manifest   — package.json or requirements.txt\n"
            "  config     — JSON file with allow/deny license lists\n"
            "  license_db — mock license database JSON (optional)",
            file=sys.stderr,
        )
        return 1

    manifest_path = argv[0]
    config_path = argv[1]
    license_db_path = argv[2] if len(argv) > 2 else None

    for path, label in [(manifest_path, "manifest"), (config_path, "config")]:
        if not Path(path).exists():
            print(f"Error: {label} file not found: {path}", file=sys.stderr)
            return 1

    license_db: dict = {}
    if license_db_path:
        if not Path(license_db_path).exists():
            print(f"Error: license database not found: {license_db_path}", file=sys.stderr)
            return 1
        with open(license_db_path) as f:
            license_db = json.load(f)

    try:
        results = generate_report(manifest_path, config_path, license_db)
    except (ValueError, json.JSONDecodeError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(format_report(results))
    # Always exit 0 — compliance failures are reported, not process failures
    return 0


if __name__ == "__main__":
    sys.exit(main())
