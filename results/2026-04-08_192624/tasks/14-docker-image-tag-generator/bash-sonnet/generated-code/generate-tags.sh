#!/usr/bin/env bash
# generate-tags.sh
#
# Docker Image Tag Generator
# Generates Docker image tags from git context following common conventions:
#   - main / master branch  →  "latest"  +  "<branch>-<short-sha>"
#   - PR                    →  "pr-<number>"
#   - Semver git tag        →  "v<major>.<minor>.<patch>"
#   - Feature branch        →  "<sanitized-branch>-<short-sha>"
#
# TDD: tests in tests/test_docker_tags.bats drive this implementation.
#   RED   → test written first, fails (no script)
#   GREEN → minimum code added to pass each test
#   REFACTOR → helpers extracted, edge-cases hardened
#
# Input (environment variables):
#   INPUT_BRANCH      Git branch name  (e.g. "main", "feature/my-feature")
#   INPUT_SHA         Full commit SHA   (e.g. "abc1234def5678")
#   INPUT_TAG         Git tag           (e.g. "v1.2.3" or "1.2.3")
#   INPUT_PR_NUMBER   Pull request #    (e.g. "42")
#
# Output: space-separated tag list printed to stdout.
# Exit:   0 on success, 1 on error.

set -euo pipefail

# ---------------------------------------------------------------------------
# sanitize_tag <string>
#
# Normalise a string so it is safe to use as a Docker tag component.
# Rules (Docker tag spec + common convention):
#   1. Lowercase
#   2. Replace any character that is not [a-z0-9-] with a hyphen
#   3. Collapse consecutive hyphens into one
#   4. Strip leading / trailing hyphens
#
# RED:    test "[ACT] uppercase branch name is lowercased" failed with no script
# GREEN:  tr-based pipeline handles all four rules in order
# ---------------------------------------------------------------------------
sanitize_tag() {
    local input="$1"
    local result

    # 1. Lowercase
    result=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')

    # 2. Replace non-[a-z0-9-] characters with '-'
    #    The '-' at the end of the tr set is treated as a literal hyphen.
    result=$(printf '%s' "$result" | tr -c 'a-z0-9-' '-')

    # 3. Collapse consecutive hyphens
    while [[ "$result" == *--* ]]; do
        result="${result//--/-}"
    done

    # 4. Strip leading / trailing hyphens
    result="${result#-}"
    result="${result%-}"

    printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# short_sha <sha>
#
# Return the first 7 characters of a commit SHA.
# ---------------------------------------------------------------------------
short_sha() {
    local sha="${1:-}"
    printf '%s' "${sha:0:7}"
}

# ---------------------------------------------------------------------------
# generate_tags
#
# Core logic — reads INPUT_* env vars and writes tags to stdout.
#
# Priority order (highest → lowest):
#   PR number  >  git tag  >  branch + SHA
# ---------------------------------------------------------------------------
generate_tags() {
    local branch="${INPUT_BRANCH:-}"
    local sha="${INPUT_SHA:-}"
    local git_tag="${INPUT_TAG:-}"
    local pr_number="${INPUT_PR_NUMBER:-}"

    # ------------------------------------------------------------------ #
    # Case 1: Pull Request                                                 #
    # RED:   "[ACT] pull request → pr-{number}" failed first              #
    # GREEN: output "pr-<n>" and return immediately                        #
    # ------------------------------------------------------------------ #
    if [[ -n "$pr_number" ]]; then
        printf 'pr-%s\n' "$pr_number"
        return 0
    fi

    # ------------------------------------------------------------------ #
    # Case 2: Semver tag                                                   #
    # RED:   "[ACT] semver tag → v{semver}" failed                         #
    # GREEN: normalise to v-prefixed tag and return                        #
    # ------------------------------------------------------------------ #
    if [[ -n "$git_tag" ]]; then
        local normalised_tag
        if [[ "$git_tag" =~ ^v[0-9] ]]; then
            normalised_tag="$git_tag"
        else
            normalised_tag="v${git_tag}"
        fi
        printf '%s\n' "$normalised_tag"
        return 0
    fi

    # ------------------------------------------------------------------ #
    # Case 3: Branch-based                                                 #
    # RED:   "[ACT] main branch → latest + main-{sha}" failed first       #
    # GREEN: "latest" for main/master; sanitized-branch-sha otherwise      #
    # REFACTOR: sanitize_tag + short_sha extracted as reusable helpers     #
    # ------------------------------------------------------------------ #
    if [[ -z "$branch" ]]; then
        printf 'Error: one of INPUT_BRANCH, INPUT_TAG, or INPUT_PR_NUMBER must be set\n' >&2
        printf 'Usage: export INPUT_BRANCH=<branch> INPUT_SHA=<sha> && bash generate-tags.sh\n' >&2
        exit 1
    fi

    local sanitized_branch sha_short
    sanitized_branch=$(sanitize_tag "$branch")
    sha_short=$(short_sha "$sha")

    local -a tags=()

    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        tags+=("latest")
        if [[ -n "$sha_short" ]]; then
            tags+=("${sanitized_branch}-${sha_short}")
        fi
    else
        # Feature / other branch
        if [[ -n "$sha_short" ]]; then
            tags+=("${sanitized_branch}-${sha_short}")
        else
            tags+=("$sanitized_branch")
        fi
    fi

    # Print space-separated tag list on one line
    printf '%s\n' "${tags[*]}"
    return 0
}

generate_tags
