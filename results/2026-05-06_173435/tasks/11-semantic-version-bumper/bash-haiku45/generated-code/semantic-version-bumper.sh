#!/usr/bin/env bash

# Semantic Version Bumper
# Determines the next semantic version based on conventional commit messages.
# Parses version files, analyzes git commits, and updates version files.

set -euo pipefail

# Default behavior when called without arguments
COMMAND="${1:-}"

# Print error message and exit
error() {
    echo "Error: $*" >&2
    exit 1
}

# Parse version from a file (package.json or VERSION)
# Supports JSON files (package.json) and plain text files (VERSION)
parse_version() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        error "Version file not found: $file"
    fi

    if [[ "$file" == *.json ]]; then
        # Parse JSON file using grep and sed for simplicity
        if ! grep -q '"version"' "$file"; then
            error "No 'version' field found in $file"
        fi
        version=$(grep '"version"' "$file" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    else
        # Assume plain text version file
        version=$(tr -d ' \n' < "$file")
    fi

    if [[ -z "$version" ]]; then
        error "Failed to parse version from $file"
    fi

    echo "$version"
}

# Analyze git commits since the last tag/initial version
# Returns the type of version bump needed: major, minor, patch, or none
analyze_commits() {
    local current_version="$1"

    # Find commits since the last version tag
    # Try to find a tag matching the version, otherwise use all commits
    local tag_ref
    if git rev-parse "v$current_version" >/dev/null 2>&1; then
        tag_ref="v$current_version..HEAD"
    elif git rev-parse "$current_version" >/dev/null 2>&1; then
        tag_ref="$current_version..HEAD"
    else
        # No tag found, use all commits (excluding the initial commit which usually just sets version)
        tag_ref="--all"
    fi

    # Check for breaking changes (BREAKING CHANGE in commit body)
    if git log "$tag_ref" --format=%B 2>/dev/null | grep -q "^BREAKING CHANGE:"; then
        echo "major"
        return 0
    fi

    # Check for features (feat: prefix)
    if git log "$tag_ref" --format=%s 2>/dev/null | grep -q "^feat"; then
        echo "minor"
        return 0
    fi

    # Check for fixes (fix: prefix)
    if git log "$tag_ref" --format=%s 2>/dev/null | grep -q "^fix"; then
        echo "patch"
        return 0
    fi

    # No version bump needed
    echo "none"
}

# Bump version to next semantic version
# Takes current version and bump type (major, minor, patch, none)
bump_version() {
    local version="$1"
    local bump_type="$2"

    local major minor patch
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    patch=$(echo "$version" | cut -d. -f3)

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
        none)
            # No change
            ;;
        *)
            error "Invalid bump type: $bump_type"
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Determine the next version based on conventional commits
determine_next_version() {
    local current_version="$1"

    local bump_type
    bump_type=$(analyze_commits "$current_version")

    local next_version
    next_version=$(bump_version "$current_version" "$bump_type")

    echo "$next_version"
}

# Update version in a file (package.json or VERSION)
update_version() {
    local file="$1"
    local new_version="$2"

    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
    fi

    if [[ "$file" == *.json ]]; then
        # Update JSON file (package.json)
        if ! command -v jq &>/dev/null; then
            # Fallback to sed if jq is not available
            sed -i.bak "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$new_version\"/" "$file"
            rm -f "$file.bak"
        else
            jq ".version = \"$new_version\"" "$file" > "$file.tmp"
            mv "$file.tmp" "$file"
        fi
    else
        # Update plain text VERSION file
        echo "$new_version" > "$file"
    fi
}

# Generate changelog entry from commits
# Takes old version and new version
generate_changelog() {
    local old_version="$1"
    local new_version="$2"

    echo "## [$new_version] - $(date +%Y-%m-%d)"
    echo ""

    local tag_ref
    if git rev-parse "v$old_version" >/dev/null 2>&1; then
        tag_ref="v$old_version..HEAD"
    elif git rev-parse "$old_version" >/dev/null 2>&1; then
        tag_ref="$old_version..HEAD"
    else
        tag_ref="--all"
    fi

    # Group commits by type
    local has_features=false
    local has_fixes=false
    local has_breaking=false

    # Check for breaking changes
    if git log "$tag_ref" --format=%B 2>/dev/null | grep -q "^BREAKING CHANGE:"; then
        has_breaking=true
    fi

    # Check for features
    if git log "$tag_ref" --format=%s 2>/dev/null | grep -q "^feat"; then
        has_features=true
    fi

    # Check for fixes
    if git log "$tag_ref" --format=%s 2>/dev/null | grep -q "^fix"; then
        has_fixes=true
    fi

    # Output sections
    if [ "$has_breaking" = true ]; then
        echo "### ⚠️ Breaking Changes"
        git log "$tag_ref" --format=%B 2>/dev/null | grep -A 2 "^BREAKING CHANGE:" || true
        echo ""
    fi

    if [ "$has_features" = true ]; then
        echo "### Features"
        git log "$tag_ref" --format="- %s" 2>/dev/null | grep "^- feat" || true
        echo ""
    fi

    if [ "$has_fixes" = true ]; then
        echo "### Bug Fixes"
        git log "$tag_ref" --format="- %s" 2>/dev/null | grep "^- fix" || true
        echo ""
    fi
}

# Main command dispatcher
case "$COMMAND" in
    --parse-version)
        [ -z "${2:-}" ] && error "--parse-version requires a file argument"
        parse_version "$2"
        ;;
    --determine-next-version)
        [ -z "${2:-}" ] && error "--determine-next-version requires a version argument"
        determine_next_version "$2"
        ;;
    --update-version)
        [ -z "${2:-}" ] && error "--update-version requires a file argument"
        [ -z "${3:-}" ] && error "--update-version requires a version argument"
        update_version "$2" "$3"
        ;;
    --generate-changelog)
        [ -z "${2:-}" ] && error "--generate-changelog requires old version argument"
        [ -z "${3:-}" ] && error "--generate-changelog requires new version argument"
        generate_changelog "$2" "$3"
        ;;
    --help|-h)
        cat <<EOF
Semantic Version Bumper

Usage: $0 <command> [arguments]

Commands:
  --parse-version <file>                 Extract version from package.json or VERSION file
  --determine-next-version <version>     Determine next version based on git commits
  --update-version <file> <version>      Update version in package.json or VERSION file
  --generate-changelog <old> <new>       Generate changelog between two versions
  --help                                 Show this help message

Examples:
  $0 --parse-version package.json
  $0 --determine-next-version 1.0.0
  $0 --update-version package.json 1.1.0
  $0 --generate-changelog 1.0.0 1.1.0
EOF
        ;;
    *)
        error "Unknown command: $COMMAND. Use --help for usage information."
        ;;
esac
