"""
Dependency License Checker - Parse manifests and check licenses against allow/deny lists.

TDD Approach:
1. parse_manifest: Extract dependencies from various formats
2. get_license: Mock license lookup (can be replaced with real API)
3. check_licenses: Validate each dependency against config
4. generate_report: Format results for output
"""

import json
import re
from typing import List, Dict, Optional, Any


def parse_manifest(manifest: Any, manifest_type: str = "package.json") -> List[Dict[str, str]]:
    """
    Parse dependency manifest and extract name+version pairs.

    Args:
        manifest: Either dict (for JSON) or string (for text formats)
        manifest_type: Type of manifest ("package.json" or "requirements.txt")

    Returns:
        List of dicts with 'name' and 'version' keys
    """
    if manifest_type == "package.json":
        return _parse_package_json(manifest)
    elif manifest_type == "requirements.txt":
        return _parse_requirements_txt(manifest)
    else:
        raise ValueError(f"Unsupported manifest type: {manifest_type}")


def _parse_package_json(manifest: Dict) -> List[Dict[str, str]]:
    """Extract dependencies from package.json dict."""
    deps = []
    dependencies = manifest.get("dependencies", {})
    for name, version in dependencies.items():
        deps.append({"name": name, "version": version})
    return deps


def _parse_requirements_txt(content: str) -> List[Dict[str, str]]:
    """Extract dependencies from requirements.txt format string."""
    deps = []
    for line in content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        # Handle both formats: name==version and name>=version
        # If only name (no operator), use name as-is
        # If operator exists, include operator in version
        match = re.match(r'([a-zA-Z0-9\-_.]+)(==|>=|<=|~=|>|<|!=)?(.*)$', line)
        if match:
            name = match.group(1)
            op = match.group(2) or ""
            version_part = match.group(3) or ""
            # For == operator, just use the version without operator
            # For other operators, include the operator
            if op == "==":
                version = version_part
            else:
                version = f"{op}{version_part}"
            deps.append({"name": name, "version": version})
    return deps


def get_license(name: str, version: str) -> Optional[str]:
    """
    Mock license lookup. In production, this would query an API.
    Returns None if license is unknown.
    """
    # This is a mock - in real scenarios, query npm registry, PyPI, etc.
    return None


def check_licenses(
    dependencies: List[Dict[str, str]],
    config: Dict[str, Any]
) -> List[Dict[str, Any]]:
    """
    Check each dependency's license against allow/deny lists.

    Args:
        dependencies: List of dicts with 'name' and 'version'
        config: Dict with 'allow_licenses' and 'deny_licenses' lists

    Returns:
        List of dicts with license status information
    """
    allow_list = config.get("allow_licenses", [])
    deny_list = config.get("deny_licenses", [])

    report = []
    for dep in dependencies:
        name = dep["name"]
        version = dep["version"]

        license_name = get_license(name, version)

        status_entry = {
            "name": name,
            "version": version,
            "license": license_name
        }

        if license_name is None:
            status_entry["status"] = "unknown"
            status_entry["reason"] = f"Could not determine license for {name}"
        elif license_name in deny_list:
            status_entry["status"] = "denied"
            status_entry["reason"] = f"{license_name} in deny-list"
        elif license_name in allow_list:
            status_entry["status"] = "approved"
        else:
            status_entry["status"] = "unknown"
            status_entry["reason"] = f"{license_name} not in allow-list"

        report.append(status_entry)

    return report


def generate_report(report: List[Dict[str, Any]]) -> str:
    """
    Format compliance report for display.

    Args:
        report: List of dependency status dicts from check_licenses()

    Returns:
        Formatted string report
    """
    lines = [
        "=" * 80,
        "DEPENDENCY LICENSE COMPLIANCE REPORT",
        "=" * 80
    ]

    approved = [d for d in report if d["status"] == "approved"]
    denied = [d for d in report if d["status"] == "denied"]
    unknown = [d for d in report if d["status"] == "unknown"]

    lines.append(f"\nSummary: {len(approved)} approved, {len(denied)} denied, {len(unknown)} unknown")

    if approved:
        lines.append("\n✓ APPROVED:")
        for dep in approved:
            lines.append(f"  {dep['name']}@{dep['version']} [{dep['license']}]")

    if denied:
        lines.append("\n✗ DENIED:")
        for dep in denied:
            lines.append(f"  {dep['name']}@{dep['version']} [{dep['license']}] - {dep.get('reason', '')}")

    if unknown:
        lines.append("\n? UNKNOWN:")
        for dep in unknown:
            lines.append(f"  {dep['name']}@{dep['version']} - {dep.get('reason', '')}")

    lines.append("\n" + "=" * 80)
    return "\n".join(lines)


def load_config(config_path: str) -> Dict[str, Any]:
    """Load license config from JSON file."""
    with open(config_path, 'r') as f:
        return json.load(f)


def main(manifest_path: str, config_path: str, manifest_type: str = "package.json"):
    """
    Main entry point: Load manifest, config, check licenses, output report.
    """
    # Load config
    config = load_config(config_path)

    # Load and parse manifest
    if manifest_type == "package.json":
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        dependencies = parse_manifest(manifest, "package.json")
    else:
        with open(manifest_path, 'r') as f:
            content = f.read()
        dependencies = parse_manifest(content, manifest_type)

    # Check licenses
    report = check_licenses(dependencies, config)

    # Generate and print report
    formatted_report = generate_report(report)
    print(formatted_report)

    return report


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Usage: python license_checker.py <manifest_path> <config_path> [manifest_type]")
        sys.exit(1)

    manifest_path = sys.argv[1]
    config_path = sys.argv[2]
    manifest_type = sys.argv[3] if len(sys.argv) > 3 else "package.json"

    main(manifest_path, config_path, manifest_type)
