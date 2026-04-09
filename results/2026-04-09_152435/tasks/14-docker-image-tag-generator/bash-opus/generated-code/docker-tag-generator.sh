#!/usr/bin/env bash
# docker-tag-generator.sh — Generate Docker image tags from git context.
#
# Inputs (environment variables):
#   GIT_BRANCH    — current branch name (e.g. "main", "feature/foo")
#   GIT_SHA       — full commit SHA
#   GIT_TAG       — git tag, if any (e.g. "v1.2.3")
#   PR_NUMBER     — pull-request number, if any
#
# Outputs:
#   One Docker-safe tag per line on stdout.
#
# Conventions:
#   main/master          → "latest"
#   PR build             → "pr-{number}"
#   Semver tag           → the tag itself (e.g. "v1.2.3")
#   Feature branch       → "{branch}-{short-sha}"
#
# All tags are sanitised: lowercased, special chars replaced with hyphens,
# leading/trailing hyphens stripped, consecutive hyphens collapsed.

set -euo pipefail

# --- helpers ----------------------------------------------------------------

# Sanitise a string into a valid Docker tag component.
# Docker tags: [a-zA-Z0-9_.-] but we restrict further to lowercase alnum + hyphen.
sanitize_tag() {
  local raw="$1"
  local tag
  # Lowercase
  tag="${raw,,}"
  # Replace any char that isn't alphanumeric or hyphen with hyphen
  tag="${tag//[^a-z0-9-]/-}"
  # Collapse consecutive hyphens
  while [[ "$tag" == *--* ]]; do
    tag="${tag//--/-}"
  done
  # Strip leading/trailing hyphens
  tag="${tag#-}"
  tag="${tag%-}"
  printf '%s' "$tag"
}

# --- main -------------------------------------------------------------------

main() {
  local branch="${GIT_BRANCH:-}"
  local sha="${GIT_SHA:-}"
  local tag="${GIT_TAG:-}"
  local pr="${PR_NUMBER:-}"

  # We need at least a branch or a tag
  if [[ -z "$branch" && -z "$tag" ]]; then
    echo "ERROR: At least one of GIT_BRANCH or GIT_TAG must be set" >&2
    exit 1
  fi

  local tags=()

  # 1. If a semver tag is present, emit it (sanitised)
  if [[ -n "$tag" ]]; then
    local sanitized
    sanitized="$(sanitize_tag "$tag")"
    if [[ -n "$sanitized" ]]; then
      tags+=("$sanitized")
    fi
  fi

  # 2. If this is a PR, emit pr-{number}
  if [[ -n "$pr" ]]; then
    tags+=("pr-${pr}")
  fi

  # 3. Branch-based tags
  if [[ -n "$branch" ]]; then
    # Strip refs/heads/ prefix if present
    branch="${branch#refs/heads/}"

    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
      tags+=("latest")
    else
      # Feature branch: {branch}-{short-sha}
      if [[ -n "$sha" ]]; then
        local short_sha="${sha:0:7}"
        local safe_branch
        safe_branch="$(sanitize_tag "$branch")"
        if [[ -n "$safe_branch" ]]; then
          tags+=("${safe_branch}-${short_sha}")
        fi
      fi
    fi
  fi

  # If we produced no tags, that's an error
  if [[ ${#tags[@]} -eq 0 ]]; then
    echo "ERROR: No tags could be generated from the provided inputs" >&2
    exit 1
  fi

  # Output one tag per line
  printf 'DOCKER_TAG=%s\n' "${tags[@]}"
}

# Allow sourcing without executing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
