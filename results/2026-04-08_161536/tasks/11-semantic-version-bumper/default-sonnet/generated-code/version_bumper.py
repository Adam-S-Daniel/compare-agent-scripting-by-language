"""
Semantic Version Bumper
=======================
Parses a version file (version.txt or package.json), determines the next
version from conventional commit messages, updates the file in-place, and
generates a changelog entry.

Conventional commit types → bump level:
  feat!  / BREAKING CHANGE footer  → major
  feat                             → minor
  fix                              → patch
  anything else (chore/docs/…)     → no bump
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Optional


# ─────────────────────────────────────────────
# Version parsing
# ─────────────────────────────────────────────

_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def parse_version(file_path: str) -> tuple[int, int, int]:
    """Return (major, minor, patch) parsed from *file_path*.

    Supports:
    - Plain text files containing only the version string (version.txt style).
    - JSON files with a top-level "version" field (package.json style).

    Raises:
        FileNotFoundError: if *file_path* does not exist.
        ValueError: if the version string is not valid semver.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {file_path}")

    if path.suffix == ".json":
        data = json.loads(path.read_text())
        raw = data.get("version", "")
    else:
        raw = path.read_text().strip()

    m = _SEMVER_RE.match(raw)
    if not m:
        raise ValueError(f"Invalid semantic version '{raw}' in {file_path}")

    return int(m.group(1)), int(m.group(2)), int(m.group(3))


# ─────────────────────────────────────────────
# Commit type detection
# ─────────────────────────────────────────────

# Matches the conventional commit header: <type>[optional scope][!]: <description>
_CONV_COMMIT_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\([^)]*\))?(?P<breaking>!)?\s*:",
    re.MULTILINE,
)
_BREAKING_FOOTER_RE = re.compile(r"BREAKING[- ]CHANGE\s*:", re.IGNORECASE)

# Priority ordering (highest first)
_BUMP_PRIORITY = {"major": 3, "minor": 2, "patch": 1}


def _classify_commit(message: str) -> Optional[str]:
    """Return 'major', 'minor', 'patch', or None for a single commit message."""
    header_match = _CONV_COMMIT_RE.match(message)
    if not header_match:
        return None

    commit_type = header_match.group("type")
    is_breaking = bool(header_match.group("breaking"))

    # Breaking change indicator in header (feat!) or in footer
    if is_breaking or _BREAKING_FOOTER_RE.search(message):
        return "major"

    if commit_type == "feat":
        return "minor"

    if commit_type == "fix":
        return "patch"

    return None  # chore, docs, style, test, ci, …


def determine_bump_type(commits: list[str]) -> Optional[str]:
    """Return the highest-priority bump type across all *commits*, or None."""
    highest: Optional[str] = None
    for msg in commits:
        level = _classify_commit(msg)
        if level and (_BUMP_PRIORITY.get(level, 0) > _BUMP_PRIORITY.get(highest or "", 0)):
            highest = level
    return highest


# ─────────────────────────────────────────────
# Version bump calculation
# ─────────────────────────────────────────────

def bump_version(
    current: tuple[int, int, int],
    bump_type: Optional[str],
) -> tuple[int, int, int]:
    """Return the next (major, minor, patch) tuple.

    Rules:
    - major bump resets minor and patch to 0.
    - minor bump resets patch to 0.
    - patch bump increments patch only.
    - None returns *current* unchanged.

    Raises:
        ValueError: for unrecognised *bump_type* values.
    """
    major, minor, patch = current

    if bump_type is None:
        return current
    if bump_type == "major":
        return (major + 1, 0, 0)
    if bump_type == "minor":
        return (major, minor + 1, 0)
    if bump_type == "patch":
        return (major, minor, patch + 1)

    raise ValueError(f"Unknown bump type: '{bump_type}'")


# ─────────────────────────────────────────────
# Version file update
# ─────────────────────────────────────────────

def _version_str(version: tuple[int, int, int]) -> str:
    return "{}.{}.{}".format(*version)


def update_version_file(file_path: str, new_version: tuple[int, int, int]) -> None:
    """Write *new_version* back to *file_path* (version.txt or package.json)."""
    path = Path(file_path)
    ver_str = _version_str(new_version)

    if path.suffix == ".json":
        data = json.loads(path.read_text())
        data["version"] = ver_str
        path.write_text(json.dumps(data, indent=2) + "\n")
    else:
        path.write_text(ver_str + "\n")


# ─────────────────────────────────────────────
# Changelog generation
# ─────────────────────────────────────────────

def generate_changelog_entry(
    new_version: tuple[int, int, int],
    commits: list[str],
) -> str:
    """Return a markdown changelog entry for *new_version* from *commits*."""
    today = date.today().isoformat()
    ver_str = _version_str(new_version)

    # Bucket commits by section
    sections: dict[str, list[str]] = {
        "Breaking Changes": [],
        "Features": [],
        "Bug Fixes": [],
        "Other": [],
    }

    for msg in commits:
        header_match = _CONV_COMMIT_RE.match(msg)
        if not header_match:
            continue

        commit_type = header_match.group("type")
        is_breaking = bool(header_match.group("breaking")) or bool(
            _BREAKING_FOOTER_RE.search(msg)
        )

        # Extract the short description from the first line
        first_line = msg.splitlines()[0]
        # Strip the "type[(scope)][!]: " prefix to get just the description
        desc = re.sub(r"^[a-z]+(?:\([^)]*\))?!?\s*:\s*", "", first_line)

        if is_breaking:
            sections["Breaking Changes"].append(desc)
        elif commit_type == "feat":
            sections["Features"].append(desc)
        elif commit_type == "fix":
            sections["Bug Fixes"].append(desc)
        else:
            sections["Other"].append(desc)

    lines = [f"## [{ver_str}] - {today}", ""]

    section_titles = {
        "Breaking Changes": "### Breaking Changes",
        "Features": "### Features",
        "Bug Fixes": "### Bug Fixes",
        "Other": "### Other",
    }

    for key, title in section_titles.items():
        items = sections[key]
        if items:
            lines.append(title)
            lines.extend(f"- {item}" for item in items)
            lines.append("")

    return "\n".join(lines)


# ─────────────────────────────────────────────
# Changelog file I/O
# ─────────────────────────────────────────────

def update_changelog(changelog_path: str, entry: str) -> None:
    """Prepend *entry* to the changelog file at *changelog_path*."""
    path = Path(changelog_path)
    existing = path.read_text() if path.exists() else ""
    path.write_text(entry.rstrip("\n") + "\n\n" + existing)


# ─────────────────────────────────────────────
# High-level pipeline
# ─────────────────────────────────────────────

def run_version_bumper(
    version_file: str,
    commits: list[str],
    changelog_path: Optional[str] = None,
) -> str:
    """Run the full version-bump pipeline.

    Steps:
    1. Parse current version from *version_file*.
    2. Determine bump type from *commits*.
    3. Calculate new version.
    4. If version changed, update *version_file* and (optionally) *changelog_path*.
    5. Return the new version string.
    """
    current = parse_version(version_file)
    bump_type = determine_bump_type(commits)
    new_version = bump_version(current, bump_type)

    if new_version != current:
        update_version_file(version_file, new_version)

        if changelog_path:
            entry = generate_changelog_entry(new_version, commits)
            update_changelog(changelog_path, entry)

    return _version_str(new_version)


# ─────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────

def main() -> None:
    """CLI: version_bumper.py <version-file> [changelog-file]

    Reads commit messages from stdin (one per line, blank-line-separated for
    multi-line bodies), prints the new version to stdout.
    """
    if len(sys.argv) < 2:
        print("Usage: version_bumper.py <version-file> [changelog-file]", file=sys.stderr)
        sys.exit(1)

    version_file = sys.argv[1]
    changelog_file = sys.argv[2] if len(sys.argv) > 2 else None

    # Read commits from stdin; records are separated by NUL (\0) or double newlines
    raw = sys.stdin.read()
    if "\0" in raw:
        commits = [c.strip() for c in raw.split("\0") if c.strip()]
    else:
        # Fall back: each non-empty line is its own commit
        commits = [line.strip() for line in raw.splitlines() if line.strip()]

    new_version = run_version_bumper(version_file, commits, changelog_file)
    print(new_version)


if __name__ == "__main__":
    main()
