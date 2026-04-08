# Semantic Version Bumper
# Parses version strings, classifies conventional commits, bumps versions,
# and generates changelog entries.

import json
import re
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


@dataclass
class SemVer:
    """Represents a semantic version (major.minor.patch)."""
    major: int
    minor: int
    patch: int

    def __str__(self):
        return f"{self.major}.{self.minor}.{self.patch}"


class BumpType(Enum):
    """The type of version bump indicated by a commit."""
    MAJOR = "major"
    MINOR = "minor"
    PATCH = "patch"


@dataclass
class Commit:
    """A parsed conventional commit."""
    bump_type: BumpType
    type: str | None      # e.g. "feat", "fix", "chore"
    description: str
    scope: str | None


# Maps conventional commit types to bump levels
_BUMP_MAP = {"feat": BumpType.MINOR}
# Everything else (fix, chore, docs, refactor, etc.) defaults to PATCH


def parse_commit(message: str) -> Commit:
    """Parse a conventional commit message and determine the bump type.

    Supports: type[(scope)][!]: description
    A trailing '!' or 'BREAKING CHANGE:' footer triggers a major bump.
    """
    first_line = message.split("\n")[0]
    is_breaking = "BREAKING CHANGE:" in message or "BREAKING-CHANGE:" in message

    # Match conventional commit pattern: type(scope)!: description
    match = re.match(r"^(\w+)(?:\(([^)]+)\))?(!)?\s*:\s*(.+)$", first_line)
    if not match:
        # Non-conventional commit — treat as patch
        return Commit(BumpType.PATCH, None, first_line.strip(), None)

    ctype, scope, bang, desc = match.groups()
    if bang or is_breaking:
        bump = BumpType.MAJOR
    else:
        bump = _BUMP_MAP.get(ctype, BumpType.PATCH)

    return Commit(bump, ctype, desc.strip(), scope)


def bump_version(current: SemVer, commit_messages: list[str]) -> SemVer:
    """Determine the next version by analyzing commit messages.

    The highest bump type wins: major > minor > patch.
    Major resets minor+patch, minor resets patch.
    """
    if not commit_messages:
        raise ValueError("No commits provided — cannot determine version bump")

    # Parse all commits and find the highest bump level
    # MAJOR > MINOR > PATCH, so we use ordering: MAJOR=0, MINOR=1, PATCH=2
    priority = {BumpType.MAJOR: 0, BumpType.MINOR: 1, BumpType.PATCH: 2}
    parsed = [parse_commit(msg) for msg in commit_messages]
    highest = min(parsed, key=lambda c: priority[c.bump_type]).bump_type

    if highest == BumpType.MAJOR:
        return SemVer(current.major + 1, 0, 0)
    elif highest == BumpType.MINOR:
        return SemVer(current.major, current.minor + 1, 0)
    else:
        return SemVer(current.major, current.minor, current.patch + 1)


def parse_version(version_str: str) -> SemVer:
    """Parse a semantic version string like '1.2.3' or 'v1.2.3'."""
    match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)$", version_str.strip())
    if not match:
        raise ValueError(f"Invalid semantic version: '{version_str}'")
    return SemVer(int(match.group(1)), int(match.group(2)), int(match.group(3)))


def read_version_file(path: str) -> SemVer:
    """Read a version from a VERSION file or package.json."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Version file not found: {path}")

    content = p.read_text()

    if p.name == "package.json":
        data = json.loads(content)
        if "version" not in data:
            raise ValueError(f"No 'version' field in {path}")
        return parse_version(data["version"])

    # Plain text version file (e.g. VERSION)
    return parse_version(content.strip())


def write_version_file(path: str, version: SemVer) -> None:
    """Write the new version to a VERSION file or package.json."""
    p = Path(path)

    if p.name == "package.json":
        data = json.loads(p.read_text())
        data["version"] = str(version)
        p.write_text(json.dumps(data, indent=2) + "\n")
    else:
        p.write_text(str(version) + "\n")


# Changelog section headers mapped from commit types
_SECTION_MAP = {
    "feat": "Features",
    "fix": "Bug Fixes",
}


def generate_changelog(version: SemVer, commit_messages: list[str]) -> str:
    """Generate a markdown changelog entry grouped by commit type."""
    if not commit_messages:
        raise ValueError("No commits provided — cannot generate changelog")

    parsed = [parse_commit(msg) for msg in commit_messages]

    # Group commits by section
    sections: dict[str, list[Commit]] = {}
    for c in parsed:
        section = _SECTION_MAP.get(c.type, "Other") if c.type else "Other"
        sections.setdefault(section, []).append(c)

    lines = [f"## {version}\n"]
    # Render known sections first in a stable order, then "Other"
    for section in ["Features", "Bug Fixes", "Other"]:
        if section not in sections:
            continue
        lines.append(f"### {section}\n")
        for c in sections[section]:
            prefix = "**BREAKING** " if c.bump_type == BumpType.MAJOR else ""
            scope = f"**{c.scope}**: " if c.scope else ""
            lines.append(f"- {prefix}{scope}{c.description}")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def load_commits(path: str) -> list[str]:
    """Load commit messages from a file (one per line, blank lines skipped)."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Commits file not found: {path}")
    return [line for line in p.read_text().splitlines() if line.strip()]


def main():
    """CLI entry point: semver.py <version-file> <commits-file>"""
    if len(sys.argv) != 3:
        print("Usage: semver.py <version-file> <commits-file>", file=sys.stderr)
        sys.exit(1)

    version_file, commits_file = sys.argv[1], sys.argv[2]

    try:
        current = read_version_file(version_file)
        commits = load_commits(commits_file)
        new_version = bump_version(current, commits)
        write_version_file(version_file, new_version)
        changelog = generate_changelog(new_version, commits)

        print(f"{current} -> {new_version}\n")
        print(changelog)
    except (ValueError, FileNotFoundError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
