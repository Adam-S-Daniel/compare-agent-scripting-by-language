"""
Docker Image Tag Generator

Generates Docker image tags based on git context following common conventions:
- latest          -> main or master branch, and semver-tagged releases
- pr-{number}     -> pull request builds
- v{semver}       -> git tags matching semantic versioning (e.g. v1.2.3)
- {branch}-{sha}  -> feature branches (sanitized: lowercase, special chars -> dashes)

Usage:
    python3 tag_generator.py --branch BRANCH --sha SHA [--pr PR] [--tags TAG1,TAG2]
    python3 tag_generator.py  # reads from environment variables

Environment variables (used when no CLI args given):
    BRANCH_NAME: git branch or ref (e.g., main, refs/heads/feature/foo)
    COMMIT_SHA:  full commit SHA
    PR_NUMBER:   pull request number (empty string if not a PR)
    GIT_TAGS:    comma-separated list of git tags at this commit
"""
import argparse
import os
import re
import sys


def sanitize_tag(tag: str) -> str:
    """
    Sanitize a string to be a valid Docker image tag.

    Rules:
    - Lowercase everything
    - Replace any character that isn't alphanumeric, dot, underscore, or dash with a dash
    - Collapse consecutive dashes into one
    - Strip leading/trailing dashes
    """
    tag = tag.lower()
    # Replace invalid chars (anything not alphanumeric, dot, underscore, dash)
    tag = re.sub(r'[^a-z0-9._-]', '-', tag)
    # Collapse consecutive dashes
    tag = re.sub(r'-+', '-', tag)
    # Strip leading/trailing dashes
    tag = tag.strip('-')
    return tag


def get_short_sha(sha: str) -> str:
    """Return the first 7 characters of a commit SHA (standard short-sha length)."""
    if not sha:
        return ''
    return sha[:7]


def _normalize_branch(branch: str) -> tuple[str, str]:
    """
    Normalize a git ref to a simple branch name.

    Returns (branch_name, extracted_pr_number_or_empty).
    Examples:
        refs/heads/main        -> (main, "")
        refs/heads/feature/foo -> (feature/foo, "")
        refs/tags/v1.2.3       -> (v1.2.3, "")
        refs/pull/42/merge     -> (refs/pull/42/merge, "42")
        main                   -> (main, "")
    """
    pr_number = ''
    if branch.startswith('refs/heads/'):
        branch = branch[len('refs/heads/'):]
    elif branch.startswith('refs/tags/'):
        branch = branch[len('refs/tags/'):]
    elif branch.startswith('refs/pull/'):
        # Extract PR number from refs/pull/{number}/merge
        parts = branch.split('/')
        if len(parts) >= 3:
            pr_number = parts[2]
    return branch, pr_number


def generate_tags(
    branch: str,
    sha: str,
    tags: list,
    pr_number: str,
) -> list:
    """
    Generate Docker image tags from git context.

    Args:
        branch:    Branch name or full git ref (e.g., 'main', 'refs/heads/feature/foo')
        sha:       Full commit SHA
        tags:      List of git tags pointing at this commit (e.g., ['v1.2.3'])
        pr_number: PR number if this is a pull request, else empty string

    Returns:
        List of Docker image tag strings (always lowercase, no invalid chars)
    """
    if sha != sha.lower():
        sha = sha.lower()

    short_sha = get_short_sha(sha)
    result = []

    # Normalize branch ref and extract PR number from ref if present
    branch_name, ref_pr = _normalize_branch(branch)

    # PR number: prefer explicit argument, fall back to ref-derived
    effective_pr = pr_number or ref_pr

    # --- Priority 1: Pull request ---
    if effective_pr:
        result.append(f'pr-{effective_pr}')
        return result

    # --- Priority 2: Semver git tag ---
    # Match tags like v1.2.3 or 1.2.3 (with optional pre-release suffix)
    semver_pattern = re.compile(r'^v?\d+\.\d+\.\d+')
    semver_tags = [t for t in tags if semver_pattern.match(t)]
    if semver_tags:
        for tag in semver_tags:
            result.append(sanitize_tag(tag))
        result.append('latest')
        return result

    # --- Priority 3: Main/master branch ---
    if branch_name in ('main', 'master'):
        result.append('latest')
        if short_sha:
            result.append(f'{branch_name}-{short_sha}')
        return result

    # --- Priority 4: Feature/other branch ---
    safe_branch = sanitize_tag(branch_name)
    if safe_branch:
        if short_sha:
            result.append(f'{safe_branch}-{short_sha}')
        else:
            result.append(safe_branch)

    return result


def main() -> None:
    """CLI entry point: parse arguments and print generated tags."""
    parser = argparse.ArgumentParser(
        description='Generate Docker image tags from git context.',
    )
    parser.add_argument('--branch', default=os.environ.get('BRANCH_NAME', ''),
                        help='Branch name or git ref')
    parser.add_argument('--sha', default=os.environ.get('COMMIT_SHA', ''),
                        help='Full commit SHA')
    parser.add_argument('--pr', default=os.environ.get('PR_NUMBER', ''),
                        help='Pull request number (empty if not a PR)')
    parser.add_argument('--tags', default=os.environ.get('GIT_TAGS', ''),
                        help='Comma-separated list of git tags at this commit')

    args = parser.parse_args()

    if not args.branch:
        print("Error: --branch or BRANCH_NAME env var is required", file=sys.stderr)
        sys.exit(1)
    if not args.sha:
        print("Error: --sha or COMMIT_SHA env var is required", file=sys.stderr)
        sys.exit(1)

    # Parse comma-separated tags (filter empty strings)
    git_tags = [t.strip() for t in args.tags.split(',') if t.strip()] if args.tags else []

    generated = generate_tags(args.branch, args.sha, git_tags, args.pr)

    # Print tags to stdout (one per line) with a parseable prefix
    print("GENERATED_TAGS: " + ",".join(generated))
    for tag in generated:
        print(f"  - {tag}")


if __name__ == '__main__':
    main()
