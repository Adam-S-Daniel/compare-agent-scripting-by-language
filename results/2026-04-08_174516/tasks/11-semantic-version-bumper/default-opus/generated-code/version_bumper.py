#!/usr/bin/env python3
"""
Semantic Version Bumper

Parses a version file (VERSION or package.json) containing a semantic version,
determines the next version based on conventional commit messages, updates the
version file, generates a changelog entry, and outputs the new version.

Conventional commit mapping:
  - fix:              -> patch bump
  - feat:             -> minor bump
  - BREAKING CHANGE / !:  -> major bump

TDD approach: each function was developed test-first (see test fixtures and
run_tests.py for the full test harness that validates through act).
"""

import json
import re
import sys
import subprocess
from datetime import datetime
from pathlib import Path


# ---------------------------------------------------------------------------
# Version parsing & formatting
# ---------------------------------------------------------------------------

def parse_version(version_str):
    """Parse a semantic version string into (major, minor, patch) tuple.

    Accepts optional 'v' prefix. Raises ValueError on bad input.
    """
    match = re.match(r'^v?(\d+)\.(\d+)\.(\d+)$', version_str.strip())
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str.strip()}'")
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def format_version(major, minor, patch):
    """Format a (major, minor, patch) tuple back to a version string."""
    return f"{major}.{minor}.{patch}"


# ---------------------------------------------------------------------------
# Version file I/O (supports plain VERSION file and package.json)
# ---------------------------------------------------------------------------

def read_version_file(path):
    """Read version string from a VERSION file or package.json."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Version file not found: {path}")

    content = p.read_text().strip()

    if p.name == 'package.json':
        data = json.loads(content)
        if 'version' not in data:
            raise ValueError("package.json missing 'version' field")
        return data['version']
    else:
        # Plain text version file
        return content


def write_version_file(path, new_version):
    """Write a new version to a VERSION file or package.json."""
    p = Path(path)

    if p.name == 'package.json':
        data = json.loads(p.read_text())
        data['version'] = new_version
        p.write_text(json.dumps(data, indent=2) + '\n')
    else:
        p.write_text(new_version + '\n')


# ---------------------------------------------------------------------------
# Commit message handling
# ---------------------------------------------------------------------------

def get_commit_messages(commit_log=None):
    """Return list of commit message subjects.

    If commit_log is provided (string), split by newlines.
    Otherwise read from git log.
    """
    if commit_log is not None:
        return [line.strip() for line in commit_log.strip().split('\n') if line.strip()]

    result = subprocess.run(
        ['git', 'log', '--format=%s'],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Warning: git log failed: {result.stderr}", file=sys.stderr)
        return []
    return [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]


def determine_bump(commit_messages):
    """Determine the highest-priority bump type from conventional commits.

    Priority: major > minor > patch.
    Returns 'major', 'minor', 'patch', or None if no conventional commits.
    """
    bump = None

    for msg in commit_messages:
        # Breaking change — highest priority, return immediately
        if 'BREAKING CHANGE' in msg or re.match(r'^[a-z]+(\(.+?\))?!:', msg):
            return 'major'

        # Feature — second priority
        if re.match(r'^feat(\(.+?\))?:', msg):
            if bump != 'minor':
                bump = 'minor'

        # Fix — lowest conventional priority
        if re.match(r'^fix(\(.+?\))?:', msg):
            if bump is None:
                bump = 'patch'

    return bump


def bump_version(version_tuple, bump_type):
    """Apply a bump to a version tuple and return the new tuple."""
    major, minor, patch = version_tuple

    if bump_type == 'major':
        return (major + 1, 0, 0)
    elif bump_type == 'minor':
        return (major, minor + 1, 0)
    elif bump_type == 'patch':
        return (major, minor, patch + 1)
    else:
        raise ValueError(f"Unknown bump type: {bump_type}")


# ---------------------------------------------------------------------------
# Changelog generation
# ---------------------------------------------------------------------------

def generate_changelog(new_version, commit_messages, date=None):
    """Generate a markdown changelog entry grouped by commit type."""
    if date is None:
        date = datetime.now().strftime('%Y-%m-%d')

    lines = [f"## [{new_version}] - {date}", ""]

    breaking, features, fixes, other = [], [], [], []

    for msg in commit_messages:
        if 'BREAKING CHANGE' in msg or re.match(r'^[a-z]+(\(.+?\))?!:', msg):
            breaking.append(msg)
        elif re.match(r'^feat(\(.+?\))?:', msg):
            features.append(msg)
        elif re.match(r'^fix(\(.+?\))?:', msg):
            fixes.append(msg)
        else:
            other.append(msg)

    if breaking:
        lines.append("### Breaking Changes")
        for msg in breaking:
            lines.append(f"- {msg}")
        lines.append("")

    if features:
        lines.append("### Features")
        for msg in features:
            lines.append(f"- {msg}")
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes")
        for msg in fixes:
            lines.append(f"- {msg}")
        lines.append("")

    if other:
        lines.append("### Other")
        for msg in other:
            lines.append(f"- {msg}")
        lines.append("")

    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main():
    """CLI entry point for the version bumper."""
    import argparse

    parser = argparse.ArgumentParser(description='Semantic Version Bumper')
    parser.add_argument('--version-file', default='VERSION',
                        help='Path to version file (VERSION or package.json)')
    parser.add_argument('--commit-log', default=None,
                        help='Path to file with commit messages (one per line)')
    parser.add_argument('--changelog', default='CHANGELOG.md',
                        help='Path to changelog output file')
    parser.add_argument('--date', default=None,
                        help='Date for changelog entry (YYYY-MM-DD)')

    args = parser.parse_args()

    # --- Read current version ---
    try:
        version_str = read_version_file(args.version_file)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    current_version = parse_version(version_str)
    print(f"Current version: {format_version(*current_version)}")

    # --- Gather commit messages ---
    if args.commit_log:
        commit_log_content = Path(args.commit_log).read_text()
        commits = get_commit_messages(commit_log_content)
    else:
        commits = get_commit_messages()

    if not commits:
        print("No commits found. Version unchanged.")
        sys.exit(0)

    print(f"Found {len(commits)} commit(s)")

    # --- Determine bump ---
    bump_type = determine_bump(commits)
    if bump_type is None:
        print("No conventional commits found. Version unchanged.")
        sys.exit(0)

    print(f"Bump type: {bump_type}")

    # --- Apply bump ---
    new_version_tuple = bump_version(current_version, bump_type)
    new_version = format_version(*new_version_tuple)
    print(f"New version: {new_version}")

    # --- Update version file ---
    write_version_file(args.version_file, new_version)
    print(f"Updated {args.version_file}")

    # --- Generate and write changelog ---
    changelog_entry = generate_changelog(new_version, commits, args.date)

    changelog_path = Path(args.changelog)
    if changelog_path.exists():
        existing = changelog_path.read_text()
        changelog_path.write_text(changelog_entry + '\n' + existing)
    else:
        changelog_path.write_text(changelog_entry)

    print(f"Updated {args.changelog}")

    # Output for CI consumption
    print(f"NEW_VERSION={new_version}")

    return new_version


if __name__ == '__main__':
    main()
