#!/usr/bin/env python3
"""
Semantic Version Bumper

Parses a version file (VERSION or package.json) containing a semantic version
string, determines the next version based on conventional commit messages,
updates the version file, generates a changelog entry, and outputs the new version.

Conventional commit mapping:
  fix:              -> patch bump  (e.g. 1.0.0 -> 1.0.1)
  feat:             -> minor bump  (e.g. 1.0.0 -> 1.1.0)
  BREAKING CHANGE/! -> major bump  (e.g. 1.0.0 -> 2.0.0)

Approach: Each function is a small, testable unit. The main() function
orchestrates reading the version, getting commits, classifying them,
bumping, writing back, and generating the changelog.
"""

import json
import os
import re
import subprocess
import sys
from datetime import date


# ---------------------------------------------------------------------------
# Version parsing and manipulation
# ---------------------------------------------------------------------------

def parse_version(version_str):
    """Parse a semantic version string into a (major, minor, patch) tuple.

    Accepts optional leading 'v' prefix (e.g. 'v1.2.3' or '1.2.3').
    Raises ValueError for malformed input.
    """
    version_str = version_str.strip()
    match = re.match(r'^v?(\d+)\.(\d+)\.(\d+)$', version_str)
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str}'")
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def bump_version(version_tuple, bump_type):
    """Return the bumped version string given a (major, minor, patch) tuple.

    Rules:
      major -> major+1, minor=0, patch=0
      minor -> minor+1, patch=0
      patch -> patch+1
    """
    major, minor, patch = version_tuple
    if bump_type == 'major':
        return f"{major + 1}.0.0"
    elif bump_type == 'minor':
        return f"{major}.{minor + 1}.0"
    elif bump_type == 'patch':
        return f"{major}.{minor}.{patch + 1}"
    else:
        raise ValueError(f"Unknown bump type: '{bump_type}'")


# ---------------------------------------------------------------------------
# Version file I/O
# ---------------------------------------------------------------------------

def read_version():
    """Read the current version from VERSION file or package.json.

    Returns (version_string, source_file) tuple.
    Prefers VERSION file if both exist.
    """
    if os.path.exists('VERSION'):
        with open('VERSION', 'r') as f:
            content = f.read().strip()
            if not content:
                raise ValueError("VERSION file is empty")
            return content, 'VERSION'
    elif os.path.exists('package.json'):
        with open('package.json', 'r') as f:
            data = json.load(f)
        if 'version' not in data:
            raise ValueError("package.json missing 'version' field")
        return data['version'], 'package.json'
    else:
        raise FileNotFoundError("No VERSION file or package.json found")


def write_version(new_version, source):
    """Write the new version back to the source file."""
    if source == 'VERSION':
        with open('VERSION', 'w') as f:
            f.write(new_version + '\n')
    elif source == 'package.json':
        with open('package.json', 'r') as f:
            data = json.load(f)
        data['version'] = new_version
        with open('package.json', 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
    else:
        raise ValueError(f"Unknown source file: '{source}'")


# ---------------------------------------------------------------------------
# Commit parsing and classification
# ---------------------------------------------------------------------------

def get_commits():
    """Retrieve commit messages from git log.

    Uses a custom separator to split multi-line commit messages.
    Returns a list of full commit message strings.
    """
    separator = '---COMMIT_END---'
    try:
        result = subprocess.run(
            ['git', 'log', '--format=%B' + separator],
            capture_output=True, text=True, check=True
        )
        raw = result.stdout
        commits = [c.strip() for c in raw.split(separator) if c.strip()]
        return commits
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to read git log: {e.stderr}")


def classify_commit(message):
    """Classify a single conventional commit message.

    Returns 'major', 'minor', 'patch', or None (if not a conventional commit).

    Breaking changes are detected by:
      1. 'BREAKING CHANGE:' or 'BREAKING-CHANGE:' anywhere in the body/footer
      2. '!' before the colon in the type prefix (e.g. 'feat!:', 'fix!:')
    """
    first_line = message.split('\n')[0].strip()

    # Check for BREAKING CHANGE in the full message body
    if 'BREAKING CHANGE' in message or 'BREAKING-CHANGE' in message:
        return 'major'

    # Check for ! before : (e.g. feat!: or refactor(scope)!:)
    if re.match(r'^[a-z]+(\([^)]+\))?!:', first_line):
        return 'major'

    # Feature commit -> minor bump
    if re.match(r'^feat(\([^)]+\))?:', first_line):
        return 'minor'

    # Fix commit -> patch bump
    if re.match(r'^fix(\([^)]+\))?:', first_line):
        return 'patch'

    # Not a conventional commit we recognize
    return None


def determine_bump_type(commits):
    """Determine the highest-priority bump type across all commits.

    Priority: major > minor > patch.
    Raises ValueError if no conventional commits are found.
    """
    priority = {'major': 3, 'minor': 2, 'patch': 1}
    best_type = None
    best_priority = 0

    for commit in commits:
        classification = classify_commit(commit)
        if classification and priority[classification] > best_priority:
            best_type = classification
            best_priority = priority[classification]

    if best_type is None:
        raise ValueError("No conventional commits found — cannot determine bump type")

    return best_type


# ---------------------------------------------------------------------------
# Changelog generation
# ---------------------------------------------------------------------------

def generate_changelog(commits, new_version):
    """Generate a markdown changelog entry from conventional commits.

    Groups entries under Breaking Changes, Features, and Bug Fixes.
    """
    today = date.today().isoformat()
    lines = [f"## [{new_version}] - {today}", ""]

    breaking = []
    features = []
    fixes = []

    for commit in commits:
        first_line = commit.split('\n')[0].strip()
        classification = classify_commit(commit)
        if classification is None:
            continue

        # Extract the description after the type prefix
        desc_match = re.match(r'^[a-z]+(\([^)]+\))?!?:\s*(.+)', first_line)
        desc = desc_match.group(2) if desc_match else first_line

        if classification == 'major':
            breaking.append(f"- **BREAKING:** {desc}")
        elif classification == 'minor':
            features.append(f"- {desc}")
        elif classification == 'patch':
            fixes.append(f"- {desc}")

    if breaking:
        lines.append("### Breaking Changes")
        lines.extend(breaking)
        lines.append("")
    if features:
        lines.append("### Features")
        lines.extend(features)
        lines.append("")
    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(fixes)
        lines.append("")

    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main():
    """Orchestrate the version bump pipeline."""
    try:
        # 1. Read current version
        version_str, source = read_version()
        version_tuple = parse_version(version_str)
        print(f"Current version: {version_str} (from {source})")

        # 2. Get commit messages and determine bump type
        commits = get_commits()
        if not commits:
            print("Error: no commits found", file=sys.stderr)
            sys.exit(1)

        bump_type = determine_bump_type(commits)
        print(f"Bump type: {bump_type}")

        # 3. Compute new version
        new_version = bump_version(version_tuple, bump_type)
        print(f"New version: {new_version}")

        # 4. Write updated version back to file
        write_version(new_version, source)

        # 5. Generate and write changelog
        changelog_entry = generate_changelog(commits, new_version)
        existing = ""
        if os.path.exists('CHANGELOG.md'):
            with open('CHANGELOG.md', 'r') as f:
                existing = f.read()

        with open('CHANGELOG.md', 'w') as f:
            header = "# Changelog\n\n"
            if existing.startswith("# Changelog"):
                body = existing[len("# Changelog"):].lstrip('\n')
                f.write(header + changelog_entry + '\n' + body)
            else:
                f.write(header + changelog_entry)

        print("Changelog updated")

        # 6. Machine-readable output for CI consumption
        print(f"BUMPED_VERSION={new_version}")

    except (FileNotFoundError, ValueError, RuntimeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
