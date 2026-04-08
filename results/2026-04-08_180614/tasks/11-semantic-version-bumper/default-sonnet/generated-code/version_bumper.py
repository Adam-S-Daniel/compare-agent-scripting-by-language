#!/usr/bin/env python3
"""
Semantic Version Bumper
=======================
Parses a package.json version, analyses conventional commit messages to decide
the next semantic version (major / minor / patch), updates package.json, and
generates a CHANGELOG entry.

Conventional Commits spec:
  feat:  → minor bump
  fix:   → patch bump
  feat!/fix!/any! or "BREAKING CHANGE" in body → major bump

This file was written AFTER the failing tests in test_version_bumper.py
(TDD green phase).  The public API is intentionally minimal — only what the
tests require.
"""

import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path


# ---------------------------------------------------------------------------
# Version parsing
# ---------------------------------------------------------------------------

def parse_version(version_str: str) -> tuple[int, int, int]:
    """Return (major, minor, patch) from a semver string like '1.2.3'.

    Pre-release suffixes (e.g. '-alpha') are ignored.
    Raises ValueError for anything that doesn't start with 'N.N.N'.
    """
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)", version_str)
    if not match:
        raise ValueError(f"Invalid semantic version: {version_str!r}")
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


# ---------------------------------------------------------------------------
# Bump-type determination
# ---------------------------------------------------------------------------

# Patterns for conventional commit subjects
_BREAKING_SUBJECT = re.compile(r"^(feat|fix|refactor|chore|docs|style|perf|test)!(\(.+\))?:")
_FEAT_SUBJECT = re.compile(r"^feat(\(.+\))?:")
_FIX_SUBJECT = re.compile(r"^fix(\(.+\))?:")


def determine_bump_type(commits: list[dict]) -> str:
    """Return 'major', 'minor', or 'patch' given a list of commit dicts.

    Each commit dict: {'hash': str, 'message': str, 'body': str}
    Precedence: major > minor > patch.
    """
    bump = "patch"  # conservative default

    for commit in commits:
        subject = commit.get("message", "")
        body = commit.get("body", "")

        # Breaking change — return immediately, nothing can override this
        if _BREAKING_SUBJECT.match(subject) or "BREAKING CHANGE" in subject or "BREAKING CHANGE" in body:
            return "major"

        if _FEAT_SUBJECT.match(subject):
            bump = "minor"  # may still be upgraded to major by a later commit

    return bump


# ---------------------------------------------------------------------------
# Version arithmetic
# ---------------------------------------------------------------------------

def bump_version(version_str: str, bump_type: str) -> str:
    """Return the next version string given the current version and bump type."""
    if bump_type not in ("major", "minor", "patch"):
        raise ValueError(f"Invalid bump type: {bump_type!r}. Expected major, minor, or patch.")

    major, minor, patch = parse_version(version_str)

    if bump_type == "major":
        return f"{major + 1}.0.0"
    if bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


# ---------------------------------------------------------------------------
# package.json I/O
# ---------------------------------------------------------------------------

def read_version_from_package_json(file_path: str = "package.json") -> str:
    """Read the 'version' field from a package.json file."""
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Version file not found: {file_path}")
    data = json.loads(path.read_text())
    if "version" not in data:
        raise KeyError("No 'version' field in package.json")
    return data["version"]


def write_version_to_package_json(version: str, file_path: str = "package.json") -> None:
    """Update the 'version' field in package.json in-place."""
    path = Path(file_path)
    data = json.loads(path.read_text())
    data["version"] = version
    path.write_text(json.dumps(data, indent=2) + "\n")


# ---------------------------------------------------------------------------
# Changelog generation
# ---------------------------------------------------------------------------

def generate_changelog(commits: list[dict], new_version: str) -> str:
    """Return a Markdown changelog entry for the given commits and new version."""
    today = datetime.now().strftime("%Y-%m-%d")

    breaking, features, fixes = [], [], []

    for commit in commits:
        subject = commit.get("message", "")
        body = commit.get("body", "")

        if _BREAKING_SUBJECT.match(subject) or "BREAKING CHANGE" in subject or "BREAKING CHANGE" in body:
            breaking.append(subject)
        elif _FEAT_SUBJECT.match(subject):
            # Strip the 'feat[(scope)]: ' prefix to get the description
            desc = re.sub(r"^feat(\(.+\))?:\s*", "", subject)
            features.append(desc)
        elif _FIX_SUBJECT.match(subject):
            desc = re.sub(r"^fix(\(.+\))?:\s*", "", subject)
            fixes.append(desc)

    lines = [f"## [{new_version}] - {today}", ""]

    if breaking:
        lines += ["### Breaking Changes"] + [f"- {b}" for b in breaking] + [""]
    if features:
        lines += ["### Features"] + [f"- {f}" for f in features] + [""]
    if fixes:
        lines += ["### Bug Fixes"] + [f"- {f}" for f in fixes] + [""]

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

# NUL-separated format: HASH\x00SUBJECT\x00BODY\x00
# Using NUL (ASCII 0) guarantees no false matches — commit messages and bodies
# can never contain NUL.  Fields come in triples: hash, subject, body.
_GIT_FORMAT = "%H%x00%s%x00%b%x00"


def parse_git_log(log_output: str) -> list[dict]:
    """Parse NUL-terminated git log output into a list of commit dicts.

    Format written by get_git_commits: each commit produces three
    NUL-terminated fields: hash, subject, body.
    """
    commits = []
    fields = log_output.split("\x00")
    i = 0
    while i < len(fields):
        hash_val = fields[i].strip()
        if not hash_val:
            i += 1
            continue
        subject = fields[i + 1].strip() if i + 1 < len(fields) else ""
        body = fields[i + 2].strip() if i + 2 < len(fields) else ""
        commits.append({"hash": hash_val, "message": subject, "body": body})
        i += 3
    return commits


def get_git_commits(since_ref: str | None = None) -> list[dict]:
    """Return commits since *since_ref* (a tag or hash), or all commits."""
    rev_range = f"{since_ref}..HEAD" if since_ref else "HEAD"
    cmd = ["git", "log", rev_range, f"--pretty=format:{_GIT_FORMAT}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return parse_git_log(result.stdout)
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"git log failed: {exc.stderr.strip()}") from exc


def find_latest_version_tag() -> str | None:
    """Return the most recent vX.Y.Z tag reachable from HEAD, or None."""
    try:
        result = subprocess.run(
            ["git", "describe", "--match", "v*", "--abbrev=0", "--tags"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None  # no tags yet


# ---------------------------------------------------------------------------
# Main entry point (used by the GitHub Actions workflow)
# ---------------------------------------------------------------------------

def main() -> None:
    version_file = os.environ.get("VERSION_FILE", "package.json")

    # 1. Read current version
    current_version = read_version_from_package_json(version_file)
    print(f"Current version: {current_version}")

    # 2. Collect commits since the last version tag
    last_tag = find_latest_version_tag()
    if last_tag:
        print(f"Last tag: {last_tag}")
    commits = get_git_commits(since_ref=last_tag)

    if not commits:
        print("No new commits since last tag — skipping version bump.")
        print(f"VERSION={current_version}")
        _set_github_output("new_version", current_version)
        return

    print(f"Analysing {len(commits)} commit(s)…")

    # 3. Determine bump
    bump_type = determine_bump_type(commits)
    print(f"Bump type: {bump_type}")

    # 4. Calculate new version
    new_version = bump_version(current_version, bump_type)
    print(f"New version: {new_version}")

    # 5. Update version file
    write_version_to_package_json(new_version, version_file)
    print(f"Updated {version_file}")

    # 6. Generate and display changelog
    changelog = generate_changelog(commits, new_version)
    print("\n--- Changelog entry ---")
    print(changelog)
    print("--- End changelog ---")

    # 7. Emit outputs for downstream workflow steps
    print(f"VERSION={new_version}")
    _set_github_output("new_version", new_version)
    _set_github_output("bump_type", bump_type)


def _set_github_output(name: str, value: str) -> None:
    """Write a GitHub Actions step output variable (no-op outside CI)."""
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a") as fh:
            fh.write(f"{name}={value}\n")


if __name__ == "__main__":
    main()
