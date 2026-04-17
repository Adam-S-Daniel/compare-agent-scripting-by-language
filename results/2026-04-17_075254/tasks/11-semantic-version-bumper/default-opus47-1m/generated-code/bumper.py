#!/usr/bin/env python3
"""Semantic version bumper.

Reads a version (from version.txt or package.json), inspects a list of
conventional-commit messages, determines the bump type
(feat -> minor, fix -> patch, ! or BREAKING CHANGE -> major), updates the
version file, and prepends a changelog entry. Prints the new version.

Usage:
    python3 bumper.py --version-file version.txt \\
        --commits-file commits.txt --changelog CHANGELOG.md
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import List, Optional

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
# Conventional commit header: type(scope)?!?: subject
HEADER_RE = re.compile(r"^(?P<type>[a-zA-Z]+)(?:\([^)]*\))?(?P<bang>!)?:\s*(?P<subject>.+)$")


class BumpError(Exception):
    """Raised for any user-facing failure (bad input, missing files, etc.)."""


# ---------- IO helpers ----------

def read_version(path: str) -> str:
    """Read a semver string from either a plain text file or package.json."""
    p = Path(path)
    if not p.exists():
        raise BumpError(f"Version file not found: {path}")
    text = p.read_text()
    if p.name == "package.json" or _looks_like_json(text):
        try:
            data = json.loads(text)
        except json.JSONDecodeError as e:
            raise BumpError(f"Invalid JSON in {path}: {e}") from e
        version = data.get("version")
        if not isinstance(version, str):
            raise BumpError(f"Missing 'version' field in {path}")
    else:
        version = text.strip()
    if not SEMVER_RE.match(version):
        raise BumpError(f"Invalid semantic version '{version}' in {path}")
    return version


def write_version(path: str, new_version: str) -> None:
    """Write back the new version, preserving package.json structure."""
    p = Path(path)
    text = p.read_text() if p.exists() else ""
    if p.name == "package.json" or _looks_like_json(text):
        data = json.loads(text)
        data["version"] = new_version
        p.write_text(json.dumps(data, indent=2) + "\n")
    else:
        p.write_text(new_version + "\n")


def _looks_like_json(text: str) -> bool:
    return text.lstrip().startswith("{")


# ---------- commit parsing ----------

def parse_commits(raw: str) -> List[str]:
    """Split a commit log file into individual commit messages.

    Commits are separated by blank lines (so multi-line messages with bodies
    survive); single-line per commit also works.
    """
    # Treat each non-empty line as one commit unless we see a "---" separator
    # (kept simple: line-per-commit is sufficient for fixtures/CI use here).
    return [line.rstrip() for line in raw.splitlines() if line.strip()]


def determine_bump(commits: List[str]) -> Optional[str]:
    """Return 'major', 'minor', 'patch', or None based on commit types."""
    bump = None
    rank = {"patch": 1, "minor": 2, "major": 3}
    for msg in commits:
        kind = _classify(msg)
        if kind and (bump is None or rank[kind] > rank[bump]):
            bump = kind
    return bump


def _classify(message: str) -> Optional[str]:
    if "BREAKING CHANGE" in message:
        return "major"
    header = message.splitlines()[0]
    m = HEADER_RE.match(header)
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


# ---------- bump math ----------

def bump_version(current: str, kind: str) -> str:
    m = SEMVER_RE.match(current)
    if not m:
        raise BumpError(f"Invalid current version: {current}")
    major, minor, patch = (int(x) for x in m.groups())
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    if kind == "patch":
        return f"{major}.{minor}.{patch + 1}"
    raise BumpError(f"Unknown bump kind: {kind}")


# ---------- changelog ----------

def generate_changelog(version: str, commits: List[str]) -> str:
    """Render a markdown changelog block for `version` from `commits`."""
    breaking, features, fixes = [], [], []
    for msg in commits:
        header = msg.splitlines()[0]
        m = HEADER_RE.match(header)
        if not m:
            continue
        subject = m.group("subject")
        if m.group("bang") or "BREAKING CHANGE" in msg:
            breaking.append(subject)
        elif m.group("type").lower() == "feat":
            features.append(subject)
        elif m.group("type").lower() == "fix":
            fixes.append(subject)

    lines = [f"## {version}", ""]
    if breaking:
        lines.append("### Breaking Changes")
        lines.extend(f"- {s}" for s in breaking)
        lines.append("")
    if features:
        lines.append("### Features")
        lines.extend(f"- {s}" for s in features)
        lines.append("")
    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(f"- {s}" for s in fixes)
        lines.append("")
    return "\n".join(lines)


def _prepend_changelog(path: str, entry: str) -> None:
    p = Path(path)
    existing = p.read_text() if p.exists() else "# Changelog\n\n"
    if not existing.startswith("# Changelog"):
        existing = "# Changelog\n\n" + existing
    head, _, tail = existing.partition("\n\n")
    p.write_text(f"{head}\n\n{entry}\n{tail}".rstrip() + "\n")


# ---------- end-to-end glue ----------

def run(version_file: str, commits_file: str, changelog_file: str) -> str:
    current = read_version(version_file)
    cpath = Path(commits_file)
    if not cpath.exists():
        raise BumpError(f"Commits file not found: {commits_file}")
    commits = parse_commits(cpath.read_text())
    if not commits:
        raise BumpError("No commits provided")
    kind = determine_bump(commits)
    if kind is None:
        raise BumpError("No releasable commits (only chore/docs/etc.)")
    new_version = bump_version(current, kind)
    write_version(version_file, new_version)
    entry = generate_changelog(new_version, commits)
    _prepend_changelog(changelog_file, entry)
    return new_version


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Bump semantic version from conventional commits")
    parser.add_argument("--version-file", required=True)
    parser.add_argument("--commits-file", required=True)
    parser.add_argument("--changelog", default="CHANGELOG.md")
    args = parser.parse_args(argv)
    try:
        new_version = run(args.version_file, args.commits_file, args.changelog)
    except BumpError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    # Final printed line is the new version (consumed by the CI workflow).
    print(f"NEW_VERSION={new_version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
