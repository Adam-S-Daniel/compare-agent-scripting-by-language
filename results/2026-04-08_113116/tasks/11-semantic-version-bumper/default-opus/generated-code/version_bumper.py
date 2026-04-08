"""Semantic version bumper.

Parses version files, classifies conventional commits, bumps the version,
generates a changelog entry, and outputs the new version.
"""

import re
import json
import os
import sys
from datetime import date
from pathlib import Path


# --- Version parsing ---

def parse_version(version_str: str) -> tuple[int, int, int]:
    """Parse a semver string like '1.2.3' or 'v1.2.3' into (major, minor, patch)."""
    match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)$", version_str.strip())
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str}'")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


# --- Commit classification ---

# Conventional commit pattern: type(optional-scope)optional-!: description
_COMMIT_RE = re.compile(r"^(?P<type>\w+)(?:\([^)]*\))?(?P<bang>!)?:\s")

# Only these types trigger a version bump
_BUMP_TYPES = {"feat": "minor", "fix": "patch", "perf": "patch"}


def classify_commits(commits: list[str]) -> dict[str, list[str]]:
    """Classify conventional commits into {major, minor, patch} buckets.

    A commit is 'major' if it has a '!' after the type/scope or contains
    'BREAKING CHANGE:' in the body. 'feat' maps to minor, 'fix'/'perf' to patch.
    Non-bumping types (docs, chore, style, etc.) are ignored.
    """
    result: dict[str, list[str]] = {}
    for commit in commits:
        first_line = commit.split("\n")[0]
        match = _COMMIT_RE.match(first_line)
        if not match:
            continue

        # Check for breaking change indicators
        if match.group("bang") or "BREAKING CHANGE:" in commit:
            result.setdefault("major", []).append(commit)
            continue

        bump = _BUMP_TYPES.get(match.group("type"))
        if bump:
            result.setdefault(bump, []).append(commit)

    return result


def determine_bump(classified: dict[str, list[str]]) -> str | None:
    """Return the highest-priority bump level, or None if no bump needed."""
    for level in ("major", "minor", "patch"):
        if level in classified:
            return level
    return None


# --- Version bumping ---

def bump_version(version: tuple[int, int, int], level: str | None) -> tuple[int, int, int]:
    """Apply a bump level to a version tuple. Returns unchanged version if level is None."""
    major, minor, patch = version
    if level == "major":
        return (major + 1, 0, 0)
    elif level == "minor":
        return (major, minor + 1, 0)
    elif level == "patch":
        return (major, minor, patch + 1)
    return version


def format_version(version: tuple[int, int, int]) -> str:
    """Format a version tuple as 'X.Y.Z'."""
    return f"{version[0]}.{version[1]}.{version[2]}"


# --- Version file I/O ---

def read_version_file(path: Path) -> str:
    """Read a version string from a plain VERSION file or package.json."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {path}")

    if path.name == "package.json":
        data = json.loads(path.read_text())
        if "version" not in data:
            raise ValueError(f"No 'version' field in {path}")
        return data["version"]

    # Plain text version file
    return path.read_text().strip()


def write_version_file(path: Path, new_version: str) -> None:
    """Write a version string to a plain VERSION file or package.json."""
    path = Path(path)
    if path.name == "package.json":
        data = json.loads(path.read_text())
        data["version"] = new_version
        path.write_text(json.dumps(data, indent=2) + "\n")
    else:
        path.write_text(new_version + "\n")


# --- Changelog generation ---

# Map bump categories to human-readable changelog section names
_SECTION_NAMES = {
    "major": "BREAKING CHANGES",
    "minor": "Features",
    "patch": "Bug Fixes",
}


def _extract_description(commit: str) -> str:
    """Pull the short description out of a conventional commit message."""
    first_line = commit.split("\n")[0]
    # Strip 'type(scope)!: ' prefix to get just the description
    match = _COMMIT_RE.match(first_line)
    if match:
        return first_line[match.end():]
    return first_line


def generate_changelog(version: str, classified: dict[str, list[str]]) -> str:
    """Produce a markdown changelog entry for the given version and classified commits."""
    today = date.today().isoformat()
    lines = [f"## {version} ({today})", ""]

    # Emit sections in priority order so breaking changes appear first
    for level in ("major", "minor", "patch"):
        commits = classified.get(level, [])
        if not commits:
            continue
        lines.append(f"### {_SECTION_NAMES[level]}")
        lines.append("")
        for c in commits:
            lines.append(f"- {_extract_description(c)}")
        lines.append("")

    return "\n".join(lines)


# --- Fixture loading ---

def load_commits_from_file(path: Path) -> list[str]:
    """Load commit messages from a fixture file.

    Commits are separated by '---' lines, allowing multi-line commit
    bodies (e.g., with BREAKING CHANGE: footers) within a single entry.
    """
    path = Path(path)
    text = path.read_text()

    chunks = re.split(r"\n---\n", text.strip())
    return [chunk.strip() for chunk in chunks if chunk.strip()]


# --- CLI entry point ---

def main() -> None:
    """CLI: version_bumper.py <version-file> <commit-log-file>

    Reads the current version, classifies commits, bumps the version,
    writes the updated file, prints changelog and new version to stdout.
    """
    if len(sys.argv) < 3:
        print(
            "Usage: version_bumper.py <version-file> <commit-log-file>",
            file=sys.stderr,
        )
        sys.exit(1)

    version_file = Path(sys.argv[1])
    commit_file = Path(sys.argv[2])

    # Read current version
    raw_version = read_version_file(version_file)
    current = parse_version(raw_version)

    # Classify commits and determine bump
    commits = load_commits_from_file(commit_file)
    classified = classify_commits(commits)
    level = determine_bump(classified)

    if level is None:
        print("No version-bumping commits found. Version unchanged.")
        print(format_version(current))
        sys.exit(0)

    # Bump and write
    new = bump_version(current, level)
    new_str = format_version(new)
    write_version_file(version_file, new_str)

    # Generate and print changelog
    changelog = generate_changelog(new_str, classified)
    print(changelog)
    print(f"Version bumped: {format_version(current)} -> {new_str} ({level})")


if __name__ == "__main__":
    main()
