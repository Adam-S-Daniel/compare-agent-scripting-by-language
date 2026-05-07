"""Dependency license compliance checker.

Parses a manifest (package.json or requirements.txt), resolves each dependency's
license via a pluggable lookup function (mocked for testing), and classifies it
against an allow / deny policy. Emits a text or JSON compliance report.

Design notes
------------
- Lookup is injected as a callable so tests can avoid network calls. The CLI
  accepts ``--mock-licenses`` (a JSON dict) which becomes the lookup; in a real
  deployment you'd replace this with a registry-backed resolver.
- License names are normalized to upper-case for case-insensitive matching.
- "Deny wins" when a license appears in both lists -- fail-safe default for
  compliance.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Callable, Iterable


class Status(str, Enum):
    APPROVED = "approved"
    DENIED = "denied"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class Result:
    name: str
    version: str
    license: str | None
    status: Status


@dataclass(frozen=True)
class Config:
    allow: set[str]
    deny: set[str]


# Lookup signature: name -> license SPDX id (or None if not found).
LookupFn = Callable[[str], "str | None"]


# --- Manifest parsing ---------------------------------------------------

def parse_manifest(path: str) -> dict[str, str]:
    """Parse a manifest file and return ``{name: version_spec}``.

    Supports package.json (npm) and requirements.txt (pip). The manifest type
    is inferred from the filename.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")

    name = p.name
    if name == "package.json" or p.suffix == ".json":
        return _parse_package_json(p)
    if name == "requirements.txt" or p.suffix == ".txt":
        return _parse_requirements_txt(p)
    raise ValueError(
        f"Unsupported manifest type: {name}. Supported: package.json, requirements.txt"
    )


def _parse_package_json(p: Path) -> dict[str, str]:
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {p.name}: {e}") from e
    deps: dict[str, str] = {}
    for key in ("dependencies", "devDependencies", "peerDependencies"):
        deps.update(data.get(key) or {})
    return deps


# pip requirement spec: ``name<op>version`` where op is one of ==, >=, <=, ~=,
# !=, >, <. We split on the first such operator we find.
_PIP_OPS = ("==", ">=", "<=", "~=", "!=", ">", "<")


def _parse_requirements_txt(p: Path) -> dict[str, str]:
    deps: dict[str, str] = {}
    for raw in p.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        name, version = _split_pip_req(line)
        deps[name] = version
    return deps


def _split_pip_req(line: str) -> tuple[str, str]:
    for op in _PIP_OPS:
        i = line.find(op)
        if i >= 0:
            name = line[:i].strip()
            rest = line[i:].strip()
            # Convention: drop the `==` exact-pin so the version reads as a
            # plain SemVer string; keep other operators because they convey
            # meaning (>=2.0 differs from 2.0).
            if op == "==":
                return name, rest[2:].strip()
            return name, rest
    # Bare package name with no version pin.
    return line.strip(), "*"


# --- Config loading -----------------------------------------------------

def load_config(path: str) -> Config:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {p.name}: {e}") from e
    return Config(
        allow={s.upper() for s in (data.get("allow") or [])},
        deny={s.upper() for s in (data.get("deny") or [])},
    )


# --- Checking -----------------------------------------------------------

class LicenseChecker:
    """Classifies a single dependency against the allow / deny policy."""

    def __init__(self, allow: set[str], deny: set[str], lookup: LookupFn):
        # Store normalized for case-insensitive comparisons.
        self.allow = {s.upper() for s in allow}
        self.deny = {s.upper() for s in deny}
        self.lookup = lookup

    def check(self, name: str, version: str) -> Result:
        lic = self.lookup(name)
        if lic is None:
            return Result(name, version, None, Status.UNKNOWN)
        norm = lic.upper()
        # Deny takes precedence over allow -- fail-safe.
        if norm in self.deny:
            return Result(name, version, lic, Status.DENIED)
        if norm in self.allow:
            return Result(name, version, lic, Status.APPROVED)
        return Result(name, version, lic, Status.UNKNOWN)


def check_dependencies(
    deps: dict[str, str],
    allow: set[str],
    deny: set[str],
    lookup: LookupFn,
) -> list[Result]:
    checker = LicenseChecker(allow=allow, deny=deny, lookup=lookup)
    return [checker.check(name, ver) for name, ver in deps.items()]


# --- Reporting ----------------------------------------------------------

def generate_report(results: Iterable[Result], fmt: str = "text") -> str:
    results = list(results)
    counts = {s: 0 for s in Status}
    for r in results:
        counts[r.status] += 1

    if fmt == "json":
        return json.dumps({
            "summary": {s.value: counts[s] for s in Status},
            "dependencies": [
                {
                    "name": r.name,
                    "version": r.version,
                    "license": r.license,
                    "status": r.status.value,
                }
                for r in results
            ],
        }, indent=2)

    if fmt != "text":
        raise ValueError(f"Unsupported report format: {fmt}")

    lines = ["License compliance report", "=" * 26, ""]
    for r in results:
        lic = r.license or "(unknown)"
        lines.append(f"  {r.name}@{r.version}  license={lic}  status={r.status.value.upper()}")
    lines += [
        "",
        "Summary:",
        f"  approved: {counts[Status.APPROVED]}",
        f"  denied: {counts[Status.DENIED]}",
        f"  unknown: {counts[Status.UNKNOWN]}",
    ]
    return "\n".join(lines)


# --- CLI ----------------------------------------------------------------

def _build_lookup(arg: str | None) -> LookupFn:
    """Build a lookup function from a JSON map (testing mock).

    A real implementation would query an SPDX database / package registry; this
    pluggable seam keeps that swap easy.
    """
    if not arg:
        return lambda _name: None
    try:
        mapping = json.loads(arg)
    except json.JSONDecodeError as e:
        raise ValueError(f"--mock-licenses must be JSON: {e}") from e
    if not isinstance(mapping, dict):
        raise ValueError("--mock-licenses must be a JSON object")
    return lambda name: mapping.get(name)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check dependency licenses against an allow/deny policy.",
    )
    parser.add_argument("--manifest", required=True, help="Path to package.json or requirements.txt")
    parser.add_argument("--config", required=True, help="Path to policy JSON {allow, deny}")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument(
        "--mock-licenses",
        default=None,
        help="JSON object mapping package name -> license id (for testing).",
    )
    parser.add_argument("--output", default=None, help="Write report to this file (default: stdout)")
    args = parser.parse_args(argv)

    try:
        deps = parse_manifest(args.manifest)
        cfg = load_config(args.config)
        lookup = _build_lookup(args.mock_licenses)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    results = check_dependencies(deps, cfg.allow, cfg.deny, lookup)
    report = generate_report(results, fmt=args.format)

    if args.output:
        Path(args.output).write_text(report)
    else:
        print(report)

    # Exit non-zero if any dependency is denied. Unknown does NOT fail the
    # build by default -- treat it as a warning the report surfaces.
    return 1 if any(r.status == Status.DENIED for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
