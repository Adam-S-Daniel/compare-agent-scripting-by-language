#!/usr/bin/env bash
# bump-version.sh — Semantic version bumper driven by conventional commits
#
# Modes of operation:
#   --parse-only <file>                Parse and print current version from file
#   --detect-bump <commits-file>       Detect bump type (major/minor/patch) from commits
#   --bump <type> <version>            Calculate next version given bump type
#   --version-file <f> --commits <f>   Full pipeline: bump version file in place
#     [--changelog <file>]             Optional: also generate/update changelog

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Parse a semver string and export MAJOR, MINOR, PATCH components
parse_semver() {
    local version="$1"
    if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        die "Invalid semver: '$version'"
    fi
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
}

# Read the version string from a file (VERSION plain text or package.json)
read_version_from_file() {
    local file="$1"
    [[ -f "$file" ]] || die "Version file does not exist: $file"

    if [[ "$file" == *.json ]]; then
        # Extract "version": "x.y.z" from package.json using sed (no jq required)
        local ver
        ver=$(grep '"version"' "$file" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        [[ -n "$ver" ]] || die "No version field found in $file"
        echo "$ver"
    else
        # Plain text VERSION file — first non-empty line
        local ver
        ver=$(grep -m1 '[0-9]' "$file" | tr -d '[:space:]')
        [[ -n "$ver" ]] || die "No version found in $file"
        echo "$ver"
    fi
}

# Write new version back to file, preserving format
write_version_to_file() {
    local file="$1"
    local new_version="$2"

    if [[ "$file" == *.json ]]; then
        # Replace the "version" line in package.json in-place
        sed -i "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$new_version\"/" "$file"
    else
        # Overwrite plain VERSION file
        echo "$new_version" > "$file"
    fi
}

# Determine the bump type from a file of commit messages
detect_bump_type_from_file() {
    local commits_file="$1"
    [[ -f "$commits_file" ]] || die "Commits file does not exist: $commits_file"

    local content
    content=$(cat "$commits_file")
    [[ -n "$content" ]] || die "No commits found — commits file is empty"

    # Major: feat! / fix! / any type with ! before colon, OR "BREAKING CHANGE:" footer
    if echo "$content" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:' || \
       echo "$content" | grep -qE '^BREAKING CHANGE:'; then
        echo "major"
        return
    fi

    # Minor: any feat: commit
    if echo "$content" | grep -qE '^feat(\([^)]*\))?:'; then
        echo "minor"
        return
    fi

    # Patch: fix:, docs:, chore:, style:, refactor:, perf:, test:, build:, ci:
    if echo "$content" | grep -qE '^(fix|docs|chore|style|refactor|perf|test|build|ci)(\([^)]*\))?:'; then
        echo "patch"
        return
    fi

    # Default to patch for anything else
    echo "patch"
}

# Calculate the next version given bump type and current version
calculate_next_version() {
    local bump_type="$1"
    local current="$2"
    parse_semver "$current"

    case "$bump_type" in
        major) echo "$((MAJOR + 1)).0.0" ;;
        minor) echo "${MAJOR}.$((MINOR + 1)).0" ;;
        patch) echo "${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
        *) die "Unknown bump type: '$bump_type'" ;;
    esac
}

# Generate a changelog entry and prepend it to the changelog file
generate_changelog() {
    local changelog_file="$1"
    local new_version="$2"
    local commits_file="$3"
    local date_str
    date_str=$(date +%Y-%m-%d)

    # Build the new entry
    local entry
    entry="## [$new_version] - $date_str"$'\n'$'\n'

    # Categorise commits
    local features fixes breaking others
    features=$(grep -E '^feat(\([^)]*\))?:' "$commits_file" | sed 's/^[^:]*: //' || true)
    fixes=$(grep -E '^(fix|bug)(\([^)]*\))?:' "$commits_file" | sed 's/^[^:]*: //' || true)
    breaking=$(grep -E '^[a-zA-Z]+(\([^)]*\))?!:|^BREAKING CHANGE:' "$commits_file" | sed 's/^[^:]*: //' || true)
    others=$(grep -vE '^(feat|fix|bug|BREAKING CHANGE)[^:]*:' "$commits_file" | grep -v '^[[:space:]]*$' || true)

    if [[ -n "$breaking" ]]; then
        entry+="### Breaking Changes"$'\n'
        while IFS= read -r line; do
            [[ -n "$line" ]] && entry+="- $line"$'\n'
        done <<< "$breaking"
        entry+=$'\n'
    fi

    if [[ -n "$features" ]]; then
        entry+="### Features"$'\n'
        while IFS= read -r line; do
            [[ -n "$line" ]] && entry+="- $line"$'\n'
        done <<< "$features"
        entry+=$'\n'
    fi

    if [[ -n "$fixes" ]]; then
        entry+="### Fixed"$'\n'
        while IFS= read -r line; do
            [[ -n "$line" ]] && entry+="- $line"$'\n'
        done <<< "$fixes"
        entry+=$'\n'
    fi

    if [[ -n "$others" ]]; then
        entry+="### Other"$'\n'
        while IFS= read -r line; do
            [[ -n "$line" ]] && entry+="- $line"$'\n'
        done <<< "$others"
        entry+=$'\n'
    fi

    if [[ -f "$changelog_file" ]]; then
        # Prepend new entry to existing file
        local existing
        existing=$(cat "$changelog_file")
        printf '%s\n%s' "$entry" "$existing" > "$changelog_file"
    else
        printf '%s' "$entry" > "$changelog_file"
    fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
main() {
    local mode=""
    local version_file=""
    local commits_file=""
    local changelog_file=""
    local bump_type=""
    local current_version=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --parse-only)
                mode="parse"
                version_file="$2"
                shift 2
                ;;
            --detect-bump)
                mode="detect"
                commits_file="$2"
                shift 2
                ;;
            --bump)
                mode="bump"
                bump_type="$2"
                current_version="$3"
                shift 3
                ;;
            --version-file)
                version_file="$2"
                shift 2
                ;;
            --commits)
                commits_file="$2"
                shift 2
                ;;
            --changelog)
                changelog_file="$2"
                shift 2
                ;;
            *)
                die "Unknown argument: $1"
                ;;
        esac
    done

    case "$mode" in
        parse)
            read_version_from_file "$version_file"
            ;;
        detect)
            detect_bump_type_from_file "$commits_file"
            ;;
        bump)
            calculate_next_version "$bump_type" "$current_version"
            ;;
        "")
            # Full pipeline: requires --version-file and --commits
            [[ -n "$version_file" ]] || die "No version file specified (use --version-file)"
            [[ -n "$commits_file" ]] || die "No commits file specified (use --commits)"

            local current new_version bump
            current=$(read_version_from_file "$version_file")
            bump=$(detect_bump_type_from_file "$commits_file")
            new_version=$(calculate_next_version "$bump" "$current")

            write_version_to_file "$version_file" "$new_version"

            if [[ -n "$changelog_file" ]]; then
                generate_changelog "$changelog_file" "$new_version" "$commits_file"
            fi

            echo "$new_version"
            ;;
        *)
            die "Unknown mode: $mode"
            ;;
    esac
}

main "$@"
