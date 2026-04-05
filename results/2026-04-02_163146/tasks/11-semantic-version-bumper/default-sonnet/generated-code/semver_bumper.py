"""
Semantic Version Bumper
=======================
Parses a version file (package.json or plain version.txt), determines the
next semantic version from conventional commit messages, updates the file,
and generates a changelog entry.

Conventional Commit rules implemented:
  - feat!: / fix!: / *!: or BREAKING CHANGE footer  → major bump
  - feat: ...                                        → minor bump
  - fix: ...                                         → patch bump
  - anything else (docs, chore, style, …)            → no bump

TDD approach: tests were written first in test_semver_bumper.py (red), then
this module was written to make every test pass (green).
"""

import json
import re
from datetime import date
from pathlib import Path

# ---------------------------------------------------------------------------
# Semver helpers
# ---------------------------------------------------------------------------

# Matches a canonical semver string: MAJOR.MINOR.PATCH
_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def _validate_semver(version: str) -> tuple[int, int, int]:
    """Return (major, minor, patch) ints or raise ValueError."""
    m = _SEMVER_RE.match(version.strip())
    if not m:
        raise ValueError(f"Not a valid semver string: {version!r}")
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


# ---------------------------------------------------------------------------
# 1. parse_version(file_path) -> str
# ---------------------------------------------------------------------------

def parse_version(file_path: str) -> str:
    """Read and return the semantic version string from *file_path*.

    Supports:
    - ``package.json`` — reads the ``version`` key.
    - Any other file    — treats the first non-empty line as the version.

    Raises:
        FileNotFoundError: if *file_path* does not exist.
        ValueError:        if the version string is missing or not valid semver.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {file_path}")

    if path.suffix == ".json":
        data = json.loads(path.read_text())
        if "version" not in data:
            raise ValueError(f"No 'version' key in {file_path}")
        version = data["version"]
    else:
        # Plain text file — first non-empty line is the version
        lines = [ln.strip() for ln in path.read_text().splitlines() if ln.strip()]
        if not lines:
            raise ValueError(f"Version file is empty: {file_path}")
        version = lines[0]

    _validate_semver(version)   # raises ValueError for bad values
    return version


# ---------------------------------------------------------------------------
# 2. determine_bump_type(commits) -> str | None
# ---------------------------------------------------------------------------

# Regex for the conventional commit type+scope+breaking-marker prefix.
# Applied with match() so it always anchors at position 0 (the subject line).
_CC_PREFIX_RE = re.compile(
    r"^(?P<type>[a-z]+)"       # type: feat, fix, chore, …
    r"(?:\([^)]*\))?"          # optional (scope)
    r"(?P<breaking>!)?"        # optional ! for breaking
    r":\s*",                   # colon + whitespace
)

# Matches the "BREAKING CHANGE:" footer in the commit body
_BREAKING_FOOTER_RE = re.compile(r"BREAKING[ -]CHANGE\s*:", re.IGNORECASE)


def determine_bump_type(commits: list[str]) -> str | None:
    """Analyse *commits* and return the required bump type.

    Returns one of ``"major"``, ``"minor"``, ``"patch"``, or ``None``.
    Higher-priority bumps always win: major > minor > patch > None.
    """
    highest = None   # track the highest bump seen so far

    _priority = {"patch": 1, "minor": 2, "major": 3}

    def _raise(candidate: str) -> None:
        nonlocal highest
        if highest is None or _priority[candidate] > _priority[highest]:
            highest = candidate

    for commit in commits:
        # Check for BREAKING CHANGE in the footer (multi-line commit body)
        if _BREAKING_FOOTER_RE.search(commit):
            _raise("major")
            continue

        m = _CC_PREFIX_RE.match(commit)
        if not m:
            continue

        commit_type = m.group("type")
        is_breaking = bool(m.group("breaking"))

        if is_breaking:
            _raise("major")
        elif commit_type == "feat":
            _raise("minor")
        elif commit_type == "fix":
            _raise("patch")
        # docs, chore, style, refactor, test, ci → no bump

    return highest


# ---------------------------------------------------------------------------
# 3. bump_version(current_version, bump_type) -> str
# ---------------------------------------------------------------------------

def bump_version(current_version: str, bump_type: str) -> str:
    """Return the next version string after applying *bump_type*.

    Args:
        current_version: A valid semver string like ``"1.2.3"``.
        bump_type:       One of ``"major"``, ``"minor"``, ``"patch"``.

    Raises:
        ValueError: if *current_version* is not valid semver or *bump_type*
                    is not one of the three allowed values.
    """
    if bump_type not in ("major", "minor", "patch"):
        raise ValueError(
            f"Invalid bump type {bump_type!r}. Must be 'major', 'minor', or 'patch'."
        )

    major, minor, patch = _validate_semver(current_version)

    if bump_type == "major":
        return f"{major + 1}.0.0"
    elif bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    else:  # patch
        return f"{major}.{minor}.{patch + 1}"


# ---------------------------------------------------------------------------
# 4. update_version_file(file_path, new_version)
# ---------------------------------------------------------------------------

def update_version_file(file_path: str, new_version: str) -> None:
    """Write *new_version* back to *file_path*, preserving file type semantics.

    - For ``package.json``: updates the ``version`` key; preserves all other
      fields and pretty-prints with 2-space indent.
    - For plain text files: overwrites the file with ``new_version + newline``.

    Raises:
        FileNotFoundError: if *file_path* does not exist.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {file_path}")

    if path.suffix == ".json":
        data = json.loads(path.read_text())
        data["version"] = new_version
        path.write_text(json.dumps(data, indent=2) + "\n")
    else:
        path.write_text(new_version + "\n")


# ---------------------------------------------------------------------------
# 5. generate_changelog(new_version, commits) -> str
# ---------------------------------------------------------------------------

def generate_changelog(new_version: str, commits: list[str]) -> str:
    """Build a Markdown changelog entry for *new_version* from *commits*.

    Sections included (only when non-empty):
    - **Features** — feat commits
    - **Bug Fixes** — fix commits
    - **Breaking Changes** — breaking commits / BREAKING CHANGE footers

    docs, chore, style, etc. are excluded from the changelog body (they are
    internal housekeeping and not user-facing).
    """
    today = date.today().isoformat()

    features: list[str] = []
    fixes: list[str] = []
    breaking: list[str] = []

    for commit in commits:
        # Grab just the first line (subject line) for the changelog
        subject = commit.splitlines()[0]

        is_breaking_footer = bool(_BREAKING_FOOTER_RE.search(commit))
        m = _CC_PREFIX_RE.match(subject)

        if is_breaking_footer:
            # Use the subject without the type prefix as description
            desc = subject if not m else subject[m.end():]
            breaking.append(desc.strip())
        elif m:
            commit_type = m.group("type")
            is_breaking = bool(m.group("breaking"))
            desc = subject[m.end():].strip()

            if is_breaking:
                breaking.append(desc)
            elif commit_type == "feat":
                features.append(desc)
            elif commit_type == "fix":
                fixes.append(desc)
            # else: silently skip docs, chore, style, …

    lines: list[str] = [
        f"## [{new_version}] - {today}",
        "",
    ]

    if breaking:
        lines.append("### Breaking Changes")
        lines.extend(f"- {item}" for item in breaking)
        lines.append("")

    if features:
        lines.append("### Features")
        lines.extend(f"- {item}" for item in features)
        lines.append("")

    if fixes:
        lines.append("### Bug Fixes")
        lines.extend(f"- {item}" for item in fixes)
        lines.append("")

    if not breaking and not features and not fixes:
        lines.append("_No user-facing changes._")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 6. run_version_bump(file_path, commits, return_changelog=False)
# ---------------------------------------------------------------------------

def run_version_bump(
    file_path: str,
    commits: list[str],
    *,
    return_changelog: bool = False,
) -> str | tuple[str, str]:
    """End-to-end version bump pipeline.

    1. Parse the current version from *file_path*.
    2. Determine the bump type from *commits*.
    3. If no bump type is needed, return the current version unchanged.
    4. Calculate the new version and update *file_path*.
    5. Generate a changelog entry.

    Args:
        file_path:        Path to the version file (package.json or .txt).
        commits:          List of conventional commit message strings.
        return_changelog: When ``True``, return ``(new_version, changelog)``
                          instead of just ``new_version``.

    Returns:
        The new (or unchanged) version string, or a tuple of
        ``(version, changelog)`` when *return_changelog* is ``True``.
    """
    current_version = parse_version(file_path)
    bump_type = determine_bump_type(commits)

    if bump_type is None:
        # No version change needed
        new_version = current_version
        changelog = generate_changelog(current_version, commits)
    else:
        new_version = bump_version(current_version, bump_type)
        update_version_file(file_path, new_version)
        changelog = generate_changelog(new_version, commits)

    if return_changelog:
        return new_version, changelog
    return new_version


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    import argparse

    parser = argparse.ArgumentParser(
        description="Bump semantic version based on conventional commits."
    )
    parser.add_argument(
        "version_file",
        help="Path to package.json or version.txt",
    )
    parser.add_argument(
        "--commits-file",
        help=(
            "Path to a text file containing commit messages (one per line, "
            "or blank-line separated for multi-line commits). "
            "Reads from stdin if omitted."
        ),
    )
    parser.add_argument(
        "--changelog",
        action="store_true",
        help="Also print the generated changelog entry.",
    )
    args = parser.parse_args()

    # Read commits from file or stdin
    if args.commits_file:
        raw = Path(args.commits_file).read_text()
    else:
        raw = sys.stdin.read()

    # Split on blank lines to support multi-line commit messages
    commit_list = [block.strip() for block in raw.split("\n\n") if block.strip()]

    result = run_version_bump(
        args.version_file,
        commit_list,
        return_changelog=args.changelog,
    )

    if args.changelog:
        new_ver, changelog_text = result
        print(new_ver)
        print()
        print(changelog_text)
    else:
        print(result)
