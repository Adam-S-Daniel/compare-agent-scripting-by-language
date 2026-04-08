"""
Docker image tag generator.

Generates appropriate Docker image tags from git context (branch, commit SHA,
tags, PR number) following common conventions:
  - "latest" for main/master branches
  - "pr-{number}" for pull requests
  - "v{semver}" for semver tags
  - "{branch}-{short-sha}" for feature branches

All tags are sanitized: lowercased, special characters replaced with hyphens.
"""

import re
import sys


# Branches that map to the "latest" tag.
DEFAULT_BRANCHES = {"main", "master"}

# Matches semver: optional "v" prefix, major.minor.patch, optional prerelease/build.
SEMVER_RE = re.compile(
    r"^v?(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)"
    r"(?P<prerelease>-[a-zA-Z0-9._-]+)?(?P<build>\+[a-zA-Z0-9._-]+)?$"
)


def sanitize_tag(tag: str) -> str:
    """Sanitize a Docker tag: lowercase, replace invalid chars with hyphens,
    collapse runs of hyphens, strip leading/trailing hyphens."""
    tag = tag.lower()
    tag = re.sub(r"[^a-z0-9._-]", "-", tag)
    tag = re.sub(r"-{2,}", "-", tag)
    tag = tag.strip("-")
    return tag


def generate_tags(
    branch: str = "",
    commit_sha: str = "",
    tag: str = "",
    pr_number: int | None = None,
) -> list[str]:
    """Generate a list of Docker image tags from git context.

    Args:
        branch:     Current git branch name.
        commit_sha: Full commit SHA (at least 7 chars recommended).
        tag:        Git tag, if any (e.g. "v1.2.3").
        pr_number:  Pull-request number, if this build is for a PR.

    Returns:
        A deduplicated, ordered list of Docker image tags.
    """
    if not branch and not tag and pr_number is None:
        raise ValueError("At least one of branch, tag, or pr_number must be provided")

    tags: list[str] = []

    # Main/master → latest
    if branch in DEFAULT_BRANCHES:
        tags.append("latest")

    # Pull request → pr-{number}
    if pr_number is not None:
        tags.append(f"pr-{pr_number}")

    # Feature branch → {sanitized-branch}-{short-sha}
    if branch and branch not in DEFAULT_BRANCHES and commit_sha:
        short_sha = commit_sha[:7]
        branch_tag = sanitize_tag(f"{branch}-{short_sha}")
        tags.append(branch_tag)

    # Semver git tag → version tags (v1.2.3, v1.2, v1)
    if tag:
        m = SEMVER_RE.match(tag.strip())
        if m:
            major, minor, patch = m.group("major"), m.group("minor"), m.group("patch")
            prerelease = m.group("prerelease") or ""
            full = f"v{major}.{minor}.{patch}{prerelease}"
            tags.append(full)
            # Only add shortened aliases for stable (non-prerelease) versions
            if not prerelease:
                tags.append(f"v{major}.{minor}")
                tags.append(f"v{major}")
        else:
            # Non-semver tag — sanitize and include as-is
            sanitized = sanitize_tag(tag)
            if sanitized:
                tags.append(sanitized)

    # Deduplicate while preserving order
    seen: set[str] = set()
    unique: list[str] = []
    for t in tags:
        if t not in seen:
            seen.add(t)
            unique.append(t)
    return unique


def main() -> None:
    """CLI entry point. Accepts git context via flags and prints tags."""
    import argparse

    parser = argparse.ArgumentParser(description="Generate Docker image tags from git context")
    parser.add_argument("--branch", default="", help="Git branch name")
    parser.add_argument("--sha", default="", help="Full git commit SHA")
    parser.add_argument("--tag", default="", help="Git tag (e.g. v1.2.3)")
    parser.add_argument("--pr", type=int, default=None, help="Pull request number")
    args = parser.parse_args()

    try:
        tags = generate_tags(
            branch=args.branch,
            commit_sha=args.sha,
            tag=args.tag,
            pr_number=args.pr,
        )
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    for t in tags:
        print(t)


if __name__ == "__main__":
    main()
