#!/usr/bin/env python3
"""
Docker Image Tag Generator

Generates appropriate Docker image tags based on git context:
- 'latest' for main/master branch
- 'pr-{number}' for pull requests
- 'v{semver}' for semver tags
- '{branch}-{short-sha}' for feature branches
- 'sha-{short-sha}' always when SHA is provided

All tags are sanitized: lowercase, no special characters except hyphens and dots.

TDD Approach:
  Round 1 (RED):  Test that main branch produces 'latest' tag -> FAIL (no code)
  Round 1 (GREEN): Implement main/master -> 'latest' logic
  Round 2 (RED):  Test PR number produces 'pr-{n}' tag -> FAIL
  Round 2 (GREEN): Implement PR tag logic
  Round 3 (RED):  Test semver tag produces 'v{x.y.z}' tag -> FAIL
  Round 3 (GREEN): Implement semver tag logic
  Round 4 (RED):  Test feature branch produces '{branch}-{sha}' tag -> FAIL
  Round 4 (GREEN): Implement feature branch logic
  Round 5 (RED):  Test sanitization (uppercase, special chars) -> FAIL
  Round 5 (GREEN): Implement sanitize_tag()
  Round 6 (REFACTOR): Clean up, add sha- tag, error handling
"""

import argparse
import re
import sys


def sanitize_tag(tag: str) -> str:
    """Sanitize a Docker image tag component.

    Rules:
      - Convert to lowercase
      - Replace any character that isn't alphanumeric, hyphen, or dot with a hyphen
      - Collapse consecutive hyphens into one
      - Strip leading/trailing hyphens
    """
    tag = tag.lower()
    tag = re.sub(r'[^a-z0-9.\-]', '-', tag)
    tag = re.sub(r'-{2,}', '-', tag)
    tag = tag.strip('-')
    return tag


def generate_tags(branch: str = '', sha: str = '', tag: str = '', pr_number: str = '') -> list[str]:
    """Generate Docker image tags based on git context.

    Args:
        branch:    Git branch name (e.g. 'main', 'feature/my-feature')
        sha:       Full or partial commit SHA
        tag:       Git tag (e.g. 'v1.2.3', '2.0.0')
        pr_number: Pull request number as a string

    Returns:
        Ordered list of Docker image tags.
    """
    tags = []
    short_sha = sha[:7] if sha else ''

    # Rule 1: main/master branch -> 'latest'
    if branch in ('main', 'master'):
        tags.append('latest')

    # Rule 2: Pull request -> 'pr-{number}'
    if pr_number:
        try:
            num = int(pr_number)
            if num <= 0:
                print(f"Error: PR number must be positive, got '{pr_number}'", file=sys.stderr)
            else:
                tags.append(f'pr-{num}')
        except ValueError:
            print(f"Error: Invalid PR number '{pr_number}'", file=sys.stderr)

    # Rule 3: Semver git tag -> 'v{major}.{minor}.{patch}'
    if tag:
        semver_pattern = re.compile(r'^v?(\d+\.\d+\.\d+(?:[a-zA-Z0-9.+\-]*)?)$')
        match = semver_pattern.match(tag.strip())
        if match:
            version = match.group(1)
            tags.append(f'v{version}')
        else:
            print(f"Warning: Tag '{tag}' does not match semver pattern, skipping", file=sys.stderr)

    # Rule 4: Feature branch -> '{sanitized-branch}-{short-sha}'
    if branch and branch not in ('main', 'master') and short_sha:
        sanitized = sanitize_tag(branch)
        if sanitized:
            tags.append(f'{sanitized}-{short_sha}')

    # Rule 5: Always include sha-based tag when SHA is available
    if short_sha:
        tags.append(f'sha-{short_sha}')

    return tags


def main():
    parser = argparse.ArgumentParser(description='Generate Docker image tags from git context')
    parser.add_argument('--branch', default='', help='Git branch name')
    parser.add_argument('--sha', default='', help='Commit SHA (full or short)')
    parser.add_argument('--tag', default='', help='Git tag (e.g. v1.2.3)')
    parser.add_argument('--pr', default='', help='Pull request number')

    args = parser.parse_args()

    # At least one input is required
    if not any([args.branch, args.sha, args.tag, args.pr]):
        print("Error: At least one of --branch, --sha, --tag, or --pr is required.", file=sys.stderr)
        sys.exit(1)

    tags = generate_tags(branch=args.branch, sha=args.sha, tag=args.tag, pr_number=args.pr)

    if not tags:
        print("Error: No tags could be generated from the provided inputs.", file=sys.stderr)
        sys.exit(1)

    # Output one tag per line for easy consumption by CI/CD pipelines
    for t in tags:
        print(t)


if __name__ == '__main__':
    main()
