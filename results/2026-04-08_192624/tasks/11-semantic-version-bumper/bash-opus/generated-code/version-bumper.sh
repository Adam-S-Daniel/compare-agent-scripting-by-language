#!/usr/bin/env bash
# version-bumper.sh — Semantic version bumper based on conventional commits
#
# Reads a VERSION file (or package.json), analyses conventional commit messages,
# determines the appropriate version bump (major/minor/patch), updates the
# version file, generates a changelog entry, and prints the new version.
#
# Usage:
#   version-bumper.sh [--version-file FILE] [--commit-log FILE]
#
# Options:
#   --version-file FILE   Path to VERSION file or package.json (default: VERSION)
#   --commit-log FILE     Path to file containing commit messages, one per line.
#                         If omitted, reads from git log since last tag.
#
# Exit codes:
#   0  Success
#   1  General error (missing file, bad version, etc.)

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Parse the current version from a file.
# Supports plain VERSION files (just "1.2.3") and package.json ("version": "1.2.3").
parse_version() {
  local file="$1"

  [[ -f "$file" ]] || die "Version file not found: $file"

  local content
  content=$(<"$file")

  if [[ "$file" == *.json ]]; then
    # Extract version from JSON — lightweight, no jq dependency
    local ver
    ver=$(echo "$content" | grep -oP '"version"\s*:\s*"\K[0-9]+\.[0-9]+\.[0-9]+' || true)
    [[ -n "$ver" ]] || die "Could not parse version from $file"
    echo "$ver"
  else
    # Plain text file — expect semver on first non-empty line
    local ver
    ver=$(echo "$content" | grep -oP '^[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    [[ -n "$ver" ]] || die "Could not parse version from $file"
    echo "$ver"
  fi
}

# Read commit messages from a file or git log.
read_commits() {
  local commit_log="$1"

  if [[ -n "$commit_log" ]]; then
    [[ -f "$commit_log" ]] || die "Commit log file not found: $commit_log"
    cat "$commit_log"
  else
    # Fall back to git log since last tag
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$last_tag" ]]; then
      git log "${last_tag}..HEAD" --pretty=format:"%s"
    else
      git log --pretty=format:"%s"
    fi
  fi
}

# Determine bump type from conventional commit messages.
# Returns: major, minor, or patch
determine_bump() {
  local commits="$1"
  local bump="patch"

  while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue

    # Breaking change — indicated by "BREAKING CHANGE" anywhere or "!" after type
    if echo "$msg" | grep -qiP '(BREAKING CHANGE|^[a-z]+(\(.+\))?!:)'; then
      bump="major"
      break  # major is the highest — no need to keep looking
    fi

    # feat -> minor bump (only upgrade, never downgrade)
    if echo "$msg" | grep -qP '^feat(\(.+\))?:'; then
      bump="minor"
    fi

    # fix -> patch (already the default, but be explicit for clarity)
    # Other prefixes (chore, docs, ci, etc.) don't trigger a bump beyond patch
  done <<< "$commits"

  echo "$bump"
}

# Apply a bump to a semver string.  Returns the new version.
bump_version() {
  local version="$1"
  local bump="$2"

  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"

  case "$bump" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      die "Unknown bump type: $bump"
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

# Write the new version back to the file.
write_version() {
  local file="$1"
  local old_version="$2"
  local new_version="$3"

  if [[ "$file" == *.json ]]; then
    # Replace version in JSON
    sed -i "s/\"version\"\s*:\s*\"${old_version}\"/\"version\": \"${new_version}\"/" "$file"
  else
    # Replace version in plain text file
    sed -i "s/${old_version}/${new_version}/" "$file"
  fi
}

# Generate a changelog entry from commit messages.
generate_changelog() {
  local new_version="$1"
  local commits="$2"
  local date
  date=$(date +%Y-%m-%d)

  echo "## [$new_version] - $date"
  echo ""

  local has_breaking=false has_features=false has_fixes=false has_other=false
  local breaking_items="" feature_items="" fix_items="" other_items=""

  while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue

    if echo "$msg" | grep -qiP '(BREAKING CHANGE|^[a-z]+(\(.+\))?!:)'; then
      has_breaking=true
      breaking_items+="- $msg"$'\n'
    elif echo "$msg" | grep -qP '^feat(\(.+\))?:'; then
      has_features=true
      feature_items+="- $msg"$'\n'
    elif echo "$msg" | grep -qP '^fix(\(.+\))?:'; then
      has_fixes=true
      fix_items+="- $msg"$'\n'
    else
      has_other=true
      other_items+="- $msg"$'\n'
    fi
  done <<< "$commits"

  if $has_breaking; then
    echo "### Breaking Changes"
    echo "$breaking_items"
  fi
  if $has_features; then
    echo "### Features"
    echo "$feature_items"
  fi
  if $has_fixes; then
    echo "### Bug Fixes"
    echo "$fix_items"
  fi
  if $has_other; then
    echo "### Other"
    echo "$other_items"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local version_file="VERSION"
  local commit_log=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version-file)
        version_file="$2"
        shift 2
        ;;
      --commit-log)
        commit_log="$2"
        shift 2
        ;;
      -h|--help)
        head -18 "$0" | tail -16
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  # 1. Parse current version
  local current_version
  current_version=$(parse_version "$version_file")
  echo "Current version: $current_version"

  # 2. Read commit messages
  local commits
  commits=$(read_commits "$commit_log")
  [[ -n "$commits" ]] || die "No commits found"

  # 3. Determine bump type
  local bump
  bump=$(determine_bump "$commits")
  echo "Bump type: $bump"

  # 4. Compute new version
  local new_version
  new_version=$(bump_version "$current_version" "$bump")
  echo "New version: $new_version"

  # 5. Update version file
  write_version "$version_file" "$current_version" "$new_version"

  # 6. Generate changelog
  local changelog
  changelog=$(generate_changelog "$new_version" "$commits")
  echo ""
  echo "$changelog"

  # Append to CHANGELOG.md if it exists (or create it)
  if [[ -f CHANGELOG.md ]]; then
    local tmp
    tmp=$(mktemp)
    echo "$changelog" > "$tmp"
    echo "" >> "$tmp"
    cat CHANGELOG.md >> "$tmp"
    mv "$tmp" CHANGELOG.md
  else
    echo "$changelog" > CHANGELOG.md
  fi

  echo ""
  echo "VERSION_BUMPED=$new_version"
}

# Only run main when executed directly (not when sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
