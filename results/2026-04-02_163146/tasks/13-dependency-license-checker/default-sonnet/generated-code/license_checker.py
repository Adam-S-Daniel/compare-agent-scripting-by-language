"""
Dependency License Checker
==========================

Parses dependency manifests (package.json, requirements.txt), looks up
each dependency's license, and generates a compliance report based on
configurable allow/deny lists.

TDD approach:
  1. parse_package_json / parse_requirements_txt — manifest parsing
  2. check_license — classify a license as APPROVED/DENIED/UNKNOWN
  3. generate_report — run the full check pipeline
  4. load_config — read and validate the configuration file
"""

import json
import re
from enum import Enum
from pathlib import Path
from typing import Callable


# ---------------------------------------------------------------------------
# Domain types
# ---------------------------------------------------------------------------

class LicenseStatus(Enum):
    APPROVED = "approved"
    DENIED   = "denied"
    UNKNOWN  = "unknown"


# ---------------------------------------------------------------------------
# Manifest parsers
# ---------------------------------------------------------------------------

def parse_package_json(path: Path, include_dev: bool = False) -> dict[str, str]:
    """
    Parse a package.json file and return {package_name: version_spec}.

    By default only production dependencies are returned.
    Pass include_dev=True to merge devDependencies as well.

    Raises:
        FileNotFoundError: if the file does not exist.
        ValueError: if the file contains invalid JSON.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"package.json not found: {path}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc

    deps: dict[str, str] = {}
    deps.update(data.get("dependencies", {}))
    if include_dev:
        deps.update(data.get("devDependencies", {}))
    return deps


def parse_requirements_txt(path: Path) -> dict[str, str]:
    """
    Parse a requirements.txt file and return {package_name: version}.

    - Lines starting with '#' and blank lines are ignored.
    - Supports pinned versions (==), ranges (>=, <=, ~=, !=), and bare names.
    - Version is stored as-is; bare package names get version '*'.

    Raises:
        FileNotFoundError: if the file does not exist.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"requirements.txt not found: {path}")

    deps: dict[str, str] = {}
    # Regex: capture package name (before any version specifier or extras)
    pkg_re = re.compile(
        r"^\s*"
        r"([A-Za-z0-9_\-\.]+)"   # package name
        r"(?:\[.*?\])?"           # optional extras, e.g. requests[security]
        r"\s*"
        r"(==|>=|<=|~=|!=|>|<)?" # optional operator
        r"\s*"
        r"([^\s;#]*)"             # optional version number
    )

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("-"):
            continue  # skip comments, blank lines, and pip options like -r

        m = pkg_re.match(line)
        if not m:
            continue

        name = m.group(1)
        operator = m.group(2)
        version = m.group(3)

        # Normalise: pinned (==) → just the version number; others → keep spec
        if operator == "==" and version:
            deps[name] = version
        elif operator and version:
            deps[name] = f"{operator}{version}"
        else:
            deps[name] = "*"

    return deps


# ---------------------------------------------------------------------------
# License classification
# ---------------------------------------------------------------------------

def check_license(
    package_name: str,
    license_id: str | None,
    config: dict,
) -> LicenseStatus:
    """
    Classify a single dependency's license against the allow/deny config.

    Returns:
        LicenseStatus.APPROVED  — license is in the allow list
        LicenseStatus.DENIED    — license is in the deny list
        LicenseStatus.UNKNOWN   — license is None or not in either list
    """
    if license_id is None:
        return LicenseStatus.UNKNOWN

    allow: list[str] = config.get("allow", [])
    deny:  list[str] = config.get("deny",  [])

    if license_id in deny:
        return LicenseStatus.DENIED
    if license_id in allow:
        return LicenseStatus.APPROVED
    return LicenseStatus.UNKNOWN


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(
    deps: dict[str, str],
    config: dict,
    license_lookup: Callable[[str], str | None],
) -> dict:
    """
    Build a full compliance report for the given dependencies.

    Args:
        deps:           {package_name: version_spec} from a manifest parser.
        config:         allow/deny config (see load_config).
        license_lookup: callable(package_name) → SPDX license string or None.
                        Inject a mock in tests; use a real registry client in prod.

    Returns a dict with structure:
        {
          "passed": bool,          # True iff no DENIED packages found
          "summary": {
            "total":    int,
            "approved": int,
            "denied":   int,
            "unknown":  int,
          },
          "results": {
            "<package>": {
              "version": str,
              "license": str | None,
              "status":  str,       # LicenseStatus.value
            },
            ...
          }
        }
    """
    results: dict = {}
    counts = {"approved": 0, "denied": 0, "unknown": 0}

    for name, version in deps.items():
        license_id = license_lookup(name)
        status = check_license(name, license_id, config)
        counts[status.value] += 1
        results[name] = {
            "version": version,
            "license": license_id,
            "status":  status.value,
        }

    return {
        "passed": counts["denied"] == 0,
        "summary": {
            "total":    len(deps),
            "approved": counts["approved"],
            "denied":   counts["denied"],
            "unknown":  counts["unknown"],
        },
        "results": results,
    }


# ---------------------------------------------------------------------------
# Configuration loader
# ---------------------------------------------------------------------------

def load_config(path: Path) -> dict:
    """
    Load and validate the license configuration JSON file.

    Expected schema:
        { "allow": [...], "deny": [...] }

    Raises:
        FileNotFoundError: if the config file does not exist.
        ValueError: if the JSON is invalid or required keys are missing.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path}")

    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in config {path}: {exc}") from exc

    for required_key in ("allow", "deny"):
        if required_key not in config:
            raise ValueError(
                f"Config is missing required key '{required_key}' in {path}"
            )

    return config


# ---------------------------------------------------------------------------
# CLI entry point (optional convenience wrapper)
# ---------------------------------------------------------------------------

def _print_report(report: dict) -> None:
    """Pretty-print a compliance report to stdout."""
    status_icon = {"approved": "✓", "denied": "✗", "unknown": "?"}
    print("\n=== Dependency License Compliance Report ===\n")
    for name, entry in sorted(report["results"].items()):
        icon = status_icon.get(entry["status"], "?")
        lic = entry["license"] or "unknown"
        print(f"  [{icon}] {name} ({entry['version']}) — {lic} [{entry['status'].upper()}]")
    s = report["summary"]
    print(f"\nSummary: {s['total']} total | "
          f"{s['approved']} approved | {s['denied']} denied | {s['unknown']} unknown")
    verdict = "PASS" if report["passed"] else "FAIL"
    print(f"Overall: {verdict}\n")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print(
            "Usage: python license_checker.py <manifest> <config.json>\n"
            "  manifest: path to package.json or requirements.txt\n"
            "  config:   path to license config JSON\n",
            file=sys.stderr,
        )
        sys.exit(1)

    manifest_path = Path(sys.argv[1])
    config_path   = Path(sys.argv[2])

    config = load_config(config_path)

    if manifest_path.name == "package.json":
        deps = parse_package_json(manifest_path)
    elif manifest_path.name.endswith(".txt"):
        deps = parse_requirements_txt(manifest_path)
    else:
        print(f"Unsupported manifest format: {manifest_path}", file=sys.stderr)
        sys.exit(1)

    # In production you'd call a real registry here; for the CLI demo we use
    # a trivial stub that always returns None (unknown).
    def _stub_lookup(pkg: str) -> str | None:
        return None

    report = generate_report(deps, config, _stub_lookup)
    _print_report(report)
    sys.exit(0 if report["passed"] else 1)
