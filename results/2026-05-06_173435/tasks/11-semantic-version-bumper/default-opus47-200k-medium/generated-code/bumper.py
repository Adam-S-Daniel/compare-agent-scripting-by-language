"""Semantic version bumper driven by conventional commit messages.

Workflow:
  1. Read current version from a VERSION file or package.json.
  2. Parse a conventional-commit log (commits separated by lines of "---").
  3. Pick the largest needed bump (breaking -> major, feat -> minor, fix -> patch).
  4. Write the new version back and append a Markdown changelog entry.

Designed to be driven by an external log so it stays testable without git.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import date
from typing import Optional

# header: type(scope)?!?: description
_HEADER = re.compile(r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?:\s*(?P<desc>.+)$")
_VERSION = re.compile(r"^\d+\.\d+\.\d+$")

# Commits in fixture logs are separated by a `---` line. Real `git log` users
# can produce this format with `--pretty=format:%B%n---`.
_COMMIT_DELIM = re.compile(r"^---\s*$", re.MULTILINE)


def parse_commits(log: str) -> list[dict]:
    """Parse a conventional-commit log into structured records."""
    if not log.strip():
        return []
    chunks = [c.strip() for c in _COMMIT_DELIM.split(log) if c.strip()]
    commits = []
    for chunk in chunks:
        lines = chunk.splitlines()
        header = lines[0].strip()
        body = "\n".join(lines[1:])
        m = _HEADER.match(header)
        if not m:
            commits.append({
                "type": "other", "scope": None, "description": header,
                "breaking": False,
            })
            continue
        breaking = bool(m.group("bang")) or "BREAKING CHANGE" in body
        commits.append({
            "type": m.group("type").lower(),
            "scope": m.group("scope"),
            "description": m.group("desc").strip(),
            "breaking": breaking,
        })
    return commits


def determine_bump(commits: list[dict]) -> Optional[str]:
    """Return 'major', 'minor', 'patch', or None."""
    if not commits:
        return None
    if any(c.get("breaking") for c in commits):
        return "major"
    types = {c.get("type") for c in commits}
    if "feat" in types:
        return "minor"
    if "fix" in types or "perf" in types:
        return "patch"
    return None


def bump_version(version: str, kind: str) -> str:
    if not _VERSION.match(version):
        raise ValueError(f"Not a valid semver: {version!r}")
    major, minor, patch = (int(p) for p in version.split("."))
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    if kind == "patch":
        return f"{major}.{minor}.{patch + 1}"
    raise ValueError(f"Unknown bump kind: {kind!r}")


def read_version(path: str) -> str:
    if not os.path.exists(path):
        raise FileNotFoundError(f"Version file not found: {path}")
    if path.endswith("package.json"):
        with open(path) as f:
            data = json.load(f)
        if "version" not in data:
            raise ValueError(f"package.json at {path} has no 'version' field")
        return data["version"]
    with open(path) as f:
        return f.read().strip()


def write_version(path: str, version: str) -> None:
    if path.endswith("package.json"):
        with open(path) as f:
            data = json.load(f)
        data["version"] = version
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        return
    with open(path, "w") as f:
        f.write(version + "\n")


def generate_changelog(version: str, commits: list[dict]) -> str:
    """Render a Markdown changelog entry for `version` covering `commits`."""
    lines = [f"## {version} - {date.today().isoformat()}", ""]
    breaking = [c for c in commits if c["breaking"]]
    feats = [c for c in commits if c["type"] == "feat" and not c["breaking"]]
    fixes = [c for c in commits if c["type"] in ("fix", "perf") and not c["breaking"]]

    def fmt(c):
        scope = f"**{c['scope']}**: " if c.get("scope") else ""
        return f"- {scope}{c['description']}"

    if breaking:
        lines.append("### BREAKING CHANGES")
        lines.extend(fmt(c) for c in breaking)
        lines.append("")
    if feats:
        lines.append("### Features")
        lines.extend(fmt(c) for c in feats)
        lines.append("")
    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(fmt(c) for c in fixes)
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def process(version_path: str, log: str, changelog_path: str) -> Optional[str]:
    """Drive the full bump pipeline and return the new version, or None if no-op."""
    current = read_version(version_path)
    commits = parse_commits(log)
    kind = determine_bump(commits)
    if kind is None:
        return None
    new_version = bump_version(current, kind)
    write_version(version_path, new_version)
    entry = generate_changelog(new_version, commits)
    existing = ""
    if os.path.exists(changelog_path):
        existing = open(changelog_path).read()
    with open(changelog_path, "w") as f:
        f.write(entry)
        if existing:
            f.write("\n" + existing)
    return new_version


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Bump semver based on conventional commits.")
    p.add_argument("--version-file", required=True, help="Path to VERSION or package.json")
    p.add_argument("--commits-file", required=True, help="Path to commit log")
    p.add_argument("--changelog", default="CHANGELOG.md")
    args = p.parse_args(argv)

    try:
        with open(args.commits_file) as f:
            log = f.read()
    except OSError as e:
        print(f"error: cannot read commits file: {e}", file=sys.stderr)
        return 2

    try:
        new = process(args.version_file, log, args.changelog)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    if new is None:
        print("no-op: no version-impacting commits")
        return 0
    print(new)
    return 0


if __name__ == "__main__":
    sys.exit(main())
