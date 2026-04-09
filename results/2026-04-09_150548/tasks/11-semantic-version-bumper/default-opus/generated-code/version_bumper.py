#!/usr/bin/env python3
"""
Semantic Version Bumper

Parses a version file (VERSION or package.json) containing a semantic version,
determines the next version based on conventional commit messages, updates the
version file, and generates a changelog entry.

Conventional commit classification:
  - BREAKING CHANGE / feat!: / fix!: -> major bump
  - feat: -> minor bump
  - fix: -> patch bump
"""

import json
import os
import re
import subprocess
import sys
from datetime import date


# --- Version Parsing ---

def parse_version(version_str):
    """Parse a semver string like '1.2.3' into a (major, minor, patch) tuple."""
    version_str = version_str.strip().lstrip("v")
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)$", version_str)
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str}'")
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def format_version(version_tuple):
    """Format a (major, minor, patch) tuple back to a string."""
    return f"{version_tuple[0]}.{version_tuple[1]}.{version_tuple[2]}"


# --- Version File I/O ---

def read_version_file(path):
    """Read version from a VERSION file or package.json."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"Version file not found: {path}")

    with open(path, "r") as f:
        content = f.read()

    if path.endswith(".json"):
        # Parse as package.json
        try:
            data = json.loads(content)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in {path}: {e}")
        if "version" not in data:
            raise ValueError(f"No 'version' field in {path}")
        return data["version"]
    else:
        # Plain text VERSION file
        return content.strip()


def write_version_file(path, new_version):
    """Write the new version back to the file."""
    if path.endswith(".json"):
        with open(path, "r") as f:
            data = json.load(f)
        data["version"] = new_version
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    else:
        with open(path, "w") as f:
            f.write(new_version + "\n")


# --- Commit Classification ---

def classify_commit(message):
    """
    Classify a conventional commit message into a bump type.
    Returns 'major', 'minor', 'patch', or None (for unrecognized commits).
    """
    first_line = message.strip().split("\n")[0]
    full_message = message.strip()

    # Check for breaking changes (highest priority)
    if "BREAKING CHANGE" in full_message or "BREAKING-CHANGE" in full_message:
        return "major"
    # Check for breaking change indicator (! before colon)
    if re.match(r"^(feat|fix|chore|refactor|docs|style|test|perf|ci|build)!:", first_line):
        return "major"

    # Check for feature commits
    if re.match(r"^feat(\(.+\))?:", first_line):
        return "minor"

    # Check for fix commits
    if re.match(r"^fix(\(.+\))?:", first_line):
        return "patch"

    return None


def classify_commits(commit_messages):
    """
    Given a list of commit messages, determine the highest-priority bump type.
    major > minor > patch
    Returns the bump type and list of classified commits.
    """
    if not commit_messages:
        raise ValueError("No commits provided")

    classified = []
    for msg in commit_messages:
        bump_type = classify_commit(msg)
        if bump_type:
            classified.append({"message": msg.strip().split("\n")[0], "type": bump_type})

    if not classified:
        raise ValueError("No conventional commits found (need feat:, fix:, or breaking changes)")

    # Determine highest priority bump
    priorities = {"major": 3, "minor": 2, "patch": 1}
    highest = max(classified, key=lambda c: priorities[c["type"]])
    return highest["type"], classified


# --- Version Bumping ---

def bump_version(current_version_tuple, bump_type):
    """Apply a bump to a version tuple. Returns the new version tuple."""
    major, minor, patch = current_version_tuple
    if bump_type == "major":
        return (major + 1, 0, 0)
    elif bump_type == "minor":
        return (major, minor + 1, 0)
    elif bump_type == "patch":
        return (major, minor, patch + 1)
    else:
        raise ValueError(f"Unknown bump type: '{bump_type}'")


# --- Changelog Generation ---

def generate_changelog(new_version, classified_commits, today=None):
    """Generate a changelog entry from classified commits."""
    if today is None:
        today = date.today().isoformat()

    lines = [f"## [{new_version}] - {today}", ""]

    # Group by type
    breaking = [c for c in classified_commits if c["type"] == "major"]
    features = [c for c in classified_commits if c["type"] == "minor"]
    fixes = [c for c in classified_commits if c["type"] == "patch"]

    if breaking:
        lines.append("### Breaking Changes")
        for c in breaking:
            lines.append(f"- {c['message']}")
        lines.append("")

    if features:
        lines.append("### Features")
        for c in features:
            lines.append(f"- {c['message']}")
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes")
        for c in fixes:
            lines.append(f"- {c['message']}")
        lines.append("")

    return "\n".join(lines)


# --- Git Integration ---

def get_commit_messages():
    """Get commit messages from git log (since last tag or all commits)."""
    try:
        # Try to get commits since the last tag
        result = subprocess.run(
            ["git", "describe", "--tags", "--abbrev=0"],
            capture_output=True, text=True, check=True
        )
        last_tag = result.stdout.strip()
        result = subprocess.run(
            ["git", "log", f"{last_tag}..HEAD", "--pretty=format:%B---COMMIT_SEP---"],
            capture_output=True, text=True, check=True
        )
    except subprocess.CalledProcessError:
        # No tags found, get all commits
        result = subprocess.run(
            ["git", "log", "--pretty=format:%B---COMMIT_SEP---"],
            capture_output=True, text=True, check=True
        )

    raw = result.stdout.strip()
    if not raw:
        raise ValueError("No commits found in git log")

    messages = [m.strip() for m in raw.split("---COMMIT_SEP---") if m.strip()]
    return messages


# --- Main Entry Point ---

def main(version_file=None, commit_file=None):
    """
    Main function. Can read commits from git or from a file (for testing).
    version_file: path to VERSION or package.json (default: auto-detect)
    commit_file: path to a file with commit messages separated by ---COMMIT_SEP---
    """
    # Auto-detect version file
    if version_file is None:
        if os.path.exists("VERSION"):
            version_file = "VERSION"
        elif os.path.exists("package.json"):
            version_file = "package.json"
        else:
            print("ERROR: No VERSION file or package.json found", file=sys.stderr)
            sys.exit(1)

    # Read current version
    try:
        current_version_str = read_version_file(version_file)
        current_version = parse_version(current_version_str)
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Current version: {format_version(current_version)}")

    # Get commits
    try:
        if commit_file:
            with open(commit_file, "r") as f:
                raw = f.read()
            commit_messages = [m.strip() for m in raw.split("---COMMIT_SEP---") if m.strip()]
        else:
            commit_messages = get_commit_messages()
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    # Classify and bump
    try:
        bump_type, classified = classify_commits(commit_messages)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    new_version_tuple = bump_version(current_version, bump_type)
    new_version_str = format_version(new_version_tuple)

    print(f"Bump type: {bump_type}")
    print(f"New version: {new_version_str}")

    # Update version file
    write_version_file(version_file, new_version_str)
    print(f"Updated {version_file}")

    # Generate changelog
    changelog = generate_changelog(new_version_str, classified)
    changelog_path = "CHANGELOG.md"

    # Prepend to existing changelog or create new one
    if os.path.exists(changelog_path):
        with open(changelog_path, "r") as f:
            existing = f.read()
        with open(changelog_path, "w") as f:
            f.write(changelog + "\n" + existing)
    else:
        with open(changelog_path, "w") as f:
            f.write("# Changelog\n\n" + changelog)

    print(f"Updated {changelog_path}")
    print(f"NEW_VERSION={new_version_str}")

    return new_version_str


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Semantic Version Bumper")
    parser.add_argument("--version-file", help="Path to VERSION or package.json")
    parser.add_argument("--commit-file", help="Path to commit messages file (for testing)")
    args = parser.parse_args()
    main(version_file=args.version_file, commit_file=args.commit_file)
