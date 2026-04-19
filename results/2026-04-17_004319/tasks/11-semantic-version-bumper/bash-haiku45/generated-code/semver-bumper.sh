#!/usr/bin/env bash

# Semantic Version Bumper
# Parses version files, analyzes conventional commits, and bumps versions accordingly
# Supports both package.json and VERSION files

set -euo pipefail

# Extract version from package.json or VERSION file
parse_version() {
  local file="$1"

  if [[ "$file" == *.json ]]; then
    # Extract version from JSON file (handle both compact and spaced formats)
    grep -oE '"version"\s*:\s*"[^"]*"' "$file" | cut -d'"' -f4
  else
    # Treat as plain text VERSION file
    head -1 "$file" | xargs
  fi
}

# Bump version based on type (major, minor, patch)
bump_version() {
  local version="$1"
  local bump_type="$2"

  # Split version into components
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"

  case "$bump_type" in
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
      echo "Invalid bump type: $bump_type" >&2
      return 1
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

# Determine bump type from commits using conventional commit format
# Returns: major, minor, or patch
get_bump_type() {
  local from_ref="$1"
  local to_ref="$2"

  # Get commit messages between refs
  local commits
  commits=$(git log "$from_ref..$to_ref" --pretty=format:"%B")

  # Check for breaking changes (highest priority)
  if echo "$commits" | grep -qE "^BREAKING CHANGE:|^feat!:"; then
    echo "major"
    return 0
  fi

  # Check for features (minor)
  if echo "$commits" | grep -qE "^feat(\(.+\))?:"; then
    echo "minor"
    return 0
  fi

  # Check for fixes (patch)
  if echo "$commits" | grep -qE "^fix(\(.+\))?:"; then
    echo "patch"
    return 0
  fi

  # Default to patch if no conventional commits found
  echo "patch"
}

# Update version in file
update_version() {
  local file="$1"
  local new_version="$2"

  if [[ "$file" == *.json ]]; then
    # Update JSON file while preserving formatting
    sed -i "s/\"version\": *\"[^\"]*\"/\"version\":\"$new_version\"/" "$file" || \
    sed -i "s/\"version\":\"[^\"]*\"/\"version\":\"$new_version\"/" "$file"
  else
    # Update plain text VERSION file
    echo "$new_version" > "$file"
  fi
}

# Generate changelog entry from commits
generate_changelog_entry() {
  local from_ref="$1"
  local to_ref="$2"
  local version="$3"

  local output=""
  output+="## [$version] - $(date +%Y-%m-%d)"$'\n'

  # Get commits and categorize them
  local commit_log
  commit_log=$(git log "$from_ref..$to_ref" --pretty=format:"%h %s")

  local features=""
  local fixes=""
  local breaking=""

  while IFS= read -r line; do
    if [[ $line =~ ^[a-f0-9]+\ feat ]]; then
      features+="  - ${line#* }"$'\n'
    elif [[ $line =~ ^[a-f0-9]+\ fix ]]; then
      fixes+="  - ${line#* }"$'\n'
    elif [[ $line =~ BREAKING\ CHANGE|feat! ]]; then
      breaking+="  - ${line#* }"$'\n'
    fi
  done <<< "$commit_log"

  if [[ -n "$breaking" ]]; then
    output+=$'\n'"### Breaking Changes"$'\n'"$breaking"
  fi

  if [[ -n "$features" ]]; then
    output+=$'\n'"### Features"$'\n'"$features"
  fi

  if [[ -n "$fixes" ]]; then
    output+=$'\n'"### Bug Fixes"$'\n'"$fixes"
  fi

  echo -e "$output"
}

# Main flow: parse version, determine bump, update files, generate changelog
main_flow() {
  local version_file="$1"
  local from_ref="$2"
  local to_ref="$3"

  # Parse current version
  local current_version
  current_version=$(parse_version "$version_file")

  # Determine bump type from commits
  local bump_type
  bump_type=$(get_bump_type "$from_ref" "$to_ref")

  # Calculate new version
  local new_version
  new_version=$(bump_version "$current_version" "$bump_type")

  # Update version in file
  update_version "$version_file" "$new_version"

  # Generate changelog
  local changelog
  changelog=$(generate_changelog_entry "$from_ref" "$to_ref" "$new_version")

  echo "$changelog" > CHANGELOG_ENTRY.md

  # Output the new version
  echo "$new_version"
}

# Export functions for sourcing in tests
export -f parse_version
export -f bump_version
export -f get_bump_type
export -f update_version
export -f generate_changelog_entry
export -f main_flow
