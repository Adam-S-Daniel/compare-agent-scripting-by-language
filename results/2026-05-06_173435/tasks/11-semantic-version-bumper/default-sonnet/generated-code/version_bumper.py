"""
Semantic Version Bumper

Parses version files and conventional commit messages to determine
the next semantic version (major/minor/patch), updates the version file,
and generates a changelog entry.

Conventional commit -> bump mapping:
  feat!: / fix!: / BREAKING CHANGE  -> major
  feat: / feat(<scope>):             -> minor
  fix: / fix(<scope>):               -> patch
  everything else                    -> no bump
"""
import re
import sys
import os
import json
from pathlib import Path
from datetime import datetime


def parse_version(version_str: str) -> tuple[int, int, int]:
    """Parse 'X.Y.Z' version string into (major, minor, patch) tuple."""
    match = re.match(r"^\s*(\d+)\.(\d+)\.(\d+)", version_str.strip())
    if not match:
        raise ValueError(f"Invalid version string: {version_str!r}")
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def read_version(
    version_file: str = "VERSION",
    package_json: str = "package.json",
) -> str:
    """Read current version from VERSION file (preferred) or package.json."""
    if os.path.exists(version_file):
        return Path(version_file).read_text().strip()
    if os.path.exists(package_json):
        data = json.loads(Path(package_json).read_text())
        return data["version"]
    raise FileNotFoundError(
        f"No version source found. Expected '{version_file}' or '{package_json}'."
    )


def classify_commit(message: str) -> str:
    """
    Classify a single commit message according to the conventional commits spec.

    Returns one of: 'major', 'minor', 'patch', 'none'.
    """
    message = message.strip()
    if not message:
        return "none"

    # Breaking change: type! or literal BREAKING CHANGE anywhere
    if re.match(r"^[a-z]+\s*!:", message) or "BREAKING CHANGE" in message:
        return "major"

    # feat(<scope>): or feat:
    if re.match(r"^feat(\([^)]*\))?:", message):
        return "minor"

    # fix(<scope>): or fix:
    if re.match(r"^fix(\([^)]*\))?:", message):
        return "patch"

    return "none"


def parse_commits(commits_text: str) -> list[dict]:
    """
    Parse a block of commit messages (one per line) and classify each.

    Returns a list of dicts with 'message' and 'type' keys.
    """
    commits = []
    for line in commits_text.split("\n"):
        line = line.strip()
        if not line:
            continue
        commits.append({"message": line, "type": classify_commit(line)})
    return commits


def determine_bump(commits: list[dict]) -> str:
    """
    Determine the version bump type from a list of classified commits.

    Priority: major > minor > patch > none.
    """
    types = {c["type"] for c in commits}
    if "major" in types:
        return "major"
    if "minor" in types:
        return "minor"
    if "patch" in types:
        return "patch"
    return "none"


def bump_version(version_tuple: tuple[int, int, int], bump_type: str) -> str:
    """
    Calculate the new version string.

    major bump: X+1.0.0
    minor bump: X.Y+1.0
    patch bump: X.Y.Z+1
    none:       X.Y.Z (unchanged)
    """
    major, minor, patch = version_tuple
    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    if bump_type == "patch":
        return f"{major}.{minor}.{patch + 1}"
    return f"{major}.{minor}.{patch}"


def generate_changelog(
    commits: list[dict], old_version: str, new_version: str
) -> str:
    """Generate a markdown changelog entry grouped by change type."""
    date = datetime.now().strftime("%Y-%m-%d")
    lines = [f"## [{new_version}] - {date}", ""]

    breaking = [c for c in commits if c["type"] == "major"]
    features = [c for c in commits if c["type"] == "minor"]
    fixes = [c for c in commits if c["type"] == "patch"]
    other = [c for c in commits if c["type"] == "none"]

    if breaking:
        lines += ["### Breaking Changes"] + [f"- {c['message']}" for c in breaking] + [""]
    if features:
        lines += ["### Features"] + [f"- {c['message']}" for c in features] + [""]
    if fixes:
        lines += ["### Bug Fixes"] + [f"- {c['message']}" for c in fixes] + [""]
    if other:
        lines += ["### Other Changes"] + [f"- {c['message']}" for c in other] + [""]

    return "\n".join(lines)


def update_version_file(
    new_version: str,
    version_file: str = "VERSION",
    package_json: str = "package.json",
) -> None:
    """Write the new version back to whichever file was the source."""
    if os.path.exists(version_file):
        Path(version_file).write_text(new_version + "\n")
    elif os.path.exists(package_json):
        data = json.loads(Path(package_json).read_text())
        data["version"] = new_version
        Path(package_json).write_text(json.dumps(data, indent=2) + "\n")


def main() -> int:
    """
    Entry point: read version + commits, compute bump, update files, print result.

    Reads VERSION (or package.json) for current version.
    Reads commits.txt (or COMMITS_FILE env var) for commit messages.
    Writes NEW_VERSION.txt and CHANGELOG_ENTRY.md.
    Prints OLD_VERSION, BUMP_TYPE, NEW_VERSION to stdout.
    """
    version_file = os.environ.get("VERSION_FILE", "VERSION")
    package_json = os.environ.get("PACKAGE_JSON", "package.json")
    commits_file = os.environ.get("COMMITS_FILE", "commits.txt")

    # Read current version
    try:
        version_str = read_version(version_file=version_file, package_json=package_json)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    try:
        version_tuple = parse_version(version_str)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    old_version = f"{version_tuple[0]}.{version_tuple[1]}.{version_tuple[2]}"

    # Read commit messages
    if os.path.exists(commits_file):
        commits_text = Path(commits_file).read_text()
    else:
        # Fall back to git log (last 20 commits)
        import subprocess
        result = subprocess.run(
            ["git", "log", "--oneline", "-20"],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print("ERROR: No commits.txt found and git log failed.", file=sys.stderr)
            return 1
        commits_text = result.stdout

    commits = parse_commits(commits_text)
    if not commits:
        print("WARNING: No commit messages found; version unchanged.", file=sys.stderr)

    bump_type = determine_bump(commits)
    new_version = bump_version(version_tuple, bump_type)

    # Generate changelog entry
    changelog_entry = generate_changelog(commits, old_version, new_version)

    # Update version source file
    update_version_file(new_version, version_file=version_file, package_json=package_json)

    # Write output artifacts
    Path("NEW_VERSION.txt").write_text(new_version)
    Path("CHANGELOG_ENTRY.md").write_text(changelog_entry)

    # Print results with clear markers for test harness parsing
    print(f"OLD_VERSION: {old_version}")
    print(f"BUMP_TYPE: {bump_type}")
    print(f"NEW_VERSION: {new_version}")
    print()
    print("=== Changelog Entry ===")
    print(changelog_entry)

    return 0


if __name__ == "__main__":
    sys.exit(main())
