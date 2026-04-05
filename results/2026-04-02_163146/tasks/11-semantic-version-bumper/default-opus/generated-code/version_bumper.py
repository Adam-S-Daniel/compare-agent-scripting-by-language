"""
Semantic Version Bumper
=======================
Parses version files (plain text or package.json), determines the next
version from conventional commit messages, updates the file, and generates
a changelog entry.

Conventional Commits mapping:
  - fix:              -> patch bump
  - feat:             -> minor bump
  - <type>!: or
    BREAKING CHANGE:  -> major bump
  - anything else     -> no bump (but listed in changelog under "Other")

The highest bump type across all commits wins.
"""

import enum
import json
import os
import re
from datetime import date


# ── Bump type enum (ordered so max() gives the right answer) ─────────

class BumpType(enum.IntEnum):
    NONE = 0
    PATCH = 1
    MINOR = 2
    MAJOR = 3


# ── Cycle 1: parse / format version strings ─────────────────────────

_VERSION_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")


def parse_version(raw: str) -> tuple[int, int, int]:
    """Parse a semver string like '1.2.3' or 'v1.2.3' into (major, minor, patch).

    Raises ValueError for anything that doesn't match X.Y.Z.
    """
    raw = raw.strip()
    m = _VERSION_RE.match(raw)
    if not m:
        raise ValueError(f"Invalid semantic version: {raw!r}")
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))


def format_version(version: tuple[int, int, int]) -> str:
    """Format (major, minor, patch) back to 'X.Y.Z'."""
    return f"{version[0]}.{version[1]}.{version[2]}"


# ── Cycle 2: classify a single commit message ───────────────────────

# Matches lines like: feat: ..., fix(scope): ..., feat!: ...
_CONVENTIONAL_RE = re.compile(
    r"^(?P<type>[a-z]+)"          # type (feat, fix, chore, …)
    r"(?:\([^)]*\))?"             # optional scope
    r"(?P<bang>!)?"               # optional breaking-change marker
    r":\s",                       # colon + space
)


def classify_commit(message: str) -> BumpType:
    """Classify a commit message into a BumpType based on Conventional Commits.

    Breaking changes (! suffix or BREAKING CHANGE footer) -> MAJOR
    feat -> MINOR
    fix  -> PATCH
    Everything else -> NONE
    """
    first_line = message.split("\n")[0]
    m = _CONVENTIONAL_RE.match(first_line)

    # Check for BREAKING CHANGE anywhere in the full message
    if "BREAKING CHANGE" in message:
        return BumpType.MAJOR

    if not m:
        return BumpType.NONE

    if m.group("bang"):
        return BumpType.MAJOR

    commit_type = m.group("type")
    if commit_type == "feat":
        return BumpType.MINOR
    if commit_type == "fix":
        return BumpType.PATCH

    # Other conventional types (chore, docs, style, refactor, test, ci, …)
    return BumpType.NONE


# ── Cycle 3: determine the highest bump from a list of commits ───────

def determine_bump(commits: list[str]) -> BumpType:
    """Return the highest BumpType across all commits."""
    if not commits:
        return BumpType.NONE
    return max(classify_commit(c) for c in commits)


# ── Cycle 4: apply the bump ─────────────────────────────────────────

def bump_version(
    version: tuple[int, int, int], bump: BumpType
) -> tuple[int, int, int]:
    """Return a new version tuple with the bump applied.

    MAJOR -> (major+1, 0, 0)
    MINOR -> (major, minor+1, 0)
    PATCH -> (major, minor, patch+1)
    NONE  -> unchanged
    """
    major, minor, patch = version
    if bump == BumpType.MAJOR:
        return (major + 1, 0, 0)
    if bump == BumpType.MINOR:
        return (major, minor + 1, 0)
    if bump == BumpType.PATCH:
        return (major, minor, patch + 1)
    return version


# ── Cycle 5: read / write version files ──────────────────────────────

def read_version_file(path: str) -> tuple[int, int, int]:
    """Read a version from a plain-text VERSION file or a package.json.

    Raises FileNotFoundError if the file doesn't exist.
    Raises ValueError if the version can't be parsed.
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"Version file not found: {path}")

    if path.endswith(".json"):
        with open(path) as f:
            data = json.load(f)
        if "version" not in data:
            raise ValueError(f"No 'version' field in {path}")
        return parse_version(data["version"])

    # Plain text file — first non-empty line is the version
    with open(path) as f:
        raw = f.read().strip()
    return parse_version(raw)


def write_version_file(path: str, version: tuple[int, int, int]) -> None:
    """Write a version back to a plain-text file or package.json."""
    version_str = format_version(version)

    if path.endswith(".json"):
        with open(path) as f:
            data = json.load(f)
        data["version"] = version_str
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        return

    # Plain text — just write the version string
    with open(path, "w") as f:
        f.write(version_str + "\n")


# ── Cycle 6: generate changelog ──────────────────────────────────────

def _parse_commit_parts(message: str) -> dict:
    """Extract type, scope, description, and breaking flag from a commit."""
    first_line = message.split("\n")[0]
    m = _CONVENTIONAL_RE.match(first_line)
    is_breaking = "BREAKING CHANGE" in message or (m and m.group("bang"))

    if not m:
        return {
            "type": None,
            "scope": None,
            "description": first_line.strip(),
            "breaking": is_breaking,
        }

    # Extract scope if present
    scope_match = re.search(r"\(([^)]+)\)", first_line)
    scope = scope_match.group(1) if scope_match else None
    # Description is everything after "type(scope)!: "
    desc = re.sub(r"^[a-z]+(?:\([^)]*\))?!?:\s*", "", first_line)

    return {
        "type": m.group("type"),
        "scope": scope,
        "description": desc.strip(),
        "breaking": is_breaking,
    }


def generate_changelog(version: str, commits: list[str]) -> str:
    """Generate a markdown changelog entry for the given version and commits.

    Groups commits by type: BREAKING CHANGES, Features, Bug Fixes, Other.
    """
    lines = [f"## {version}\n"]

    if not commits:
        lines.append("No notable changes.\n")
        return "\n".join(lines)

    # Categorize commits
    breaking = []
    features = []
    fixes = []
    other = []

    for msg in commits:
        parts = _parse_commit_parts(msg)
        scope_prefix = f"**{parts['scope']}:** " if parts["scope"] else ""
        entry = f"- {scope_prefix}{parts['description']}"

        if parts["breaking"]:
            breaking.append(entry)
        elif parts["type"] == "feat":
            features.append(entry)
        elif parts["type"] == "fix":
            fixes.append(entry)
        else:
            other.append(entry)

    if breaking:
        lines.append("### BREAKING CHANGES\n")
        lines.extend(breaking)
        lines.append("")

    if features:
        lines.append("### Features\n")
        lines.extend(features)
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes\n")
        lines.extend(fixes)
        lines.append("")

    if other:
        lines.append("### Other\n")
        lines.extend(other)
        lines.append("")

    return "\n".join(lines)


# ── Cycle 7: full pipeline ───────────────────────────────────────────

def run_pipeline(
    version_path: str,
    commits: list[str],
    changelog_path: str,
) -> str:
    """End-to-end: read version, determine bump, write new version, generate changelog.

    Returns the new version string (or the unchanged version if no bump).
    """
    # 1. Read current version
    current = read_version_file(version_path)

    # 2. Determine bump type
    bump = determine_bump(commits)

    # 3. Compute new version
    new_version = bump_version(current, bump)
    new_version_str = format_version(new_version)

    # 4. Write updated version file (only if changed)
    if new_version != current:
        write_version_file(version_path, new_version)

    # 5. Generate and write changelog
    changelog_entry = generate_changelog(new_version_str, commits)
    if os.path.exists(changelog_path):
        with open(changelog_path) as f:
            existing = f.read()
        with open(changelog_path, "w") as f:
            f.write(changelog_entry + "\n" + existing)
    else:
        with open(changelog_path, "w") as f:
            f.write(changelog_entry)

    # 6. Output the new version
    return new_version_str


# ── CLI entry point ──────────────────────────────────────────────────

def main():
    """Simple CLI: version_bumper.py <version-file> <changelog-file> [commit-file]

    commit-file should contain one commit message per line (or multi-line
    messages separated by a blank line).  If omitted, reads from stdin.
    """
    import sys

    if len(sys.argv) < 3:
        print(
            "Usage: version_bumper.py <version-file> <changelog-file> [commit-file]",
            file=sys.stderr,
        )
        sys.exit(1)

    version_path = sys.argv[1]
    changelog_path = sys.argv[2]

    # Read commits
    if len(sys.argv) >= 4:
        with open(sys.argv[3]) as f:
            raw = f.read()
    else:
        raw = sys.stdin.read()

    # Split on double newlines to support multi-line commit bodies
    commits = [c.strip() for c in raw.split("\n\n") if c.strip()]
    if not commits:
        # Fall back to single-line splitting
        commits = [line.strip() for line in raw.splitlines() if line.strip()]

    try:
        new_version = run_pipeline(version_path, commits, changelog_path)
        print(new_version)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
