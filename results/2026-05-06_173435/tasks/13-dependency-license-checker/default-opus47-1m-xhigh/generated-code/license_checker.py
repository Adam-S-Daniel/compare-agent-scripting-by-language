#!/usr/bin/env python3
"""
Dependency license checker.

Reads a dependency manifest (package.json or requirements.txt), looks up the
license for each dependency through an injectable lookup function, and
classifies each dependency against an allow/deny list of licenses to produce
a compliance report.

Design notes
- The license lookup is dependency-injected so tests can mock it and the
  CLI can read from a JSON "license database" file. This keeps everything
  deterministic and offline (no network calls), which is what production
  CI normally wants too.
- Deny overrides allow. If the same SPDX id appears on both lists, deny
  wins (safer default).
- Unknown licenses are flagged as non-compliant. CI should fail closed.
- Comparisons are case-insensitive on the license string.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from typing import Callable, Iterable, List, Optional


# ---------------------------------------------------------------------------
# Domain types
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class Dependency:
    """A single (name, version) pair extracted from a manifest."""

    name: str
    version: str


class Status:
    """String-typed enum for report status values."""

    APPROVED = "approved"
    DENIED = "denied"
    UNKNOWN = "unknown"


# A license lookup is any callable taking (name, version) and returning a
# license string (e.g. an SPDX id) or None when unknown.
LicenseLookup = Callable[[str, str], Optional[str]]


# ---------------------------------------------------------------------------
# Manifest parsing
# ---------------------------------------------------------------------------

def parse_package_json(content: str) -> List[Dependency]:
    """Extract direct dependencies from package.json text.

    Combines `dependencies` and `devDependencies`; each entry becomes
    one Dependency. Order is preserved, dependencies first.
    """
    try:
        data = json.loads(content)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid package.json: {e}") from e

    deps: List[Dependency] = []
    for key in ("dependencies", "devDependencies"):
        block = data.get(key) or {}
        if not isinstance(block, dict):
            raise ValueError(f"Invalid package.json: '{key}' must be an object")
        for name, version in block.items():
            deps.append(Dependency(name=name, version=str(version)))
    return deps


# Matches the `name`+`specifier` portion of a requirements.txt line; PEP 508
# environment markers and extras are stripped to keep things simple.
_REQ_SPLIT = re.compile(r"^([A-Za-z0-9_.\-]+)\s*(.*)$")


def parse_requirements_txt(content: str) -> List[Dependency]:
    """Extract direct dependencies from a requirements.txt body.

    Skips blank lines, comments (`#`), and pip directives (`-r`, `-e`,
    `--something`). Strips inline comments and PEP 508 environment markers.
    The version field preserves the operator + version specifier
    (e.g. ``"==1.2.0"``, ``">=2"``, or empty when unpinned).
    """
    deps: List[Dependency] = []
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("-"):
            continue
        # Strip inline comment.
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        # Strip environment markers / extras to keep the version specifier
        # readable in the report.
        line = line.split(";", 1)[0].strip()
        line = re.sub(r"\[[^\]]*\]", "", line).strip()
        match = _REQ_SPLIT.match(line)
        if not match:
            continue
        name = match.group(1)
        version = match.group(2).strip()
        # For an exact pin (==X) drop the operator so the report shows the
        # plain version. Other specifiers (>=, ~=, <, !=, …) keep theirs.
        if version.startswith("==") and not version.startswith("==="):
            version = version[2:].strip()
        deps.append(Dependency(name=name, version=version))
    return deps


def parse_manifest(path: str) -> List[Dependency]:
    """Detect the manifest format from the filename and parse it."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Manifest not found: {path}")

    lower = path.lower()
    if lower.endswith("package.json"):
        return parse_package_json(content)
    if lower.endswith("requirements.txt"):
        return parse_requirements_txt(content)
    raise ValueError(
        f"Unsupported manifest format: {path} "
        "(supported: package.json, requirements.txt)"
    )


# ---------------------------------------------------------------------------
# Compliance classification
# ---------------------------------------------------------------------------

def _norm(s: Optional[str]) -> Optional[str]:
    return s.strip().lower() if isinstance(s, str) else None


def check_dependency(
    license: Optional[str],
    allow_list: Iterable[str],
    deny_list: Iterable[str],
) -> str:
    """Classify a single dependency by its license.

    Rules:
      - missing/None license  -> UNKNOWN
      - license in deny list  -> DENIED (deny wins on conflict)
      - license in allow list -> APPROVED
      - anything else         -> UNKNOWN
    """
    if license is None or _norm(license) == "":
        return Status.UNKNOWN
    norm_lic = _norm(license)
    deny = {_norm(x) for x in deny_list}
    allow = {_norm(x) for x in allow_list}
    if norm_lic in deny:
        return Status.DENIED
    if norm_lic in allow:
        return Status.APPROVED
    return Status.UNKNOWN


def generate_report(
    dependencies: Iterable[Dependency],
    license_lookup: LicenseLookup,
    config: dict,
) -> dict:
    """Build a compliance report for the given dependencies.

    `config` should contain `allow` (list of permitted SPDX ids) and `deny`
    (list of forbidden SPDX ids); both default to empty.
    """
    allow_list = config.get("allow") or []
    deny_list = config.get("deny") or []
    entries = []
    counts = {Status.APPROVED: 0, Status.DENIED: 0, Status.UNKNOWN: 0}
    for dep in dependencies:
        license = license_lookup(dep.name, dep.version)
        status = check_dependency(license, allow_list, deny_list)
        counts[status] += 1
        entries.append(
            {
                "name": dep.name,
                "version": dep.version,
                "license": license,
                "status": status,
            }
        )
    total = sum(counts.values())
    return {
        "entries": entries,
        "summary": {
            "approved": counts[Status.APPROVED],
            "denied": counts[Status.DENIED],
            "unknown": counts[Status.UNKNOWN],
            "total": total,
        },
        # Strict mode: any deny or unknown breaks compliance.
        "compliant": counts[Status.DENIED] == 0 and counts[Status.UNKNOWN] == 0,
    }


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

_HEADER = "{:<30}  {:<15}  {:<20}  {}".format("DEPENDENCY", "VERSION", "LICENSE", "STATUS")


def format_report_text(report: dict) -> str:
    """Render the report as a human-readable, CI-grep-friendly text block."""
    lines = ["License Compliance Report", "=" * 78, _HEADER, "-" * 78]
    for e in report["entries"]:
        lic = e["license"] if e["license"] is not None else "<unknown>"
        lines.append(
            "{:<30}  {:<15}  {:<20}  {}".format(
                e["name"][:30], (e["version"] or "")[:15], lic[:20], e["status"]
            )
        )
    s = report["summary"]
    lines.append("-" * 78)
    # Stable, machine-readable summary line — CI assertions key on this.
    lines.append(
        f"SUMMARY: approved={s['approved']} denied={s['denied']} "
        f"unknown={s['unknown']} total={s['total']}"
    )
    lines.append(f"COMPLIANT: {'true' if report['compliant'] else 'false'}")
    return "\n".join(lines)


def format_report_json(report: dict) -> str:
    """Render the report as pretty-printed JSON."""
    return json.dumps(report, indent=2, sort_keys=False)


# ---------------------------------------------------------------------------
# License database loader (acts as the mocked lookup for the CLI)
# ---------------------------------------------------------------------------

def make_lookup_from_db(db_path: str) -> LicenseLookup:
    """Build a license lookup from a JSON file mapping name -> license.

    The JSON may be a flat ``{"name": "MIT"}`` map or a nested
    ``{"name": {"version": "MIT"}}`` map (with optional ``"*"`` fallback).
    Anything else returns None for that dependency.
    """
    try:
        with open(db_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"License database not found: {db_path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid license database JSON: {e}") from e

    def lookup(name: str, version: str) -> Optional[str]:
        entry = data.get(name)
        if entry is None:
            return None
        if isinstance(entry, str):
            return entry
        if isinstance(entry, dict):
            return entry.get(version) or entry.get("*")
        return None

    return lookup


def _empty_lookup(_name: str, _version: str) -> Optional[str]:
    return None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="license_checker",
        description=(
            "Parse a dependency manifest and check each dependency's license "
            "against allow/deny lists."
        ),
    )
    p.add_argument("manifest", help="Path to package.json or requirements.txt")
    p.add_argument(
        "--config",
        required=True,
        help="Path to JSON config file with 'allow' and 'deny' license lists",
    )
    p.add_argument(
        "--license-db",
        help=(
            "Optional JSON file mapping dependency name -> license "
            "(used as the mocked license lookup). When omitted all "
            "dependencies fall back to UNKNOWN."
        ),
    )
    p.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format (default: text)",
    )
    p.add_argument(
        "--output",
        help="Write report to this path instead of stdout",
    )
    return p


def main(argv: Optional[List[str]] = None) -> int:
    """CLI entry point. Returns process exit code.

    Exit codes
      0 - all dependencies approved (compliant)
      1 - at least one denied or unknown dependency (non-compliant)
      2 - usage / I/O error
    """
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        deps = parse_manifest(args.manifest)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2

    try:
        with open(args.config, "r", encoding="utf-8") as f:
            try:
                config = json.load(f)
            except json.JSONDecodeError as e:
                print(f"Error: invalid config JSON ({args.config}): {e}", file=sys.stderr)
                return 2
    except FileNotFoundError:
        print(f"Error: config file not found: {args.config}", file=sys.stderr)
        return 2

    if args.license_db:
        try:
            lookup = make_lookup_from_db(args.license_db)
        except (FileNotFoundError, ValueError) as e:
            print(f"Error: {e}", file=sys.stderr)
            return 2
    else:
        lookup = _empty_lookup

    try:
        report = generate_report(deps, lookup, config)
    except Exception as e:  # surface lookup failures meaningfully
        print(f"Error: license lookup failed: {e}", file=sys.stderr)
        return 2

    rendered = (
        format_report_json(report) if args.format == "json" else format_report_text(report)
    )

    if args.output:
        try:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(rendered + "\n")
        except OSError as e:
            print(f"Error: cannot write output file: {e}", file=sys.stderr)
            return 2
    else:
        print(rendered)

    return 0 if report["compliant"] else 1


if __name__ == "__main__":  # pragma: no cover - exercised via subprocess test
    sys.exit(main())
