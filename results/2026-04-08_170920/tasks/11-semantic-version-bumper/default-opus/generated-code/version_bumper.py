#!/usr/bin/env python3
"""Semantic version bumper based on conventional commits.

Parses a version file or package.json, determines the next version from
conventional commit messages, updates the version file, generates a changelog
entry, and outputs the new version.
"""

import re
import json
import sys
import os
from datetime import date


def parse_version(version_str: str) -> tuple[int, int, int]:
    """Parse a semantic version string into (major, minor, patch).

    Raises ValueError if the string is not a valid semver.
    """
    version_str = version_str.strip()
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)$", version_str)
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str}'")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def version_to_str(version: tuple[int, int, int]) -> str:
    """Convert a version tuple back to a string like '1.2.3'."""
    return f"{version[0]}.{version[1]}.{version[2]}"


def read_version(filepath: str) -> tuple[int, int, int]:
    """Read a semantic version from a VERSION file or package.json.

    Detects file type by extension. Raises FileNotFoundError if missing.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Version file not found: {filepath}")

    with open(filepath) as f:
        if filepath.endswith(".json"):
            data = json.load(f)
            return parse_version(data["version"])
        else:
            return parse_version(f.read())


def write_version(filepath: str, version: tuple[int, int, int]) -> None:
    """Write a semantic version to a VERSION file or package.json."""
    ver_str = version_to_str(version)

    if filepath.endswith(".json"):
        with open(filepath) as f:
            data = json.load(f)
        data["version"] = ver_str
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    else:
        with open(filepath, "w") as f:
            f.write(ver_str + "\n")


# Regex for conventional commit: type(scope)!: description
_COMMIT_RE = re.compile(r"^(\w+)(?:\([^)]*\))?(!)?\s*:")


def classify_commit(message: str) -> str | None:
    """Classify a conventional commit message into a bump type.

    Returns 'major', 'minor', 'patch', or None (no bump needed).
    Breaking changes (! suffix or BREAKING CHANGE footer) -> major.
    feat -> minor, fix -> patch, everything else -> None.
    """
    # Check for BREAKING CHANGE footer anywhere in the message
    if "BREAKING CHANGE" in message or "BREAKING-CHANGE" in message:
        return "major"

    match = _COMMIT_RE.match(message)
    if not match:
        return None

    commit_type, bang = match.group(1), match.group(2)

    # The ! after type/scope means breaking change
    if bang:
        return "major"

    if commit_type == "feat":
        return "minor"
    if commit_type == "fix":
        return "patch"

    return None


def parse_commit_log(filepath: str) -> list[str]:
    """Parse a commit log file into individual commit messages.

    Each commit is separated by blank lines. Single-line commits are
    separated by newlines. Multi-line commits (with body/footer) are
    separated by double newlines.
    """
    with open(filepath) as f:
        content = f.read().strip()

    if not content:
        return []

    # Split on double newlines first (multi-line commits with body),
    # then split remaining single-line groups on single newlines.
    raw_blocks = content.split("\n\n")
    commits = []
    for block in raw_blocks:
        block = block.strip()
        if not block:
            continue
        # If a block has lines that each look like a commit header, split them
        lines = block.split("\n")
        if len(lines) > 1 and all(_COMMIT_RE.match(l) for l in lines):
            commits.extend(l.strip() for l in lines if l.strip())
        else:
            # Multi-line commit message (header + body/footer)
            commits.append(block)
    return commits


# Priority order for bump types (highest wins)
_BUMP_PRIORITY = {"major": 3, "minor": 2, "patch": 1}


def determine_bump(commits: list[str]) -> str | None:
    """Determine the highest-priority version bump from a list of commits.

    Returns 'major', 'minor', 'patch', or None if no bump-worthy commits.
    """
    best = None
    best_priority = 0
    for msg in commits:
        bump = classify_commit(msg)
        if bump and _BUMP_PRIORITY.get(bump, 0) > best_priority:
            best = bump
            best_priority = _BUMP_PRIORITY[bump]
    return best


def bump_version(
    version: tuple[int, int, int], bump_type: str
) -> tuple[int, int, int]:
    """Apply a bump to a version tuple.

    patch: increment patch, keep major/minor.
    minor: increment minor, reset patch.
    major: increment major, reset minor and patch.
    """
    major, minor, patch = version
    if bump_type == "patch":
        return (major, minor, patch + 1)
    if bump_type == "minor":
        return (major, minor + 1, 0)
    if bump_type == "major":
        return (major + 1, 0, 0)
    raise ValueError(f"Invalid bump type: '{bump_type}'")


def _extract_description(message: str) -> str:
    """Extract the description part from a conventional commit's first line."""
    first_line = message.split("\n")[0]
    # Strip the type(scope)!: prefix
    match = _COMMIT_RE.match(first_line)
    if match:
        return first_line[match.end():].strip()
    return first_line.strip()


def generate_changelog(
    version_str: str,
    commits: list[str],
    date_str: str | None = None,
) -> str:
    """Generate a markdown changelog entry from a list of commit messages.

    Groups commits by type: Breaking Changes, Features, Bug Fixes.
    """
    if date_str is None:
        date_str = date.today().isoformat()

    breaking = []
    features = []
    fixes = []

    for msg in commits:
        desc = _extract_description(msg)
        bump = classify_commit(msg)
        if bump == "major":
            breaking.append(desc)
        elif bump == "minor":
            features.append(desc)
        elif bump == "patch":
            fixes.append(desc)

    lines = [f"## {version_str} ({date_str})", ""]

    if breaking:
        lines.append("### Breaking Changes")
        lines.extend(f"- {d}" for d in breaking)
        lines.append("")

    if features:
        lines.append("### Features")
        lines.extend(f"- {d}" for d in features)
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(f"- {d}" for d in fixes)
        lines.append("")

    return "\n".join(lines)


def run_bumper(
    version_file: str,
    commit_log: str,
    changelog_file: str,
    date_override: str | None = None,
) -> str | None:
    """Orchestrate the full version bump process.

    1. Read current version
    2. Parse commits and determine bump type
    3. Bump version
    4. Generate changelog and prepend to file
    5. Write updated version
    6. Return new version string (or None if no bump)
    """
    current = read_version(version_file)
    commits = parse_commit_log(commit_log)
    bump_type = determine_bump(commits)

    if bump_type is None:
        return None

    new_version = bump_version(current, bump_type)
    new_str = version_to_str(new_version)

    # Generate changelog entry
    entry = generate_changelog(new_str, commits, date_override)

    # Prepend to existing changelog or create new one
    if os.path.exists(changelog_file):
        existing = open(changelog_file).read()
        with open(changelog_file, "w") as f:
            f.write(entry + "\n" + existing)
    else:
        with open(changelog_file, "w") as f:
            f.write(entry)

    # Update version file
    write_version(version_file, new_version)

    return new_str


def main():
    """CLI entry point. Usage: version_bumper.py VERSION_FILE COMMIT_LOG [CHANGELOG]"""
    import argparse

    parser = argparse.ArgumentParser(description="Semantic version bumper")
    parser.add_argument("version_file", help="Path to VERSION file or package.json")
    parser.add_argument("commit_log", help="Path to file with conventional commit messages")
    parser.add_argument("--changelog", default="CHANGELOG.md", help="Path to changelog file")
    parser.add_argument("--date", default=None, help="Override date for changelog (YYYY-MM-DD)")
    args = parser.parse_args()

    try:
        result = run_bumper(args.version_file, args.commit_log, args.changelog, args.date)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if result is None:
        print("No version bump needed.")
    else:
        print(result)


if __name__ == "__main__":
    main()
