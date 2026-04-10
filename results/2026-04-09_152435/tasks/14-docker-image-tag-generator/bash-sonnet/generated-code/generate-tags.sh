#!/usr/bin/env bash
# Docker Image Tag Generator
#
# Given git context (branch name, commit SHA, optional tag, optional PR number),
# generates appropriate Docker image tags following common conventions:
#   - latest          for main/master branches
#   - pr-{number}     for pull requests
#   - v{semver}       for semver-tagged commits
#   - {branch}-{sha}  for feature branches (sanitized, short SHA)
#
# Tag sanitization rules:
#   1. Lowercase everything
#   2. Replace any non-alphanumeric character (except hyphens) with a hyphen
#   3. Collapse consecutive hyphens into one
#   4. Trim leading and trailing hyphens
#
# Usage: generate-tags.sh --branch BRANCH --sha SHA [--tag TAG] [--pr PR_NUMBER]
# Output: one Docker tag per line (stdout)

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Usage / help
# ─────────────────────────────────────────────────────────────────────────────

usage() {
    cat >&2 <<'EOF'
Usage: generate-tags.sh --branch BRANCH --sha SHA [--tag TAG] [--pr PR_NUMBER]

Options:
  --branch BRANCH    Git branch name (required)
  --sha    SHA       Full commit SHA (required)
  --tag    TAG       Git tag, e.g. v1.2.3 (optional)
  --pr     NUMBER    Pull request number (optional)

Output:
  One Docker image tag per line on stdout.
EOF
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

BRANCH=""
SHA=""
GIT_TAG=""
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch) BRANCH="$2"; shift 2 ;;
        --sha)    SHA="$2";    shift 2 ;;
        --tag)    GIT_TAG="$2"; shift 2 ;;
        --pr)     PR_NUMBER="$2"; shift 2 ;;
        *) echo "Error: unknown option '$1'" >&2; usage ;;
    esac
done

# Validate required inputs
if [[ -z "$BRANCH" ]]; then
    echo "Error: --branch is required" >&2
    exit 1
fi
if [[ -z "$SHA" ]]; then
    echo "Error: --sha is required" >&2
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helper: sanitize a string for use as a Docker tag component
# ─────────────────────────────────────────────────────────────────────────────

sanitize_tag() {
    local input="$1"
    # 1. Lowercase
    input="${input,,}"
    # 2. Replace characters that are NOT alphanumeric or hyphens with hyphens
    input="${input//[^a-z0-9-]/-}"
    # 3. Collapse consecutive hyphens into a single hyphen
    while [[ "$input" == *--* ]]; do
        input="${input//--/-}"
    done
    # 4. Trim leading hyphens
    while [[ "$input" == -* ]]; do
        input="${input#-}"
    done
    # 5. Trim trailing hyphens
    while [[ "$input" == *- ]]; do
        input="${input%-}"
    done
    echo "$input"
}

# ─────────────────────────────────────────────────────────────────────────────
# Derive the short SHA (first 7 characters)
# ─────────────────────────────────────────────────────────────────────────────

SHORT_SHA="${SHA:0:7}"

# ─────────────────────────────────────────────────────────────────────────────
# Tag generation rules (applied in order; multiple rules can fire)
# ─────────────────────────────────────────────────────────────────────────────

TAGS=()

# Rule 1 – Semver tag present → emit v{semver}
if [[ -n "$GIT_TAG" ]] && [[ "$GIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9] ]]; then
    TAGS+=("$GIT_TAG")
fi

# Rule 2 – Main/master branch → emit 'latest'
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    TAGS+=("latest")
fi

# Rule 3 – PR present (and no semver tag) → emit pr-{number}
if [[ -n "$PR_NUMBER" ]] && [[ -z "$GIT_TAG" ]]; then
    TAGS+=("pr-${PR_NUMBER}")
fi

# Rule 4 – Feature branch (not main/master, no PR, no semver tag) → {branch}-{sha}
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]] \
    && [[ -z "$PR_NUMBER" ]] \
    && [[ -z "$GIT_TAG" ]]; then
    SANITIZED_BRANCH=$(sanitize_tag "$BRANCH")
    TAGS+=("${SANITIZED_BRANCH}-${SHORT_SHA}")
fi

# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────

for tag in "${TAGS[@]}"; do
    echo "$tag"
done
