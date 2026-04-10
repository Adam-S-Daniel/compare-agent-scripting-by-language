#!/usr/bin/env bash
# bump-version.sh - Semantic version bumper based on conventional commits
#
# Usage: bump-version.sh <version-file> <commits-file>
#
#   version-file  Path to version.txt (plain semver) or package.json
#   commits-file  Path to file with conventional commit messages, one per line
#
# Conventional commit -> bump type:
#   fix(scope): message         -> patch  (1.0.0 -> 1.0.1)
#   feat(scope): message        -> minor  (1.0.0 -> 1.1.0)
#   feat!: message              -> major  (1.0.0 -> 2.0.0)
#   BREAKING CHANGE in message  -> major  (1.0.0 -> 2.0.0)
#
# Output: new semantic version string (printed to stdout)
# Side effects:
#   - Updates version-file with new version
#   - Creates/prepends to CHANGELOG.md in same directory as version-file

set -euo pipefail

# ---------------------------------------------------------------------------
# parse_version <file>
# Extract the semver string from a version.txt or package.json file.
# Prints the version to stdout.
# ---------------------------------------------------------------------------
parse_version() {
    local file="$1"
    local version

    if [[ "$file" == *package.json ]]; then
        # Extract "version": "x.y.z" using grep + sed (no jq dependency)
        version=$(grep '"version"' "$file" \
            | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
            | head -1)
    else
        # Plain version file: first non-blank line
        version=$(grep -v '^[[:space:]]*$' "$file" | head -1 | tr -d '[:space:]')
    fi

    echo "$version"
}

# ---------------------------------------------------------------------------
# validate_semver <version>
# Returns 0 if version looks like MAJOR.MINOR.PATCH, non-zero otherwise.
# ---------------------------------------------------------------------------
validate_semver() {
    local version="$1"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ---------------------------------------------------------------------------
# determine_bump_type <commits-file>
# Analyzes commit messages and prints the bump type: none|patch|minor|major
# Priority: major > minor > patch > none
#
# Regex patterns stored in variables to avoid bash [[ ]] parsing issues
# with ERE metacharacters like ) inside the conditional expression.
# ---------------------------------------------------------------------------
determine_bump_type() {
    local commits_file="$1"
    local bump_type="none"

    # ERE patterns for conventional commit types (store in vars to avoid [[ ]] parsing issues)
    local re_breaking_bang='^[a-zA-Z]+(\([^)]*\))?!:'
    local re_breaking_text='BREAKING[[:space:]]CHANGE'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'

    while IFS= read -r commit || [[ -n "$commit" ]]; do
        # Skip blank lines and comment lines
        [[ -z "$commit" || "$commit" == \#* ]] && continue

        # Major: any type with ! suffix (feat!:, fix!:, chore(api)!:, …)
        # or BREAKING CHANGE anywhere in the line
        if [[ "$commit" =~ $re_breaking_bang ]] \
           || [[ "$commit" =~ $re_breaking_text ]]; then
            echo "major"
            return 0
        fi

        # Minor: feat(scope): or feat:
        if [[ "$commit" =~ $re_feat ]]; then
            bump_type="minor"
            continue
        fi

        # Patch: fix(scope): or fix:  (only if no higher bump seen yet)
        if [[ "$commit" =~ $re_fix ]] && [[ "$bump_type" == "none" ]]; then
            bump_type="patch"
        fi
    done < "$commits_file"

    echo "$bump_type"
}

# ---------------------------------------------------------------------------
# bump_version <current> <bump_type>
# Calculates and prints the next version string.
# ---------------------------------------------------------------------------
bump_version() {
    local current="$1"
    local bump_type="$2"

    # Split into components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"

    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch + 1))"
            ;;
        none)
            echo "$current"
            ;;
        *)
            echo "ERROR: unknown bump type: $bump_type" >&2
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# update_version_file <file> <new_version>
# Writes new_version back into the file (version.txt or package.json).
# ---------------------------------------------------------------------------
update_version_file() {
    local file="$1"
    local new_version="$2"

    if [[ "$file" == *package.json ]]; then
        # Replace the "version" field value using sed
        sed -i "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$new_version\"/" "$file"
    else
        echo "$new_version" > "$file"
    fi
}

# ---------------------------------------------------------------------------
# generate_changelog <dir> <new_version> <commits_file>
# Prepends a new changelog entry to CHANGELOG.md in <dir>.
# ---------------------------------------------------------------------------
generate_changelog() {
    local dir="$1"
    local new_version="$2"
    local commits_file="$3"
    local changelog="$dir/CHANGELOG.md"
    local today
    today=$(date +%Y-%m-%d)

    # Collect commits by category
    local features=() fixes=() breaking=() other=()

    # Same patterns as determine_bump_type (stored in vars to avoid [[ ]] issues)
    local re_breaking_bang='^[a-zA-Z]+(\([^)]*\))?!:'
    local re_breaking_text='BREAKING[[:space:]]CHANGE'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'

    while IFS= read -r commit || [[ -n "$commit" ]]; do
        [[ -z "$commit" || "$commit" == \#* ]] && continue

        if [[ "$commit" =~ $re_breaking_bang ]] \
           || [[ "$commit" =~ $re_breaking_text ]]; then
            breaking+=("$commit")
        elif [[ "$commit" =~ $re_feat ]]; then
            features+=("$commit")
        elif [[ "$commit" =~ $re_fix ]]; then
            fixes+=("$commit")
        else
            other+=("$commit")
        fi
    done < "$commits_file"

    # Build the new entry
    local entry
    entry="## [$new_version] - $today"$'\n'

    if [[ ${#breaking[@]} -gt 0 ]]; then
        entry+=$'\n'"### Breaking Changes"$'\n'
        for c in "${breaking[@]}"; do
            entry+="- $c"$'\n'
        done
    fi

    if [[ ${#features[@]} -gt 0 ]]; then
        entry+=$'\n'"### Features"$'\n'
        for c in "${features[@]}"; do
            entry+="- $c"$'\n'
        done
    fi

    if [[ ${#fixes[@]} -gt 0 ]]; then
        entry+=$'\n'"### Bug Fixes"$'\n'
        for c in "${fixes[@]}"; do
            entry+="- $c"$'\n'
        done
    fi

    if [[ ${#other[@]} -gt 0 ]]; then
        entry+=$'\n'"### Other"$'\n'
        for c in "${other[@]}"; do
            entry+="- $c"$'\n'
        done
    fi

    # Prepend to existing changelog or create new one
    if [[ -f "$changelog" ]]; then
        local existing
        existing=$(cat "$changelog")
        printf '%s\n\n%s\n' "$entry" "$existing" > "$changelog"
    else
        printf '%s\n' "$entry" > "$changelog"
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <version-file> <commits-file>" >&2
        exit 1
    fi

    local version_file="$1"
    local commits_file="$2"

    # Validate inputs
    if [[ ! -f "$version_file" ]]; then
        echo "Error: version file not found: $version_file" >&2
        exit 1
    fi

    if [[ ! -f "$commits_file" ]]; then
        echo "Error: commits file not found: $commits_file" >&2
        exit 1
    fi

    # Parse current version
    local current_version
    current_version=$(parse_version "$version_file")

    if ! validate_semver "$current_version"; then
        echo "Error: invalid semantic version '${current_version}' in $version_file" >&2
        exit 1
    fi

    # Determine bump type from commits
    local bump_type
    bump_type=$(determine_bump_type "$commits_file")

    # Calculate new version
    local new_version
    new_version=$(bump_version "$current_version" "$bump_type")

    # Update version file (only if version changed)
    if [[ "$new_version" != "$current_version" ]]; then
        update_version_file "$version_file" "$new_version"
        # Generate changelog entry
        local version_dir
        version_dir=$(dirname "$version_file")
        generate_changelog "$version_dir" "$new_version" "$commits_file"
    fi

    # Output the new (or unchanged) version
    echo "$new_version"
}

main "$@"
