#!/usr/bin/env python3
"""
docker_tag_generator.py - Generates Docker image tags based on git context.

Tag conventions (in priority order):
  1. Semver git tag (vX.Y.Z)  → 'v{version}' + 'latest'
  2. Pull Request              → 'pr-{number}'  (only this tag)
  3. main / master branch      → 'latest'
  4. Any other branch          → '{sanitized-branch}-{short-sha}'

Tag sanitization rules:
  - Lowercase only
  - Replace anything not [a-z0-9-] with a hyphen
  - Collapse consecutive hyphens into one
  - Strip leading/trailing hyphens

Usage (CLI):
  BRANCH=main COMMIT_SHA=abc1234... python docker_tag_generator.py

Environment variables read by main():
  BRANCH      - git branch name          (e.g. 'main', 'feature/foo')
  COMMIT_SHA  - full git commit SHA      (e.g. 'abc1234def5678...')
  GIT_TAGS    - comma-separated git tags (e.g. 'v1.2.3')
  PR_NUMBER   - pull request number      (e.g. '42')
"""

import os
import re
import sys


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def sanitize_tag(tag: str) -> str:
    """
    Sanitize a string so it is safe to use as (part of) a Docker tag.

    Steps applied in order:
      1. Lowercase
      2. Replace every char that is not [a-z0-9-] with a hyphen
      3. Collapse runs of hyphens into a single hyphen
      4. Strip leading / trailing hyphens

    Examples:
      'Feature/My_Branch' → 'feature-my-branch'
      'fix/bug.123'       → 'fix-bug-123'
      '/feature/'         → 'feature'
    """
    tag = tag.lower()
    tag = re.sub(r"[^a-z0-9-]", "-", tag)
    tag = re.sub(r"-+", "-", tag)
    tag = tag.strip("-")
    return tag


def is_semver_tag(git_tag: str) -> bool:
    """
    Return True if *git_tag* follows strict vX.Y.Z semantic versioning.

    Accepts:  v1.2.3   v0.0.1   v10.20.30
    Rejects:  1.2.3    v1.2     vX.Y.Z    feature/v1.2.3
    """
    return bool(re.match(r"^v\d+\.\d+\.\d+$", git_tag))


# ---------------------------------------------------------------------------
# Tag generation
# ---------------------------------------------------------------------------

def generate_tags(
    branch: str = "",
    commit_sha: str = "",
    git_tags: list = None,
    pr_number: str = "",
) -> list:
    """
    Generate Docker image tags for the given git context.

    Args:
        branch:     Git branch name.
        commit_sha: Full git commit SHA (first 7 chars used as short SHA).
        git_tags:   List of git tags pointing at this commit.
        pr_number:  Pull-request number as a string, or '' if not a PR.

    Returns:
        Sorted list of unique Docker image tag strings.
    """
    if git_tags is None:
        git_tags = []

    tags: set[str] = set()
    short_sha = commit_sha[:7] if commit_sha else ""

    # --- Rule 1: semver git tags always add the version + 'latest' ----------
    for git_tag in git_tags:
        if is_semver_tag(git_tag):
            tags.add(git_tag)        # e.g. 'v1.2.3'
            tags.add("latest")

    # --- Rule 2: PR builds get only 'pr-{number}' ---------------------------
    if pr_number:
        return sorted({"pr-" + str(pr_number)})

    # --- Rule 3: main / master branch → 'latest' ----------------------------
    if branch in ("main", "master"):
        tags.add("latest")
        return sorted(tags)

    # --- Rule 4: feature / other branches → '{branch}-{short-sha}' ----------
    if branch and short_sha:
        sanitized = sanitize_tag(branch)
        if sanitized:
            tags.add(f"{sanitized}-{short_sha}")

    return sorted(tags)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """
    Read git context from environment variables, generate tags, and print them.

    Reads:
      BRANCH      - branch name
      COMMIT_SHA  - full commit SHA
      GIT_TAGS    - comma-separated list of git tags
      PR_NUMBER   - PR number (empty string if not a PR)

    Outputs:
      Human-readable tag list on stdout.
      A 'DOCKER_TAGS_OUTPUT: tag1,tag2,...' line for machine parsing.
      Writes 'tags=...' to $GITHUB_OUTPUT when running in GitHub Actions.
    """
    branch = os.environ.get("BRANCH", "").strip()
    commit_sha = os.environ.get("COMMIT_SHA", "").strip()
    git_tags_raw = os.environ.get("GIT_TAGS", "").strip()
    pr_number = os.environ.get("PR_NUMBER", "").strip()

    git_tags = (
        [t.strip() for t in git_tags_raw.split(",") if t.strip()]
        if git_tags_raw
        else []
    )

    if not any([branch, commit_sha, git_tags, pr_number]):
        print(
            "Warning: no git context provided. "
            "Set BRANCH, COMMIT_SHA, GIT_TAGS, or PR_NUMBER.",
            file=sys.stderr,
        )

    tags = generate_tags(
        branch=branch,
        commit_sha=commit_sha,
        git_tags=git_tags,
        pr_number=pr_number,
    )

    # Human-readable output
    print("Generated Docker image tags:")
    for tag in tags:
        print(f"  - {tag}")

    # Machine-parseable marker used by the test harness
    print(f"DOCKER_TAGS_OUTPUT: {','.join(tags)}")

    # GitHub Actions step output (ignored outside GHA)
    github_output = os.environ.get("GITHUB_OUTPUT", "")
    if github_output:
        try:
            with open(github_output, "a") as fh:
                fh.write(f"tags={','.join(tags)}\n")
        except OSError as exc:
            print(f"Warning: could not write GITHUB_OUTPUT: {exc}", file=sys.stderr)


if __name__ == "__main__":
    main()
