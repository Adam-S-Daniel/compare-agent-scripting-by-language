#!/usr/bin/env python3
"""
Semantic version bumper based on conventional commits.

Approach:
  1. Read current version from package.json or a plain version.txt.
  2. Get commit messages from a fixture file (--commits-file) or from
     `git log` since the last version tag.
  3. Classify each message per the Conventional Commits spec:
       feat!: / BREAKING CHANGE → major
       feat:  → minor
       fix:   → patch
  4. Apply the highest-priority bump, update the version file, print
     a changelog entry, and emit NEW_VERSION=<version> for CI parsing.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import date
from enum import Enum
from pathlib import Path
from typing import List, Optional, Tuple


# ─── Types ────────────────────────────────────────────────────────────────────

class BumpType(Enum):
    MAJOR = "major"
    MINOR = "minor"
    PATCH = "patch"
    NONE  = "none"


# ─── Version parsing ──────────────────────────────────────────────────────────

def parse_version(version_str: str) -> Tuple[int, int, int]:
    """Parse 'v1.2.3' or '1.2.3' into (major, minor, patch)."""
    match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)", version_str.strip())
    if not match:
        raise ValueError(f"Invalid semantic version: {version_str!r}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


# ─── Version file I/O ─────────────────────────────────────────────────────────

def read_version_from_file(filepath: str) -> str:
    """Read version from package.json (key 'version') or a plain text file."""
    path = Path(filepath)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {filepath}")

    if path.name == "package.json":
        with open(path) as f:
            data = json.load(f)
        if "version" not in data:
            raise KeyError("No 'version' field in package.json")
        return data["version"]

    # Plain text: strip whitespace / trailing newline
    return path.read_text().strip()


def write_version_to_file(filepath: str, new_version: str) -> None:
    """Write the new version back to the file, preserving all other fields."""
    path = Path(filepath)

    if path.name == "package.json":
        with open(path) as f:
            data = json.load(f)
        data["version"] = new_version
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    else:
        path.write_text(new_version + "\n")


# ─── Commit analysis ──────────────────────────────────────────────────────────

# Conventional commit patterns
_BREAKING_RE = re.compile(
    r"BREAKING[- ]CHANGE|^(?:feat|fix|chore|refactor|style|test|docs|perf)!:",
    re.IGNORECASE,
)
_FEAT_RE = re.compile(r"^feat(?:\([^)]+\))?:")
_FIX_RE  = re.compile(r"^fix(?:\([^)]+\))?:")


def determine_bump_type(commit_messages: List[str]) -> BumpType:
    """
    Return the highest-priority BumpType required by the list of commit messages.

    Priority: MAJOR > MINOR > PATCH > NONE
    """
    bump = BumpType.NONE

    for msg in commit_messages:
        if _BREAKING_RE.search(msg):
            return BumpType.MAJOR  # Nothing overrides a breaking change
        if _FEAT_RE.match(msg):
            if bump in (BumpType.NONE, BumpType.PATCH):
                bump = BumpType.MINOR
        elif _FIX_RE.match(msg):
            if bump == BumpType.NONE:
                bump = BumpType.PATCH

    return bump


# ─── Version bumping ──────────────────────────────────────────────────────────

def bump_version(current_version: str, bump_type: BumpType) -> str:
    """Apply bump_type to current_version and return the new version string."""
    major, minor, patch = parse_version(current_version)

    if bump_type == BumpType.MAJOR:
        return f"{major + 1}.0.0"
    if bump_type == BumpType.MINOR:
        return f"{major}.{minor + 1}.0"
    if bump_type == BumpType.PATCH:
        return f"{major}.{minor}.{patch + 1}"
    return current_version  # NONE: unchanged


def update_version_file(filepath: str, bump_type: BumpType) -> Tuple[str, str]:
    """Read version, apply bump, write back. Returns (old_version, new_version)."""
    old = read_version_from_file(filepath)
    new = bump_version(old, bump_type)
    if new != old:
        write_version_to_file(filepath, new)
    return old, new


# ─── Changelog generation ─────────────────────────────────────────────────────

def generate_changelog_entry(
    version: str,
    commits: List[str],
    release_date: Optional[str] = None,
) -> str:
    """Return a Markdown changelog block for the given version and commits."""
    if release_date is None:
        release_date = date.today().isoformat()

    breaking, features, fixes, other = [], [], [], []
    for msg in commits:
        if _BREAKING_RE.search(msg):
            breaking.append(msg)
        elif _FEAT_RE.match(msg):
            features.append(msg)
        elif _FIX_RE.match(msg):
            fixes.append(msg)
        else:
            other.append(msg)

    lines = [f"## [{version}] - {release_date}", ""]
    for section_title, items in (
        ("Breaking Changes", breaking),
        ("Features",         features),
        ("Bug Fixes",        fixes),
        ("Other",            other),
    ):
        if items:
            lines.append(f"### {section_title}")
            lines.extend(f"- {m}" for m in items)
            lines.append("")

    return "\n".join(lines)


# ─── Git helpers ──────────────────────────────────────────────────────────────

def get_commits_from_git(repo_path: str = ".") -> Tuple[List[str], Optional[str]]:
    """
    Return (commit_messages, last_tag).
    Gets messages since the most recent 'v*' tag, or all commits if no tags.
    """
    tag_result = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0", "--match", "v*"],
        cwd=repo_path,
        capture_output=True,
        text=True,
    )

    if tag_result.returncode == 0:
        last_tag = tag_result.stdout.strip()
        ref_range = f"{last_tag}..HEAD"
    else:
        last_tag = None
        ref_range = "HEAD"

    log_result = subprocess.run(
        ["git", "log", ref_range, "--pretty=format:%s"],
        cwd=repo_path,
        capture_output=True,
        text=True,
    )
    commits = [l for l in log_result.stdout.strip().splitlines() if l]
    return commits, last_tag


def get_commits_from_file(filepath: str) -> List[str]:
    """Read commit messages from a plain text file (one message per line)."""
    path = Path(filepath)
    if not path.exists():
        raise FileNotFoundError(f"Commits file not found: {filepath}")
    return [l for l in path.read_text().splitlines() if l.strip()]


# ─── CLI entry point ──────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Bump semantic version from conventional commit messages."
    )
    parser.add_argument(
        "--version-file", default="package.json",
        help="Path to version file (package.json or version.txt)",
    )
    parser.add_argument(
        "--commits-file", default=None,
        help="Path to a text file with one commit message per line "
             "(default: use git log since last tag)",
    )
    parser.add_argument(
        "--repo", default=".",
        help="Path to the git repository (used when --commits-file is absent)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Analyse commits and print proposed version, but don't write files",
    )
    args = parser.parse_args()

    try:
        # ── Gather commits ────────────────────────────────────────────────────
        if args.commits_file:
            commits   = get_commits_from_file(args.commits_file)
            last_tag  = "(from file)"
        else:
            commits, last_tag = get_commits_from_git(args.repo)

        print(f"Last tag       : {last_tag or '(none)'}")
        print(f"Commits found  : {len(commits)}")

        if not commits:
            current = read_version_from_file(args.version_file)
            print(f"No commits to analyse — version unchanged: {current}")
            print(f"\nNEW_VERSION={current}")
            return

        # ── Determine bump ────────────────────────────────────────────────────
        bump_type = determine_bump_type(commits)
        print(f"Bump type      : {bump_type.value}")

        # ── Apply bump ────────────────────────────────────────────────────────
        if args.dry_run:
            current = read_version_from_file(args.version_file)
            new     = bump_version(current, bump_type)
            print(f"Current version: {current}")
            print(f"New version    : {new} (dry run — file not updated)")
        else:
            old, new = update_version_file(args.version_file, bump_type)
            print(f"Current version: {old}")
            print(f"New version    : {new}")

            # ── Generate changelog ────────────────────────────────────────────
            changelog = generate_changelog_entry(new, commits)
            print("\n--- Changelog entry ---")
            print(changelog)
            print("--- end changelog ---")

        # Machine-parseable line for CI scripts
        print(f"\nNEW_VERSION={new}")

    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except (json.JSONDecodeError, KeyError) as exc:
        print(f"Error parsing version file: {exc}", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:  # noqa: BLE001
        print(f"Unexpected error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
