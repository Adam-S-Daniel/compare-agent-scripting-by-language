"""
Semantic Version Bumper

Reads a VERSION file (or package.json), analyzes conventional commits to determine
the appropriate semver bump (major/minor/patch), updates the file, and generates
a changelog entry.

Conventional commit rules:
  BREAKING CHANGE or `type!:` in any commit -> major
  feat:                                      -> minor
  fix: (or any other type)                   -> patch
"""
import sys
import re
import os
import json
from pathlib import Path


def parse_version(version_str: str) -> tuple[int, int, int]:
    """Parse 'MAJOR.MINOR.PATCH' string into a tuple of ints."""
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)\s*$", version_str.strip())
    if not match:
        raise ValueError(f"Invalid version format: {version_str!r}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def determine_bump_type(commits: list[str]) -> str:
    """
    Scan commit messages and return the highest required bump level.
    Short-circuits on 'major'; otherwise accumulates highest seen level.
    """
    bump = "patch"
    for commit in commits:
        line = commit.strip()
        # Breaking change: explicit keyword anywhere in message
        if "BREAKING CHANGE" in line:
            return "major"
        # Breaking change: type followed by ! before colon (e.g. feat!, fix!, feat(scope)!)
        if re.match(r"^[a-z]+(\([^)]+\))?!:", line):
            return "major"
        # Feature bump
        if re.match(r"^feat(\([^)]+\))?:", line):
            bump = "minor"
    return bump


def bump_version(version: tuple[int, int, int], bump_type: str) -> tuple[int, int, int]:
    """Return new version tuple after applying bump_type."""
    major, minor, patch = version
    if bump_type == "major":
        return (major + 1, 0, 0)
    if bump_type == "minor":
        return (major, minor + 1, 0)
    return (major, minor, patch + 1)


def format_version(version: tuple[int, int, int]) -> str:
    return ".".join(str(v) for v in version)


def generate_changelog_entry(version: str, commits: list[str]) -> str:
    """Build a markdown changelog section for the given version."""
    breaking: list[str] = []
    features: list[str] = []
    fixes: list[str] = []
    other: list[str] = []

    for commit in commits:
        line = commit.strip()
        if not line:
            continue
        if "BREAKING CHANGE" in line or re.match(r"^[a-z]+(\([^)]+\))?!:", line):
            breaking.append(f"- {line}")
        elif re.match(r"^feat(\([^)]+\))?:", line):
            features.append(f"- {line}")
        elif re.match(r"^fix(\([^)]+\))?:", line):
            fixes.append(f"- {line}")
        else:
            other.append(f"- {line}")

    sections: list[str] = [f"## {version}\n"]
    if breaking:
        sections.append("### Breaking Changes\n")
        sections.extend(breaking)
        sections.append("")
    if features:
        sections.append("### Features\n")
        sections.extend(features)
        sections.append("")
    if fixes:
        sections.append("### Bug Fixes\n")
        sections.extend(fixes)
        sections.append("")
    if other:
        sections.append("### Other\n")
        sections.extend(other)
        sections.append("")

    return "\n".join(sections) + "\n"


def read_version(version_file: str) -> str:
    """Read version string from VERSION file or package.json."""
    p = Path(version_file)
    if p.name == "package.json":
        data = json.loads(p.read_text())
        return data["version"]
    return p.read_text().strip()


def write_version(new_version: str, version_file: str) -> None:
    """Write new version to VERSION file or package.json."""
    p = Path(version_file)
    if p.name == "package.json":
        data = json.loads(p.read_text())
        data["version"] = new_version
        p.write_text(json.dumps(data, indent=2) + "\n")
    else:
        p.write_text(new_version + "\n")


def read_commits(commits_file: str) -> list[str]:
    """Read non-blank commit messages from a text file (one per line)."""
    p = Path(commits_file)
    if not p.exists():
        return []
    return [line for line in p.read_text().splitlines() if line.strip()]


def main() -> None:
    version_file = os.environ.get("VERSION_FILE", "VERSION")
    commits_file = os.environ.get("COMMITS_FILE", "commits.txt")

    if not Path(version_file).exists():
        print(f"Error: version file not found: {version_file}", file=sys.stderr)
        sys.exit(1)

    current = read_version(version_file)
    try:
        version_tuple = parse_version(current)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    commits = read_commits(commits_file)
    if not commits:
        print(f"Warning: no commits found in {commits_file}", file=sys.stderr)

    bump_type = determine_bump_type(commits)
    new_tuple = bump_version(version_tuple, bump_type)
    new_version = format_version(new_tuple)

    write_version(new_version, version_file)

    # Prepend new entry to CHANGELOG.md
    changelog_path = Path("CHANGELOG.md")
    existing = changelog_path.read_text() if changelog_path.exists() else ""
    entry = generate_changelog_entry(new_version, commits)
    changelog_path.write_text(entry + existing)

    print(f"Bumped {current} -> {new_version} ({bump_type})")
    print(f"NEW_VERSION={new_version}")


if __name__ == "__main__":
    main()
