"""Dependency license compliance checker.

Approach:
- Parse a manifest file (package.json or requirements.txt) into a {name: version}
  dict. Dispatch based on filename so we have one entry point.
- Look up each dependency's license via an injectable callable. Default CLI
  implementation reads from a JSON "license database" file — this is the mock
  used in tests and in CI. In production you would swap in a real registry call.
- Classify each license against allow/deny lists. Deny wins over allow
  (fail-closed). Anything not on either list, or with no known license, is
  "unknown".
- Emit a structured JSON compliance report. Exit code 1 if non-compliant.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Callable, Dict, List, Optional


class ManifestError(Exception):
    """Raised when a manifest file cannot be read or parsed."""


LicenseLookup = Callable[[str, str], Optional[str]]


def parse_package_json(path: str) -> Dict[str, str]:
    """Extract dependencies + devDependencies from an npm package.json."""
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError as e:
        raise ManifestError(f"manifest not found: {path}") from e
    except json.JSONDecodeError as e:
        raise ManifestError(f"invalid JSON in {path}: {e}") from e

    deps: Dict[str, str] = {}
    for key in ("dependencies", "devDependencies"):
        for name, version in (data.get(key) or {}).items():
            deps[name] = version
    return deps


def parse_requirements_txt(path: str) -> Dict[str, str]:
    """Parse a pip requirements.txt — very loose (good enough for a report)."""
    try:
        with open(path) as f:
            lines = f.readlines()
    except FileNotFoundError as e:
        raise ManifestError(f"manifest not found: {path}") from e

    deps: Dict[str, str] = {}
    for raw in lines:
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        # Split on the first specifier character. "*" means "any version".
        for i, ch in enumerate(line):
            if ch in "=<>!~":
                name = line[:i].strip()
                version = line[i:].strip()
                deps[name] = version
                break
        else:
            deps[line] = "*"
    return deps


def parse_manifest(path: str) -> Dict[str, str]:
    """Dispatch to the right parser based on filename."""
    if not os.path.exists(path):
        raise ManifestError(f"manifest not found: {path}")
    base = os.path.basename(path).lower()
    if base == "package.json":
        return parse_package_json(path)
    if base == "requirements.txt":
        return parse_requirements_txt(path)
    raise ManifestError(f"unsupported manifest type: {base}")


def check_license(
    name: str,
    version: str,
    allow: List[str],
    deny: List[str],
    lookup: LicenseLookup,
) -> Dict:
    """Classify one dependency. Deny wins if both lists contain the license."""
    license_id = lookup(name, version)
    if license_id is None:
        status = "unknown"
    elif license_id in deny:
        status = "denied"
    elif license_id in allow:
        status = "approved"
    else:
        status = "unknown"
    return {"name": name, "version": version, "license": license_id, "status": status}


def generate_report(entries: List[Dict]) -> Dict:
    """Aggregate per-dependency results into a summary report."""
    summary = {"approved": 0, "denied": 0, "unknown": 0, "total": len(entries)}
    for e in entries:
        summary[e["status"]] += 1
    return {
        "summary": summary,
        "compliant": summary["denied"] == 0,
        "dependencies": entries,
    }


def run(manifest_path: str, config: Dict, lookup: LicenseLookup) -> Dict:
    """End-to-end: parse manifest, classify each dep, build report."""
    deps = parse_manifest(manifest_path)
    allow = config.get("allow", [])
    deny = config.get("deny", [])
    entries = [check_license(n, v, allow, deny, lookup) for n, v in deps.items()]
    return generate_report(entries)


def _db_lookup(db: Dict[str, str]) -> LicenseLookup:
    """Build a lookup callable from a dict — the mock used in CLI/CI."""
    return lambda name, _version: db.get(name)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Dependency license compliance checker")
    parser.add_argument("--manifest", required=True, help="path to package.json or requirements.txt")
    parser.add_argument("--config", required=True, help="JSON file with 'allow' and 'deny' arrays")
    parser.add_argument("--license-db", required=True, help="JSON file mapping dep name -> license ID (mock)")
    parser.add_argument("--output", required=True, help="where to write the JSON report")
    args = parser.parse_args(argv)

    try:
        with open(args.config) as f:
            config = json.load(f)
        with open(args.license_db) as f:
            db = json.load(f)
        report = run(args.manifest, config, lookup=_db_lookup(db))
    except ManifestError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR reading config/db: {e}", file=sys.stderr)
        return 2

    with open(args.output, "w") as f:
        json.dump(report, f, indent=2)

    s = report["summary"]
    print(f"License compliance report: {s['approved']} approved, "
          f"{s['denied']} denied, {s['unknown']} unknown (of {s['total']})")
    for dep in report["dependencies"]:
        print(f"  [{dep['status'].upper():8s}] {dep['name']}@{dep['version']} -> {dep['license']}")
    print(f"Compliant: {report['compliant']}")

    return 0 if report["compliant"] else 1


if __name__ == "__main__":
    sys.exit(main())
