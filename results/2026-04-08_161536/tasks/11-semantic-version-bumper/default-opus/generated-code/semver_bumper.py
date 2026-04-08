#!/usr/bin/env python3
"""Semantic Version Bumper

Parses version files, determines the next version from conventional commits,
updates the version file, and generates a changelog entry.

Conventional commit format:
  feat: ...     -> minor bump
  fix: ...      -> patch bump
  BREAKING CHANGE / feat!: / fix!: -> major bump
"""

import re
import json
import subprocess
import sys
from datetime import date
from pathlib import Path


# -- Version parsing --

def parse_version(version_str: str) -> tuple[int, int, int]:
    """Parse a semver string (optionally prefixed with 'v') into (major, minor, patch)."""
    match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)$", version_str.strip())
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str}'")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


# -- Commit classification --

def classify_commit(message: str) -> str:
    """Classify a conventional commit message into a bump type: major, minor, or patch.

    Rules:
      - 'BREAKING CHANGE' in body/footer or '!' after type -> major
      - 'feat' type (without breaking) -> minor
      - Everything else -> patch
    """
    first_line = message.split("\n")[0]

    # Check for breaking changes: bang notation or BREAKING CHANGE footer
    if re.match(r"^\w+!:", first_line) or "BREAKING CHANGE" in message:
        return "major"

    # Check for feature
    if re.match(r"^feat(\(.+\))?:", first_line):
        return "minor"

    # Default: patch (fix, chore, docs, refactor, etc.)
    return "patch"


# -- Version bumping --

def bump_version(current: tuple[int, int, int], commits: list[str]) -> tuple[int, int, int]:
    """Determine the next version by finding the highest bump level across all commits.

    The highest bump wins: major > minor > patch.
    """
    if not commits:
        return current

    major, minor, patch = current
    bump_levels = [classify_commit(c) for c in commits]

    if "major" in bump_levels:
        return (major + 1, 0, 0)
    elif "minor" in bump_levels:
        return (major, minor + 1, 0)
    else:
        return (major, minor, patch + 1)


def format_version(version: tuple[int, int, int]) -> str:
    """Format a version tuple as a string."""
    return f"{version[0]}.{version[1]}.{version[2]}"


# -- File I/O --

def read_version_file(path: str) -> str:
    """Read the version string from a VERSION file or package.json.

    Raises FileNotFoundError if the file doesn't exist.
    Raises ValueError if package.json lacks a 'version' field.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Version file not found: {path}")

    if p.name == "package.json":
        data = json.loads(p.read_text())
        if "version" not in data:
            raise ValueError(f"No 'version' field in {path}")
        return data["version"]
    else:
        return p.read_text().strip()


def write_version_file(path: str, version: str) -> None:
    """Write the version string to a VERSION file or package.json."""
    p = Path(path)
    if p.name == "package.json":
        data = json.loads(p.read_text())
        data["version"] = version
        p.write_text(json.dumps(data, indent=2) + "\n")
    else:
        p.write_text(version + "\n")


# -- Changelog generation --

def generate_changelog(version: str, commits: list[str], today: str | None = None) -> str:
    """Generate a markdown changelog entry grouped by type."""
    if today is None:
        today = date.today().isoformat()

    features = []
    fixes = []
    breaking = []
    other = []

    for msg in commits:
        first_line = msg.split("\n")[0]
        bump = classify_commit(msg)

        # Extract description (strip type prefix)
        desc_match = re.match(r"^\w+!?(\(.+\))?:\s*(.+)", first_line)
        desc = desc_match.group(2) if desc_match else first_line

        if bump == "major":
            breaking.append(desc)
        elif re.match(r"^feat", first_line):
            features.append(desc)
        elif re.match(r"^fix", first_line):
            fixes.append(desc)
        else:
            other.append(desc)

    lines = [f"## {version} ({today})", ""]

    if breaking:
        lines += ["### BREAKING CHANGES", ""] + [f"- {d}" for d in breaking] + [""]
    if features:
        lines += ["### Features", ""] + [f"- {d}" for d in features] + [""]
    if fixes:
        lines += ["### Bug Fixes", ""] + [f"- {d}" for d in fixes] + [""]
    if other:
        lines += ["### Other", ""] + [f"- {d}" for d in other] + [""]

    return "\n".join(lines)


# -- Git log parsing --

def parse_git_log(raw: str) -> list[str]:
    """Parse git log --oneline output into commit message strings.

    Expected format: '<hash> <message>' per line.
    """
    lines = raw.strip().splitlines()
    result = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # Strip the leading hash (first space-separated token)
        parts = line.split(" ", 1)
        result.append(parts[1] if len(parts) > 1 else parts[0])
    return result


# -- Git integration --

def get_commits_since_tag(tag: str | None = None) -> list[str]:
    """Get commit messages since the given tag (or all commits if no tag)."""
    if tag:
        cmd = ["git", "log", f"{tag}..HEAD", "--oneline"]
    else:
        cmd = ["git", "log", "--oneline"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return parse_git_log(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running git: {e.stderr}", file=sys.stderr)
        return []


# -- Main entry point --

def main():
    """CLI entry point: bump version based on conventional commits."""
    import argparse

    parser = argparse.ArgumentParser(description="Semantic version bumper")
    parser.add_argument(
        "version_file",
        help="Path to VERSION file or package.json",
    )
    parser.add_argument(
        "--tag", default=None,
        help="Git tag to diff from (default: use all commits)",
    )
    parser.add_argument(
        "--changelog", default="CHANGELOG.md",
        help="Path to changelog file (default: CHANGELOG.md)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print new version without writing files",
    )
    parser.add_argument(
        "--commits-from-stdin", action="store_true",
        help="Read commit log from stdin instead of git",
    )
    args = parser.parse_args()

    # Read current version
    try:
        current_str = read_version_file(args.version_file)
        current = parse_version(current_str)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Get commits
    if args.commits_from_stdin:
        raw = sys.stdin.read()
        commits = parse_git_log(raw)
    else:
        commits = get_commits_since_tag(args.tag)

    if not commits:
        print(f"No commits found. Version stays at {current_str}")
        sys.exit(0)

    # Compute new version
    new_version = bump_version(current, commits)
    new_str = format_version(new_version)

    # Generate changelog
    changelog_entry = generate_changelog(new_str, commits)

    if args.dry_run:
        print(f"Current: {current_str}")
        print(f"New:     {new_str}")
        print()
        print(changelog_entry)
    else:
        # Write version file
        write_version_file(args.version_file, new_str)

        # Prepend to changelog
        changelog_path = Path(args.changelog)
        existing = changelog_path.read_text() if changelog_path.exists() else ""
        changelog_path.write_text(changelog_entry + "\n" + existing)

        print(new_str)


if __name__ == "__main__":
    main()
