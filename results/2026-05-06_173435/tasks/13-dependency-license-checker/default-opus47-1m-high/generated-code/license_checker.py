"""Dependency license checker.

Parses a manifest (package.json / requirements.txt), looks up each
dependency's license, and classifies it against an allow/deny config.

The license lookup is injected so tests can mock it; the CLI also accepts
a ``mock_licenses`` block in the config so the workflow can run fully
hermetically without network access.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Callable, Optional


# A license-lookup callable: (name, version) -> SPDX id or None when unknown.
LicenseLookup = Callable[[str, str], Optional[str]]


class ManifestParseError(Exception):
    """Raised when a manifest can't be read or understood."""


class LicenseLookupError(Exception):
    """Raised by a lookup implementation that wants to signal a transient
    failure (e.g. registry unreachable). check_compliance catches this and
    records the dependency as ``unknown`` rather than aborting the run."""


# ---------------------------------------------------------------------------
# Manifest parsing
# ---------------------------------------------------------------------------

# requirements.txt line: name + optional version specifier. We deliberately
# keep this lightweight rather than pulling in pip's full parser.
_REQ_LINE_RE = re.compile(
    r"""^\s*
        (?P<name>[A-Za-z0-9_.\-]+)            # package name
        \s*
        (?P<spec>(?:==|>=|<=|~=|!=|>|<)\s*[^\s#]+)?   # optional version spec
        \s*(?:\#.*)?$                          # optional trailing comment
    """,
    re.VERBOSE,
)


def parse_manifest(path: str) -> dict[str, str]:
    """Return a flat ``{name: version_spec}`` map from the given manifest.

    Supports ``package.json`` and ``requirements.txt``. Unpinned Python
    requirements are recorded as ``"*"`` so they're still reported.
    """
    if not os.path.exists(path):
        raise ManifestParseError(f"Manifest not found: {path}")

    name = os.path.basename(path).lower()
    if name == "package.json" or path.endswith(".json"):
        return _parse_package_json(path)
    if name == "requirements.txt" or path.endswith(".txt"):
        return _parse_requirements_txt(path)
    raise ManifestParseError(
        f"Unsupported manifest type: {path} (expected package.json or requirements.txt)"
    )


def _parse_package_json(path: str) -> dict[str, str]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise ManifestParseError(f"Invalid JSON in {path}: {exc}") from exc

    deps: dict[str, str] = {}
    for section in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies"):
        block = data.get(section) or {}
        if not isinstance(block, dict):
            raise ManifestParseError(f"{section} in {path} is not an object")
        for n, v in block.items():
            deps[n] = str(v)
    return deps


def _parse_requirements_txt(path: str) -> dict[str, str]:
    deps: dict[str, str] = {}
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            m = _REQ_LINE_RE.match(line)
            if not m:
                # Skip unrecognized lines (e.g. -r other.txt) rather than fail.
                continue
            name = m.group("name")
            spec = (m.group("spec") or "").replace(" ", "")
            # Pinned (==) -> bare version; range/compat -> keep operator.
            if spec.startswith("=="):
                spec = spec[2:]
            deps[name] = spec or "*"
    return deps


# ---------------------------------------------------------------------------
# Compliance check
# ---------------------------------------------------------------------------

def check_compliance(
    deps: dict[str, str],
    config: dict,
    lookup_license: LicenseLookup,
) -> list[dict]:
    """Classify each dependency as approved / denied / unknown.

    Deny-list takes precedence over allow-list (fail-closed). A dependency
    whose license can't be determined is recorded as ``unknown`` with the
    license field set to None.
    """
    allow = {s.lower() for s in config.get("allow", [])}
    deny = {s.lower() for s in config.get("deny", [])}

    report: list[dict] = []
    for name, version in deps.items():
        entry: dict = {"name": name, "version": version, "license": None,
                       "status": "unknown"}
        try:
            license_id = lookup_license(name, version)
        except LicenseLookupError as exc:
            entry["error"] = str(exc)
            report.append(entry)
            continue

        entry["license"] = license_id
        if license_id is None:
            entry["status"] = "unknown"
        else:
            key = license_id.lower()
            if key in deny:
                entry["status"] = "denied"
            elif key in allow:
                entry["status"] = "approved"
            else:
                entry["status"] = "unknown"
        report.append(entry)
    return report


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(entries: list[dict], fmt: str = "text") -> str:
    """Render the compliance report in the chosen format."""
    counts = {"approved": 0, "denied": 0, "unknown": 0}
    for e in entries:
        counts[e["status"]] = counts.get(e["status"], 0) + 1

    if fmt == "json":
        return json.dumps(
            {"summary": counts, "dependencies": entries},
            indent=2, sort_keys=False,
        )
    if fmt == "text":
        lines = ["Dependency License Compliance Report", "=" * 40]
        for e in entries:
            license_str = e["license"] if e["license"] else "<unknown>"
            lines.append(
                f"  [{e['status']:<8}] {e['name']}@{e['version']} -> {license_str}"
            )
        lines.append("")
        lines.append(
            f"Summary: approved={counts['approved']} "
            f"denied={counts['denied']} unknown={counts['unknown']}"
        )
        return "\n".join(lines)
    raise ValueError(f"Unknown format: {fmt}")


# ---------------------------------------------------------------------------
# CLI / main entry point
# ---------------------------------------------------------------------------

def _make_mock_lookup(mock_table: dict[str, str]) -> LicenseLookup:
    """Build a deterministic lookup from a config-provided mock map.

    Used so the CI workflow runs without contacting any registry.
    """
    def _lookup(name: str, version: str) -> Optional[str]:
        return mock_table.get(name)
    return _lookup


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="license_checker",
        description="Check dependency licenses against allow/deny lists.",
    )
    parser.add_argument("--manifest", required=True,
                        help="Path to package.json or requirements.txt")
    parser.add_argument("--config", required=True,
                        help="Path to JSON config with allow/deny (and optional mock_licenses)")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--output", default=None,
                        help="Write the report here instead of stdout")
    args = parser.parse_args(argv)

    try:
        deps = parse_manifest(args.manifest)
    except ManifestParseError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    try:
        with open(args.config, encoding="utf-8") as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: failed to read config {args.config}: {exc}", file=sys.stderr)
        return 2

    lookup = _make_mock_lookup(config.get("mock_licenses", {}))
    entries = check_compliance(deps, config, lookup_license=lookup)
    rendered = generate_report(entries, fmt=args.format)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(rendered)
    else:
        print(rendered)

    # Non-zero exit if any dependency is denied — useful for CI gating.
    return 1 if any(e["status"] == "denied" for e in entries) else 0


if __name__ == "__main__":
    raise SystemExit(main())
