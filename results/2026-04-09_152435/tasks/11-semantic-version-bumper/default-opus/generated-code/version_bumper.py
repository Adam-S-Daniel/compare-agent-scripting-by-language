#!/usr/bin/env python3
"""Semantic Version Bumper

Parses a VERSION file (or package.json) containing a semantic version string,
determines the next version based on conventional commit messages, updates the
version file, generates a changelog entry, and outputs the new version.

Conventional Commit Rules:
  fix: ...                     -> patch bump
  feat: ...                    -> minor bump
  feat!: ... / BREAKING CHANGE -> major bump

TDD Approach:
  Each function was developed test-first. Comments document the red/green/refactor
  cycle for each piece of functionality.
"""

import json
import os
import re
import subprocess
import sys
from datetime import date


# ---------------------------------------------------------------------------
# Version parsing
# ---------------------------------------------------------------------------
# RED:  parse_version("1.2.3") should return (1, 2, 3)
# GREEN: Implemented regex match returning integer tuple
# REFACTOR: Added strip/lstrip for robustness with whitespace and 'v' prefix
# RED:  parse_version("bad") should exit with clear error
# GREEN: Added error branch with informative message

def parse_version(version_str):
    """Parse a semantic version string into (major, minor, patch)."""
    version_str = version_str.strip().lstrip("v")
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)$", version_str)
    if not match:
        print(f"Error: Invalid version format: '{version_str}'", file=sys.stderr)
        print("Expected format: MAJOR.MINOR.PATCH (e.g., 1.2.3)", file=sys.stderr)
        sys.exit(1)
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


# ---------------------------------------------------------------------------
# Version file I/O
# ---------------------------------------------------------------------------
# RED:  read_version_file("VERSION") should return "1.0.0" from a VERSION file
# GREEN: Implemented plain-text file read
# RED:  read_version_file should fall back to package.json when VERSION missing
# GREEN: Added package.json fallback with json.load
# REFACTOR: Unified error messages, added file-not-found guard

def read_version_file(path="VERSION"):
    """Read the current version from a VERSION file or package.json."""
    if os.path.exists(path):
        with open(path) as f:
            return f.read().strip()

    # Fallback: try package.json
    pkg_path = "package.json"
    if os.path.exists(pkg_path):
        with open(pkg_path) as f:
            data = json.load(f)
        if "version" in data:
            return data["version"]

    print(f"Error: No version file found (tried '{path}' and 'package.json')",
          file=sys.stderr)
    sys.exit(1)


# RED:  write_version_file("2.0.0") should create a VERSION file containing "2.0.0\n"
# GREEN: Simple open/write

def write_version_file(version, path="VERSION"):
    """Write the new version to the VERSION file."""
    with open(path, "w") as f:
        f.write(version + "\n")


# ---------------------------------------------------------------------------
# Git log reading
# ---------------------------------------------------------------------------
# RED:  get_conventional_commits() should return list of commit subject lines
# GREEN: Implemented via git log --format=%s --no-merges
# REFACTOR: Added graceful error handling for missing git repo

def get_conventional_commits():
    """Get commit subject lines from git log."""
    try:
        result = subprocess.run(
            ["git", "log", "--format=%s", "--no-merges"],
            capture_output=True, text=True, check=True,
        )
        commits = [
            line.strip()
            for line in result.stdout.strip().split("\n")
            if line.strip()
        ]
        return commits
    except subprocess.CalledProcessError as e:
        print(f"Error: Failed to read git log: {e.stderr}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Bump-type determination
# ---------------------------------------------------------------------------
# RED:  ["fix: bug"] should yield "patch"
# GREEN: Added regex for fix: prefix
# RED:  ["feat: new thing"] should yield "minor"
# GREEN: Added regex for feat: prefix
# RED:  ["feat!: breaking"] should yield "major"
# GREEN: Added breaking-change detection (type! and BREAKING CHANGE)
# RED:  ["feat!: x", "feat: y", "fix: z"] should yield "major" (highest wins)
# GREEN: Implemented priority ordering: major > minor > patch
# REFACTOR: Consolidated into single pass with boolean flags

def determine_bump_type(commits):
    """Determine the version bump type from conventional commits.

    Priority: major > minor > patch.
    """
    has_breaking = False
    has_feat = False
    has_fix = False

    for commit in commits:
        if re.match(r"^\w+!:", commit) or "BREAKING CHANGE" in commit:
            has_breaking = True
        elif re.match(r"^feat(\(.+?\))?:", commit):
            has_feat = True
        elif re.match(r"^fix(\(.+?\))?:", commit):
            has_fix = True

    if has_breaking:
        return "major"
    if has_feat:
        return "minor"
    if has_fix:
        return "patch"
    # Default to patch when no conventional commits are recognized
    return "patch"


# ---------------------------------------------------------------------------
# Version arithmetic
# ---------------------------------------------------------------------------
# RED:  bump_version(1, 0, 0, "patch") == "1.0.1"
# GREEN: Implemented patch increment
# RED:  bump_version(1, 1, 0, "minor") == "1.2.0"  (patch resets)
# GREEN: Added minor increment with patch reset
# RED:  bump_version(0, 5, 3, "major") == "1.0.0"  (minor+patch reset)
# GREEN: Added major increment with minor+patch reset

def bump_version(major, minor, patch, bump_type):
    """Apply a semantic version bump and return the new version string."""
    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


# ---------------------------------------------------------------------------
# Changelog generation
# ---------------------------------------------------------------------------
# RED:  generate_changelog with fix commits should produce "### Bug Fixes" section
# GREEN: Implemented categorized markdown output
# RED:  generate_changelog with feat commits should produce "### Features" section
# GREEN: Added features category
# RED:  generate_changelog with breaking commits should produce "### Breaking Changes"
# GREEN: Added breaking changes category
# REFACTOR: Grouped categories, added date header, cleaned up empty sections

def generate_changelog(commits, new_version):
    """Generate a markdown changelog entry from conventional commits."""
    today = date.today().isoformat()

    breaking = []
    features = []
    fixes = []
    other = []

    for commit in commits:
        if re.match(r"^\w+!:", commit) or "BREAKING CHANGE" in commit:
            breaking.append(commit)
        elif re.match(r"^feat(\(.+?\))?:", commit):
            features.append(commit)
        elif re.match(r"^fix(\(.+?\))?:", commit):
            fixes.append(commit)
        else:
            other.append(commit)

    lines = [f"## [{new_version}] - {today}", ""]

    if breaking:
        lines.append("### Breaking Changes")
        for c in breaking:
            lines.append(f"- {c}")
        lines.append("")

    if features:
        lines.append("### Features")
        for c in features:
            lines.append(f"- {c}")
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes")
        for c in fixes:
            lines.append(f"- {c}")
        lines.append("")

    if other:
        lines.append("### Other")
        for c in other:
            lines.append(f"- {c}")
        lines.append("")

    return "\n".join(lines)


# RED:  update_changelog should prepend entry to existing CHANGELOG.md
# GREEN: Read existing content, insert after header
# REFACTOR: Handle missing file and missing header gracefully

def update_changelog(entry, path="CHANGELOG.md"):
    """Prepend a changelog entry to CHANGELOG.md."""
    existing = ""
    if os.path.exists(path):
        with open(path) as f:
            existing = f.read()

    if existing.startswith("# Changelog"):
        header_end = existing.index("\n") + 1
        new_content = existing[:header_end] + "\n" + entry + "\n" + existing[header_end:]
    else:
        new_content = "# Changelog\n\n" + entry + "\n" + existing

    with open(path, "w") as f:
        f.write(new_content)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main():
    """Orchestrate the version bump pipeline."""
    # 1. Read current version
    current_version = read_version_file()
    major, minor, patch = parse_version(current_version)
    print(f"CURRENT_VERSION={current_version}")

    # 2. Analyze commits
    commits = get_conventional_commits()
    if not commits:
        print("Error: No commits found. Nothing to bump.", file=sys.stderr)
        sys.exit(1)

    bump_type = determine_bump_type(commits)
    print(f"BUMP_TYPE={bump_type}")

    # 3. Calculate new version
    new_version = bump_version(major, minor, patch, bump_type)
    print(f"NEW_VERSION={new_version}")

    # 4. Update VERSION file
    write_version_file(new_version)

    # 5. Generate and update changelog
    changelog_entry = generate_changelog(commits, new_version)
    update_changelog(changelog_entry)
    print("CHANGELOG_ENTRY_START")
    print(changelog_entry)
    print("CHANGELOG_ENTRY_END")

    # 6. Summary
    print(f"Successfully bumped version: {current_version} -> {new_version} ({bump_type})")

    return new_version


if __name__ == "__main__":
    main()
