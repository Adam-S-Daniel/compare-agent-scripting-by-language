"""
Semantic Version Bumper
=======================
Reads a version from package.json, inspects conventional commit messages,
bumps the version (major / minor / patch), updates the file, and emits a
changelog entry.

Conventional Commits rules (https://www.conventionalcommits.org/):
  - feat!:  or   fix!:  or  any type with '!'      → MAJOR
  - "BREAKING CHANGE" anywhere in a commit message  → MAJOR
  - feat: / feat(scope):                            → MINOR
  - fix:  / fix(scope):                             → PATCH
  - anything else (chore, docs, ci, …)              → no bump

TDD implementation order (each section corresponds to a test class above):
  1. parse_version
  2. format_version
  3. determine_bump_type
  4. bump_version
  5. read_version_from_package_json / write_version_to_package_json
  6. generate_changelog_entry
  7. run  (integration)
"""

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Literal

# Type alias — one of the four possible bump outcomes.
BumpType = Literal["major", "minor", "patch", "none"]


# ──────────────────────────────────────────────────────────────────────────────
# 1 & 2. Version parsing / formatting
# ──────────────────────────────────────────────────────────────────────────────

def parse_version(version_str: str) -> tuple[int, int, int]:
    """Return (major, minor, patch) integers from a semver string.

    Accepts an optional leading 'v' (e.g. 'v1.2.3').
    Raises ValueError for strings that don't match the expected pattern.
    """
    match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)", version_str.strip())
    if not match:
        raise ValueError(f"Invalid semantic version: {version_str!r}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def format_version(major: int, minor: int, patch: int) -> str:
    """Render a version tuple back to 'X.Y.Z' string form."""
    return f"{major}.{minor}.{patch}"


# ──────────────────────────────────────────────────────────────────────────────
# 3. Commit analysis
# ──────────────────────────────────────────────────────────────────────────────

# Patterns that indicate a BREAKING CHANGE — checked before feat/fix.
_BREAKING_BODY_RE = re.compile(r"BREAKING[\s-]CHANGE", re.IGNORECASE)
# Type with '!' suffix: feat!, fix!, refactor!, etc.
_BREAKING_BANG_RE = re.compile(r"^[a-z]+(\([^)]*\))?!", re.MULTILINE)
# Conventional feat and fix headers.
_FEAT_RE = re.compile(r"^feat(\([^)]*\))?:", re.MULTILINE)
_FIX_RE = re.compile(r"^fix(\([^)]*\))?:", re.MULTILINE)


def determine_bump_type(commits: list[str]) -> BumpType:
    """Scan a list of commit messages and return the highest-priority bump type.

    Priority: major > minor > patch > none.
    A single breaking-change commit overrides everything else.
    """
    bump: BumpType = "none"

    for commit in commits:
        if not commit.strip():
            continue  # skip blank lines / empty entries

        # Major (highest priority — short-circuit as soon as found)
        if _BREAKING_BODY_RE.search(commit) or _BREAKING_BANG_RE.search(commit):
            return "major"

        # Minor (only upgrade if we haven't already seen minor)
        if _FEAT_RE.search(commit):
            bump = "minor"

        # Patch (only upgrade from "none")
        if _FIX_RE.search(commit) and bump == "none":
            bump = "patch"

    return bump


# ──────────────────────────────────────────────────────────────────────────────
# 4. Version bumping
# ──────────────────────────────────────────────────────────────────────────────

def bump_version(version_str: str, bump_type: BumpType) -> str:
    """Apply bump_type to version_str and return the resulting version string.

    - major: X+1.0.0
    - minor: X.Y+1.0
    - patch: X.Y.Z+1
    - none:  X.Y.Z  (unchanged)
    """
    major, minor, patch = parse_version(version_str)  # raises ValueError if bad

    if bump_type == "major":
        return format_version(major + 1, 0, 0)
    if bump_type == "minor":
        return format_version(major, minor + 1, 0)
    if bump_type == "patch":
        return format_version(major, minor, patch + 1)
    # "none"
    return format_version(major, minor, patch)


# ──────────────────────────────────────────────────────────────────────────────
# 5. package.json I/O
# ──────────────────────────────────────────────────────────────────────────────

def read_version_from_package_json(file_path: Path) -> str:
    """Read the 'version' field from package.json.

    Raises FileNotFoundError if the file doesn't exist.
    Raises KeyError if there is no 'version' field.
    """
    if not file_path.exists():
        raise FileNotFoundError(f"package.json not found: {file_path}")
    with file_path.open() as fh:
        data = json.load(fh)
    if "version" not in data:
        raise KeyError(f"No 'version' field in {file_path}")
    return data["version"]


def write_version_to_package_json(file_path: Path, new_version: str) -> None:
    """Write new_version into the 'version' field of package.json in-place.

    All other fields are preserved; indentation is kept at 2 spaces.
    """
    with file_path.open() as fh:
        data = json.load(fh)
    data["version"] = new_version
    with file_path.open("w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")  # POSIX trailing newline


# ──────────────────────────────────────────────────────────────────────────────
# 6. Changelog generation
# ──────────────────────────────────────────────────────────────────────────────

def generate_changelog_entry(commits: list[str], new_version: str) -> str:
    """Build a Markdown changelog section for new_version from the given commits.

    Sections (only rendered when non-empty):
      ### Breaking Changes
      ### Features
      ### Bug Fixes
      ### Other Changes
    """
    today = date.today().isoformat()

    breaking: list[str] = []
    features: list[str] = []
    fixes: list[str] = []
    other: list[str] = []

    for commit in commits:
        commit = commit.strip()
        if not commit:
            continue
        if _BREAKING_BODY_RE.search(commit) or _BREAKING_BANG_RE.search(commit):
            breaking.append(commit)
        elif _FEAT_RE.search(commit):
            features.append(commit)
        elif _FIX_RE.search(commit):
            fixes.append(commit)
        else:
            other.append(commit)

    lines: list[str] = [f"## [{new_version}] - {today}", ""]

    def _section(title: str, items: list[str]) -> None:
        if items:
            lines.append(f"### {title}")
            for item in items:
                lines.append(f"- {item}")
            lines.append("")

    _section("Breaking Changes", breaking)
    _section("Features", features)
    _section("Bug Fixes", fixes)
    _section("Other Changes", other)

    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
# 7. High-level orchestration
# ──────────────────────────────────────────────────────────────────────────────

def run(package_json: Path, commits_file: Path) -> tuple[str, str]:
    """Execute the full version-bump pipeline.

    Args:
        package_json:  Path to package.json (read + updated in place).
        commits_file:  Path to a text file with one commit message per line
                       (or multi-line commit bodies separated by blank lines).

    Returns:
        (new_version, changelog_entry)

    Raises:
        FileNotFoundError  if either path does not exist.
        KeyError           if package.json has no 'version' field.
        ValueError         if the stored version is not valid semver.
    """
    if not package_json.exists():
        raise FileNotFoundError(f"package.json not found: {package_json}")
    if not commits_file.exists():
        raise FileNotFoundError(f"Commits file not found: {commits_file}")

    current_version = read_version_from_package_json(package_json)
    raw_commits = commits_file.read_text().splitlines()

    bump_type = determine_bump_type(raw_commits)
    new_version = bump_version(current_version, bump_type)

    write_version_to_package_json(package_json, new_version)
    changelog = generate_changelog_entry(raw_commits, new_version)

    return new_version, changelog


# ──────────────────────────────────────────────────────────────────────────────
# CLI entry point
# ──────────────────────────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Bump semantic version in package.json based on conventional commits."
    )
    p.add_argument("package_json", help="Path to package.json")
    p.add_argument(
        "commits_file",
        nargs="?",
        default="-",
        help="Path to commit-message file (default: read from stdin)",
    )
    p.add_argument(
        "--changelog",
        metavar="FILE",
        help="Append changelog entry to this file (default: print to stdout)",
    )
    return p


def main(argv: list[str] | None = None) -> None:
    parser = _build_parser()
    args = parser.parse_args(argv)

    pkg_path = Path(args.package_json)

    # Allow stdin as the commits source
    if args.commits_file == "-":
        commits_text = sys.stdin.read()
        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as tmp:
            tmp.write(commits_text)
            commits_path = Path(tmp.name)
    else:
        commits_path = Path(args.commits_file)

    try:
        new_version, changelog = run(pkg_path, commits_path)
    except (FileNotFoundError, KeyError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    print(new_version)

    if args.changelog:
        changelog_file = Path(args.changelog)
        existing = changelog_file.read_text() if changelog_file.exists() else ""
        changelog_file.write_text(changelog + "\n" + existing)
        print(f"Changelog written to {args.changelog}", file=sys.stderr)
    else:
        print(changelog)


if __name__ == "__main__":
    main()
