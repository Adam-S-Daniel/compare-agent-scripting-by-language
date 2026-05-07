#!/usr/bin/env bash
# Semantic Version Bumper
# Parses a version file, determines next version from conventional commits,
# updates the file, and generates a changelog entry.
#
# Usage: version-bumper.sh <version-file> <commits-file>
#   version-file: plain text file with "x.y.z" OR a package.json
#   commits-file: one commit message per line (conventional commits format)

set -euo pipefail

VERSION_FILE="${1:-version.txt}"
COMMITS_FILE="${2:-commits.txt}"

# Parse semantic version from file — supports plain text or package.json
parse_version() {
    local file="$1"
    local version
    if [[ "$file" == *.json ]]; then
        version=$(grep '"version"' "$file" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    else
        version=$(tr -d '[:space:]' < "$file")
    fi
    echo "$version"
}

# Determine bump type from conventional commits.
# Precedence: major > minor > patch
# BREAKING CHANGE footer or ! suffix -> major
# feat: prefix -> minor
# fix: (and anything else) -> patch
determine_bump_type() {
    local commits_file="$1"
    local bump_type="patch"
    # Bash =~ requires complex regex patterns in a variable to avoid syntax errors
    local re_breaking='^[a-z]+(\([^)]*\))?!:'
    local re_feat='^feat(\([^)]*\))?:'

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines
        [[ -z "$line" ]] && continue

        # Breaking change: type! suffix or BREAKING CHANGE footer
        if [[ "$line" =~ $re_breaking ]] || \
           [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
            bump_type="major"
            break  # major is highest, no need to keep scanning
        fi

        # Feature: bump to minor unless we already know it's major
        if [[ "$line" =~ $re_feat ]] && [[ "$bump_type" != "major" ]]; then
            bump_type="minor"
        fi
    done < "$commits_file"

    echo "$bump_type"
}

# Calculate next semantic version
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
            echo "Error: Unknown bump type: $bump_type" >&2
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Update version in the version file in-place
update_version() {
    local file="$1"
    local new_version="$2"

    if [[ "$file" == *.json ]]; then
        # Use a temp file to avoid partial writes
        local tmp
        tmp=$(mktemp)
        sed "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${new_version}\"/" \
            "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        echo "$new_version" > "$file"
    fi
}

# Generate a conventional changelog entry grouped by commit type
generate_changelog() {
    local commits_file="$1"
    local new_version="$2"
    local date
    date=$(date +%Y-%m-%d)

    local breaking_changes=()
    local features=()
    local fixes=()

    local re_breaking='^[a-z]+(\([^)]*\))?!:'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ $re_breaking ]] || \
           [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
            breaking_changes+=("- $line")
        elif [[ "$line" =~ $re_feat ]]; then
            features+=("- $line")
        elif [[ "$line" =~ $re_fix ]]; then
            fixes+=("- $line")
        fi
    done < "$commits_file"

    echo "## [${new_version}] - ${date}"
    echo ""

    if [[ ${#breaking_changes[@]} -gt 0 ]]; then
        echo "### BREAKING CHANGES"
        printf '%s\n' "${breaking_changes[@]}"
        echo ""
    fi

    if [[ ${#features[@]} -gt 0 ]]; then
        echo "### Features"
        printf '%s\n' "${features[@]}"
        echo ""
    fi

    if [[ ${#fixes[@]} -gt 0 ]]; then
        echo "### Bug Fixes"
        printf '%s\n' "${fixes[@]}"
        echo ""
    fi
}

main() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "Error: Version file '$VERSION_FILE' not found" >&2
        exit 1
    fi

    if [[ ! -f "$COMMITS_FILE" ]]; then
        echo "Error: Commits file '$COMMITS_FILE' not found" >&2
        exit 1
    fi

    local current_version
    current_version=$(parse_version "$VERSION_FILE")

    if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid semantic version: '$current_version'" >&2
        exit 1
    fi

    local bump_type
    bump_type=$(determine_bump_type "$COMMITS_FILE")

    local new_version
    new_version=$(bump_version "$current_version" "$bump_type")

    update_version "$VERSION_FILE" "$new_version"

    echo "BUMP_TYPE=${bump_type}"
    echo "OLD_VERSION=${current_version}"
    echo "NEW_VERSION=${new_version}"
    echo ""
    echo "=== CHANGELOG ==="
    generate_changelog "$COMMITS_FILE" "$new_version"
}

main "$@"
