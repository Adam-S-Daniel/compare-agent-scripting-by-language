#!/usr/bin/env python3
"""
Semantic version bumper based on conventional commit messages.

Parses a VERSION file, classifies commits (feat->minor, fix->patch, breaking->major),
bumps the version, generates a changelog entry, and outputs the new version.
"""
import argparse
import json
import os
import re
import sys
from datetime import date


def parse_version(version_str):
    """Parse a semantic version string into (major, minor, patch) tuple."""
    version_str = version_str.strip().lstrip("v")
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)$", version_str)
    if not match:
        print(f"Error: Invalid semantic version: '{version_str}'", file=sys.stderr)
        sys.exit(1)
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def read_version_file(path):
    """Read version from a VERSION file or package.json."""
    if not os.path.isfile(path):
        print(f"Error: Version file not found: {path}", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        content = f.read().strip()
    if path.endswith(".json"):
        data = json.loads(content)
        if "version" not in data:
            print("Error: No 'version' field in package.json", file=sys.stderr)
            sys.exit(1)
        return data["version"]
    return content


def write_version_file(path, version_str):
    """Write the new version back to the file."""
    if path.endswith(".json"):
        with open(path) as f:
            data = json.load(f)
        data["version"] = version_str
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    else:
        with open(path, "w") as f:
            f.write(version_str + "\n")


def classify_commit(message):
    """
    Classify a conventional commit message.
    Returns 'major', 'minor', 'patch', or None if unrecognized.
    """
    message = message.strip()
    if not message:
        return None
    # Breaking change: '!' before colon or BREAKING CHANGE in footer
    if re.match(r"^\w+(\(.+\))?!:", message):
        return "major"
    if "BREAKING CHANGE:" in message or "BREAKING-CHANGE:" in message:
        return "major"
    # Feature commits
    if re.match(r"^feat(\(.+\))?:", message):
        return "minor"
    # Fix commits
    if re.match(r"^fix(\(.+\))?:", message):
        return "patch"
    return None


def determine_bump(commits):
    """
    Given a list of commit messages, determine the highest-priority bump type.
    Priority: major > minor > patch.
    """
    bump = None
    for commit in commits:
        classification = classify_commit(commit)
        if classification == "major":
            return "major"
        elif classification == "minor":
            bump = "minor"
        elif classification == "patch" and bump is None:
            bump = "patch"
    if bump is None:
        print("Error: No conventional commits found to determine version bump",
              file=sys.stderr)
        sys.exit(1)
    return bump


def bump_version(major, minor, patch, bump_type):
    """Apply the bump to the version tuple, return new version string."""
    if bump_type == "major":
        return f"{major + 1}.0.0"
    elif bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    else:
        return f"{major}.{minor}.{patch + 1}"


def generate_changelog(commits, new_version):
    """Generate a changelog entry from classified commits."""
    today = os.environ.get("CHANGELOG_DATE", date.today().isoformat())
    features = []
    fixes = []
    breaking = []

    for commit in commits:
        commit = commit.strip()
        if not commit:
            continue
        classification = classify_commit(commit)
        # Extract the description part after the prefix
        desc = re.sub(r"^\w+(\(.+\))?!?:\s*", "", commit.split("\n")[0])
        if classification == "major":
            breaking.append(desc)
        elif classification == "minor":
            features.append(desc)
        elif classification == "patch":
            fixes.append(desc)

    lines = [f"## [{new_version}] - {today}", ""]
    if breaking:
        lines.append("### Breaking Changes")
        for item in breaking:
            lines.append(f"- {item}")
        lines.append("")
    if features:
        lines.append("### Features")
        for item in features:
            lines.append(f"- {item}")
        lines.append("")
    if fixes:
        lines.append("### Fixes")
        for item in fixes:
            lines.append(f"- {item}")
        lines.append("")
    return "\n".join(lines)


def read_commits(commits_file=None):
    """Read commits from a file or from git log."""
    if commits_file:
        if not os.path.isfile(commits_file):
            print(f"Error: Commits file not found: {commits_file}", file=sys.stderr)
            sys.exit(1)
        with open(commits_file) as f:
            # Support multi-line commits separated by blank lines
            content = f.read()
            return [c.strip() for c in content.strip().split("\n") if c.strip()]
    # Fall back to git log
    import subprocess
    result = subprocess.run(
        ["git", "log", "--format=%B", "--no-merges", "HEAD~10..HEAD"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        # Try without range for repos with fewer than 10 commits
        result = subprocess.run(
            ["git", "log", "--format=%B", "--no-merges"],
            capture_output=True, text=True
        )
    if result.returncode != 0:
        print(f"Error: Failed to read git log: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return [line.strip() for line in result.stdout.strip().split("\n") if line.strip()]


def main():
    parser = argparse.ArgumentParser(description="Semantic version bumper")
    parser.add_argument("--version-file", default="VERSION",
                        help="Path to version file (VERSION or package.json)")
    parser.add_argument("--commits-file", default=None,
                        help="Path to commits file (one per line, for testing)")
    parser.add_argument("--changelog-file", default="CHANGELOG.md",
                        help="Path to changelog output file")
    args = parser.parse_args()

    current_version_str = read_version_file(args.version_file)
    major, minor, patch = parse_version(current_version_str)
    print(f"Current version: {major}.{minor}.{patch}")

    commits = read_commits(args.commits_file)
    if not commits:
        print("Error: No commits found", file=sys.stderr)
        sys.exit(1)

    bump_type = determine_bump(commits)
    new_version = bump_version(major, minor, patch, bump_type)
    print(f"Bump type: {bump_type}")
    print(f"New version: {new_version}")

    write_version_file(args.version_file, new_version)

    changelog_entry = generate_changelog(commits, new_version)
    print(f"\n{changelog_entry}")

    # Write changelog
    if os.path.isfile(args.changelog_file):
        with open(args.changelog_file) as f:
            existing = f.read()
        with open(args.changelog_file, "w") as f:
            f.write(changelog_entry + "\n" + existing)
    else:
        with open(args.changelog_file, "w") as f:
            f.write("# Changelog\n\n" + changelog_entry)

    # Output for GitHub Actions
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            f.write(f"new_version={new_version}\n")
            f.write(f"bump_type={bump_type}\n")

    return new_version


if __name__ == "__main__":
    main()
