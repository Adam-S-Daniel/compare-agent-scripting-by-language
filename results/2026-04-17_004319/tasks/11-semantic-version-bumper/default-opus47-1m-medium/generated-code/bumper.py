"""Semantic version bumper driven by conventional commits.

Pipeline:
    read_version -> parse_commits -> determine_bump -> bump_version
                 -> update_version_file + generate_changelog -> stdout

A commit log is a plain-text stream of conventional-commit messages. A new
commit starts on any line beginning with a recognized type token (feat, fix,
chore, ...). Subsequent lines belong to the previous commit's body, which is
where BREAKING CHANGE footers may live.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional

# Conventional Commits types we recognize. Anything else is ignored when
# computing the bump (treated as a non-release-affecting change).
COMMIT_TYPES = {"feat", "fix", "chore", "docs", "style", "refactor",
                "perf", "test", "build", "ci", "revert"}

# Header pattern: type(optional-scope)optional-!: subject
_HEADER_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?:\s*(?P<subject>.+)$"
)
_SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def read_version(path: str) -> str:
    """Return the semver string in *path*. Supports package.json or a plain file."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"version file not found: {path}")
    text = p.read_text()
    if p.name.endswith(".json"):
        version = json.loads(text).get("version", "")
    else:
        version = text.strip()
    if not _SEMVER_RE.match(version):
        raise ValueError(f"invalid semver in {path}: {version!r}")
    return version


def parse_commits(text: str) -> list[dict]:
    """Parse a commit log into a list of dicts.

    Each commit becomes ``{"type", "scope", "subject", "breaking", "body"}``.
    A line whose prefix matches a known type starts a new commit; trailing
    lines accumulate into the previous commit's body until the next header.
    """
    commits: list[dict] = []
    current: Optional[dict] = None
    for raw in text.splitlines():
        line = raw.rstrip()
        m = _HEADER_RE.match(line)
        if m and m.group("type") in COMMIT_TYPES:
            current = {
                "type": m.group("type"),
                "scope": m.group("scope"),
                "subject": m.group("subject"),
                "breaking": bool(m.group("bang")),
                "body": [],
            }
            commits.append(current)
        elif current is not None:
            current["body"].append(line)

    # Promote BREAKING CHANGE footers to the breaking flag.
    for c in commits:
        body_text = "\n".join(c["body"])
        if "BREAKING CHANGE" in body_text or "BREAKING-CHANGE" in body_text:
            c["breaking"] = True
    return commits


def determine_bump(commits: list[dict]) -> Optional[str]:
    """Given parsed commits, return ``"major" | "minor" | "patch" | None``."""
    if any(c["breaking"] for c in commits):
        return "major"
    if any(c["type"] == "feat" for c in commits):
        return "minor"
    if any(c["type"] == "fix" for c in commits):
        return "patch"
    return None


def bump_version(current: str, kind: str) -> str:
    """Apply *kind* (major/minor/patch) to *current* and return the new version."""
    if not _SEMVER_RE.match(current):
        raise ValueError(f"invalid semver: {current!r}")
    major, minor, patch = (int(n) for n in current.split("."))
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    if kind == "patch":
        return f"{major}.{minor}.{patch + 1}"
    raise ValueError(f"invalid bump kind: {kind!r}")


def update_version_file(path: str, new_version: str) -> None:
    """Write *new_version* into the version file in place."""
    p = Path(path)
    if p.name.endswith(".json"):
        data = json.loads(p.read_text())
        data["version"] = new_version
        # Pretty-print to stay friendly to package.json conventions.
        p.write_text(json.dumps(data, indent=2) + "\n")
    else:
        p.write_text(new_version + "\n")


def generate_changelog(commits: list[dict], new_version: str) -> str:
    """Return a Markdown changelog block grouped by feat/fix/breaking."""
    feats = [c for c in commits if c["type"] == "feat" and not c["breaking"]]
    fixes = [c for c in commits if c["type"] == "fix" and not c["breaking"]]
    breaks = [c for c in commits if c["breaking"]]

    lines = [f"## {new_version}", ""]
    if breaks:
        lines.append("### BREAKING CHANGES")
        for c in breaks:
            scope = f"**{c['scope']}**: " if c["scope"] else ""
            lines.append(f"- {scope}{c['subject']}")
        lines.append("")
    if feats:
        lines.append("### Features")
        for c in feats:
            scope = f"**{c['scope']}**: " if c["scope"] else ""
            lines.append(f"- {scope}{c['subject']}")
        lines.append("")
    if fixes:
        lines.append("### Bug Fixes")
        for c in fixes:
            scope = f"**{c['scope']}**: " if c["scope"] else ""
            lines.append(f"- {scope}{c['subject']}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _prepend_changelog(path: str, entry: str) -> None:
    p = Path(path)
    existing = p.read_text() if p.exists() else "# Changelog\n\n"
    p.write_text(existing.rstrip() + "\n\n" + entry)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Bump semver from conventional commits.")
    ap.add_argument("--version-file", required=True,
                    help="Path to package.json or plain VERSION file.")
    ap.add_argument("--commits-file", required=True,
                    help="Path to a file containing conventional commit messages.")
    ap.add_argument("--changelog", default="CHANGELOG.md",
                    help="Path to changelog file to update (default: CHANGELOG.md).")
    args = ap.parse_args(argv)

    try:
        current = read_version(args.version_file)
        commits = parse_commits(Path(args.commits_file).read_text())
        kind = determine_bump(commits)
        if kind is None:
            print(current)
            print("no release-worthy commits; version unchanged", file=sys.stderr)
            return 0
        new_version = bump_version(current, kind)
        update_version_file(args.version_file, new_version)
        _prepend_changelog(args.changelog, generate_changelog(commits, new_version))
        print(new_version)
        return 0
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
