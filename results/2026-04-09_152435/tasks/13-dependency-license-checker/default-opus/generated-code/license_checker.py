#!/usr/bin/env python3
"""
Dependency License Checker

Parses dependency manifests (package.json, requirements.txt), checks each
dependency's license against an allow-list and deny-list, and generates
a compliance report.

License lookups are injected as a callable to support mocking in tests.
"""
import json
import os
import re
import sys


def parse_package_json(filepath):
    """Parse a package.json file and extract dependency names and versions.

    Extracts from both 'dependencies' and 'devDependencies' sections.
    Returns a list of dicts with 'name' and 'version' keys.
    """
    with open(filepath, "r") as f:
        data = json.load(f)

    deps = []
    for section in ("dependencies", "devDependencies"):
        for name, version in data.get(section, {}).items():
            deps.append({"name": name, "version": version})
    return deps


def parse_requirements_txt(filepath):
    """Parse a requirements.txt file and extract dependency names and versions.

    Skips comments (lines starting with #) and blank lines.
    Handles ==, >=, <=, ~=, != version specifiers; uses 'unknown' if no version.
    Returns a list of dicts with 'name' and 'version' keys.
    """
    with open(filepath, "r") as f:
        lines = f.readlines()

    deps = []
    for line in lines:
        line = line.strip()
        # Skip blank lines and comments
        if not line or line.startswith("#"):
            continue
        # Split on version specifiers
        match = re.match(r"^([a-zA-Z0-9_.-]+)\s*(?:[><=!~]+)\s*(.+)$", line)
        if match:
            deps.append({"name": match.group(1), "version": match.group(2)})
        else:
            # Package with no version constraint
            deps.append({"name": line.strip(), "version": "unknown"})
    return deps


def parse_manifest(filepath):
    """Parse a dependency manifest file, auto-detecting format by filename.

    Supports: package.json, requirements.txt
    Raises ValueError for unsupported formats, FileNotFoundError for missing files.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Manifest file not found: {filepath}")

    basename = os.path.basename(filepath)
    if basename.endswith(".json") and "package" in basename:
        return parse_package_json(filepath)
    elif basename.endswith(".txt") and "requirements" in basename:
        return parse_requirements_txt(filepath)
    else:
        raise ValueError(f"Unsupported manifest format: {basename}")


def load_config(filepath):
    """Load license configuration from a JSON file.

    Config should have 'allowed_licenses' and 'denied_licenses' arrays.
    Raises FileNotFoundError for missing files, ValueError for invalid JSON.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Config file not found: {filepath}")

    with open(filepath, "r") as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in config file: {e}")

    return config


def check_compliance(deps, config, license_lookup_fn):
    """Check each dependency's license against the allow/deny lists.

    Args:
        deps: List of {"name": str, "version": str} dicts.
        config: Dict with "allowed_licenses" and "denied_licenses" lists.
        license_lookup_fn: Callable(name, version) -> license string or None.

    Returns:
        List of result dicts with name, version, license, and status fields.
        Status is one of: 'approved', 'denied', 'unknown'.
    """
    allowed = set(config.get("allowed_licenses", []))
    denied = set(config.get("denied_licenses", []))
    results = []

    for dep in deps:
        license_id = license_lookup_fn(dep["name"], dep["version"])

        if license_id and license_id in denied:
            status = "denied"
        elif license_id and license_id in allowed:
            status = "approved"
        else:
            status = "unknown"

        results.append({
            "name": dep["name"],
            "version": dep["version"],
            "license": license_id,
            "status": status,
        })

    return results


def generate_report(results):
    """Generate a human-readable compliance report from check results.

    Includes per-dependency status and a summary with counts.
    Returns the report as a string.
    """
    lines = []
    lines.append("=" * 60)
    lines.append("  Dependency License Compliance Report")
    lines.append("=" * 60)
    lines.append("")

    approved_count = sum(1 for r in results if r["status"] == "approved")
    denied_count = sum(1 for r in results if r["status"] == "denied")
    unknown_count = sum(1 for r in results if r["status"] == "unknown")

    for r in results:
        status_label = r["status"].upper()
        license_str = r["license"] if r["license"] else "N/A"
        lines.append(f"  [{status_label}] {r['name']}@{r['version']} - {license_str}")

    lines.append("")
    lines.append("-" * 60)
    lines.append(f"  Summary: Approved: {approved_count} | Denied: {denied_count} | Unknown: {unknown_count}")
    lines.append(f"  Total: {len(results)}")
    lines.append("")

    if denied_count > 0:
        lines.append("  Result: FAIL - Denied licenses found")
    else:
        lines.append("  Result: PASS - No denied licenses")

    lines.append("=" * 60)
    return "\n".join(lines)


# Built-in mock license database for demo/CI use
MOCK_LICENSE_DB = {
    "express": "MIT",
    "lodash": "MIT",
    "jest": "MIT",
    "react": "MIT",
    "webpack": "MIT",
    "typescript": "Apache-2.0",
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "pandas": "BSD-3-Clause",
    "django": "BSD-3-Clause",
    "scipy": "BSD-3-Clause",
    "gpl-lib": "GPL-3.0",
    "agpl-lib": "AGPL-3.0",
}


def mock_license_lookup(name, version):
    """Built-in mock license lookup using a static database."""
    return MOCK_LICENSE_DB.get(name)


def main():
    """CLI entry point. Usage: python license_checker.py <manifest> <config>"""
    if len(sys.argv) < 3:
        print("Usage: python license_checker.py <manifest_file> <config_file>")
        print("  manifest_file: path to package.json or requirements.txt")
        print("  config_file:   path to license config JSON")
        sys.exit(1)

    manifest_path = sys.argv[1]
    config_path = sys.argv[2]

    try:
        deps = parse_manifest(manifest_path)
        config = load_config(config_path)
        results = check_compliance(deps, config, mock_license_lookup)
        report = generate_report(results)
        print(report)

        # Exit with non-zero status if any denied licenses found
        denied = [r for r in results if r["status"] == "denied"]
        sys.exit(1 if denied else 0)

    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
