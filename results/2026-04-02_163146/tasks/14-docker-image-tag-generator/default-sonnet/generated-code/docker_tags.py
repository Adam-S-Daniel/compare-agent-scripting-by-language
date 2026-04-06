"""
Docker Image Tag Generator

Generates Docker image tags from git context following common conventions:
  - 'latest'          → main or master branch
  - 'pr-{number}'     → pull requests
  - 'v{semver}'       → git semver tags (e.g. v1.2.3)
  - '{branch}-{sha}'  → feature branches (sanitized, short SHA)

Tag sanitization rules:
  - Lowercase only
  - Slashes replaced with hyphens
  - Only [a-z0-9._-] allowed (other chars removed)
  - Leading/trailing hyphens stripped
"""

import re
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class GitContext:
    """Mock-friendly container for git context inputs.

    All fields are provided as inputs (no real git calls),
    making this fully testable without a real repository.
    """
    branch: str
    sha: str                         # Full commit SHA
    tags: list                       # List of git tag strings
    pr_number: Optional[int] = None  # Pull request number, or None

    @property
    def short_sha(self) -> str:
        """First 7 characters of the commit SHA."""
        return self.sha[:7]


# Semver pattern: optional 'v' prefix, then MAJOR.MINOR.PATCH with optional pre-release/build
_SEMVER_RE = re.compile(r'^v\d+\.\d+\.\d+')

# Valid Docker tag characters: [a-z0-9._-]
_INVALID_CHARS_RE = re.compile(r'[^a-z0-9._-]')
_MULTI_HYPHEN_RE = re.compile(r'-{2,}')

# Main branch names that produce 'latest'
_MAIN_BRANCHES = {"main", "master"}


def sanitize_tag(raw: str) -> str:
    """Sanitize a string for use as a Docker image tag.

    Steps:
    1. Lowercase
    2. Replace slashes with hyphens
    3. Remove any character not in [a-z0-9._-]
    4. Collapse multiple consecutive hyphens
    5. Strip leading/trailing hyphens
    """
    tag = raw.lower()
    tag = tag.replace("/", "-")
    tag = _INVALID_CHARS_RE.sub("", tag)
    tag = _MULTI_HYPHEN_RE.sub("-", tag)
    tag = tag.strip("-")
    return tag


def generate_tags(ctx: GitContext) -> list:
    """Generate Docker image tags from git context.

    Rules applied in order (all applicable rules produce tags):
    1. main/master branch → add 'latest'
    2. PR number present  → add 'pr-{number}'
    3. Git semver tags    → add each 'v{semver}' tag
    4. Feature branch     → add '{sanitized-branch}-{short-sha}'
       (skipped for main/master since 'latest' covers it)

    Returns a deduplicated list of valid Docker tags.
    """
    tags = []

    branch_lower = ctx.branch.lower()

    # Rule 1: main/master → 'latest'
    if branch_lower in _MAIN_BRANCHES:
        tags.append("latest")

    # Rule 2: pull request → 'pr-{number}'
    if ctx.pr_number is not None:
        tags.append(f"pr-{ctx.pr_number}")

    # Rule 3: git semver tags → include sanitized semver tags
    for git_tag in ctx.tags:
        if _SEMVER_RE.match(git_tag):
            sanitized = sanitize_tag(git_tag)
            if sanitized:
                tags.append(sanitized)

    # Rule 4: feature branch → '{branch}-{short-sha}'
    # Only for non-main branches (main already has 'latest')
    if branch_lower not in _MAIN_BRANCHES:
        sanitized_branch = sanitize_tag(ctx.branch)
        if sanitized_branch:
            branch_sha_tag = f"{sanitized_branch}-{ctx.short_sha}"
            tags.append(branch_sha_tag)

    # Deduplicate while preserving order
    seen = set()
    result = []
    for tag in tags:
        if tag not in seen:
            seen.add(tag)
            result.append(tag)

    return result


def main():
    """CLI entry point demonstrating tag generation with sample inputs."""
    import json

    # Sample scenarios demonstrating all tag conventions
    scenarios = [
        {
            "description": "Main branch release",
            "context": GitContext(branch="main", sha="abc1234def5678", tags=["v2.1.0"], pr_number=None),
        },
        {
            "description": "Pull request from feature branch",
            "context": GitContext(branch="feature/add-auth", sha="deadbeef12345", tags=[], pr_number=99),
        },
        {
            "description": "Feature branch (no PR)",
            "context": GitContext(branch="feature/My-Feature_v2", sha="cafebabe9876", tags=[], pr_number=None),
        },
        {
            "description": "Hotfix branch with semver tag",
            "context": GitContext(branch="hotfix/critical-fix", sha="11112222333344", tags=["v1.9.1"], pr_number=None),
        },
    ]

    for scenario in scenarios:
        ctx = scenario["context"]
        tags = generate_tags(ctx)
        print(f"\n{scenario['description']}")
        print(f"  Branch:  {ctx.branch}")
        print(f"  SHA:     {ctx.sha} (short: {ctx.short_sha})")
        print(f"  Tags:    {ctx.tags}")
        print(f"  PR:      {ctx.pr_number}")
        print(f"  → Docker tags: {json.dumps(tags)}")


if __name__ == "__main__":
    main()
