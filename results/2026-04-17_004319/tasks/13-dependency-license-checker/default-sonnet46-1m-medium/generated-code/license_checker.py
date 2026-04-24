#!/usr/bin/env python3
# Dependency License Checker
# Parses package.json or requirements.txt, checks licenses against
# an allow/deny config, and generates a compliance report.
#
# License lookups are done via MOCK_LICENSE_DB for testability.
# In production, substitute a real PyPI/npm API call.

import json
import re
import sys
from typing import Optional

# ── Mock license database ─────────────────────────────────────────────────────
# Substitutes for real npm/PyPI API calls. Tests use this directly.
MOCK_LICENSE_DB: dict[str, str] = {
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "pandas": "BSD-3-Clause",
    "django": "BSD-3-Clause",
    "pytest": "MIT",
    "black": "MIT",
    "isort": "MIT",
    "click": "BSD-3-Clause",
    "pyyaml": "MIT",
    "pyyaml-env-tag": "MIT",
    "colorama": "BSD-3-Clause",
    "certifi": "MPL-2.0",
    "urllib3": "MIT",
    "charset-normalizer": "MIT",
    "idna": "BSD-3-Clause",
    # Explicitly problematic packages
    "gpl-lib": "GPL-3.0",
    "agpl-package": "AGPL-3.0",
    "lgpl-package": "LGPL-2.1",
    "copyleft-lib": "GPL-2.0",
}


# ── Manifest parsing ──────────────────────────────────────────────────────────

def parse_manifest(path: str) -> dict[str, str]:
    """Parse a dependency manifest and return {name: version} mapping.

    Supports package.json and requirements.txt formats.
    """
    import os
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Manifest not found: {path}")

    filename = os.path.basename(path)

    if filename == "package.json":
        return _parse_package_json(path)
    elif filename == "requirements.txt":
        return _parse_requirements_txt(path)
    else:
        raise ValueError(f"Unsupported manifest format: {filename}. "
                         "Supported: package.json, requirements.txt")


def _parse_package_json(path: str) -> dict[str, str]:
    with open(path) as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in {path}: {e}") from e

    deps: dict[str, str] = {}
    for section in ("dependencies", "devDependencies", "peerDependencies"):
        deps.update(data.get(section, {}))
    return deps


def _parse_requirements_txt(path: str) -> dict[str, str]:
    deps: dict[str, str] = {}
    with open(path) as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith("-"):
                continue
            # Strip extras like package[extra] -> package
            line = re.sub(r"\[.*?\]", "", line)
            # Split on version specifiers: ==, >=, <=, !=, ~=, >
            m = re.match(r"^([A-Za-z0-9_.\-]+)([=<>!~]+(.*))?$", line)
            if m:
                name = m.group(1).strip()
                version = m.group(3).strip() if m.group(3) else "unspecified"
                deps[name] = version
    return deps


# ── Config loading ────────────────────────────────────────────────────────────

def load_config(path: str) -> dict:
    """Load license allow/deny config from a JSON file."""
    import os
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Config not found: {path}")

    with open(path) as f:
        cfg = json.load(f)

    if "allow" not in cfg or "deny" not in cfg:
        raise ValueError("Config must contain both 'allow' and 'deny' lists")
    return cfg


# ── License lookup ────────────────────────────────────────────────────────────

def lookup_license(package: str, db: dict[str, str]) -> Optional[str]:
    """Return the license for a package from the provided database, or None."""
    return db.get(package)


# ── Classification ────────────────────────────────────────────────────────────

def classify_license(license_: Optional[str], config: dict) -> str:
    """Return 'approved', 'denied', or 'unknown'."""
    if license_ is None:
        return "unknown"
    if license_ in config["allow"]:
        return "approved"
    if license_ in config["deny"]:
        return "denied"
    return "unknown"


# ── Report generation ─────────────────────────────────────────────────────────

def generate_report(
    deps: dict[str, str],
    config: dict,
    db: dict[str, str],
) -> dict:
    """Build a structured compliance report dict."""
    approved = []
    denied = []
    unknown = []

    for name in sorted(deps):
        license_ = lookup_license(name, db)
        status = classify_license(license_, config)
        label = license_ if license_ else "unknown"
        entry = f"{name} ({label})"
        if status == "approved":
            approved.append(entry)
        elif status == "denied":
            denied.append(entry)
        else:
            unknown.append(entry)

    return {
        "approved": approved,
        "denied": denied,
        "unknown": unknown,
        "summary": {
            "approved": len(approved),
            "denied": len(denied),
            "unknown": len(unknown),
        },
        # FAIL only when there are denied packages; unknown is a warning
        "status": "FAIL" if denied else "PASS",
    }


# ── Report formatting ─────────────────────────────────────────────────────────

def format_report(report: dict, manifest_path: str) -> str:
    lines = [
        "=== Dependency License Compliance Report ===",
        f"Manifest: {manifest_path}",
        "",
    ]
    for entry in report["approved"]:
        lines.append(f"APPROVED: {entry}")
    for entry in report["denied"]:
        lines.append(f"DENIED: {entry}")
    for entry in report["unknown"]:
        lines.append(f"UNKNOWN: {entry}")

    s = report["summary"]
    lines.append("")
    lines.append(
        f"Summary: {s['approved']} approved, {s['denied']} denied, {s['unknown']} unknown"
    )
    lines.append(f"Status: {report['status']}")
    return "\n".join(lines)


# ── CLI entry point ───────────────────────────────────────────────────────────

def main(argv: list[str] = sys.argv[1:]) -> int:
    if len(argv) < 2:
        print("Usage: license_checker.py <manifest> <config>", file=sys.stderr)
        return 2

    manifest_path, config_path = argv[0], argv[1]

    try:
        deps = parse_manifest(manifest_path)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error reading manifest: {e}", file=sys.stderr)
        return 1

    try:
        config = load_config(config_path)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error reading config: {e}", file=sys.stderr)
        return 1

    report = generate_report(deps, config, MOCK_LICENSE_DB)
    print(format_report(report, manifest_path))

    # Exit 1 if any denied packages found
    return 1 if report["denied"] else 0


if __name__ == "__main__":
    sys.exit(main())
