#!/usr/bin/env bash
# Docker Image Tag Generator
#
# Generates Docker image tags from git context following common conventions:
#   - "latest"              for main/master branches
#   - "pr-{number}"         for pull requests
#   - "v{semver}"           for semver tags (also gets "latest")
#   - "{branch}-{short-sha}" for feature branches
#
# Inputs (environment variables):
#   BRANCH_NAME  - Git branch name
#   COMMIT_SHA   - Full 40-char commit SHA (required)
#   GIT_TAG      - Git tag, e.g. v1.2.3 (optional)
#   PR_NUMBER    - Pull request number (optional)
#
# Outputs one Docker-safe tag per line to stdout.

set -euo pipefail

# Sanitize a string for use as a Docker image tag:
#   - lowercase
#   - replace invalid characters with dashes
#   - collapse repeated dashes
#   - strip leading/trailing separators
#   - truncate to 128 characters (Docker limit)
sanitize_tag() {
    local tag="$1"
    # Convert to lowercase
    tag="${tag,,}"
    # Replace chars not in [a-z0-9.-] with dashes (underscores become dashes too)
    tag=$(printf '%s' "$tag" | sed 's/[^a-z0-9.-]/-/g')
    # Collapse consecutive dashes
    tag=$(printf '%s' "$tag" | sed 's/-\{2,\}/-/g')
    # Strip leading/trailing separators
    tag=$(printf '%s' "$tag" | sed 's/^[._-]*//;s/[._-]*$//')
    # Docker tag max length is 128
    tag="${tag:0:128}"
    printf '%s' "$tag"
}

main() {
    # Validate required inputs
    if [[ -z "${COMMIT_SHA:-}" ]]; then
        echo "ERROR: COMMIT_SHA is required" >&2
        exit 1
    fi

    if [[ -z "${BRANCH_NAME:-}" && -z "${GIT_TAG:-}" ]]; then
        echo "ERROR: Either BRANCH_NAME or GIT_TAG must be provided" >&2
        exit 1
    fi

    local short_sha="${COMMIT_SHA:0:7}"
    local tags=()

    # Semver tag: emit sanitized tag name + "latest"
    if [[ -n "${GIT_TAG:-}" ]]; then
        tags+=("$(sanitize_tag "$GIT_TAG")")
        if [[ "$GIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            tags+=("latest")
        fi
    fi

    # Pull request: pr-{number}
    if [[ -n "${PR_NUMBER:-}" ]]; then
        tags+=("pr-${PR_NUMBER}")
    fi

    # Branch handling
    if [[ -n "${BRANCH_NAME:-}" ]]; then
        local sanitized_branch
        sanitized_branch=$(sanitize_tag "$BRANCH_NAME")

        # main/master → "latest"
        if [[ "$BRANCH_NAME" == "main" || "$BRANCH_NAME" == "master" ]]; then
            tags+=("latest")
        fi

        # Every branch gets {branch}-{short-sha}
        tags+=("${sanitized_branch}-${short_sha}")
    fi

    # Output unique tags, preserving insertion order
    printf '%s\n' "${tags[@]}" | awk '!seen[$0]++'
}

main "$@"
