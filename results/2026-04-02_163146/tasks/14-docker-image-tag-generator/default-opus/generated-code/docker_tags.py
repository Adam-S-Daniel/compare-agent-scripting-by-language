#!/usr/bin/env python3
"""
Docker Image Tag Generator

Generates appropriate Docker image tags from git context (branch name,
commit SHA, tags, PR number) following common conventions:

  - "latest"            for the main/master branch
  - "pr-{number}"       for pull requests
  - "v{semver}"         for semver tags (e.g. v1.2.3)
  - "{branch}-{sha7}"   for feature branches

All tags are sanitized: lowercased, special characters replaced with hyphens,
leading/trailing hyphens stripped, and consecutive hyphens collapsed.
"""

import re
import sys
import json


def sanitize_tag(tag: str) -> str:
    """Sanitize a string for use as a Docker image tag.

    Docker tags must match [a-zA-Z0-9_.-] but by convention we also
    lowercase and replace anything outside [a-z0-9._-] with hyphens,
    then collapse runs of hyphens and strip leading/trailing hyphens.
    """
    if not tag:
        raise ValueError("Tag cannot be empty")

    # Lowercase first
    tag = tag.lower()
    # Replace any character that isn't alphanumeric, dot, or hyphen
    tag = re.sub(r"[^a-z0-9.\-]", "-", tag)
    # Collapse consecutive hyphens
    tag = re.sub(r"-{2,}", "-", tag)
    # Strip leading/trailing hyphens
    tag = tag.strip("-")

    if not tag:
        raise ValueError("Tag is empty after sanitization")

    return tag


def generate_tags(
    branch: str = "",
    commit_sha: str = "",
    tag: str = "",
    pr_number: int | None = None,
) -> list[str]:
    """Generate Docker image tags from git context.

    Args:
        branch:     Current git branch name (e.g. "main", "feature/cool-thing").
        commit_sha: Full or abbreviated commit SHA.
        tag:        Git tag, if any (e.g. "v1.2.3").
        pr_number:  Pull request number, if applicable.

    Returns:
        A list of Docker-safe image tags.

    Raises:
        ValueError: If no usable git context is provided.
    """
    tags: list[str] = []

    # --- Rule 1: semver tag  →  "v{semver}" ---
    if tag:
        semver_match = re.match(
            r"^v?(\d+\.\d+\.\d+(?:[a-zA-Z0-9.+\-]*)?)$", tag
        )
        if semver_match:
            version = semver_match.group(1)
            tags.append(sanitize_tag(f"v{version}"))
        else:
            # Non-semver tag — sanitize and use as-is
            tags.append(sanitize_tag(tag))

    # --- Rule 2: PR number  →  "pr-{number}" ---
    if pr_number is not None:
        if not isinstance(pr_number, int) or pr_number <= 0:
            raise ValueError(f"PR number must be a positive integer, got: {pr_number}")
        tags.append(f"pr-{pr_number}")

    # --- Rule 3: main/master branch  →  "latest" ---
    if branch in ("main", "master"):
        tags.append("latest")

    # --- Rule 4: feature branch  →  "{branch}-{short_sha}" ---
    if branch and branch not in ("main", "master"):
        short_sha = commit_sha[:7] if commit_sha else ""
        if short_sha:
            tags.append(sanitize_tag(f"{branch}-{short_sha}"))
        else:
            tags.append(sanitize_tag(branch))

    # Must produce at least one tag
    if not tags:
        raise ValueError(
            "Cannot generate tags: provide at least a branch, tag, or PR number"
        )

    return tags


# --- CLI entry point ---
def main() -> None:
    """Parse JSON from stdin or command-line args and print tags."""
    import argparse

    parser = argparse.ArgumentParser(description="Generate Docker image tags from git context")
    parser.add_argument("--branch", default="", help="Git branch name")
    parser.add_argument("--sha", default="", help="Git commit SHA")
    parser.add_argument("--tag", default="", help="Git tag (e.g. v1.2.3)")
    parser.add_argument("--pr", type=int, default=None, help="Pull request number")
    parser.add_argument("--json", action="store_true", help="Output as JSON array")

    args = parser.parse_args()

    try:
        result = generate_tags(
            branch=args.branch,
            commit_sha=args.sha,
            tag=args.tag,
            pr_number=args.pr,
        )
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(result))
    else:
        for t in result:
            print(t)


if __name__ == "__main__":
    main()
