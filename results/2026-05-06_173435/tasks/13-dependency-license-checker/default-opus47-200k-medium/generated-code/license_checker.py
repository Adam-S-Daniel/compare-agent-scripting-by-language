"""Dependency license compliance checker.

Reads a manifest (package.json or requirements.txt), looks up each
dependency's license, then classifies it against an allow/deny list.

The license lookup is pluggable: a `lookup` callable taking a package name
and returning a license string (or None) is injected into `build_report`.
For real use you'd hit npm/PyPI; in tests and in the demo `--mock` mode we
substitute a static dict so behavior is deterministic.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Callable, Iterable, List, Optional, Tuple

Dep = Tuple[str, str]


class LicenseLookupError(Exception):
    """Raised by a lookup function when it cannot reach its data source."""


# A built-in mock "license database" used when --mock is passed on the CLI.
# Keeping this here lets the workflow run hermetically with no network calls.
_MOCK_DB = {
    "left-pad": "MIT",
    "lodash": "MIT",
    "jest": "MIT",
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "evil-lib": "GPL-3.0",
    "copyleft-thing": "GPL-3.0",
    "good": "MIT",
    "bad": "GPL-3.0",
}


def _default_lookup(name: str) -> Optional[str]:
    """Default lookup used by the CLI in --mock mode. Tests patch this."""
    return _MOCK_DB.get(name)


def parse_manifest(path: str) -> List[Dep]:
    """Parse a manifest file, returning a list of (name, version) tuples.

    Supports package.json (npm) and requirements.txt (pip).
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"manifest not found: {path}")

    lower = path.lower()
    if lower.endswith(".json"):
        return _parse_package_json(path)
    if lower.endswith(".txt"):
        return _parse_requirements_txt(path)
    raise ValueError(
        f"unsupported manifest format: {path} "
        "(expected .json package manifest or .txt requirements file)"
    )


def _parse_package_json(path: str) -> List[Dep]:
    with open(path) as f:
        data = json.load(f)
    deps: List[Dep] = []
    # Both runtime and dev deps are in scope for license compliance.
    for section in ("dependencies", "devDependencies"):
        for name, version in (data.get(section) or {}).items():
            deps.append((name, version))
    return deps


# Match e.g. "requests==2.31.0", "flask>=2.0", "numpy~=1.24", "name<3"
_REQ_RE = re.compile(
    r"^\s*([A-Za-z0-9_.\-]+)\s*((?:==|>=|<=|~=|!=|>|<).*?)?\s*(?:#.*)?$"
)


def _parse_requirements_txt(path: str) -> List[Dep]:
    deps: List[Dep] = []
    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            m = _REQ_RE.match(line)
            if not m:
                continue
            name = m.group(1)
            version = (m.group(2) or "").strip()
            # Treat exact pins ("==X") as the bare version; keep range
            # operators (>=, ~=, etc.) intact.
            if version.startswith("=="):
                version = version[2:].strip()
            deps.append((name, version))
    return deps


def check_license(
    license_name: Optional[str],
    allow: Iterable[str],
    deny: Iterable[str],
) -> str:
    """Classify a license string.

    Returns one of: "approved", "denied", "unknown". Denial wins when a
    license appears in both lists — the safer default for compliance.
    """
    if license_name is None:
        return "unknown"
    if license_name in set(deny):
        return "denied"
    if license_name in set(allow):
        return "approved"
    return "unknown"


def build_report(
    deps: Iterable[Dep],
    config: dict,
    lookup: Callable[[str], Optional[str]],
) -> List[dict]:
    """Resolve each dep's license via `lookup` and classify it."""
    allow = config.get("allow", [])
    deny = config.get("deny", [])
    rows: List[dict] = []
    for name, version in deps:
        row = {"name": name, "version": version, "license": None,
               "status": "unknown", "error": None}
        try:
            lic = lookup(name)
        except LicenseLookupError as e:
            row["error"] = str(e)
            rows.append(row)
            continue
        row["license"] = lic
        row["status"] = check_license(lic, allow, deny)
        rows.append(row)
    return rows


def load_config(path: str) -> dict:
    """Load the allow/deny config, defaulting missing keys to empty lists."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"config not found: {path}")
    with open(path) as f:
        data = json.load(f)
    return {
        "allow": list(data.get("allow", [])),
        "deny": list(data.get("deny", [])),
    }


def format_report(report: List[dict]) -> str:
    """Pretty-print the report as a human-readable table + summary."""
    lines = ["Dependency License Compliance Report",
             "=" * 60,
             f"{'NAME':<24} {'VERSION':<14} {'LICENSE':<14} STATUS"]
    for row in report:
        lines.append(
            f"{row['name']:<24} {str(row['version']):<14} "
            f"{str(row['license'] or '-'):<14} {row['status']}"
        )
        if row.get("error"):
            lines.append(f"  ! lookup error: {row['error']}")
    counts = {"approved": 0, "denied": 0, "unknown": 0}
    for row in report:
        counts[row["status"]] += 1
    lines.append("-" * 60)
    lines.append(
        f"Summary: {counts['approved']} approved, "
        f"{counts['denied']} denied, {counts['unknown']} unknown"
    )
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> Tuple[int, str]:
    """CLI entry point. Returns (exit_code, printed_output) for testability."""
    parser = argparse.ArgumentParser(
        description="Check dependency licenses against an allow/deny list."
    )
    parser.add_argument("--manifest", required=True,
                        help="Path to package.json or requirements.txt")
    parser.add_argument("--config", required=True,
                        help="Path to JSON config with 'allow' and 'deny' lists")
    parser.add_argument("--mock", action="store_true",
                        help="Use built-in mock license database (no network)")
    parser.add_argument("--json", action="store_true",
                        help="Emit machine-readable JSON instead of a table")
    args = parser.parse_args(argv)

    try:
        deps = parse_manifest(args.manifest)
        config = load_config(args.config)
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as e:
        msg = f"ERROR: {e}"
        print(msg, file=sys.stderr)
        return 2, msg

    if not args.mock:
        # Real lookups are out of scope for this exercise; fail loudly so
        # nobody accidentally relies on missing functionality in CI.
        msg = "ERROR: only --mock mode is implemented in this build"
        print(msg, file=sys.stderr)
        return 2, msg

    report = build_report(deps, config, lookup=_default_lookup)

    if args.json:
        output = json.dumps(report, indent=2)
    else:
        output = format_report(report)
    print(output)

    # Exit nonzero if any dep is denied — blocks merges in CI.
    rc = 1 if any(r["status"] == "denied" for r in report) else 0
    return rc, output


if __name__ == "__main__":
    code, _ = main()
    sys.exit(code)
