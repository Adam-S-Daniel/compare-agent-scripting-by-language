"""
Semantic version bumper following conventional commits specification.

Conventional commit types:
  fix: -> patch bump
  feat: -> minor bump
  feat!: or BREAKING CHANGE footer -> major bump

Usage:
  python version_bumper.py [--version-file FILE] [--changelog CHANGELOG] \
                           [--commits-file FILE]
"""
import json
import os
import re
import sys
from datetime import date
from typing import Optional


# Regex for a valid semantic version string
_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")

# Conventional commit type -> bump priority (higher = more important)
_TYPE_PRIORITY = {
    "fix": 1,
    "feat": 2,
    "major": 3,
}

# Commit types that appear in the changelog
_CHANGELOG_TYPES = {"feat", "fix", "perf", "revert"}

# Commit types to include in "Features" section
_FEAT_TYPES = {"feat"}
# Commit types to include in "Bug Fixes" section
_FIX_TYPES = {"fix", "revert"}
# Commit types to include in "Performance" section
_PERF_TYPES = {"perf"}


# ============================================================
# Parsing
# ============================================================

def parse_version(version_file: str) -> tuple[int, int, int]:
    """Return (major, minor, patch) from a VERSION file or package.json."""
    if not os.path.exists(version_file):
        raise FileNotFoundError(f"Version file not found: {version_file}")

    if os.path.basename(version_file) == "package.json":
        with open(version_file) as f:
            data = json.load(f)
        if "version" not in data:
            raise ValueError("No 'version' field in package.json")
        raw = data["version"]
    else:
        with open(version_file) as f:
            raw = f.read().strip()

    return _parse_semver_string(raw)


def _parse_semver_string(raw: str) -> tuple[int, int, int]:
    m = _SEMVER_RE.match(raw.strip())
    if not m:
        raise ValueError(f"Invalid semantic version: '{raw}'")
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


# ============================================================
# Commit analysis
# ============================================================

def determine_bump_type(commits: list[str]) -> Optional[str]:
    """
    Return the highest bump type required by the commit list:
      'major', 'minor', 'patch', or None (no releasable change).
    """
    bump = 0  # 0 = none, 1 = patch, 2 = minor, 3 = major

    for msg in commits:
        subject = msg.split("\n")[0].strip()
        body = msg[len(subject):].strip()

        # Breaking change indicators
        if "BREAKING CHANGE" in body or "BREAKING CHANGE" in subject:
            bump = max(bump, 3)
            continue

        m = re.match(r"^(\w+)(\([\w/-]+\))?(!)?:", subject)
        if not m:
            continue

        ctype = m.group(1)
        breaking = m.group(3) == "!"

        if breaking:
            bump = max(bump, 3)
        elif ctype == "feat":
            bump = max(bump, 2)
        elif ctype == "fix":
            bump = max(bump, 1)
        # Other types (docs, chore, style, ci, test) do not bump

    if bump == 3:
        return "major"
    if bump == 2:
        return "minor"
    if bump == 1:
        return "patch"
    return None


# ============================================================
# Version arithmetic
# ============================================================

def calculate_next_version(
    current: tuple[int, int, int], bump: Optional[str]
) -> tuple[int, int, int]:
    major, minor, patch = current
    if bump == "major":
        return (major + 1, 0, 0)
    if bump == "minor":
        return (major, minor + 1, 0)
    if bump == "patch":
        return (major, minor, patch + 1)
    return current


def version_to_str(v: tuple[int, int, int]) -> str:
    return f"{v[0]}.{v[1]}.{v[2]}"


# ============================================================
# File updates
# ============================================================

def update_version_file(version_file: str, new_version: tuple[int, int, int]) -> None:
    """Write the new version back to the file."""
    version_str = version_to_str(new_version)
    if os.path.basename(version_file) == "package.json":
        with open(version_file) as f:
            data = json.load(f)
        data["version"] = version_str
        with open(version_file, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    else:
        with open(version_file, "w") as f:
            f.write(version_str + "\n")


# ============================================================
# Changelog
# ============================================================

def generate_changelog(
    new_version: str, commits: list[str], today: str
) -> str:
    """Build a Markdown changelog entry for the new version."""
    features: list[str] = []
    fixes: list[str] = []
    breaking_items: list[str] = []

    for msg in commits:
        subject = msg.split("\n")[0].strip()
        body = msg[len(subject):].strip()

        # Detect BREAKING CHANGE footer
        if "BREAKING CHANGE:" in body:
            bc_desc = re.search(r"BREAKING CHANGE: (.+)", body)
            if bc_desc:
                breaking_items.append(bc_desc.group(1).strip())

        m = re.match(r"^(\w+)(?:\([\w/-]+\))?(!)?:\s*(.+)$", subject)
        if not m:
            continue

        ctype, breaking_bang, description = m.group(1), m.group(2), m.group(3)

        if breaking_bang:
            breaking_items.append(description)
        elif ctype in _FEAT_TYPES:
            features.append(description)
        elif ctype in _FIX_TYPES:
            fixes.append(description)

    lines = [f"## [{new_version}] - {today}", ""]

    if breaking_items:
        lines.append("### BREAKING CHANGES")
        lines.extend(f"- {item}" for item in breaking_items)
        lines.append("")

    if features:
        lines.append("### Features")
        lines.extend(f"- {item}" for item in features)
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(f"- {item}" for item in fixes)
        lines.append("")

    if not breaking_items and not features and not fixes:
        lines.append("_No user-facing changes in this release._")
        lines.append("")

    return "\n".join(lines)


def prepend_changelog(changelog_file: str, entry: str) -> None:
    """Prepend a changelog entry before existing content."""
    existing = ""
    if os.path.exists(changelog_file):
        with open(changelog_file) as f:
            existing = f.read()

    with open(changelog_file, "w") as f:
        f.write(entry)
        if existing:
            f.write(existing)


# ============================================================
# High-level runner
# ============================================================

def run(
    version_file: str,
    commits: list[str],
    changelog_file: str,
    today: Optional[str] = None,
) -> str:
    """
    Full pipeline: parse -> bump -> update file -> write changelog.
    Returns the new version string.
    """
    if today is None:
        today = date.today().isoformat()

    current = parse_version(version_file)
    bump_type = determine_bump_type(commits)
    new_version = calculate_next_version(current, bump_type)
    new_version_str = version_to_str(new_version)

    if bump_type is not None:
        update_version_file(version_file, new_version)

    entry = generate_changelog(new_version_str, commits, today)
    prepend_changelog(changelog_file, entry)

    return new_version_str


# ============================================================
# CLI entry point
# ============================================================

def _load_commits_from_git(repo_dir: str = ".") -> list[str]:
    """Read commits since last tag using git log."""
    import subprocess
    try:
        last_tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            cwd=repo_dir, stderr=subprocess.DEVNULL, text=True
        ).strip()
        rev_range = f"{last_tag}..HEAD"
    except subprocess.CalledProcessError:
        rev_range = "HEAD"

    out = subprocess.check_output(
        ["git", "log", rev_range, "--format=%B%x00"],
        cwd=repo_dir, text=True
    )
    return [c.strip() for c in out.split("\x00") if c.strip()]


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Semantic version bumper")
    parser.add_argument("--version-file", default="VERSION",
                        help="Path to VERSION or package.json")
    parser.add_argument("--changelog", default="CHANGELOG.md",
                        help="Path to CHANGELOG.md")
    parser.add_argument("--commits-file", default=None,
                        help="Path to file with newline-delimited commit messages (for testing)")
    parser.add_argument("--use-git", action="store_true", default=False,
                        help="Read commits from git log since last tag")
    args = parser.parse_args()

    if args.commits_file:
        with open(args.commits_file) as f:
            raw = f.read()
        # Support null-byte or double-newline as commit separators
        if "\x00" in raw:
            commits = [c.strip() for c in raw.split("\x00") if c.strip()]
        else:
            commits = [c.strip() for c in raw.strip().split("\n\n") if c.strip()]
            if not commits:
                commits = [c.strip() for c in raw.strip().splitlines() if c.strip()]
    elif args.use_git:
        commits = _load_commits_from_git()
    else:
        # Default: read from git
        commits = _load_commits_from_git()

    new_version = run(
        version_file=args.version_file,
        commits=commits,
        changelog_file=args.changelog,
    )
    print(new_version)


if __name__ == "__main__":
    main()
