#!/usr/bin/env python3
"""
Docker Image Tag Generator

Generates appropriate Docker image tags from git context following common conventions:
- 'latest' for main/master branches
- 'pr-{number}' for pull requests
- 'v{semver}' (e.g. 1.2.3) for semver tags
- '{branch}-{short-sha}' for feature branches

All tags are sanitized: lowercased, special characters replaced with hyphens,
leading/trailing hyphens stripped, consecutive hyphens collapsed.
"""

import argparse
import re
import sys
import json


def sanitize_tag(tag: str) -> str:
    """Sanitize a Docker image tag: lowercase, replace special chars, collapse hyphens."""
    # Docker tags allow [a-zA-Z0-9_.-] but we normalize to lowercase with hyphens
    tag = tag.lower()
    # Replace any character that isn't alphanumeric, hyphen, or dot with a hyphen
    tag = re.sub(r"[^a-z0-9.\-]", "-", tag)
    # Collapse consecutive hyphens
    tag = re.sub(r"-{2,}", "-", tag)
    # Strip leading/trailing hyphens and dots
    tag = tag.strip("-.")
    # Final safety: must not be empty
    if not tag:
        raise ValueError("Tag sanitization produced an empty string")
    return tag


def extract_semver(tag: str) -> str:
    """Extract semver from a git tag like 'v1.2.3' or '1.2.3'. Returns the version without 'v' prefix."""
    match = re.match(r"^v?(\d+\.\d+\.\d+.*)$", tag)
    if match:
        return match.group(1)
    return ""


def generate_tags(
    branch: str = "",
    commit_sha: str = "",
    git_tag: str = "",
    pr_number: str = "",
) -> list[str]:
    """
    Generate Docker image tags based on git context.

    Args:
        branch: Current git branch name
        commit_sha: Full commit SHA
        git_tag: Git tag (e.g. 'v1.2.3')
        pr_number: Pull request number

    Returns:
        List of Docker image tags
    """
    tags = []
    short_sha = commit_sha[:7] if commit_sha else ""

    # Priority 1: If there's a semver git tag, use it
    if git_tag:
        semver = extract_semver(git_tag)
        if semver:
            tags.append(semver)
            # Also add major.minor and major tags for semver
            parts = semver.split(".")
            if len(parts) >= 2:
                tags.append(f"{parts[0]}.{parts[1]}")
            if len(parts) >= 1:
                tags.append(parts[0])
        else:
            # Non-semver tag — sanitize and use as-is
            tags.append(sanitize_tag(git_tag))

    # Priority 2: PR tags
    if pr_number:
        try:
            pr_num = int(pr_number)
            tags.append(f"pr-{pr_num}")
        except ValueError:
            raise ValueError(f"Invalid PR number: {pr_number}")

    # Priority 3: Branch-based tags
    if branch:
        # Main/master branch gets 'latest'
        if branch in ("main", "master"):
            tags.append("latest")
            if short_sha:
                tags.append(f"sha-{short_sha}")
        else:
            # Feature branch: {sanitized-branch}-{short-sha}
            sanitized = sanitize_tag(branch)
            if short_sha:
                tags.append(f"{sanitized}-{short_sha}")
            else:
                tags.append(sanitized)

    if not tags:
        raise ValueError(
            "No tags could be generated. Provide at least a branch, tag, or PR number."
        )

    # Deduplicate while preserving order
    seen = set()
    unique_tags = []
    for t in tags:
        if t not in seen:
            seen.add(t)
            unique_tags.append(t)

    return unique_tags


def main():
    parser = argparse.ArgumentParser(description="Generate Docker image tags from git context")
    parser.add_argument("--branch", default="", help="Git branch name")
    parser.add_argument("--sha", default="", help="Git commit SHA")
    parser.add_argument("--tag", default="", help="Git tag")
    parser.add_argument("--pr", default="", help="Pull request number")
    parser.add_argument("--json", action="store_true", help="Output as JSON array")
    args = parser.parse_args()

    try:
        tags = generate_tags(
            branch=args.branch,
            commit_sha=args.sha,
            git_tag=args.tag,
            pr_number=args.pr,
        )
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(tags))
    else:
        # Output one tag per line for easy consumption in CI
        for tag in tags:
            print(tag)


if __name__ == "__main__":
    main()
