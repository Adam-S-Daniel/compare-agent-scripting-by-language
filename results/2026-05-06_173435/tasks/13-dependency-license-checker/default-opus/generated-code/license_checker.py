"""
Dependency License Checker

Parses dependency manifests (package.json, requirements.txt), looks up licenses,
and checks compliance against configurable allow/deny lists.

Built using TDD - each function was implemented to satisfy a specific failing test.
"""
import json
import re
import sys

# Mock license database - simulates an external license lookup service.
# In production this would call an API like libraries.io or npm registry.
LICENSE_DB = {
    "express": "MIT",
    "lodash": "MIT",
    "jest": "MIT",
    "react": "MIT",
    "webpack": "MIT",
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "django": "BSD-3-Clause",
    "redis": "GPL-3.0",
    "readline": "GPL-3.0",
    "mysql-connector": "GPL-3.0",
}


def parse_manifest(content: str, filename: str) -> list[dict]:
    """Parse a dependency manifest file and return list of {name, version} dicts."""
    if filename == "package.json":
        return _parse_package_json(content)
    elif filename == "requirements.txt":
        return _parse_requirements_txt(content)
    else:
        raise ValueError(f"Unsupported manifest type: {filename}")


def _parse_package_json(content: str) -> list[dict]:
    try:
        data = json.loads(content)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in package.json: {e}")

    deps = []
    for section in ("dependencies", "devDependencies"):
        for name, version in data.get(section, {}).items():
            deps.append({"name": name, "version": version})
    return deps


def _parse_requirements_txt(content: str) -> list[dict]:
    deps = []
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.match(r"^([a-zA-Z0-9_.-]+)\s*(.*)", line)
        if match:
            name = match.group(1)
            version = match.group(2).strip()
            deps.append({"name": name, "version": version})
    return deps


def lookup_license(package_name: str) -> str:
    """Look up the license for a package. Returns 'UNKNOWN' if not found."""
    return LICENSE_DB.get(package_name, "UNKNOWN")


def check_compliance(license_name: str, config: dict) -> str:
    """Check a license against allow/deny lists. Returns approved/denied/unknown."""
    if license_name in config.get("denied_licenses", []):
        return "denied"
    if license_name in config.get("allowed_licenses", []):
        return "approved"
    return "unknown"


def generate_report(deps: list[dict], config: dict) -> list[dict]:
    """Generate a compliance report for a list of dependencies."""
    report = []
    for dep in deps:
        license_name = lookup_license(dep["name"])
        status = check_compliance(license_name, config)
        report.append({
            "name": dep["name"],
            "version": dep["version"],
            "license": license_name,
            "status": status,
        })
    return report


def format_report(report: list[dict]) -> str:
    """Format the compliance report as human-readable text."""
    lines = []
    lines.append("=" * 60)
    lines.append("DEPENDENCY LICENSE COMPLIANCE REPORT")
    lines.append("=" * 60)
    lines.append("")

    approved = [e for e in report if e["status"] == "approved"]
    denied = [e for e in report if e["status"] == "denied"]
    unknown = [e for e in report if e["status"] == "unknown"]

    for entry in report:
        status_label = entry["status"].upper()
        lines.append(f"{status_label}: {entry['name']}@{entry['version']} ({entry['license']})")

    lines.append("")
    lines.append(f"Summary: {len(approved)} approved, {len(denied)} denied, {len(unknown)} unknown")
    lines.append("")

    if denied:
        lines.append("ERROR: Denied licenses found!")
        return "\n".join(lines)

    if unknown:
        lines.append("WARNING: Unknown licenses found - manual review required.")
        return "\n".join(lines)

    lines.append("All dependencies have approved licenses.")
    return "\n".join(lines)


def run_checker(manifest_path: str, config_path: str) -> list[dict]:
    """Run the full license check pipeline."""
    with open(manifest_path, "r") as f:
        manifest_content = f.read()

    with open(config_path, "r") as f:
        config = json.load(f)

    filename = manifest_path.split("/")[-1]
    deps = parse_manifest(manifest_content, filename)
    return generate_report(deps, config)


def main():
    if len(sys.argv) < 3:
        print("Usage: python license_checker.py <manifest_file> <config_file>")
        print("  manifest_file: path to package.json or requirements.txt")
        print("  config_file: path to license config JSON")
        sys.exit(1)

    manifest_path = sys.argv[1]
    config_path = sys.argv[2]

    try:
        report = run_checker(manifest_path, config_path)
        output = format_report(report)
        print(output)

        # Exit with non-zero if any denied licenses found
        if any(entry["status"] == "denied" for entry in report):
            sys.exit(2)
    except (ValueError, FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
