"""
Docker Image Tag Generator

Generates Docker image tags from git context following common conventions:
  - main/master branch  → "latest" + "{branch}-{short-sha}"
  - pull request        → "pr-{number}" + "{sanitized-branch}-{short-sha}"
  - semver git tag      → "v{semver}" (or sanitized tag string)
  - feature branch      → "{sanitized-branch}-{short-sha}"

All tags are sanitized: lowercase, only alphanumeric + dashes, no leading/trailing dashes.
"""

import re

# Branches that get the "latest" tag
_MAIN_BRANCHES = {"main", "master"}

# Number of characters to keep from the commit SHA
_SHA_LENGTH = 8


def sanitize_tag(tag: str) -> str:
    """
    Sanitize a string so it is a valid Docker image tag component.

    Rules applied in order:
      1. Lowercase everything
      2. Replace forward-slashes with dashes (common in branch names)
      3. Replace any remaining non-alphanumeric, non-dash characters with dashes
      4. Collapse consecutive dashes into one
      5. Strip leading/trailing dashes
    """
    tag = tag.lower()
    tag = tag.replace("/", "-")
    # Docker tags allow [a-z0-9._-]; preserve dots (needed for semver like v1.2.3)
    tag = re.sub(r"[^a-z0-9.\-]", "-", tag)
    tag = re.sub(r"-{2,}", "-", tag)
    tag = tag.strip("-")
    return tag


def _short_sha(sha: str) -> str:
    """Return the first 8 characters of the commit SHA."""
    return sha[:_SHA_LENGTH]


def generate_tags(ctx: dict) -> list[str]:
    """
    Generate a deduplicated list of Docker image tags from git context.

    Expected ctx keys:
      branch    (str)        – current git branch name
      sha       (str)        – full commit SHA
      tags      (list[str])  – git tags pointing at this commit (may be empty)
      pr_number (int | None) – pull-request number, or None if not a PR build

    Raises ValueError if branch or sha is missing/empty.
    """
    branch: str = ctx.get("branch", "")
    sha: str = ctx.get("sha", "")
    git_tags: list = ctx.get("tags", [])
    pr_number = ctx.get("pr_number")

    # ── Input validation ───────────────────────────────────────────────────
    if not branch:
        raise ValueError("git context must include a non-empty 'branch'")
    if not sha:
        raise ValueError("git context must include a non-empty 'sha'")

    result: list[str] = []
    clean_branch = sanitize_tag(branch)
    short = _short_sha(sha)

    # ── Rule 1: Pull-request builds ────────────────────────────────────────
    if pr_number is not None:
        result.append(f"pr-{pr_number}")
        result.append(f"{clean_branch}-{short}")

    # ── Rule 2: Main / master branch ──────────────────────────────────────
    elif branch in _MAIN_BRANCHES:
        result.append("latest")
        result.append(f"{clean_branch}-{short}")

    # ── Rule 3: Any other branch ──────────────────────────────────────────
    else:
        result.append(f"{clean_branch}-{short}")

    # ── Rule 4: Semver / git tags ─────────────────────────────────────────
    # Include every git tag, sanitizing non-semver ones.
    for git_tag in git_tags:
        result.append(sanitize_tag(git_tag))

    # ── Deduplicate while preserving order ────────────────────────────────
    seen: set[str] = set()
    unique: list[str] = []
    for t in result:
        if t not in seen:
            seen.add(t)
            unique.append(t)

    return unique
