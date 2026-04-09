"""
Semantic Version Bumper
=======================
Parse a version file, determine the next version from conventional commits,
update the file, and generate a changelog entry.

Conventional commit types:
  feat!  / BREAKING CHANGE footer  -> major bump
  feat                              -> minor bump
  fix                               -> patch bump
  chore, docs, style, refactor, etc -> no bump

Usage (CLI):
    python3 version_bumper.py <version-file> [commit-msg ...]

    If no commits are provided, reads from stdin (one commit per line).

Exit code 0 with the new version printed to stdout.
"""

import json
import re
import sys
from datetime import date


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_CONVENTIONAL_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]*)\))?(?P<breaking>!)?:"
)

_PRIORITY = {None: 0, "patch": 1, "minor": 2, "major": 3}
_BUMP_TYPES = {"fix": "patch", "feat": "minor"}


def parse_version(file_path: str) -> str:
    """
    Return the version string from *file_path*.

    Supports:
    - package.json (JSON with a "version" key)
    - Any plain-text file (e.g. VERSION) containing only the version string
    """
    with open(file_path) as fh:
        content = fh.read()

    if file_path.endswith(".json"):
        data = json.loads(content)
        if "version" not in data:
            raise KeyError("version")
        return data["version"]

    # Plain text: strip whitespace and return the first non-empty line
    return content.strip().splitlines()[0].strip()


def parse_commit_type(message: str) -> str | None:
    """
    Classify a single commit message as 'major', 'minor', 'patch', or None.

    Rules (Conventional Commits spec):
    - BREAKING CHANGE footer or '!' after type/scope  -> 'major'
    - feat                                            -> 'minor'
    - fix                                             -> 'patch'
    - anything else                                   -> None
    """
    # Check for BREAKING CHANGE in the footer/body
    if "BREAKING CHANGE:" in message or "BREAKING-CHANGE:" in message:
        return "major"

    match = _CONVENTIONAL_RE.match(message.strip())
    if not match:
        return None

    if match.group("breaking") == "!":
        return "major"

    return _BUMP_TYPES.get(match.group("type"))


def process_commits(commits: list[str]) -> str | None:
    """
    Return the highest bump level required by the list of commit messages,
    or None if no version-relevant commits exist.
    """
    highest = None
    for msg in commits:
        level = parse_commit_type(msg)
        if _PRIORITY.get(level, 0) > _PRIORITY.get(highest, 0):
            highest = level
    return highest


def bump_version(current: str, bump_type: str | None) -> str:
    """
    Compute and return the next version string.

    Args:
        current:   SemVer string, e.g. '1.2.3'
        bump_type: 'major', 'minor', 'patch', or None (no change)

    Raises:
        ValueError: if *current* is not a valid semver string
    """
    if bump_type is None:
        return current

    parts = current.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise ValueError(f"Invalid version: {current!r}")

    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    if bump_type == "patch":
        return f"{major}.{minor}.{patch + 1}"

    raise ValueError(f"Unknown bump type: {bump_type!r}")


def generate_changelog(new_version: str, commits: list[str]) -> str:
    """
    Return a Markdown changelog entry for *new_version*.

    Commits are bucketed into ### Features, ### Bug Fixes sections.
    Chores / non-conventional messages are omitted.
    """
    features: list[str] = []
    fixes: list[str] = []

    for msg in commits:
        first_line = msg.splitlines()[0].strip()
        match = _CONVENTIONAL_RE.match(first_line)
        if not match:
            continue
        ctype = match.group("type")
        scope = match.group("scope")
        # Description = everything after ': '
        description = re.sub(r"^[a-z]+(?:\([^)]*\))?!?:\s*", "", first_line)

        if ctype == "feat":
            prefix = f"**{scope}:** " if scope else ""
            features.append(f"- {prefix}{description}")
        elif ctype == "fix":
            prefix = f"**{scope}:** " if scope else ""
            fixes.append(f"- {prefix}{description}")

    today = date.today().isoformat()
    lines = [f"## [{new_version}] - {today}", ""]

    if features:
        lines += ["### Features", ""] + features + [""]
    if fixes:
        lines += ["### Bug Fixes", ""] + fixes + [""]

    if not features and not fixes:
        lines += ["_No notable changes._", ""]

    return "\n".join(lines)


def update_version_file(file_path: str, new_version: str) -> None:
    """
    Write *new_version* back to *file_path*.

    Supports package.json (preserves all other fields) and plain-text files.

    Raises:
        FileNotFoundError: if *file_path* does not exist
    """
    # Existence check first
    with open(file_path) as fh:
        content = fh.read()

    if file_path.endswith(".json"):
        data = json.loads(content)
        data["version"] = new_version
        with open(file_path, "w") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
    else:
        with open(file_path, "w") as fh:
            fh.write(new_version + "\n")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> None:
    """
    CLI: version_bumper.py <version-file> [commit...]

    Reads commits from argv or (if none given) from stdin.
    Prints the new version to stdout and exits 0.
    Exits 1 on error.
    """
    if argv is None:
        argv = sys.argv[1:]

    if not argv:
        print("Usage: version_bumper.py <version-file> [commit...]", file=sys.stderr)
        sys.exit(1)

    version_file = argv[0]
    commits_from_args = argv[1:]

    if commits_from_args:
        commits = commits_from_args
    else:
        # Read commits from stdin (one per line, blank lines ignored)
        commits = [line.strip() for line in sys.stdin if line.strip()]

    try:
        current = parse_version(version_file)
    except FileNotFoundError:
        print(f"Error: version file not found: {version_file}", file=sys.stderr)
        sys.exit(1)
    except (KeyError, json.JSONDecodeError) as exc:
        print(f"Error reading version from {version_file}: {exc}", file=sys.stderr)
        sys.exit(1)

    bump_type = process_commits(commits)
    new_version = bump_version(current, bump_type)

    # Update the file in place
    update_version_file(version_file, new_version)

    # Generate and print changelog entry to stdout
    changelog = generate_changelog(new_version, commits)
    print(f"new_version={new_version}")
    print()
    print(changelog)


if __name__ == "__main__":
    main()
