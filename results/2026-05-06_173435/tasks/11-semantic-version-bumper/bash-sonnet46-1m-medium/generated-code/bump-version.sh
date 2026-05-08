#!/usr/bin/env bash
# bump-version.sh — Semantic version bumper using conventional commits.
#
# Usage: bump-version.sh <version-file> <commits-file>
#
#   version-file  Path to a plain-text version file (e.g. "1.2.3\n")
#                 OR a package.json whose "version" field will be updated.
#   commits-file  Path to a file containing one conventional commit message
#                 per line.  Bump precedence: major > minor > patch > none.
#
# Conventional-commit rules applied:
#   BREAKING CHANGE token or ! suffix (feat!:) → major bump
#   feat: / feat(scope):                       → minor bump
#   fix:  / fix(scope):                        → patch bump
#   everything else (chore:, docs:, …)         → no bump
#
# Output: changelog to stdout followed by "NEW_VERSION: <version>" on the
# last line.  The version file is updated in-place.

set -euo pipefail

# ---------------------------------------------------------------------------
# parse_version <file>
# Extracts the current semantic version string from a text file or package.json.
# ---------------------------------------------------------------------------
parse_version() {
    local file="$1"
    local version

    if [[ "$file" == *.json ]]; then
        version=$(grep '"version"' "$file" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
    else
        version=$(tr -d '[:space:]' < "$file")
    fi

    if [[ -z "$version" ]]; then
        echo "Error: could not parse version from $file" >&2
        exit 1
    fi

    echo "$version"
}

# ---------------------------------------------------------------------------
# determine_bump_type <commits-file>
# Scans each commit line and returns the highest-precedence bump type.
# ---------------------------------------------------------------------------
determine_bump_type() {
    local commits_file="$1"
    local bump_type="none"

    while IFS= read -r line; do
        # Empty lines are skipped
        [[ -z "$line" ]] && continue

        # Breaking change: BREAKING CHANGE token in footer OR ! before colon
        if echo "$line" | grep -qE '(^BREAKING CHANGE|^[a-z]+(\([^)]*\))?!:)'; then
            bump_type="major"
            # major is the highest — no need to read further
            break
        fi

        # Feature: sets minor (only if we haven't already hit a higher level)
        if echo "$line" | grep -qE '^feat(\([^)]*\))?:'; then
            if [[ "$bump_type" == "none" || "$bump_type" == "patch" ]]; then
                bump_type="minor"
            fi
        fi

        # Fix: sets patch (only if nothing higher was seen)
        if echo "$line" | grep -qE '^fix(\([^)]*\))?:'; then
            if [[ "$bump_type" == "none" ]]; then
                bump_type="patch"
            fi
        fi
    done < "$commits_file"

    echo "$bump_type"
}

# ---------------------------------------------------------------------------
# bump_version <current> <type>
# Returns the next semantic version string.
# ---------------------------------------------------------------------------
bump_version() {
    local version="$1"
    local bump_type="$2"
    local major minor patch

    IFS='.' read -r major minor patch <<< "$version"

    case "$bump_type" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
        none)  echo "$version" ;;
        *)
            echo "Error: unknown bump type: $bump_type" >&2
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# update_version_file <file> <new_version>
# Writes the new version back into the file (text or package.json).
# ---------------------------------------------------------------------------
update_version_file() {
    local file="$1"
    local new_version="$2"

    if [[ "$file" == *.json ]]; then
        sed -i "s/\"version\": *\"[^\"]*\"/\"version\": \"${new_version}\"/" "$file"
    else
        printf '%s\n' "$new_version" > "$file"
    fi
}

# ---------------------------------------------------------------------------
# generate_changelog <commits-file> <new_version>
# Prints a markdown changelog block to stdout.
# ---------------------------------------------------------------------------
generate_changelog() {
    local commits_file="$1"
    local new_version="$2"
    local today
    today=$(date +%Y-%m-%d)

    local -a features=()
    local -a fixes=()
    local -a breaking=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if echo "$line" | grep -qE '(^BREAKING CHANGE|^[a-z]+(\([^)]*\))?!:)'; then
            breaking+=("$line")
        elif echo "$line" | grep -qE '^feat(\([^)]*\))?:'; then
            features+=("$line")
        elif echo "$line" | grep -qE '^fix(\([^)]*\))?:'; then
            fixes+=("$line")
        fi
    done < "$commits_file"

    echo "## [${new_version}] - ${today}"
    echo ""

    if [[ ${#breaking[@]} -gt 0 ]]; then
        echo "### Breaking Changes"
        for commit in "${breaking[@]}"; do
            echo "- ${commit}"
        done
        echo ""
    fi

    if [[ ${#features[@]} -gt 0 ]]; then
        echo "### Features"
        for commit in "${features[@]}"; do
            echo "- ${commit}"
        done
        echo ""
    fi

    if [[ ${#fixes[@]} -gt 0 ]]; then
        echo "### Bug Fixes"
        for commit in "${fixes[@]}"; do
            echo "- ${commit}"
        done
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <version-file> <commits-file>" >&2
        exit 1
    fi

    local version_file="$1"
    local commits_file="$2"

    if [[ ! -f "$version_file" ]]; then
        echo "Error: version file not found: $version_file" >&2
        exit 1
    fi

    if [[ ! -f "$commits_file" ]]; then
        echo "Error: commits file not found: $commits_file" >&2
        exit 1
    fi

    local current_version
    current_version=$(parse_version "$version_file")

    local bump_type
    bump_type=$(determine_bump_type "$commits_file")

    local new_version
    new_version=$(bump_version "$current_version" "$bump_type")

    update_version_file "$version_file" "$new_version"

    generate_changelog "$commits_file" "$new_version"

    echo "NEW_VERSION: ${new_version}"
}

main "$@"
