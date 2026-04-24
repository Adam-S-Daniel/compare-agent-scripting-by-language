#!/usr/bin/env bash
# bump-version.sh
#
# Semantic-version bumper driven by conventional commit messages.
#
# Subcommands (each is independently testable):
#   --determine-bump-type <commits>   -> prints: major|minor|patch|none
#   --bump <version> <type>           -> prints: new version
#   --read-version <file>             -> prints: version from VERSION or package.json
#   --write-version <file> <version>  -> writes new version into file
#   --changelog <version> <commits>   -> prints changelog markdown entry
#   --run <version_file> <commits_file> <changelog_file>
#                                     -> full pipeline; prints new version

set -euo pipefail

# Validate "MAJOR.MINOR.PATCH" (digits only). Keeps things simple; no pre-release.
is_valid_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Inspect commit messages line-by-line and return the highest-priority bump.
# Priority: major > minor > patch > none.
determine_bump_type() {
    local commits="$1"
    local highest="none"

    # BREAKING CHANGE footer OR "type!:" prefix => major.
    if grep -qE '^BREAKING CHANGE' <<< "$commits" \
        || grep -qE '^[a-zA-Z]+(\([^)]+\))?!:' <<< "$commits"; then
        highest="major"
    elif grep -qE '^feat(\([^)]+\))?:' <<< "$commits"; then
        highest="minor"
    elif grep -qE '^fix(\([^)]+\))?:' <<< "$commits"; then
        highest="patch"
    fi

    printf '%s\n' "$highest"
}

bump_version() {
    local version="$1" type="$2"
    if ! is_valid_version "$version"; then
        echo "Invalid version: $version" >&2
        return 1
    fi
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    case "$type" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        none)  : ;;
        *) echo "Unknown bump type: $type" >&2; return 1 ;;
    esac
    printf '%s.%s.%s\n' "$major" "$minor" "$patch"
}

read_version() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file" >&2
        return 1
    fi
    if [[ "$file" == *package.json ]]; then
        # Minimal JSON parse: extract "version": "x.y.z".
        local v
        v=$(grep -E '"version"\s*:\s*"[^"]+"' "$file" | head -n1 \
            | sed -E 's/.*"version"\s*:\s*"([^"]+)".*/\1/')
        if [[ -z "$v" ]]; then
            echo "No version field in $file" >&2
            return 1
        fi
        printf '%s\n' "$v"
    else
        # Plain VERSION file: strip whitespace.
        tr -d '[:space:]' < "$file"
        echo
    fi
}

write_version() {
    local file="$1" new="$2"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file" >&2
        return 1
    fi
    if [[ "$file" == *package.json ]]; then
        # In-place replace the version field. sed's -i with a backup for portability.
        local tmp
        tmp=$(mktemp)
        sed -E 's/("version"\s*:\s*")[^"]+(")/\1'"$new"'\2/' "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        printf '%s\n' "$new" > "$file"
    fi
}

# Build a markdown changelog entry grouping feat/fix/breaking into sections.
generate_changelog() {
    local version="$1" commits="$2"
    local feats fixes breaks date
    date=$(date -u +%Y-%m-%d)
    feats=$(grep -E '^feat(\([^)]+\))?!?:' <<< "$commits" || true)
    fixes=$(grep -E '^fix(\([^)]+\))?!?:' <<< "$commits" || true)
    breaks=$(grep -E '^BREAKING CHANGE' <<< "$commits" || true)

    printf '## %s - %s\n\n' "$version" "$date"
    if [[ -n "$breaks" ]]; then
        printf '### BREAKING CHANGES\n\n'
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            printf -- '- %s\n' "${line#BREAKING CHANGE: }"
        done <<< "$breaks"
        printf '\n'
    fi
    if [[ -n "$feats" ]]; then
        printf '### Features\n\n'
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Strip "feat(scope)?!?: " prefix.
            printf -- '- %s\n' "$(sed -E 's/^feat(\([^)]+\))?!?:\s*//' <<< "$line")"
        done <<< "$feats"
        printf '\n'
    fi
    if [[ -n "$fixes" ]]; then
        printf '### Bug Fixes\n\n'
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            printf -- '- %s\n' "$(sed -E 's/^fix(\([^)]+\))?!?:\s*//' <<< "$line")"
        done <<< "$fixes"
        printf '\n'
    fi
}

# Full pipeline: read, decide, bump, write, changelog, print.
run_pipeline() {
    local vfile="$1" cfile="$2" changelog_file="$3"
    local current commits bump_type new entry existing

    current=$(read_version "$vfile")
    if [[ ! -f "$cfile" ]]; then
        echo "Commits file not found: $cfile" >&2
        return 1
    fi
    commits=$(cat "$cfile")
    bump_type=$(determine_bump_type "$commits")
    new=$(bump_version "$current" "$bump_type")

    if [[ "$bump_type" != "none" ]]; then
        write_version "$vfile" "$new"
        entry=$(generate_changelog "$new" "$commits")
        existing=""
        [[ -f "$changelog_file" ]] && existing=$(cat "$changelog_file")
        {
            printf '%s\n' "$entry"
            [[ -n "$existing" ]] && printf '%s\n' "$existing"
        } > "$changelog_file"
    fi

    printf '%s\n' "$new"
}

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 --<subcommand> [args]" >&2
        return 2
    fi
    local cmd="$1"; shift
    case "$cmd" in
        --determine-bump-type) determine_bump_type "$1" ;;
        --bump)                bump_version "$1" "$2" ;;
        --read-version)        read_version "$1" ;;
        --write-version)       write_version "$1" "$2" ;;
        --changelog)           generate_changelog "$1" "$2" ;;
        --run)                 run_pipeline "$1" "$2" "$3" ;;
        *) echo "Unknown command: $cmd" >&2; return 2 ;;
    esac
}

main "$@"
