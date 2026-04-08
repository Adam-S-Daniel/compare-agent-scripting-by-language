"""
Dependency License Checker

Parses dependency manifests (package.json, requirements.txt, etc.),
looks up each dependency's license, and generates a compliance report
against configurable allow/deny lists.
"""

import argparse
import json
import os
import re
import sys


def parse_manifest(filepath: str) -> list[dict]:
    """Parse a dependency manifest file and return a list of {name, version} dicts.

    Supports package.json and requirements.txt formats.
    Raises FileNotFoundError or ValueError on bad input.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Manifest not found: {filepath}")

    filename = os.path.basename(filepath)

    if filename == "package.json":
        return _parse_package_json(filepath)
    elif filename == "requirements.txt":
        return _parse_requirements_txt(filepath)
    else:
        raise ValueError(f"Unsupported manifest format: {filename}")


def _parse_package_json(filepath: str) -> list[dict]:
    """Extract dependencies and devDependencies from a package.json."""
    with open(filepath) as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in {filepath}: {e}")

    deps = []
    for section in ("dependencies", "devDependencies"):
        for name, version in data.get(section, {}).items():
            deps.append({"name": name, "version": version})
    return deps


# Regex: package name, then optional version specifier (==, >=, ~=, !=, <=, etc.)
_REQ_LINE = re.compile(r'^([A-Za-z0-9_][A-Za-z0-9._-]*)\s*((?:[><=!~]=?|===).+)?$')


def _parse_requirements_txt(filepath: str) -> list[dict]:
    """Extract dependency names and version specifiers from requirements.txt."""
    with open(filepath) as f:
        lines = f.readlines()

    deps = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("-"):
            continue
        m = _REQ_LINE.match(line)
        if m:
            name = m.group(1)
            raw_ver = m.group(2)
            if not raw_ver:
                version = "*"
            elif raw_ver.startswith("=="):
                # Pinned version — strip the == prefix for cleaner output
                version = raw_ver[2:]
            else:
                version = raw_ver
            deps.append({"name": name, "version": version})
    return deps


class LicenseLookup:
    """Looks up the license for a package by name.

    Accepts a `registry` dict mapping package names to license strings.
    This makes it easy to inject a mock for testing without hitting the network.
    """

    def __init__(self, registry: dict[str, str] | None = None):
        # Build a case-insensitive index for reliable lookups
        self._registry: dict[str, str] = {}
        for name, license_id in (registry or {}).items():
            self._registry[name.lower()] = license_id

    def get_license(self, package_name: str) -> str | None:
        """Return the SPDX license identifier for a package, or None if unknown."""
        return self._registry.get(package_name.lower())


class LicenseConfig:
    """Configuration specifying which licenses are allowed and which are denied.

    Licenses not in either list result in an "unknown" compliance status.
    Comparison is case-insensitive.
    """

    def __init__(self, allowed: list[str], denied: list[str]):
        self.allowed = {lic.lower() for lic in allowed}
        self.denied = {lic.lower() for lic in denied}

    def classify(self, license_id: str | None) -> str:
        """Return 'approved', 'denied', or 'unknown' for a given license."""
        if license_id is None:
            return "unknown"
        lower = license_id.lower()
        if lower in self.denied:
            return "denied"
        if lower in self.allowed:
            return "approved"
        return "unknown"


def load_config(filepath: str) -> LicenseConfig:
    """Load a LicenseConfig from a JSON file with 'allowed' and 'denied' keys."""
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Config file not found: {filepath}")
    with open(filepath) as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in config {filepath}: {e}")
    return LicenseConfig(
        allowed=data.get("allowed", []),
        denied=data.get("denied", []),
    )


def check_compliance(
    deps: list[dict],
    lookup: LicenseLookup,
    config: LicenseConfig,
) -> list[dict]:
    """Check each dependency's license against the config allow/deny lists.

    Returns a list of dicts with keys: name, version, license, status.
    """
    results = []
    for dep in deps:
        license_id = lookup.get_license(dep["name"])
        status = config.classify(license_id)
        results.append({
            "name": dep["name"],
            "version": dep["version"],
            "license": license_id,
            "status": status,
        })
    return results


_STATUS_SYMBOLS = {"approved": "✓", "denied": "✗", "unknown": "?"}


def generate_report(results: list[dict], fmt: str = "text") -> str:
    """Generate a compliance report from check_compliance results.

    fmt="text" -> human-readable table
    fmt="json" -> structured JSON with summary
    """
    summary = _build_summary(results)

    if fmt == "json":
        return json.dumps({"dependencies": results, "summary": summary}, indent=2)

    # Text format
    lines = ["Dependency License Compliance Report", "=" * 42, ""]
    for r in results:
        sym = _STATUS_SYMBOLS.get(r["status"], "?")
        lic = r["license"] or "N/A"
        lines.append(f"  [{sym}] {r['name']}@{r['version']}  license={lic}  {r['status'].upper()}")
    lines.append("")
    lines.append(f"Total: {summary['total']}  "
                 f"Approved: {summary['approved']}  "
                 f"Denied: {summary['denied']}  "
                 f"Unknown: {summary['unknown']}")
    lines.append(f"Compliant: {'YES' if summary['compliant'] else 'NO'}")
    return "\n".join(lines)


def _build_summary(results: list[dict]) -> dict:
    counts = {"approved": 0, "denied": 0, "unknown": 0}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    return {
        "total": len(results),
        **counts,
        "compliant": counts["denied"] == 0,
    }


def main(argv: list[str] | None = None) -> int:
    """CLI entry point. Returns 0 if compliant, 1 if denied deps found, 2 on error."""
    parser = argparse.ArgumentParser(description="Dependency License Checker")
    parser.add_argument("manifest", help="Path to manifest file (package.json or requirements.txt)")
    parser.add_argument("--config", required=True, help="Path to license config JSON")
    parser.add_argument("--registry", help="Path to mock license registry JSON (name->license map)")
    parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    args = parser.parse_args(argv)

    try:
        deps = parse_manifest(args.manifest)
        config = load_config(args.config)

        # Load registry from file or use empty (all unknown)
        registry = {}
        if args.registry:
            with open(args.registry) as f:
                registry = json.load(f)

        lookup = LicenseLookup(registry=registry)
        results = check_compliance(deps, lookup, config)
        print(generate_report(results, fmt=args.format))

        return 0 if _build_summary(results)["compliant"] else 1
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
