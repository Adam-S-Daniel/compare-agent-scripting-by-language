#!/usr/bin/env bash
# Semantic version bumper: reads a version file (version.txt or package.json),
# analyzes conventional commit messages to determine the bump type
# (fix→patch, feat→minor, breaking→major), updates the version file,
# generates a changelog entry, and outputs the new version.

set -euo pipefail

usage() {
    echo "Usage: $0 <version-file> <commits-file> [changelog-file]" >&2
    echo "" >&2
    echo "  version-file   path to version.txt or package.json" >&2
    echo "  commits-file   path to file with commit messages (one per line)" >&2
    echo "  changelog-file path to write changelog entry (default: CHANGELOG.md)" >&2
    exit 1
}

# Parse the semantic version from a version.txt or package.json file.
# Outputs the version string, or exits non-zero on error.
parse_version() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: version file '$file' not found" >&2
        return 1
    fi

    local version=""
    if [[ "$file" == *.json ]]; then
        # Extract version field from JSON (handles spaces around colon/value)
        version=$(grep '"version"' "$file" | head -1 \
            | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][^"]*\)".*/\1/')
    else
        version=$(tr -d '[:space:]' < "$file")
    fi

    if [[ -z "$version" ]]; then
        echo "Error: could not extract version from '$file'" >&2
        return 1
    fi

    echo "$version"
}

# Determine the version bump type from conventional commit messages.
# Reads one commit per line from the given file.
# Priority: major > minor > patch (patch is the default).
determine_bump_type() {
    local commits_file="$1"
    local bump="patch"

    # Regex patterns stored in variables to satisfy shellcheck (SC2076)
    local breaking_type='^[a-zA-Z]+(\([^)]*\))?!:'
    local breaking_body='^BREAKING[- ]CHANGE'
    local feat_type='^feat(\([^)]*\))?:'

    while IFS= read -r commit || [[ -n "$commit" ]]; do
        [[ -z "$commit" ]] && continue

        # Breaking change: either type! or BREAKING CHANGE in message body
        if [[ "$commit" =~ $breaking_type ]] || [[ "$commit" =~ $breaking_body ]]; then
            echo "major"
            return 0
        fi

        # Feature: promotes patch→minor (but cannot demote major)
        if [[ "$commit" =~ $feat_type ]]; then
            bump="minor"
        fi
    done < "$commits_file"

    echo "$bump"
}

# Compute new version by incrementing the appropriate component.
# Resets lower components to 0 per semver spec.
bump_version() {
    local version="$1"
    local bump_type="$2"
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
            echo "Error: unknown bump type '$bump_type'" >&2
            return 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Write the new version back to the source file.
update_version_file() {
    local file="$1"
    local new_version="$2"
    local tmp

    if [[ "$file" == *.json ]]; then
        tmp=$(mktemp)
        sed "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${new_version}\"/" \
            "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        echo "$new_version" > "$file"
    fi
}

# Generate a changelog entry grouped by change type (Breaking/Features/Bug Fixes/Other).
# Writes to stdout so callers can capture or redirect it.
generate_changelog_entry() {
    local commits_file="$1"
    local new_version="$2"
    local date
    date=$(date +%Y-%m-%d)

    # Accumulate commits into temp files by category
    local tmp_breaking tmp_feat tmp_fix tmp_other
    tmp_breaking=$(mktemp)
    tmp_feat=$(mktemp)
    tmp_fix=$(mktemp)
    tmp_other=$(mktemp)

    local breaking_type='^[a-zA-Z]+(\([^)]*\))?!:'
    local breaking_body='^BREAKING[- ]CHANGE'
    local feat_type='^feat(\([^)]*\))?:'
    local fix_type='^fix(\([^)]*\))?:'

    while IFS= read -r commit || [[ -n "$commit" ]]; do
        [[ -z "$commit" ]] && continue

        if [[ "$commit" =~ $breaking_type ]] || [[ "$commit" =~ $breaking_body ]]; then
            echo "- ${commit}" >> "$tmp_breaking"
        elif [[ "$commit" =~ $feat_type ]]; then
            echo "- ${commit}" >> "$tmp_feat"
        elif [[ "$commit" =~ $fix_type ]]; then
            echo "- ${commit}" >> "$tmp_fix"
        else
            echo "- ${commit}" >> "$tmp_other"
        fi
    done < "$commits_file"

    echo "## [${new_version}] - ${date}"
    echo ""

    if [[ -s "$tmp_breaking" ]]; then
        echo "### Breaking Changes"
        cat "$tmp_breaking"
        echo ""
    fi

    if [[ -s "$tmp_feat" ]]; then
        echo "### Features"
        cat "$tmp_feat"
        echo ""
    fi

    if [[ -s "$tmp_fix" ]]; then
        echo "### Bug Fixes"
        cat "$tmp_fix"
        echo ""
    fi

    if [[ -s "$tmp_other" ]]; then
        echo "### Other Changes"
        cat "$tmp_other"
        echo ""
    fi

    rm -f "$tmp_breaking" "$tmp_feat" "$tmp_fix" "$tmp_other"
}

# Prepend the changelog entry to the changelog file (creating it if absent).
write_changelog() {
    local changelog_file="$1"
    local entry="$2"
    local tmp

    tmp=$(mktemp)
    printf '%s\n\n' "$entry" > "$tmp"

    if [[ -f "$changelog_file" ]]; then
        cat "$changelog_file" >> "$tmp"
    fi

    mv "$tmp" "$changelog_file"
}

main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    local version_file="$1"
    local commits_file="$2"
    local changelog_file="${3:-CHANGELOG.md}"

    # Validate commits file early for a clear error message
    if [[ ! -f "$commits_file" ]]; then
        echo "Error: commits file '$commits_file' not found" >&2
        exit 1
    fi

    # Parse and validate current version
    local current_version
    current_version=$(parse_version "$version_file")

    if ! [[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: invalid semver '$current_version' (expected X.Y.Z)" >&2
        exit 1
    fi

    # Determine bump type, compute new version
    local bump_type new_version
    bump_type=$(determine_bump_type "$commits_file")
    new_version=$(bump_version "$current_version" "$bump_type")

    # Generate and prepend changelog entry
    local changelog_entry
    changelog_entry=$(generate_changelog_entry "$commits_file" "$new_version")
    write_changelog "$changelog_file" "$changelog_entry"

    # Update the version source file
    update_version_file "$version_file" "$new_version"

    # Output new version (primary output for CI consumption)
    echo "$new_version"
}

main "$@"
