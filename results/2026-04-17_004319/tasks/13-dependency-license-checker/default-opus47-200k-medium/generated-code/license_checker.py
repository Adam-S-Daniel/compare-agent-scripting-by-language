"""
Dependency License Checker.

Parses a Python requirements.txt manifest, looks up each dependency's license,
and classifies each against an allow-list / deny-list of licenses.

The license lookup is abstracted behind the `LicenseLookup` class so tests
(and the real CI pipeline) can inject a mocked mapping. A production version
would swap this for a PyPI JSON API call; here we ship a mock-by-default
module that reads a JSON fixture of {package_name: license}.

TDD drove the design: tests in tests/test_license_checker.py were written
first. See README-style comments on each function for the contract.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable, Mapping


def parse_requirements(path: str) -> list[tuple[str, str]]:
    """Parse a requirements.txt-style manifest.

    Returns list of (name, version) tuples. Lines with no pinned version get
    "unknown" as the version. Blank lines and '#' comments are skipped.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"requirements file not found: {path}")

    deps: list[tuple[str, str]] = []
    for raw in p.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "==" in line:
            name, _, version = line.partition("==")
            deps.append((name.strip(), version.strip()))
        else:
            # Unpinned or uses a different specifier — we don't try to
            # resolve it here, just record the name.
            name = line.split(";", 1)[0].split()[0]
            deps.append((name, "unknown"))
    return deps


def check_license(license_id: str | None, config: Mapping[str, Iterable[str]]) -> str:
    """Classify a license id against the allow/deny config.

    Returns one of: "approved", "denied", "unknown".
    - deny-list wins over allow-list if both mention the same id
    - None/missing license => "unknown"
    """
    if license_id is None:
        return "unknown"
    deny = set(config.get("deny", []))
    allow = set(config.get("allow", []))
    if license_id in deny:
        return "denied"
    if license_id in allow:
        return "approved"
    return "unknown"


class LicenseLookup:
    """Mockable license lookup.

    In production this would call the PyPI JSON API. For tests we inject a
    dict of {package: license}. For CI we load a JSON fixture.
    """

    def __init__(self, mapping: Mapping[str, str]):
        self._mapping = dict(mapping)

    def get(self, package_name: str) -> str | None:
        return self._mapping.get(package_name)

    @classmethod
    def from_json_file(cls, path: str) -> "LicenseLookup":
        data = json.loads(Path(path).read_text())
        return cls(data)


def generate_report(
    deps: list[tuple[str, str]],
    config: Mapping[str, Iterable[str]],
    lookup: LicenseLookup,
) -> dict:
    """Build a compliance report dict with per-dependency status and a summary."""
    entries = []
    counts = {"approved": 0, "denied": 0, "unknown": 0}
    for name, version in deps:
        lic = lookup.get(name)
        status = check_license(lic, config)
        counts[status] += 1
        entries.append({
            "name": name,
            "version": version,
            "license": lic,
            "status": status,
        })
    return {
        "dependencies": entries,
        "summary": {**counts, "total": len(entries)},
    }


def load_config(path: str) -> dict:
    """Load allow/deny license config from JSON."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"config not found: {path}")
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"invalid JSON in config file {path}: {e}") from e


def format_report_text(report: dict) -> str:
    """Render the report as a human-readable text block."""
    lines = ["Dependency License Compliance Report", "=" * 40]
    for d in report["dependencies"]:
        lines.append(
            f"{d['name']}=={d['version']}  license={d['license']}  status={d['status'].upper()}"
        )
    s = report["summary"]
    lines.append("-" * 40)
    lines.append(
        f"Total: {s['total']}  Approved: {s['approved']}  Denied: {s['denied']}  Unknown: {s['unknown']}"
    )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Dependency license checker")
    ap.add_argument("--requirements", required=True, help="Path to requirements.txt")
    ap.add_argument("--config", required=True, help="Path to license allow/deny JSON")
    ap.add_argument(
        "--lookup",
        required=True,
        help="Path to mock license lookup JSON ({package: license})",
    )
    ap.add_argument("--output", default=None, help="Optional path to write JSON report")
    ap.add_argument(
        "--fail-on-denied",
        action="store_true",
        help="Exit 1 if any dependency has status=denied",
    )
    args = ap.parse_args(argv)

    try:
        deps = parse_requirements(args.requirements)
        config = load_config(args.config)
        lookup = LicenseLookup.from_json_file(args.lookup)
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    report = generate_report(deps, config, lookup)
    print(format_report_text(report))

    if args.output:
        Path(args.output).write_text(json.dumps(report, indent=2))

    if args.fail_on_denied and report["summary"]["denied"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
