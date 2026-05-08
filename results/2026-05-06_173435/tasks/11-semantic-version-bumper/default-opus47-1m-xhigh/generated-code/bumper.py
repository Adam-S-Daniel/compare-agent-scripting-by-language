#!/usr/bin/env python3
"""Semantic version bumper driven by conventional commits.

Reads a version (from package.json or a plain VERSION file) and a list of
commits (split by `---COMMIT---` delimiters), classifies each commit using
conventional-commits rules:

  * `feat:`            -> minor
  * `fix:`             -> patch
  * `<type>!:` or
    a `BREAKING CHANGE:` footer -> major

then bumps the version, rewrites the version file, appends a Keep-a-Changelog
section, and prints `NEW_VERSION=...` / `BUMP_TYPE=...` so a CI workflow can
parse the result.

The module is split into small pure functions so each one can be exercised
by a unit test before being wired into the CLI — that's how it was built.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from pathlib import Path
from typing import Iterable, Sequence

# A SemVer regex tight enough to reject "not.a.version" but permissive on
# leading `v` (common in tags) and on trailing pre-release/build metadata
# which we just ignore for the purposes of bumping.
_SEMVER_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$")

# `<type>(<optional scope>)?<optional !>:` — the conventional-commits header.
_CC_HEADER_RE = re.compile(r"^(?P<type>[a-zA-Z]+)(?:\([^)]+\))?(?P<bang>!)?:")

# Bump severity ordering — used when reducing many commits to one bump kind.
_SEVERITY = {None: 0, "patch": 1, "minor": 2, "major": 3}

# Sentinel splitting individual commits in the mock log fixtures.
COMMIT_DELIMITER = "---COMMIT---"


# --------------------------------------------------------------------------- #
# Pure version helpers
# --------------------------------------------------------------------------- #

def parse_version(s: str) -> tuple[int, int, int]:
    """Parse a SemVer string into (major, minor, patch). Raises ValueError."""
    m = _SEMVER_RE.match(s.strip())
    if not m:
        raise ValueError(f"invalid semver string: {s!r}")
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def format_version(v: tuple[int, int, int]) -> str:
    """Render a version tuple as `M.m.p`."""
    return f"{v[0]}.{v[1]}.{v[2]}"


def bump_version(v: tuple[int, int, int], kind: str) -> tuple[int, int, int]:
    """Apply a bump kind ("major"/"minor"/"patch") to a version tuple."""
    major, minor, patch = v
    if kind == "major":
        return (major + 1, 0, 0)
    if kind == "minor":
        return (major, minor + 1, 0)
    if kind == "patch":
        return (major, minor, patch + 1)
    raise ValueError(f"unknown bump kind: {kind!r}")


# --------------------------------------------------------------------------- #
# Commit classification
# --------------------------------------------------------------------------- #

def classify_commit(message: str) -> str | None:
    """Return the bump kind a single commit message implies, or None.

    `BREAKING CHANGE:` in the body always wins, even if the type would
    otherwise only be a minor or patch bump.
    """
    # Body-level breaking-change footer overrides everything else.
    for line in message.splitlines():
        if line.startswith("BREAKING CHANGE:") or line.startswith("BREAKING-CHANGE:"):
            return "major"

    header = message.splitlines()[0] if message else ""
    m = _CC_HEADER_RE.match(header)
    if not m:
        return None

    if m.group("bang"):
        return "major"

    t = m.group("type").lower()
    if t == "feat":
        return "minor"
    if t == "fix":
        return "patch"
    return None


def determine_bump(commits: Sequence[str]) -> str | None:
    """Reduce a list of commits to one bump kind by max severity."""
    best: str | None = None
    for c in commits:
        kind = classify_commit(c)
        if _SEVERITY[kind] > _SEVERITY[best]:
            best = kind
    return best


def parse_commits_file(text: str) -> list[str]:
    """Split a delimited commit-log dump into individual messages."""
    chunks = [c.strip() for c in text.split(COMMIT_DELIMITER)]
    return [c for c in chunks if c]


# --------------------------------------------------------------------------- #
# Version-file I/O
# --------------------------------------------------------------------------- #

def read_version(path: Path) -> str:
    """Read the version from a package.json or plain VERSION file."""
    if not path.exists():
        raise FileNotFoundError(f"version file not found: {path}")
    text = path.read_text()
    # Try JSON first — falls through to plain-text mode on parse failure.
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return text.strip()
    if isinstance(data, dict) and "version" in data:
        return str(data["version"])
    # JSON without a `version` field — treat the raw text as the version.
    return text.strip()


def write_version(path: Path, new_version: str) -> None:
    """Write `new_version` back, preserving the file's original format."""
    text = path.read_text()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = None
    if isinstance(data, dict) and "version" in data:
        data["version"] = new_version
        # Preserve trailing newline if the original had one — keeps diffs clean.
        suffix = "\n" if text.endswith("\n") else ""
        path.write_text(json.dumps(data, indent=2) + suffix)
        return
    path.write_text(new_version + "\n")


# --------------------------------------------------------------------------- #
# Changelog
# --------------------------------------------------------------------------- #

def _commit_subject(message: str) -> str:
    """Strip the conventional-commits header and return just the description."""
    head = message.splitlines()[0]
    # Find the colon that ends the type/scope and take what's after it.
    idx = head.find(":")
    return head[idx + 1 :].strip() if idx >= 0 else head.strip()


def generate_changelog(new_version: str, commits: Iterable[str], date: str | None = None) -> str:
    """Render a Keep-a-Changelog block grouped by bump kind."""
    if date is None:
        date = _dt.date.today().isoformat()

    breaking: list[str] = []
    features: list[str] = []
    fixes: list[str] = []

    for c in commits:
        kind = classify_commit(c)
        subject = _commit_subject(c)
        if kind == "major":
            breaking.append(subject)
        elif kind == "minor":
            features.append(subject)
        elif kind == "patch":
            fixes.append(subject)

    out = [f"## [{new_version}] - {date}", ""]
    if breaking:
        out += ["### Breaking Changes", ""]
        out += [f"- {s}" for s in breaking]
        out.append("")
    if features:
        out += ["### Features", ""]
        out += [f"- {s}" for s in features]
        out.append("")
    if fixes:
        out += ["### Fixes", ""]
        out += [f"- {s}" for s in fixes]
        out.append("")
    return "\n".join(out)


def append_changelog(path: Path, block: str) -> None:
    """Prepend a new block to an existing CHANGELOG.md (or create one)."""
    header = "# Changelog\n\n"
    if path.exists():
        existing = path.read_text()
        # If the file already has the boilerplate `# Changelog` header, keep
        # it on top and insert our new block right under it.
        if existing.startswith(header):
            path.write_text(header + block + "\n" + existing[len(header):])
            return
        path.write_text(header + block + "\n" + existing)
        return
    path.write_text(header + block + "\n")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument(
        "--version-file",
        required=True,
        type=Path,
        help="package.json or plain VERSION file to read/update",
    )
    p.add_argument(
        "--commits-file",
        required=True,
        type=Path,
        help=f"path to a commits log file (chunks split by '{COMMIT_DELIMITER}')",
    )
    p.add_argument(
        "--changelog-file",
        type=Path,
        default=None,
        help="optional path to CHANGELOG.md to update",
    )
    p.add_argument(
        "--date",
        default=None,
        help="ISO date for the changelog entry (default: today)",
    )
    return p


def main(argv: Sequence[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        current_str = read_version(args.version_file)
        current = parse_version(current_str)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    if not args.commits_file.exists():
        print(f"error: commits file not found: {args.commits_file}", file=sys.stderr)
        return 2

    commits = parse_commits_file(args.commits_file.read_text())
    bump = determine_bump(commits)

    if bump is None:
        new_str = format_version(current)
        print(f"NEW_VERSION={new_str}")
        print("BUMP_TYPE=none")
        print("info: no version-bumping commits found; nothing to do.", file=sys.stderr)
        return 0

    new = bump_version(current, bump)
    new_str = format_version(new)
    write_version(args.version_file, new_str)

    if args.changelog_file is not None:
        block = generate_changelog(new_str, commits, date=args.date)
        append_changelog(args.changelog_file, block)

    print(f"NEW_VERSION={new_str}")
    print(f"BUMP_TYPE={bump}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
