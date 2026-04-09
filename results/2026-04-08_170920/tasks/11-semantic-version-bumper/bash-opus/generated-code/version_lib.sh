#!/usr/bin/env bash
# version_lib.sh - Library of functions for semantic version bumping
#
# Provides:
#   parse_version   - Extract major.minor.patch from a version string
#   read_version_file - Read version from a plain text file or package.json
#   detect_bump_type  - Determine bump type (major/minor/patch/none) from commits
#   bump_version      - Compute the next version given current + bump type
#   generate_changelog - Create a changelog entry grouped by commit type
#   update_version_file - Write the new version back to the file

set -euo pipefail

# Parse a semantic version string into "major minor patch".
# Accepts optional "v" prefix. Exits non-zero on invalid input.
parse_version() {
    local version="${1:-}"
    # Strip optional v prefix
    version="${version#v}"

    if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "Error: invalid version string: '${1:-}'" >&2
        return 1
    fi

    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
}

# Read a version string from a file.
# Supports plain text files (first line) and package.json ("version" field).
read_version_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: version file not found: $file" >&2
        return 1
    fi

    if [[ "$file" == *.json ]]; then
        # Extract version from JSON using grep+sed (no jq dependency)
        local ver
        ver="$(grep '"version"' "$file" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
        if [[ -z "$ver" ]]; then
            echo "Error: no version field found in $file" >&2
            return 1
        fi
        echo "$ver"
    else
        # Plain text: first non-empty line, trimmed
        local ver
        ver="$(grep -m1 '[0-9]' "$file" | tr -d '[:space:]')"
        if [[ -z "$ver" ]]; then
            echo "Error: no version found in $file" >&2
            return 1
        fi
        echo "$ver"
    fi
}

# Detect the bump type from a commit log file.
# Reads conventional commit messages and returns: major, minor, patch, or none.
# Priority: major > minor > patch > none.
detect_bump_type() {
    local commits_file="$1"

    if [[ ! -f "$commits_file" ]]; then
        echo "Error: commits file not found: $commits_file" >&2
        return 1
    fi

    local has_major=false
    local has_minor=false
    local has_patch=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Check for BREAKING CHANGE footer
        if [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
            has_major=true
            continue
        fi

        # Check for breaking change indicator (! before colon)
        if [[ "$line" =~ ^[a-zA-Z]+(\(.+\))?!: ]]; then
            has_major=true
            continue
        fi

        # Check for feat commits -> minor bump
        if [[ "$line" =~ ^feat(\(.+\))?: ]]; then
            has_minor=true
            continue
        fi

        # Check for fix commits -> patch bump
        if [[ "$line" =~ ^fix(\(.+\))?: ]]; then
            has_patch=true
            continue
        fi
    done < "$commits_file"

    if $has_major; then
        echo "major"
    elif $has_minor; then
        echo "minor"
    elif $has_patch; then
        echo "patch"
    else
        echo "none"
    fi
}

# Compute the next version given current version and bump type.
bump_version() {
    local version="${1:-}"
    local bump_type="${2:-}"

    # Strip optional v prefix
    version="${version#v}"

    local parts
    parts="$(parse_version "$version")" || return 1
    read -r major minor patch <<< "$parts"

    case "$bump_type" in
        major)
            echo "$(( major + 1 )).0.0"
            ;;
        minor)
            echo "${major}.$(( minor + 1 )).0"
            ;;
        patch)
            echo "${major}.${minor}.$(( patch + 1 ))"
            ;;
        none)
            echo "${major}.${minor}.${patch}"
            ;;
        *)
            echo "Error: invalid bump type: '$bump_type'" >&2
            return 1
            ;;
    esac
}

# Generate a changelog entry from commit messages, grouped by type.
# Output is Markdown formatted.
generate_changelog() {
    local commits_file="$1"
    local new_version="$2"

    local breaking=()
    local features=()
    local fixes=()
    local other=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue

        # Breaking change footer lines are context, not standalone entries
        if [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
            breaking+=("${line#*: }")
            continue
        fi

        # Breaking change with ! suffix
        if [[ "$line" =~ ^([a-zA-Z]+)(\(.+\))?!:[[:space:]]*(.*) ]]; then
            breaking+=("${BASH_REMATCH[3]}")
            continue
        fi

        # Feature commits
        if [[ "$line" =~ ^feat(\(.+\))?:[[:space:]]*(.*) ]]; then
            features+=("${BASH_REMATCH[2]}")
            continue
        fi

        # Fix commits
        if [[ "$line" =~ ^fix(\(.+\))?:[[:space:]]*(.*) ]]; then
            fixes+=("${BASH_REMATCH[2]}")
            continue
        fi

        # Everything else (docs, chore, style, ci, etc.)
        if [[ "$line" =~ ^[a-zA-Z]+(\(.+\))?:[[:space:]]*(.*) ]]; then
            other+=("${BASH_REMATCH[2]}")
            continue
        fi
    done < "$commits_file"

    # Build changelog entry
    echo "## ${new_version}"
    echo ""

    if [[ ${#breaking[@]} -gt 0 ]]; then
        echo "### Breaking Changes"
        for item in "${breaking[@]}"; do
            echo "- ${item}"
        done
        echo ""
    fi

    if [[ ${#features[@]} -gt 0 ]]; then
        echo "### Added"
        for item in "${features[@]}"; do
            echo "- ${item}"
        done
        echo ""
    fi

    if [[ ${#fixes[@]} -gt 0 ]]; then
        echo "### Fixed"
        for item in "${fixes[@]}"; do
            echo "- ${item}"
        done
        echo ""
    fi

    if [[ ${#other[@]} -gt 0 ]]; then
        echo "### Other"
        for item in "${other[@]}"; do
            echo "- ${item}"
        done
        echo ""
    fi
}

# Update the version in a file (plain text or package.json).
update_version_file() {
    local file="$1"
    local new_version="$2"

    if [[ ! -f "$file" ]]; then
        echo "Error: version file not found: $file" >&2
        return 1
    fi

    if [[ "$file" == *.json ]]; then
        # Update version field in JSON using sed
        sed -i "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${new_version}\"/" "$file"
    else
        # Plain text: replace entire content with new version
        echo "$new_version" > "$file"
    fi
}
