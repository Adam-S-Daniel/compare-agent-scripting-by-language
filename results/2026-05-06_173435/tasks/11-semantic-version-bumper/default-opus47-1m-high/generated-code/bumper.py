#!/usr/bin/env python3
"""Semantic version bumper driven by conventional commits.

Reads a version file (``package.json`` or a plain ``VERSION``-style file) and
a list of commit subjects, classifies each commit (feat -> minor, fix ->
patch, ! marker / "BREAKING CHANGE" footer -> major), bumps the version to
the highest required level, rewrites the version file, prepends a markdown
section to the changelog, and prints the new version to stdout.

Usage:
    python3 bumper.py \\
        --version-file package.json \\
        --commits-file fixtures/commits.txt \\
        --changelog-file CHANGELOG.md \\
        --date 2026-05-07

Exit codes:
    0   normal (whether or not a bump occurred)
    1   user/data error (bad semver, missing file, malformed JSON, ...)
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from pathlib import Path


# Order of bump levels. Higher numerical rank wins when commits disagree.
_LEVEL_RANK = {"none": 0, "patch": 1, "minor": 2, "major": 3}

# Conventional commit grammar:  type(scope)?!?: subject
_COMMIT_RE = re.compile(r"^(?P<type>\w+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?:\s*(?P<subject>.+)$")


# ---------------------------------------------------------------------------
# Pure functions (testable in isolation; act tests exercise them through the
# CLI surface).
# ---------------------------------------------------------------------------

def parse_semver(value: str) -> tuple[int, int, int]:
    """Parse 'X.Y.Z' (with optional surrounding whitespace) into a tuple."""
    m = re.match(r"^\s*(\d+)\.(\d+)\.(\d+)\s*$", value)
    if not m:
        raise ValueError(
            f"Not a valid semantic version: {value!r} (expected MAJOR.MINOR.PATCH)"
        )
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def format_semver(major: int, minor: int, patch: int) -> str:
    return f"{major}.{minor}.{patch}"


def categorize_commit(subject: str) -> dict:
    """Inspect one commit subject line and return a dict with keys:

    - level: 'major' | 'minor' | 'patch' | 'none'
    - type:  conventional-commit type (or None if unparseable)
    - scope: scope string (or None)
    - subject: the human-readable description portion
    - breaking: True if a breaking change marker was present
    """
    text = subject.strip()
    has_breaking_footer = "BREAKING CHANGE" in text  # covers BREAKING CHANGE: too
    m = _COMMIT_RE.match(text)
    if not m:
        return {
            "level": "none",
            "type": None,
            "scope": None,
            "subject": text,
            "breaking": has_breaking_footer,
        }

    ctype = m.group("type")
    scope = m.group("scope")
    bang = m.group("bang") == "!"
    desc = m.group("subject")
    breaking = bang or has_breaking_footer

    if breaking:
        level = "major"
    elif ctype == "feat":
        level = "minor"
    elif ctype == "fix":
        level = "patch"
    else:
        # chore/docs/refactor/style/test/etc don't bump the version on their own.
        level = "none"

    return {
        "level": level,
        "type": ctype,
        "scope": scope,
        "subject": desc,
        "breaking": breaking,
    }


def determine_highest_bump(commits: list[str]) -> str:
    """Return the highest bump level required by any commit in the list."""
    highest = "none"
    for c in commits:
        info = categorize_commit(c)
        if _LEVEL_RANK[info["level"]] > _LEVEL_RANK[highest]:
            highest = info["level"]
    return highest


def apply_bump(current: str, level: str) -> str:
    """Compute the next version. ``level == 'none'`` returns the current version."""
    major, minor, patch = parse_semver(current)
    if level == "major":
        return format_semver(major + 1, 0, 0)
    if level == "minor":
        return format_semver(major, minor + 1, 0)
    if level == "patch":
        return format_semver(major, minor, patch + 1)
    return format_semver(major, minor, patch)


def render_changelog_entry(new_version: str, commits: list[str], date_str: str) -> str:
    """Build the markdown section for one release."""
    feats: list[str] = []
    fixes: list[str] = []
    breaks: list[str] = []

    for c in commits:
        info = categorize_commit(c)
        scope = info["scope"]
        prefix = f"**{scope}:** " if scope else ""
        line = f"- {prefix}{info['subject']}"
        if info["breaking"]:
            breaks.append(line)
        elif info["type"] == "feat":
            feats.append(line)
        elif info["type"] == "fix":
            fixes.append(line)
        # other types deliberately omitted from the changelog.

    parts: list[str] = [f"## {new_version} - {date_str}", ""]
    if breaks:
        parts += ["### BREAKING CHANGES", "", *breaks, ""]
    if feats:
        parts += ["### Features", "", *feats, ""]
    if fixes:
        parts += ["### Bug Fixes", "", *fixes, ""]
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# I/O helpers (kept thin so the pure logic above stays easy to reason about).
# ---------------------------------------------------------------------------

def read_version_file(path: Path) -> tuple[str, str, dict | None]:
    """Return (current_version, kind, json_data_or_None).

    ``kind`` is 'json' for package.json-shaped files, 'plain' otherwise.
    """
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {path}")
    text = path.read_text()
    # Treat any .json file (and package.json by name) as JSON-shaped.
    if path.suffix == ".json" or path.name == "package.json":
        try:
            data = json.loads(text)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in {path}: {e}") from e
        if not isinstance(data, dict) or "version" not in data:
            raise KeyError(f"No 'version' field in {path}")
        return str(data["version"]), "json", data
    return text.strip(), "plain", None


def write_version_file(path: Path, new_version: str, kind: str, data: dict | None) -> None:
    if kind == "json":
        assert data is not None  # by construction of read_version_file
        data["version"] = new_version
        path.write_text(json.dumps(data, indent=2) + "\n")
    else:
        path.write_text(new_version + "\n")


def prepend_changelog(path: Path, entry: str) -> None:
    """Insert ``entry`` immediately under the changelog's H1, or at the top."""
    if path.exists():
        existing = path.read_text()
    else:
        existing = "# Changelog\n\n"

    if existing.lstrip().startswith("# "):
        # Split off the H1 line, keep it, then insert the new entry.
        head, sep, rest = existing.partition("\n")
        # Skip any blank line(s) immediately after the H1.
        rest = rest.lstrip("\n")
        new_text = f"{head}{sep}\n{entry}\n{rest}"
    else:
        new_text = entry + "\n" + existing
    path.write_text(new_text)


def read_commits_file(path: Path) -> list[str]:
    if not path.exists():
        raise FileNotFoundError(f"Commits file not found: {path}")
    lines = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            lines.append(line)
    return lines


# ---------------------------------------------------------------------------
# CLI entry point.
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version-file", default="package.json",
                        help="Path to package.json or VERSION file (default: package.json)")
    parser.add_argument("--commits-file", required=True,
                        help="Path to a file with one conventional commit subject per line")
    parser.add_argument("--changelog-file", default="CHANGELOG.md",
                        help="Path to the changelog (default: CHANGELOG.md)")
    parser.add_argument("--date", default=None,
                        help="ISO date for the changelog heading (defaults to today)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Compute and print the new version but don't write files")
    args = parser.parse_args(argv)

    try:
        version_path = Path(args.version_file)
        commits_path = Path(args.commits_file)
        changelog_path = Path(args.changelog_file)

        current, kind, data = read_version_file(version_path)
        # Validate parseable up-front so a malformed version errors clearly.
        parse_semver(current)

        commits = read_commits_file(commits_path)
        if not commits:
            print(f"Error: no commits found in {commits_path}", file=sys.stderr)
            return 1

        level = determine_highest_bump(commits)
        new_version = apply_bump(current, level)
        date_str = args.date or _dt.date.today().isoformat()

        if level != "none":
            entry = render_changelog_entry(new_version, commits, date_str)
            if not args.dry_run:
                write_version_file(version_path, new_version, kind, data)
                prepend_changelog(changelog_path, entry)
            print(f"Bumped {current} -> {new_version} ({level})", file=sys.stderr)
        else:
            print(
                f"No version-bumping commits; staying at {current}",
                file=sys.stderr,
            )

        # Stdout = the new version, machine-parseable.
        print(new_version)
        return 0

    except (FileNotFoundError, ValueError, KeyError, json.JSONDecodeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
