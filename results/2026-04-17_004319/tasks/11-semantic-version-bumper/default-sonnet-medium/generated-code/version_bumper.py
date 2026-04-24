#!/usr/bin/env python3
# Semantic version bumper — conventional commits -> semver bump + changelog

import re
import sys
import json
import argparse
from datetime import datetime


def parse_version(version_string: str) -> tuple[int, int, int]:
    """Parse 'MAJOR.MINOR.PATCH' string, raise ValueError if invalid."""
    match = re.match(r'^\s*(\d+)\.(\d+)\.(\d+)', version_string.strip())
    if not match:
        raise ValueError(f"Invalid version string: {version_string!r}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def read_version(version_file: str) -> str:
    """Read version from version.txt or package.json."""
    if version_file.endswith("package.json"):
        with open(version_file) as f:
            data = json.load(f)
        return data.get("version", "0.0.0")
    with open(version_file) as f:
        return f.read().strip()


def write_version(version_file: str, new_version: str) -> None:
    """Write updated version back to version.txt or package.json."""
    if version_file.endswith("package.json"):
        with open(version_file) as f:
            data = json.load(f)
        data["version"] = new_version
        with open(version_file, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    else:
        with open(version_file, "w") as f:
            f.write(new_version + "\n")


def determine_bump_type(commits: list[str]) -> str:
    """
    Determine highest-precedence version bump from conventional commits.

    Priority: major > minor > patch
    - feat! / fix! / <type>! or 'BREAKING CHANGE' in body -> major
    - feat(<scope>)?: <desc>                               -> minor
    - fix(<scope>)?: <desc>  or anything else              -> patch
    """
    bump = "patch"
    for commit in commits:
        msg = commit.strip()
        if not msg:
            continue
        # Breaking change: !-suffix or BREAKING CHANGE keyword
        if re.match(r'^[a-z]+(\([^)]+\))?!:', msg) or "BREAKING CHANGE" in msg:
            return "major"  # can't be topped — exit early
        # Feature -> at least minor
        if re.match(r'^feat(\([^)]+\))?:', msg) and bump == "patch":
            bump = "minor"
    return bump


def bump_version(
    major: int, minor: int, patch: int, bump_type: str
) -> tuple[int, int, int]:
    """Return (major, minor, patch) incremented by bump_type."""
    if bump_type == "major":
        return major + 1, 0, 0
    if bump_type == "minor":
        return major, minor + 1, 0
    return major, minor, patch + 1


def parse_commits(commits_text: str) -> list[str]:
    """Split commit log text into individual non-empty commit lines."""
    return [line.strip() for line in commits_text.strip().splitlines() if line.strip()]


def generate_changelog(commits: list[str], new_version: str) -> str:
    """Build a Markdown changelog section for new_version."""
    date = datetime.now().strftime("%Y-%m-%d")
    features, fixes, breaking, other = [], [], [], []

    for commit in commits:
        msg = commit.strip()
        if not msg:
            continue
        if re.match(r'^[a-z]+(\([^)]+\))?!:', msg) or "BREAKING CHANGE" in msg:
            breaking.append(f"- {msg}")
        elif re.match(r'^feat(\([^)]+\))?:', msg):
            features.append(f"- {msg}")
        elif re.match(r'^fix(\([^)]+\))?:', msg):
            fixes.append(f"- {msg}")
        else:
            other.append(f"- {msg}")

    lines = [f"## [{new_version}] - {date}", ""]
    if breaking:
        lines += ["### Breaking Changes", *breaking, ""]
    if features:
        lines += ["### Features", *features, ""]
    if fixes:
        lines += ["### Bug Fixes", *fixes, ""]
    if other:
        lines += ["### Other", *other, ""]

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> str:
    """Entry point. Returns the new version string."""
    parser = argparse.ArgumentParser(description="Semantic version bumper")
    parser.add_argument("--version-file", default="version.txt")
    parser.add_argument("--commits-file", default="commits.txt")
    parser.add_argument("--changelog-file", default="CHANGELOG.md")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print new version without writing files")
    args = parser.parse_args(argv)

    # Read current version
    try:
        version_str = read_version(args.version_file)
    except FileNotFoundError:
        print(f"Error: version file '{args.version_file}' not found", file=sys.stderr)
        sys.exit(1)

    try:
        major, minor, patch = parse_version(version_str)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    # Read commits
    try:
        with open(args.commits_file) as f:
            commits_text = f.read()
    except FileNotFoundError:
        print(f"Error: commits file '{args.commits_file}' not found", file=sys.stderr)
        sys.exit(1)

    commits = parse_commits(commits_text)
    if not commits:
        print("Error: no commits found in commits file", file=sys.stderr)
        sys.exit(1)

    bump_type = determine_bump_type(commits)
    new_major, new_minor, new_patch = bump_version(major, minor, patch, bump_type)
    new_version = f"{new_major}.{new_minor}.{new_patch}"
    changelog = generate_changelog(commits, new_version)

    if not args.dry_run:
        write_version(args.version_file, new_version)

        # Prepend new entry to changelog
        try:
            with open(args.changelog_file) as f:
                existing = f.read()
        except FileNotFoundError:
            existing = ""
        with open(args.changelog_file, "w") as f:
            f.write(changelog + "\n" + existing)

    # Machine-readable output consumed by the workflow
    print(f"NEW_VERSION={new_version}")
    print(f"BUMP_TYPE={bump_type}")
    print(f"OLD_VERSION={version_str}")

    return new_version


if __name__ == "__main__":
    main()
