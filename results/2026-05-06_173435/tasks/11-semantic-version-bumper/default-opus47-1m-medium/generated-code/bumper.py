"""
Semantic version bumper driven by Conventional Commits.

The flow is intentionally split into small pure functions so each one was easy
to test in isolation during the TDD cycle. The CLI / GitHub Action calls
``run`` which wires them together.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import date as _date
from pathlib import Path
from typing import Iterable, List, Optional


class BumperError(Exception):
    """Raised for any user-facing failure: missing file, bad version, etc."""


@dataclass
class Commit:
    sha: str
    type: str
    scope: Optional[str]
    subject: str
    breaking: bool


# Conventional commit header: "type(scope)!: subject" with scope and ! optional.
_HEADER = re.compile(
    r"^(?P<sha>[0-9a-f]{4,40})\s+"
    r"(?P<type>[a-zA-Z]+)"
    r"(?:\((?P<scope>[^)]+)\))?"
    r"(?P<bang>!)?"
    r":\s*(?P<subject>.+?)\s*$"
)

_SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def read_version(path: Path) -> str:
    if not path.exists():
        raise BumperError(f"version file not found: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise BumperError(f"{path} is not valid JSON: {e}") from e
    if "version" not in data:
        raise BumperError(f"{path} has no 'version' field")
    return data["version"]


def write_version(path: Path, new_version: str) -> None:
    data = json.loads(path.read_text())
    data["version"] = new_version
    path.write_text(json.dumps(data, indent=2) + "\n")


def parse_commits(log: str) -> List[Commit]:
    """
    Parse a git-log-ish blob.

    Expected layout per commit:
        <sha> <header line>
        <optional body lines>
        (blank line separates commits — also tolerated: each commit on its own line)

    Lines whose header doesn't match Conventional Commits are silently ignored
    so unrelated/legacy commits don't accidentally trigger a release.
    """
    # We walk lines top-to-bottom. A line matching the conventional header
    # starts a new commit; everything until the next header (or EOF) is body.
    commits: List[Commit] = []
    current: Optional[Commit] = None
    for raw in log.splitlines():
        line = raw.rstrip()
        m = _HEADER.match(line)
        if m:
            current = Commit(
                sha=m.group("sha"),
                type=m.group("type").lower(),
                scope=m.group("scope"),
                subject=m.group("subject"),
                breaking=bool(m.group("bang")),
            )
            commits.append(current)
            continue
        if current is not None and (
            line.lstrip().startswith("BREAKING CHANGE")
            or line.lstrip().startswith("BREAKING-CHANGE")
        ):
            current.breaking = True
    return commits


def determine_bump(commits: Iterable[Commit]) -> Optional[str]:
    has_feat = False
    has_fix = False
    for c in commits:
        if c.breaking:
            return "major"
        if c.type == "feat":
            has_feat = True
        elif c.type == "fix":
            has_fix = True
    if has_feat:
        return "minor"
    if has_fix:
        return "patch"
    return None


def bump_version(version: str, kind: str) -> str:
    m = _SEMVER.match(version)
    if not m:
        raise BumperError(f"invalid semantic version: {version!r}")
    major, minor, patch = (int(x) for x in m.groups())
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    if kind == "patch":
        return f"{major}.{minor}.{patch + 1}"
    raise BumperError(f"unknown bump kind: {kind!r}")


def render_changelog(version: str, commits: List[Commit], date: Optional[str] = None) -> str:
    date = date or _date.today().isoformat()
    breaking = [c for c in commits if c.breaking]
    feats = [c for c in commits if c.type == "feat" and not c.breaking]
    fixes = [c for c in commits if c.type == "fix" and not c.breaking]
    lines = [f"## {version} - {date}", ""]
    if breaking:
        lines.append("### Breaking Changes")
        lines += [f"- {c.subject} ({c.sha})" for c in breaking]
        lines.append("")
    if feats:
        lines.append("### Features")
        lines += [f"- {c.subject} ({c.sha})" for c in feats]
        lines.append("")
    if fixes:
        lines.append("### Bug Fixes")
        lines += [f"- {c.subject} ({c.sha})" for c in fixes]
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _prepend(path: Path, block: str) -> None:
    existing = path.read_text() if path.exists() else ""
    path.write_text(block + ("\n" + existing if existing else ""))


def run(
    package_path: Path,
    commits_path: Path,
    changelog_path: Path,
    date: Optional[str] = None,
) -> dict:
    if not commits_path.exists():
        raise BumperError(f"commits file not found: {commits_path}")
    old = read_version(package_path)
    commits = parse_commits(commits_path.read_text())
    bump = determine_bump(commits)
    if bump is None:
        return {"old_version": old, "new_version": old, "bump": None, "commits": len(commits)}
    new = bump_version(old, bump)
    write_version(package_path, new)
    _prepend(changelog_path, render_changelog(new, commits, date=date))
    return {"old_version": old, "new_version": new, "bump": bump, "commits": len(commits)}


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Semantic version bumper")
    p.add_argument("--package", default="package.json", help="path to package.json")
    p.add_argument("--commits", default="commits.txt", help="path to commit log fixture")
    p.add_argument("--changelog", default="CHANGELOG.md", help="path to changelog file")
    p.add_argument("--date", default=None, help="override date (YYYY-MM-DD) for reproducible output")
    args = p.parse_args(argv)
    try:
        result = run(
            package_path=Path(args.package),
            commits_path=Path(args.commits),
            changelog_path=Path(args.changelog),
            date=args.date,
        )
    except BumperError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    # Machine-readable single-line summary, plus a friendly version line.
    print(f"old_version={result['old_version']}")
    print(f"new_version={result['new_version']}")
    print(f"bump={result['bump']}")
    print(f"commits={result['commits']}")
    print(f"VERSION={result['new_version']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
