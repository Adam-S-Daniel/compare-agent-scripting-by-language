"""Dependency-license compliance checker.

Parses a manifest (package.json or requirements.txt), looks up each dep's
license via a pluggable DB, and compares against allow/deny lists from a JSON
policy file. The license lookup is mockable so the unit tests run offline.

Run as a script:
    python3 license_checker.py --manifest package.json --policy policy.json

Exit codes:
    0  — all dependencies approved or unknown (no explicit violations)
    1  — at least one dependency is on the deny-list
    2  — usage / input error (missing file, malformed manifest, etc.)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, List, Optional, Protocol, Sequence, Set, Tuple


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------


Status = str  # one of: "approved", "denied", "unknown"


class LicenseDB(Protocol):
    """Minimal interface a license source must implement.

    Real implementations would hit npm/PyPI/Libraries.io. Tests inject a
    dict-backed fake (see tests/fake_license_db.py).
    """

    def get_license(self, name: str, version: str) -> Optional[str]: ...


@dataclass(frozen=True)
class Policy:
    allow: Set[str] = field(default_factory=set)
    deny: Set[str] = field(default_factory=set)


@dataclass(frozen=True)
class DependencyStatus:
    name: str
    version: str
    license: Optional[str]
    status: Status


@dataclass(frozen=True)
class ComplianceReport:
    entries: List[DependencyStatus]

    @property
    def total(self) -> int:
        return len(self.entries)

    @property
    def approved_count(self) -> int:
        return sum(1 for e in self.entries if e.status == "approved")

    @property
    def denied_count(self) -> int:
        return sum(1 for e in self.entries if e.status == "denied")

    @property
    def unknown_count(self) -> int:
        return sum(1 for e in self.entries if e.status == "unknown")

    @property
    def exit_code(self) -> int:
        # Unknowns don't fail CI on their own — operators can tighten later.
        return 1 if self.denied_count > 0 else 0


# ---------------------------------------------------------------------------
# Manifest parsing
# ---------------------------------------------------------------------------


# `pkg==1.0.0`, `pkg>=1`, `pkg<2.0`, `pkg~=1.4`, etc.  PEP 440-ish but we only
# need to split the name from the specifier; we don't resolve versions.
_REQ_LINE = re.compile(
    r"^\s*([A-Za-z0-9][A-Za-z0-9._-]*)\s*((?:[<>=!~]=?|===).*)?\s*$"
)


def parse_manifest(path: Path) -> List[Tuple[str, str]]:
    """Return a list of (name, version_spec) tuples from the manifest."""
    if not path.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")

    suffix = path.suffix.lower()

    # Dispatch by extension so CI fixtures like `sample-package.json` or
    # `dev-requirements.txt` work too. Format is what matters, not the name.
    if suffix == ".json":
        return _parse_package_json(path)
    if suffix == ".txt":
        return _parse_requirements_txt(path)

    raise ValueError(
        f"Unsupported manifest format: {path.name} "
        "(expected a .json package manifest or a .txt requirements file)"
    )


def _parse_package_json(path: Path) -> List[Tuple[str, str]]:
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc

    deps: List[Tuple[str, str]] = []
    # Collect from the usual sections. peerDependencies/optionalDependencies
    # are intentionally included — they ship licenses like everything else.
    for key in (
        "dependencies",
        "devDependencies",
        "peerDependencies",
        "optionalDependencies",
    ):
        section = data.get(key) or {}
        if not isinstance(section, dict):
            raise ValueError(f"{key} in {path} must be an object")
        for pkg, version in section.items():
            deps.append((pkg, str(version)))
    return deps


def _parse_requirements_txt(path: Path) -> List[Tuple[str, str]]:
    deps: List[Tuple[str, str]] = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()  # strip comments + whitespace
        if not line:
            continue
        m = _REQ_LINE.match(line)
        if not m:
            raise ValueError(f"Cannot parse requirement line: {raw!r}")
        name = m.group(1)
        spec = (m.group(2) or "").strip()
        deps.append((name, spec))
    return deps


# ---------------------------------------------------------------------------
# Policy config
# ---------------------------------------------------------------------------


def load_config(path: Path) -> Policy:
    if not path.exists():
        raise FileNotFoundError(f"Policy not found: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc

    return Policy(
        allow=set(data.get("allow") or []),
        deny=set(data.get("deny") or []),
    )


# ---------------------------------------------------------------------------
# Compliance checking
# ---------------------------------------------------------------------------


def check_dependencies(
    deps: Sequence[Tuple[str, str]],
    db: LicenseDB,
    allow: Iterable[str],
    deny: Iterable[str],
) -> ComplianceReport:
    """Classify each dependency against the allow/deny lists.

    Precedence: deny > allow > unknown. A license that's on neither list is
    reported as unknown so operators can decide rather than silently passing.
    """
    allow_set = set(allow)
    deny_set = set(deny)
    entries: List[DependencyStatus] = []
    for name, version in deps:
        license_id = db.get_license(name, version)
        if license_id is None:
            status: Status = "unknown"
        elif license_id in deny_set:
            status = "denied"
        elif license_id in allow_set:
            status = "approved"
        else:
            status = "unknown"
        entries.append(DependencyStatus(name, version, license_id, status))
    return ComplianceReport(entries=entries)


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


_STATUS_LABEL = {
    "approved": "APPROVED",
    "denied": "DENIED",
    "unknown": "UNKNOWN",
}


def render_report(report: ComplianceReport) -> str:
    lines: List[str] = []
    lines.append("Dependency License Compliance Report")
    lines.append("=" * 40)
    if not report.entries:
        lines.append("(no dependencies found)")
    else:
        name_w = max(len(e.name) for e in report.entries)
        ver_w = max(len(e.version) for e in report.entries) if report.entries else 1
        lic_w = max(
            len(e.license or "unknown") for e in report.entries
        )
        for e in report.entries:
            lines.append(
                f"{e.name.ljust(name_w)}  "
                f"{e.version.ljust(ver_w)}  "
                f"{(e.license or 'unknown').ljust(lic_w)}  "
                f"{_STATUS_LABEL[e.status]}"
            )
    lines.append("-" * 40)
    lines.append(
        f"Summary: total={report.total} "
        f"approved={report.approved_count} "
        f"denied={report.denied_count} "
        f"unknown={report.unknown_count}"
    )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Built-in fake DB (used by CI and the test CLI runs so they don't need the
# network). Production deployments would replace this with a real lookup.
# ---------------------------------------------------------------------------


_CI_FAKE_LICENSES = {
    "lodash": "MIT",
    "express": "MIT",
    "jest": "MIT",
    "react": "MIT",
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "pytest": "MIT",
    "banned-pkg": "GPL-3.0",
    "copyleft-lib": "AGPL-3.0",
    "left-pad": "WTFPL",
}


class _BuiltinFakeDB:
    def get_license(self, name: str, version: str) -> Optional[str]:
        return _CI_FAKE_LICENSES.get(name)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Check dependency licenses against allow/deny lists.",
    )
    p.add_argument("--manifest", required=True, help="Path to manifest file")
    p.add_argument("--policy", required=True, help="Path to policy JSON")
    p.add_argument(
        "--fake-db",
        default=None,
        help=(
            "Optional JSON mapping of package name -> license id. Used to "
            "stub the license lookup in CI / tests."
        ),
    )
    return p


def _resolve_db(fake_db_path: Optional[str]) -> LicenseDB:
    """Pick a license source.

    Precedence:
    1. `--fake-db <path>` — load a JSON file and use it as the lookup.
    2. `LICENSE_CHECKER_USE_FAKE=1` env var — use the built-in fake.
    3. Otherwise use the built-in fake too (this demo has no real registry).
    """
    if fake_db_path:
        data = json.loads(Path(fake_db_path).read_text())
        from tests.fake_license_db import FakeLicenseDB

        return FakeLicenseDB(data)
    # The demo has no network-backed DB, so we always fall back to the built-in
    # fake. Real deployments would plug a registry client in here.
    return _BuiltinFakeDB()


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _build_parser().parse_args(argv)

    try:
        deps = parse_manifest(Path(args.manifest))
        policy = load_config(Path(args.policy))
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    db = _resolve_db(args.fake_db)
    report = check_dependencies(deps, db, policy.allow, policy.deny)
    print(render_report(report))
    return report.exit_code


if __name__ == "__main__":
    sys.exit(main())
