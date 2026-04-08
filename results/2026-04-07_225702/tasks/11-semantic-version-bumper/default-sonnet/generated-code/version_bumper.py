"""
Semantic Version Bumper
=======================
Parses a version file, determines the next version from conventional commits,
updates the file, and generates a changelog entry.

Conventional commit rules:
  fix:  → patch bump   (1.2.3 → 1.2.4)
  feat: → minor bump   (1.2.3 → 1.3.0)
  feat!/fix! or "BREAKING CHANGE" footer → major bump (1.2.3 → 2.0.0)
"""

import json
import re
from datetime import date
from pathlib import Path


# ── Version parsing ───────────────────────────────────────────────────────────

def parse_version(file_path: str) -> str:
    """
    Read the current version string from *file_path*.

    Supports two formats:
      • package.json – reads the top-level "version" key.
      • Any other file (e.g. VERSION) – reads the first non-empty line.

    Raises FileNotFoundError if the file does not exist.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {file_path}")

    if path.suffix == ".json":
        data = json.loads(path.read_text())
        return data["version"]

    # Plain text version file
    return path.read_text().strip().splitlines()[0].strip()


# ── Commit classification ─────────────────────────────────────────────────────

# Priority order: major > minor > patch
_BUMP_PRIORITY = {"major": 3, "minor": 2, "patch": 1}


def classify_commits(commits: list[str]) -> str | None:
    """
    Inspect a list of conventional commit messages and return the highest
    required bump level: "major", "minor", "patch", or None.

    Rules (first match wins per commit; highest across all commits wins):
      • Subject starts with 'feat!' or 'fix!' → major
      • Body/footer contains 'BREAKING CHANGE' → major
      • Subject starts with 'feat:' → minor
      • Subject starts with 'fix:'  → patch
    """
    best: str | None = None
    best_priority = 0

    for commit in commits:
        subject = commit.splitlines()[0]

        if re.match(r"^(feat|fix|[a-z]+)!:", subject):
            level = "major"
        elif "BREAKING CHANGE" in commit:
            level = "major"
        elif re.match(r"^feat(\(.+\))?:", subject):
            level = "minor"
        elif re.match(r"^fix(\(.+\))?:", subject):
            level = "patch"
        else:
            continue  # not a recognised conventional commit

        if _BUMP_PRIORITY[level] > best_priority:
            best = level
            best_priority = _BUMP_PRIORITY[level]

    return best


# ── Version bumping ───────────────────────────────────────────────────────────

_SEM_VER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def bump_version(current: str, bump_type: str) -> str:
    """
    Increment *current* semantic version according to *bump_type*.

    Raises ValueError for unrecognised bump types or non-semver strings.
    """
    if bump_type not in ("major", "minor", "patch"):
        raise ValueError(f"Unknown bump type: '{bump_type}'. Expected major, minor, or patch.")

    m = _SEM_VER_RE.match(current)
    if not m:
        raise ValueError(f"Invalid semantic version: '{current}'. Expected MAJOR.MINOR.PATCH.")

    major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))

    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


# ── Writing the updated version ───────────────────────────────────────────────

def write_version(file_path: str, new_version: str) -> None:
    """
    Persist *new_version* back to *file_path*.

    Supports the same formats as parse_version().
    Raises FileNotFoundError if the file does not exist.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {file_path}")

    if path.suffix == ".json":
        data = json.loads(path.read_text())
        data["version"] = new_version
        path.write_text(json.dumps(data, indent=2))
    else:
        path.write_text(new_version + "\n")


# ── Changelog generation ──────────────────────────────────────────────────────

# Maps conventional commit type to human-readable section heading
_TYPE_LABELS = {
    "feat": "Features",
    "fix": "Bug Fixes",
    "perf": "Performance Improvements",
    "refactor": "Code Refactoring",
    "docs": "Documentation",
    "chore": "Chores",
    "test": "Tests",
    "ci": "CI",
    "style": "Style",
}

_COMMIT_SUBJECT_RE = re.compile(r"^(?P<type>[a-z]+)(?:\(.+\))?!?:\s*(?P<desc>.+)")


def generate_changelog(new_version: str, commits: list[str]) -> str:
    """
    Build a Markdown changelog entry for *new_version* from *commits*.

    Groups commits under section headings by type.
    Returns an empty string when there are no recognisable conventional commits.
    """
    sections: dict[str, list[str]] = {}
    breaking: list[str] = []

    for commit in commits:
        subject = commit.splitlines()[0]
        is_breaking = "!" in subject.split(":")[0] or "BREAKING CHANGE" in commit

        m = _COMMIT_SUBJECT_RE.match(subject)
        if not m:
            continue

        commit_type = m.group("type")
        description = m.group("desc").strip()

        if is_breaking:
            breaking.append(description)

        label = _TYPE_LABELS.get(commit_type, commit_type.capitalize())
        sections.setdefault(label, []).append(description)

    if not sections:
        return ""

    today = date.today().isoformat()
    lines = [f"## [{new_version}] - {today}", ""]

    if breaking:
        lines.append("### Breaking Changes")
        for item in breaking:
            lines.append(f"- {item}")
        lines.append("")

    # Render each section (skip breaking changes re-listing under Features/Bug Fixes)
    for label, items in sections.items():
        lines.append(f"### {label}")
        for item in items:
            lines.append(f"- {item}")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


# ── End-to-end pipeline ───────────────────────────────────────────────────────

def run(file_path: str, commits: list[str]) -> tuple[str, str]:
    """
    Full pipeline:
      1. Parse current version from *file_path*.
      2. Classify *commits* to determine bump level.
      3. If a bump is needed, update the file and generate a changelog entry.
      4. Return (new_version, changelog_entry).

    If no conventional commits are found, the version is left unchanged and
    an empty changelog string is returned.
    """
    current = parse_version(file_path)
    bump_type = classify_commits(commits)

    if bump_type is None:
        return current, ""

    new_version = bump_version(current, bump_type)
    write_version(file_path, new_version)
    changelog = generate_changelog(new_version, commits)
    return new_version, changelog


# ── CLI entry point ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python version_bumper.py <version-file> [commit...]", file=sys.stderr)
        sys.exit(1)

    version_file = sys.argv[1]
    # Remaining args are commit messages (use quoted strings on the command line)
    commit_messages = sys.argv[2:] if len(sys.argv) > 2 else []

    new_ver, log = run(version_file, commit_messages)
    print(f"Version: {new_ver}")
    if log:
        print("\nChangelog entry:")
        print(log)
