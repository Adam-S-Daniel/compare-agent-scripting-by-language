"""
Semantic Version Bumper
=======================
Parses a version file (package.json or plain VERSION), inspects conventional
commit messages to determine the appropriate semver bump, updates the file,
and generates a changelog entry.

Conventional commit rules implemented:
  - Any commit with "BREAKING CHANGE" in body/footer OR a "!" after the type
    (e.g. "feat!:") → major bump
  - feat: / feat(scope): → minor bump
  - Everything else (fix, chore, docs, refactor, …) → patch bump
  - Priority: major > minor > patch
"""

import json
import os
import re
import sys
from datetime import date
from typing import List, Dict


# ---------------------------------------------------------------------------
# parse_version
# ---------------------------------------------------------------------------

def parse_version(filepath: str) -> str:
    """
    Read the current version string from *filepath*.

    Supports:
      - package.json  — reads the "version" key
      - Any other file — reads the first non-empty line (e.g. a VERSION file)

    Raises:
      FileNotFoundError if the file does not exist.
      KeyError          if package.json has no "version" key.
      ValueError        if the file content cannot be interpreted.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Version file not found: {filepath}")

    with open(filepath, "r", encoding="utf-8") as fh:
        content = fh.read()

    if filepath.endswith(".json"):
        data = json.loads(content)
        if "version" not in data:
            raise KeyError(f"'version' key missing from {filepath}")
        return data["version"]

    # Plain text file — first non-empty line
    for line in content.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped

    raise ValueError(f"Could not extract version from {filepath}")


# ---------------------------------------------------------------------------
# parse_commits
# ---------------------------------------------------------------------------

# Matches the start of a commit line: "<7+ char hash> <message>"
_COMMIT_START_RE = re.compile(r"^([0-9a-f]{7,40})\s+(.+)$")


def parse_commits(commit_log: str) -> List[Dict[str, str]]:
    """
    Parse a multi-line git log into a list of commit dicts.

    Expected input format (one commit per logical entry):
        <hash> <subject>
        [optional blank line + body/footer lines]
        <hash> <next subject>
        ...

    Each returned dict has:
      "hash"    — the abbreviated commit SHA
      "message" — the full text for that commit (subject + body/footer)
    """
    if not commit_log or not commit_log.strip():
        return []

    commits: List[Dict[str, str]] = []
    current_hash: str = ""
    current_lines: List[str] = []

    def _flush():
        if current_hash:
            commits.append({
                "hash": current_hash,
                "message": "\n".join(current_lines).strip(),
            })

    for line in commit_log.splitlines():
        m = _COMMIT_START_RE.match(line)
        if m:
            _flush()
            current_hash = m.group(1)
            current_lines = [m.group(2)]
        else:
            if current_hash:
                current_lines.append(line)

    _flush()
    return commits


# ---------------------------------------------------------------------------
# determine_bump_type
# ---------------------------------------------------------------------------

# Matches "feat!:" or "fix(scope)!:" — the "!" signals a breaking change
_BREAKING_EXCL_RE = re.compile(r"^\w+(?:\([^)]*\))?!:")
# Matches "feat:" or "feat(scope):"
_FEAT_RE = re.compile(r"^feat(?:\([^)]*\))?:")


def determine_bump_type(commits: List[Dict[str, str]]) -> str:
    """
    Inspect commit messages and return the highest-priority bump type:
      'major' — any breaking change indicator
      'minor' — at least one feat commit (no breaking)
      'patch' — everything else (or empty list)
    """
    bump = "patch"  # default

    for commit in commits:
        msg = commit.get("message", "")

        # Breaking change: "!" notation on the type
        if _BREAKING_EXCL_RE.match(msg):
            return "major"

        # Breaking change: "BREAKING CHANGE" in body/footer
        if "BREAKING CHANGE" in msg:
            return "major"

        # Feature → minor (only upgrade patch→minor, not major→minor)
        if _FEAT_RE.match(msg) and bump == "patch":
            bump = "minor"

    return bump


# ---------------------------------------------------------------------------
# bump_version
# ---------------------------------------------------------------------------

def bump_version(version: str, bump_type: str) -> str:
    """
    Given a semver string and a bump type, return the next version.

    Rules:
      patch → increment patch, keep major.minor
      minor → increment minor, reset patch to 0
      major → increment major, reset minor and patch to 0

    Raises ValueError for unrecognised bump_type or malformed version string.
    """
    if bump_type not in ("major", "minor", "patch"):
        raise ValueError(
            f"Unknown bump type '{bump_type}'. Must be 'major', 'minor', or 'patch'."
        )

    parts = version.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise ValueError(
            f"Invalid semver string '{version}'. Expected 'MAJOR.MINOR.PATCH'."
        )

    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


# ---------------------------------------------------------------------------
# update_version_file
# ---------------------------------------------------------------------------

def update_version_file(filepath: str, new_version: str) -> None:
    """
    Write *new_version* back into *filepath*.

    For package.json: updates only the "version" key; all other content is
    preserved (indentation kept as-is via json.dumps with indent=2).
    For other files: overwrites the file with a single version line.

    Raises FileNotFoundError if the file does not exist.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Version file not found: {filepath}")

    if filepath.endswith(".json"):
        with open(filepath, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        data["version"] = new_version
        with open(filepath, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")  # trailing newline is conventional
    else:
        with open(filepath, "w", encoding="utf-8") as fh:
            fh.write(new_version + "\n")


# ---------------------------------------------------------------------------
# generate_changelog_entry
# ---------------------------------------------------------------------------

def generate_changelog_entry(new_version: str, commits: List[Dict[str, str]]) -> str:
    """
    Produce a Markdown-formatted changelog entry for *new_version*.

    Commits are grouped into sections:
      ### Breaking Changes
      ### Features
      ### Bug Fixes
      ### Other Changes
    """
    today = date.today().isoformat()

    breaking: List[str] = []
    features: List[str] = []
    fixes: List[str] = []
    others: List[str] = []

    for commit in commits:
        msg = commit.get("message", "")
        subject = msg.splitlines()[0] if msg else ""
        sha = commit.get("hash", "")
        bullet = f"- {subject} ({sha})"

        if _BREAKING_EXCL_RE.match(subject) or "BREAKING CHANGE" in msg:
            breaking.append(bullet)
        elif _FEAT_RE.match(subject):
            features.append(bullet)
        elif re.match(r"^fix(?:\([^)]*\))?:", subject):
            fixes.append(bullet)
        else:
            others.append(bullet)

    lines = [f"## [{new_version}] — {today}", ""]

    if breaking:
        lines += ["### Breaking Changes", ""] + breaking + [""]
    if features:
        lines += ["### Features", ""] + features + [""]
    if fixes:
        lines += ["### Bug Fixes", ""] + fixes + [""]
    if others:
        lines += ["### Other Changes", ""] + others + [""]

    if not (breaking or features or fixes or others):
        lines += ["_No changes recorded._", ""]

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _usage():
    print(
        "Usage: python version_bumper.py <version-file> <commit-log-file>\n"
        "\n"
        "  version-file     path to package.json or VERSION file\n"
        "  commit-log-file  path to a file containing `git log --oneline` output\n"
        "                   (use '-' to read from stdin)\n",
        file=sys.stderr,
    )


def main():
    if len(sys.argv) != 3:
        _usage()
        sys.exit(1)

    version_file = sys.argv[1]
    log_source = sys.argv[2]

    # Read commit log
    if log_source == "-":
        commit_log = sys.stdin.read()
    else:
        if not os.path.exists(log_source):
            print(f"ERROR: commit log file not found: {log_source}", file=sys.stderr)
            sys.exit(1)
        with open(log_source, "r", encoding="utf-8") as fh:
            commit_log = fh.read()

    # Parse
    old_version = parse_version(version_file)
    commits = parse_commits(commit_log)
    bump_type = determine_bump_type(commits)
    new_version = bump_version(old_version, bump_type)

    # Update file
    update_version_file(version_file, new_version)

    # Generate changelog
    entry = generate_changelog_entry(new_version, commits)

    changelog_path = os.path.join(os.path.dirname(version_file), "CHANGELOG.md")
    if os.path.exists(changelog_path):
        with open(changelog_path, "r", encoding="utf-8") as fh:
            existing = fh.read()
        with open(changelog_path, "w", encoding="utf-8") as fh:
            fh.write(entry + "\n" + existing)
    else:
        with open(changelog_path, "w", encoding="utf-8") as fh:
            fh.write(entry)

    print(new_version)


if __name__ == "__main__":
    main()
