"""
Dependency License Checker

Parses dependency manifests (package.json, requirements.txt), looks up licenses
for each dependency, checks them against allow/deny lists, and generates a
compliance report.

License lookups are abstracted behind a function interface to allow mocking
in tests.
"""

import json
import os
import re
import sys


def parse_manifest(filepath):
    """Parse a dependency manifest file and return a list of {name, version} dicts.

    Supports package.json and requirements.txt formats.
    Detects format by filename.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Manifest file not found: {filepath}")

    basename = os.path.basename(filepath)

    with open(filepath, "r") as f:
        if basename == "package.json":
            return _parse_package_json(f)
        elif basename == "requirements.txt":
            return _parse_requirements_txt(f)
        else:
            raise ValueError(f"Unsupported manifest format: {basename}")


def _parse_package_json(f):
    """Extract dependencies from a package.json file."""
    try:
        data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in package.json: {e}") from e
    deps = []
    for section in ("dependencies", "devDependencies"):
        for name, version in data.get(section, {}).items():
            deps.append({"name": name, "version": version})
    return deps


def _parse_requirements_txt(f):
    """Extract dependencies from a requirements.txt file.

    Handles pinned (==), minimum (>=), compatible (~=) versions, and bare names.
    Skips comments (#) and blank lines.
    """
    # Pattern: package_name followed by optional version specifier
    pattern = re.compile(r'^([A-Za-z0-9_.-]+)\s*(.*)')
    deps = []
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = pattern.match(line)
        if match:
            name = match.group(1)
            version = match.group(2).strip() if match.group(2).strip() else "*"
            deps.append({"name": name, "version": version})
    return deps


def lookup_licenses(dependencies, license_resolver=None):
    """Look up the license for each dependency using the provided resolver.

    license_resolver: callable(name, version) -> str (license identifier)
    If no resolver is provided, returns 'Unknown' for all.
    """
    results = []
    for dep in dependencies:
        license_id = None
        if license_resolver:
            license_id = license_resolver(dep["name"], dep["version"])
        results.append({
            "name": dep["name"],
            "version": dep["version"],
            "license": license_id if license_id else "Unknown",
        })
    return results


def check_compliance(dependencies_with_licenses, config):
    """Check each dependency's license against allow/deny lists from config.

    Deny list takes precedence over allow list.
    Returns a new list with a 'status' field: 'approved', 'denied', or 'unknown'.
    """
    allowed = set(config.get("allowed_licenses", []))
    denied = set(config.get("denied_licenses", []))
    results = []
    for dep in dependencies_with_licenses:
        lic = dep["license"]
        # Deny takes precedence; unknown license string also maps to unknown status
        if lic in denied:
            status = "denied"
        elif lic in allowed:
            status = "approved"
        else:
            status = "unknown"
        results.append({**dep, "status": status})
    return results


def generate_report(compliance_results):
    """Generate a human-readable compliance report.

    Returns a formatted string with per-dependency status and summary counts.
    Overall result is PASS (no denied deps) or FAIL (any denied deps).
    """
    lines = []
    lines.append("=" * 60)
    lines.append("Dependency License Compliance Report")
    lines.append("=" * 60)
    lines.append("")

    approved_count = 0
    denied_count = 0
    unknown_count = 0

    for dep in compliance_results:
        status_label = dep["status"].upper()
        lines.append(f"  {dep['name']} ({dep['version']}) - {dep['license']} - {status_label}")
        if dep["status"] == "approved":
            approved_count += 1
        elif dep["status"] == "denied":
            denied_count += 1
        else:
            unknown_count += 1

    total = len(compliance_results)
    lines.append("")
    lines.append("-" * 60)
    lines.append(f"Total: {total}")
    lines.append(f"Approved: {approved_count}")
    lines.append(f"Denied: {denied_count}")
    lines.append(f"Unknown: {unknown_count}")
    lines.append("-" * 60)

    overall = "FAIL" if denied_count > 0 else "PASS"
    lines.append(f"Overall: {overall}")
    lines.append("=" * 60)

    return "\n".join(lines)


def load_config(filepath):
    """Load license configuration (allow/deny lists) from a JSON file."""
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Config file not found: {filepath}")
    with open(filepath, "r") as f:
        return json.load(f)


# Built-in mock license database for testing without real network calls.
# Maps package name -> license SPDX identifier.
MOCK_LICENSE_DB = {
    "express": "MIT",
    "lodash": "MIT",
    "jest": "MIT",
    "react": "MIT",
    "flask": "BSD-3-Clause",
    "requests": "Apache-2.0",
    "django": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "pandas": "BSD-3-Clause",
    "gpl-pkg": "GPL-3.0",
    "agpl-lib": "AGPL-3.0",
    "left-pad": "WTFPL",
}


def mock_license_resolver(name, version):
    """Mock resolver that returns licenses from a built-in database."""
    return MOCK_LICENSE_DB.get(name)


def main():
    """CLI entry point: usage: python license_checker.py <manifest> <config>"""
    if len(sys.argv) != 3:
        print("Usage: python license_checker.py <manifest_file> <config_file>", file=sys.stderr)
        sys.exit(1)

    manifest_path = sys.argv[1]
    config_path = sys.argv[2]

    try:
        config = load_config(config_path)
        deps = parse_manifest(manifest_path)
        deps_with_licenses = lookup_licenses(deps, license_resolver=mock_license_resolver)
        results = check_compliance(deps_with_licenses, config)
        report = generate_report(results)
        print(report)

        # Exit with non-zero if any denied dependencies
        if any(r["status"] == "denied" for r in results):
            sys.exit(2)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
