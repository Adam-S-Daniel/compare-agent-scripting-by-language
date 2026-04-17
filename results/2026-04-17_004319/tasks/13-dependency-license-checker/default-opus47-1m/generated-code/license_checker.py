"""
Dependency license checker.

Parses a dependency manifest (requirements.txt or package.json), looks up a
license for each dependency (mockable for testing), classifies each against
an allow-list / deny-list, and emits a JSON compliance report.

Exit codes:
    0  — all dependencies approved
    1  — at least one unknown license, no denied licenses ("warn")
    2  — at least one denied license ("fail")
    3  — usage / input error (bad manifest, missing file, etc.)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Callable, Iterable


# Type alias for the license-lookup function. Taking (name, version) keeps the
# signature compatible with a real registry lookup later, even though the mock
# ignores version.
LicenseLookup = Callable[[str, str], "str | None"]


# ---------------------------------------------------------------------------
# Manifest parsing
# ---------------------------------------------------------------------------

def parse_requirements_txt(content: str) -> list[tuple[str, str]]:
    """Parse pip's requirements.txt format.

    Recognizes `name==version`; unpinned names get version 'unknown'. Blank
    lines, `#` comments, and inline comments after two spaces are ignored.
    We intentionally keep this simple — environment markers, extras, and
    `-e` editable installs are out of scope for this checker.
    """
    deps: list[tuple[str, str]] = []
    for raw in content.splitlines():
        # Strip inline comments (anything after a `#`).
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if "==" in line:
            name, version = line.split("==", 1)
            deps.append((name.strip(), version.strip()))
        else:
            deps.append((line, "unknown"))
    return deps


def parse_package_json(content: str) -> list[tuple[str, str]]:
    """Parse an npm package.json, merging dependencies and devDependencies.

    We preserve raw semver spec strings (`^4.17.21`) rather than resolving
    them — license lookup is by name anyway.
    """
    try:
        data = json.loads(content)
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid package.json: {exc}") from exc
    deps: list[tuple[str, str]] = []
    for key in ("dependencies", "devDependencies"):
        section = data.get(key, {}) or {}
        for name, version in section.items():
            deps.append((name, version))
    return deps


def parse_manifest(path: Path) -> list[tuple[str, str]]:
    """Dispatch to the right parser based on filename."""
    name = path.name.lower()
    content = path.read_text()
    if name == "package.json":
        return parse_package_json(content)
    if name.endswith(".txt") or name == "requirements.txt":
        return parse_requirements_txt(content)
    raise ValueError(f"unsupported manifest format: {path.name}")


# ---------------------------------------------------------------------------
# License lookup (mockable)
# ---------------------------------------------------------------------------

def make_mock_lookup(mapping: dict[str, str]) -> LicenseLookup:
    """Build a lookup function backed by an in-memory dict.

    In production this would hit a registry (PyPI JSON API, npm registry,
    etc.). Tests and CI use this mock so results are deterministic and
    offline-friendly.
    """
    def _lookup(name: str, version: str) -> str | None:  # noqa: ARG001
        return mapping.get(name)
    return _lookup


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

def classify_license(
    license_id: str | None,
    allow_list: Iterable[str],
    deny_list: Iterable[str],
) -> str:
    """Classify a single license as 'approved', 'denied', or 'unknown'.

    Deny wins over allow: if a license is on both lists we treat it as denied
    (fail-safe). A missing (None) license or one on neither list is 'unknown'.
    """
    deny = set(deny_list)
    allow = set(allow_list)
    if license_id is None:
        return "unknown"
    if license_id in deny:
        return "denied"
    if license_id in allow:
        return "approved"
    return "unknown"


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(
    deps: list[tuple[str, str]],
    *,
    lookup: LicenseLookup,
    allow_list: Iterable[str],
    deny_list: Iterable[str],
) -> dict:
    """Produce the full compliance report as a plain dict.

    Shape:
        {
          "summary": {"approved": n, "denied": n, "unknown": n, "total": n},
          "overall": "pass" | "warn" | "fail",
          "dependencies": [
             {"name": ..., "version": ..., "license": ..., "status": ...},
             ...
          ]
        }
    """
    entries: list[dict] = []
    counts = {"approved": 0, "denied": 0, "unknown": 0}
    for name, version in deps:
        lic = lookup(name, version)
        status = classify_license(lic, allow_list, deny_list)
        counts[status] += 1
        entries.append({
            "name": name,
            "version": version,
            "license": lic,
            "status": status,
        })

    # Overall: any denial is a hard fail; an unknown is a warn; else pass.
    if counts["denied"] > 0:
        overall = "fail"
    elif counts["unknown"] > 0:
        overall = "warn"
    else:
        overall = "pass"

    return {
        "summary": {**counts, "total": len(deps)},
        "overall": overall,
        "dependencies": entries,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _load_config(path: Path) -> dict:
    try:
        raw = path.read_text()
    except FileNotFoundError:
        raise ValueError(f"config not found: {path}")
    try:
        cfg = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid config JSON in {path}: {exc}") from exc
    cfg.setdefault("allow", [])
    cfg.setdefault("deny", [])
    cfg.setdefault("mock_licenses", {})
    return cfg


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check dependency licenses against allow/deny lists.",
    )
    parser.add_argument("--manifest", required=True, help="Path to requirements.txt or package.json")
    parser.add_argument("--config", required=True, help="Path to JSON config with allow/deny/mock_licenses")
    parser.add_argument(
        "--output",
        default="-",
        help="Where to write the report (default: stdout). Use '-' for stdout.",
    )
    args = parser.parse_args(argv)

    manifest_path = Path(args.manifest)
    config_path = Path(args.config)

    # Input validation with friendly messages (no tracebacks).
    if not manifest_path.exists():
        print(f"error: manifest file not found: {manifest_path}", file=sys.stderr)
        return 3
    try:
        deps = parse_manifest(manifest_path)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    try:
        config = _load_config(config_path)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    lookup = make_mock_lookup(config["mock_licenses"])
    report = generate_report(
        deps,
        lookup=lookup,
        allow_list=config["allow"],
        deny_list=config["deny"],
    )

    payload = json.dumps(report, indent=2)
    if args.output == "-":
        print(payload)
    else:
        Path(args.output).write_text(payload + "\n")

    # Exit code conveys compliance: 0=pass, 1=warn, 2=fail.
    return {"pass": 0, "warn": 1, "fail": 2}[report["overall"]]


if __name__ == "__main__":
    sys.exit(main())
