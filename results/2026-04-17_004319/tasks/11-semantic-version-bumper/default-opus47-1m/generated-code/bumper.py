"""Semantic version bumper driven by conventional commit messages.

The module exposes a handful of small pure functions so each piece can be
unit-tested in isolation, plus a `main()` CLI entry point that wires them
together for use from a GitHub Actions workflow (or any shell).

Conventional-commit rules we follow:
  - `feat:`      -> minor bump
  - `fix:`       -> patch bump
  - `feat!:`, `fix!:` or a `BREAKING CHANGE:` footer -> major bump
  - Everything else (chore, docs, refactor, test, ...) -> no bump on its own.

The highest-precedence bump across all commits wins. If no commit qualifies
we emit BUMP_TYPE=none and leave the version file untouched.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date as _date
from pathlib import Path
from typing import Iterable


# Loose check — we accept simple `MAJOR.MINOR.PATCH` with numeric parts.
# Pre-release / build metadata is out of scope for this exercise.
_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")

# Conventional commit subject line: `type(optional-scope)!?: description`.
_COMMIT_RE = re.compile(
    r"^(?P<type>[a-zA-Z]+)"
    r"(?:\((?P<scope>[^)]+)\))?"
    r"(?P<bang>!)?"
    r":\s*(?P<desc>.+)$"
)

# Footer flag for breaking changes (applies to the commit above it).
_BREAKING_FOOTER_RE = re.compile(r"^BREAKING[- ]CHANGE:\s*", re.IGNORECASE)

# Precedence ordering so we can collapse many commits into one bump decision.
_BUMP_RANK = {"none": 0, "patch": 1, "minor": 2, "major": 3}
_RANK_TO_BUMP = {v: k for k, v in _BUMP_RANK.items()}


# ---------------------------------------------------------------------------
# parse_version / update_version_file
# ---------------------------------------------------------------------------

def parse_version(path: str | Path) -> str:
    """Return the semver string stored in `path`.

    Supports either a `package.json` (reads the `version` field) or a plain
    text file whose only content is the version string. Raises
    FileNotFoundError when the path does not exist and ValueError when the
    file exists but does not contain a valid semver.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Version file not found: {p}")

    if p.name == "package.json" or p.suffix == ".json":
        data = json.loads(p.read_text())
        if "version" not in data:
            raise ValueError(f"package.json at {p} has no 'version' field")
        version = data["version"]
    else:
        version = p.read_text().strip()

    if not _SEMVER_RE.match(version):
        raise ValueError(f"Not a valid semantic version in {p}: {version!r}")
    return version


def update_version_file(path: str | Path, new_version: str) -> None:
    """Write `new_version` back to `path`, preserving JSON structure."""
    p = Path(path)
    if p.name == "package.json" or p.suffix == ".json":
        data = json.loads(p.read_text())
        data["version"] = new_version
        # Keep 2-space indent so diffs stay minimal and npm-idiomatic.
        p.write_text(json.dumps(data, indent=2) + "\n")
    else:
        p.write_text(new_version + "\n")


# ---------------------------------------------------------------------------
# parse_commits
# ---------------------------------------------------------------------------

def parse_commits(text: str) -> list[dict]:
    """Parse raw commit log text into a list of commit records.

    Each commit is a single line of the input. A `BREAKING CHANGE:` line
    attached to the *previous* commit flags that commit as breaking.
    Non-conventional messages become `{"type": "other", ...}` so callers
    can still display them in the changelog.
    """
    commits: list[dict] = []
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            continue

        # A footer line like `BREAKING CHANGE: ...` flags the prior commit.
        if _BREAKING_FOOTER_RE.match(line):
            if commits:
                commits[-1]["breaking"] = True
            continue

        m = _COMMIT_RE.match(line)
        if m:
            commits.append({
                "type": m.group("type").lower(),
                "scope": m.group("scope"),
                "breaking": bool(m.group("bang")),
                "description": m.group("desc").strip(),
            })
        else:
            # Not conventional — keep it so it still shows in the changelog.
            commits.append({
                "type": "other",
                "scope": None,
                "breaking": False,
                "description": line.strip(),
            })
    return commits


# ---------------------------------------------------------------------------
# determine_bump_type / bump_version
# ---------------------------------------------------------------------------

def determine_bump_type(commits: Iterable[dict]) -> str:
    """Collapse a list of commits into a single bump decision."""
    rank = 0
    for c in commits:
        if c.get("breaking"):
            this = "major"
        elif c.get("type") == "feat":
            this = "minor"
        elif c.get("type") == "fix":
            this = "patch"
        else:
            this = "none"
        if _BUMP_RANK[this] > rank:
            rank = _BUMP_RANK[this]
    return _RANK_TO_BUMP[rank]


def bump_version(current: str, bump_type: str) -> str:
    """Return the new version string after applying `bump_type` to `current`."""
    if bump_type not in _BUMP_RANK:
        raise ValueError(f"Unknown bump type: {bump_type!r}")
    m = _SEMVER_RE.match(current)
    if not m:
        raise ValueError(f"Not a valid semantic version: {current!r}")
    major, minor, patch = (int(x) for x in m.groups())

    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    if bump_type == "patch":
        return f"{major}.{minor}.{patch + 1}"
    return current  # "none"


# ---------------------------------------------------------------------------
# generate_changelog
# ---------------------------------------------------------------------------

def _format_entry(commit: dict) -> str:
    scope = commit.get("scope")
    desc = commit["description"]
    return f"- **{scope}**: {desc}" if scope else f"- {desc}"


def generate_changelog(new_version: str, commits: list[dict], date: str | None = None) -> str:
    """Render a markdown changelog section for `new_version`."""
    today = date or _date.today().isoformat()
    lines = [f"## [{new_version}] - {today}", ""]

    # Bucket commits into the sections we actually want to render.
    breaking = [c for c in commits if c.get("breaking")]
    features = [c for c in commits if c.get("type") == "feat" and not c.get("breaking")]
    fixes = [c for c in commits if c.get("type") == "fix" and not c.get("breaking")]
    other = [
        c for c in commits
        if not c.get("breaking")
        and c.get("type") not in ("feat", "fix")
    ]

    if breaking:
        lines.append("### Breaking Changes")
        lines.extend(_format_entry(c) for c in breaking)
        lines.append("")
    if features:
        lines.append("### Features")
        lines.extend(_format_entry(c) for c in features)
        lines.append("")
    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(_format_entry(c) for c in fixes)
        lines.append("")
    if other:
        lines.append("### Other")
        lines.extend(_format_entry(c) for c in other)
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def _prepend_changelog(path: Path, entry: str) -> None:
    """Insert `entry` at the top of the changelog, creating the file if needed."""
    header = "# Changelog\n\n"
    if path.exists():
        existing = path.read_text()
        if existing.startswith("# Changelog"):
            # Keep the top-level heading, insert new entry after it.
            _, _, rest = existing.partition("\n\n")
            path.write_text(header + entry + "\n" + rest.lstrip("\n"))
        else:
            path.write_text(header + entry + "\n" + existing)
    else:
        path.write_text(header + entry)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Bump a semantic version based on conventional commits."
    )
    parser.add_argument("--version-file", required=True,
                        help="Path to package.json or plain VERSION file")
    parser.add_argument("--commits-file", required=True,
                        help="Path to a file containing commit subject lines")
    parser.add_argument("--changelog-file", required=True,
                        help="Path to CHANGELOG.md to write the new entry into")
    parser.add_argument("--date", default=None,
                        help="Optional ISO date for the changelog (default: today)")
    args = parser.parse_args(argv)

    try:
        current = parse_version(args.version_file)
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    commits_path = Path(args.commits_file)
    if not commits_path.exists():
        print(f"error: commits file not found: {commits_path}", file=sys.stderr)
        return 2
    commits = parse_commits(commits_path.read_text())

    bump_type = determine_bump_type(commits)
    new_version = bump_version(current, bump_type)

    if bump_type != "none":
        update_version_file(args.version_file, new_version)
        entry = generate_changelog(new_version, commits, date=args.date)
        _prepend_changelog(Path(args.changelog_file), entry)

    # GitHub-Actions-friendly KEY=VALUE output.
    print(f"CURRENT_VERSION={current}")
    print(f"BUMP_TYPE={bump_type}")
    print(f"NEW_VERSION={new_version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
