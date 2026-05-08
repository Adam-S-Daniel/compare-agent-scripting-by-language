#!/usr/bin/env bash
# bump_version.sh — semantic-version bumper driven by conventional-commit logs.
#
# This tool is split into small subcommands so each piece is independently
# testable: detect-bump, next-version, read-version, write-version, changelog,
# bump (the end-to-end glue). The `bump` subcommand is what CI usually calls;
# the rest exist so the bats suite can exercise pure functions without the
# end-to-end coupling.
#
# The version file may be either a plain text file containing only the version
# string or a package.json with a "version" field. We avoid pulling in jq or
# node so the script stays portable to minimal CI containers.

set -euo pipefail

# Print a one-line error to stderr and exit non-zero. Centralised so the
# subcommands all surface failures the same way.
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage:
  bump_version.sh detect-bump   <commits-file>
  bump_version.sh next-version  <current-version> <bump-type>
  bump_version.sh read-version  <version-file>
  bump_version.sh write-version <version-file> <new-version>
  bump_version.sh changelog     <new-version> <commits-file>
  bump_version.sh bump          <version-file> <commits-file> <changelog-file>

Bump types: major, minor, patch, none.
USAGE
}

# ---------------------------------------------------------------------------
# detect_bump: read a commit log and decide the highest bump level present.
#
# Conventional-commit conventions we honour:
#   - "feat:"  => minor
#   - "fix:"   => patch
#   - "<type>!:" or a "BREAKING CHANGE" line => major
# Anything else (chore, docs, refactor, test, ci, ...) is ignored for the
# bump-level decision but is still allowed in the log.
# ---------------------------------------------------------------------------
detect_bump() {
    local file="${1:-}"
    [ -n "$file" ] || die "detect-bump: missing commits file argument"
    [ -f "$file" ] || die "commits file not found: $file"

    # Store regexes in variables: bash's [[ =~ ]] is sensitive to certain
    # literal characters (parentheses, !) inside the pattern; using a variable
    # is the portable workaround.
    local re_breaking_bang='^[a-zA-Z]+(\([^)]*\))?!:'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'

    local has_major=0 has_minor=0 has_patch=0
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == *"BREAKING CHANGE"* ]]; then
            has_major=1
            continue
        fi
        if [[ "$line" =~ $re_breaking_bang ]]; then
            has_major=1
            continue
        fi
        if [[ "$line" =~ $re_feat ]]; then
            has_minor=1
            continue
        fi
        if [[ "$line" =~ $re_fix ]]; then
            has_patch=1
            continue
        fi
    done < "$file"

    if [ "$has_major" -eq 1 ]; then
        echo "major"
    elif [ "$has_minor" -eq 1 ]; then
        echo "minor"
    elif [ "$has_patch" -eq 1 ]; then
        echo "patch"
    else
        echo "none"
    fi
}

# ---------------------------------------------------------------------------
# next_version: pure semver arithmetic. No file I/O.
# ---------------------------------------------------------------------------
next_version() {
    local current="${1:-}"
    local bump="${2:-}"
    [ -n "$current" ] || die "next-version: missing current version"
    [ -n "$bump" ] || die "next-version: missing bump type"

    # Strict X.Y.Z (no pre-release/build metadata — keep it simple).
    if ! [[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        die "invalid semver: $current"
    fi
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    local patch="${BASH_REMATCH[3]}"

    case "$bump" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        none)  : ;;  # no-op: caller wants current version echoed back
        *) die "unknown bump type: $bump" ;;
    esac

    printf '%d.%d.%d\n' "$major" "$minor" "$patch"
}

# ---------------------------------------------------------------------------
# read_version: plain VERSION file or package.json (auto-detected by name).
# ---------------------------------------------------------------------------
read_version() {
    local file="${1:-}"
    [ -n "$file" ] || die "read-version: missing version file argument"
    [ -f "$file" ] || die "version file not found: $file"

    if [[ "$(basename "$file")" == "package.json" ]]; then
        # Grab the first "version": "X.Y.Z" line. We avoid jq dependency.
        local v
        v=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)
        [ -n "$v" ] || die "no version field in $file"
        echo "$v"
    else
        # Trim leading/trailing whitespace and a leading "v" if present.
        local v
        v=$(tr -d '[:space:]' < "$file")
        v="${v#v}"
        [ -n "$v" ] || die "version file is empty: $file"
        echo "$v"
    fi
}

# ---------------------------------------------------------------------------
# write_version: write back a new version, matching the input format.
# For package.json we replace just the version field rather than rewriting
# the whole file, so other fields and formatting survive untouched.
# ---------------------------------------------------------------------------
write_version() {
    local file="${1:-}"
    local new="${2:-}"
    [ -n "$file" ] || die "write-version: missing version file"
    [ -n "$new" ] || die "write-version: missing new version"
    [ -f "$file" ] || die "version file not found: $file"

    if [[ "$(basename "$file")" == "package.json" ]]; then
        # Use a temp file so a partial write can't corrupt the input.
        local tmp
        tmp=$(mktemp)
        sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1${new}\2/" \
            "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        printf '%s\n' "$new" > "$file"
    fi
}

# ---------------------------------------------------------------------------
# changelog: render a new changelog section for the given version. Prints to
# stdout — callers decide whether to append to a file.
# ---------------------------------------------------------------------------
changelog() {
    local version="${1:-}"
    local file="${2:-}"
    [ -n "$version" ] || die "changelog: missing version argument"
    [ -n "$file" ] || die "changelog: missing commits file"
    [ -f "$file" ] || die "commits file not found: $file"

    # Same regex-in-variable workaround as detect_bump.
    local re_bang='^([a-zA-Z]+)(\([^)]*\))?!:[[:space:]]*(.*)$'
    local re_feat='^feat(\([^)]*\))?:[[:space:]]*(.*)$'
    local re_fix='^fix(\([^)]*\))?:[[:space:]]*(.*)$'

    local breaking=() features=() fixes=()
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        if [[ "$line" == *"BREAKING CHANGE"* ]]; then
            # Strip the leading "BREAKING CHANGE:" if present.
            breaking+=("${line#BREAKING CHANGE: }")
            continue
        fi
        if [[ "$line" =~ $re_bang ]]; then
            breaking+=("${BASH_REMATCH[3]}")
            continue
        fi
        if [[ "$line" =~ $re_feat ]]; then
            features+=("${BASH_REMATCH[2]}")
            continue
        fi
        if [[ "$line" =~ $re_fix ]]; then
            fixes+=("${BASH_REMATCH[2]}")
            continue
        fi
        # Anything else (chore/docs/etc) is intentionally dropped from the
        # changelog body — those don't represent user-visible change.
    done < "$file"

    local date_str
    date_str=$(date -u +%Y-%m-%d)
    printf '## %s - %s\n\n' "$version" "$date_str"

    if [ ${#breaking[@]} -gt 0 ]; then
        printf '### Breaking Changes\n'
        local item
        for item in "${breaking[@]}"; do
            printf -- '- %s\n' "$item"
        done
        printf '\n'
    fi
    if [ ${#features[@]} -gt 0 ]; then
        printf '### Features\n'
        local item
        for item in "${features[@]}"; do
            printf -- '- %s\n' "$item"
        done
        printf '\n'
    fi
    if [ ${#fixes[@]} -gt 0 ]; then
        printf '### Fixes\n'
        local item
        for item in "${fixes[@]}"; do
            printf -- '- %s\n' "$item"
        done
        printf '\n'
    fi
}

# ---------------------------------------------------------------------------
# bump: glue. Reads version, decides bump, writes version, prepends changelog
# entry. Echoes the new version on stdout (so CI can capture it).
# ---------------------------------------------------------------------------
bump() {
    local version_file="${1:-}"
    local commits_file="${2:-}"
    local changelog_file="${3:-}"
    [ -n "$version_file" ] || die "bump: missing version file"
    [ -n "$commits_file" ] || die "bump: missing commits file"
    [ -n "$changelog_file" ] || die "bump: missing changelog file"

    local current bump_type new
    current=$(read_version "$version_file")
    bump_type=$(detect_bump "$commits_file")
    new=$(next_version "$current" "$bump_type")

    if [ "$bump_type" = "none" ]; then
        # Nothing to bump — keep version, leave changelog alone.
        echo "$new"
        return 0
    fi

    write_version "$version_file" "$new"

    # Build the new changelog section. If a CHANGELOG already exists, prepend
    # the new section above the prior content (after any leading "# Changelog"
    # heading the user keeps at the top).
    local section
    section=$(changelog "$new" "$commits_file")

    if [ -f "$changelog_file" ]; then
        local tmp
        tmp=$(mktemp)
        # If the file starts with a "# Changelog" heading, keep it on top.
        local first_line
        first_line=$(head -n1 "$changelog_file")
        if [[ "$first_line" =~ ^#[[:space:]] ]]; then
            {
                printf '%s\n\n' "$first_line"
                printf '%s\n' "$section"
                tail -n +2 "$changelog_file"
            } > "$tmp"
        else
            {
                printf '%s\n' "$section"
                cat "$changelog_file"
            } > "$tmp"
        fi
        mv "$tmp" "$changelog_file"
    else
        {
            printf '# Changelog\n\n'
            printf '%s\n' "$section"
        } > "$changelog_file"
    fi

    echo "$new"
}

# ---------------------------------------------------------------------------
# main: dispatch on first positional arg.
# ---------------------------------------------------------------------------
main() {
    if [ $# -lt 1 ]; then
        usage >&2
        exit 1
    fi
    local cmd="$1"; shift
    case "$cmd" in
        detect-bump)   detect_bump "$@" ;;
        next-version)  next_version "$@" ;;
        read-version)  read_version "$@" ;;
        write-version) write_version "$@" ;;
        changelog)     changelog "$@" ;;
        bump)          bump "$@" ;;
        -h|--help|help) usage ;;
        *) usage >&2; die "unknown subcommand: $cmd" ;;
    esac
}

main "$@"
