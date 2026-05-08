#!/usr/bin/env bash
#
# Semantic version bumper.
#
# Reads a version from VERSION or package.json, scans a commit log file for
# Conventional Commit prefixes, picks the next semver, writes the file back,
# and prepends a changelog entry. Designed to be invoked piecewise (read,
# detect, next, write, changelog) so each behavior can be unit-tested in
# isolation, and as a single `bump` command for end-to-end use in CI.
#
# Subcommands:
#   read     <file>                  -> prints current version
#   detect   <commits-file>          -> prints major|minor|patch|none
#   next     <ver> <bump>            -> prints the bumped version
#   write    <file> <new-ver>        -> writes new version into file
#   changelog <commits-file> <ver>   -> prints a markdown changelog entry
#   bump     <version-file> <commits> <changelog>
#                                    -> does the whole pipeline; prints
#                                       the new version on stdout

set -euo pipefail

# -- helpers ----------------------------------------------------------------

# Print a message to stderr and exit non-zero. Centralized so error format
# stays consistent.
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: bump-version.sh <command> [args...]

Commands:
  read <file>
  detect <commits-file>
  next <version> <bump-kind>
  write <file> <new-version>
  changelog <commits-file> <version>
  bump <version-file> <commits-file> <changelog-file>
EOF
}

# Validate that a string looks like X.Y.Z. Used so we fail fast when given a
# corrupted version file rather than silently propagating garbage.
is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# -- read_version -----------------------------------------------------------

# read_version <file>
#
# If the file looks like JSON (ends in .json) we extract the "version" key;
# otherwise we treat the file as a plain version string. Using a regex match
# instead of jq keeps the script dependency-free.
read_version() {
    local file="$1"
    [[ -f "$file" ]] || die "version file not found: $file"

    local version=""
    if [[ "$file" == *.json ]]; then
        # Pull the first "version": "X.Y.Z" pair we find.
        version="$(grep -Eo '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$file" \
            | head -n 1 \
            | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    else
        version="$(tr -d '[:space:]' < "$file")"
    fi

    if ! is_semver "$version"; then
        die "could not parse version from $file"
    fi
    printf '%s\n' "$version"
}

# -- detect_bump ------------------------------------------------------------

# detect_bump <commits-file>
#
# We only need to know the strongest signal in the file: a breaking change
# wins over a feat, which wins over a fix. Other Conventional Commit types
# (chore/docs/style/refactor/test/perf/build/ci/...) do not by themselves
# bump a version under our policy.
detect_bump() {
    local file="$1"
    [[ -f "$file" ]] || die "commits file not found: $file"

    # bash's [[ =~ ]] requires regexes with parens to live in a variable.
    local re_breaking_bang='^[a-zA-Z]+(\([^)]*\))?!:'
    local re_breaking_foot='^BREAKING[[:space:]_-]CHANGE:'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'

    local saw_major=0 saw_minor=0 saw_patch=0
    while IFS= read -r line; do
        if [[ "$line" =~ $re_breaking_bang ]]; then
            saw_major=1
        elif [[ "$line" =~ $re_breaking_foot ]]; then
            saw_major=1
        elif [[ "$line" =~ $re_feat ]]; then
            saw_minor=1
        elif [[ "$line" =~ $re_fix ]]; then
            saw_patch=1
        fi
    done < "$file"

    if (( saw_major )); then
        echo "major"
    elif (( saw_minor )); then
        echo "minor"
    elif (( saw_patch )); then
        echo "patch"
    else
        echo "none"
    fi
}

# -- next_version -----------------------------------------------------------

# next_version <X.Y.Z> <major|minor|patch|none>
next_version() {
    local current="$1" kind="$2"
    is_semver "$current" || die "not a semver: $current"

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"

    case "$kind" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        none)  : ;;  # unchanged
        *)     die "unknown bump kind: $kind" ;;
    esac

    printf '%d.%d.%d\n' "$major" "$minor" "$patch"
}

# -- write_version ----------------------------------------------------------

# write_version <file> <new-version>
#
# Updates the file in place. For JSON we replace just the "version" field
# (preserving every other key and its formatting). For plain VERSION files
# we overwrite the whole content.
write_version() {
    local file="$1" new="$2"
    [[ -f "$file" ]] || die "version file not found: $file"
    is_semver "$new" || die "not a semver: $new"

    if [[ "$file" == *.json ]]; then
        # Use a temp file so a failed sed does not truncate the original.
        local tmp
        tmp="$(mktemp)"
        sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]+(\")/\1${new}\2/" \
            "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        printf '%s\n' "$new" > "$file"
    fi
}

# -- changelog --------------------------------------------------------------

# changelog <commits-file> <version>
#
# Prints (does not write) a markdown block grouping commits under
# ### Features / ### Fixes / ### Breaking Changes.
changelog() {
    local file="$1" version="$2"
    [[ -f "$file" ]] || die "commits file not found: $file"

    # Collect three category buckets. Use temp files instead of arrays so
    # we play well with `set -u` even when a category ends up empty.
    local feats fixes breaks
    feats="$(mktemp)"; fixes="$(mktemp)"; breaks="$(mktemp)"
    # shellcheck disable=SC2064  # expand variables now, not on trap
    trap "rm -f '$feats' '$fixes' '$breaks'" RETURN

    local re_break_bang='^([a-zA-Z]+)(\([^)]*\))?!:[[:space:]]*(.*)$'
    local re_break_foot='^BREAKING[[:space:]_-]CHANGE:[[:space:]]*(.*)$'
    local re_feat_full='^feat(\([^)]*\))?:[[:space:]]*(.*)$'
    local re_fix_full='^fix(\([^)]*\))?:[[:space:]]*(.*)$'

    while IFS= read -r line; do
        if [[ "$line" =~ $re_break_bang ]]; then
            printf -- '- %s\n' "${BASH_REMATCH[3]}" >> "$breaks"
        elif [[ "$line" =~ $re_break_foot ]]; then
            printf -- '- %s\n' "${BASH_REMATCH[1]}" >> "$breaks"
        elif [[ "$line" =~ $re_feat_full ]]; then
            printf -- '- %s\n' "${BASH_REMATCH[2]}" >> "$feats"
        elif [[ "$line" =~ $re_fix_full ]]; then
            printf -- '- %s\n' "${BASH_REMATCH[2]}" >> "$fixes"
        fi
    done < "$file"

    printf '## %s\n\n' "$version"
    if [[ -s "$breaks" ]]; then
        printf '### Breaking Changes\n'
        cat "$breaks"
        printf '\n'
    fi
    if [[ -s "$feats" ]]; then
        printf '### Features\n'
        cat "$feats"
        printf '\n'
    fi
    if [[ -s "$fixes" ]]; then
        printf '### Fixes\n'
        cat "$fixes"
        printf '\n'
    fi
}

# -- bump (full pipeline) ---------------------------------------------------

# bump <version-file> <commits-file> <changelog-file>
#
# Returns non-zero (without modifying files) when no commits warrant a bump.
# Prepends the new entry to the changelog so the most recent release is at
# the top, which is the typical convention.
bump_all() {
    local version_file="$1" commits_file="$2" changelog_file="$3"
    [[ -f "$version_file" ]]  || die "version file not found: $version_file"
    [[ -f "$commits_file" ]]  || die "commits file not found: $commits_file"

    local current
    current="$(read_version "$version_file")"

    local kind
    kind="$(detect_bump "$commits_file")"
    if [[ "$kind" == "none" ]]; then
        die "no version-affecting commits found in $commits_file"
    fi

    local new
    new="$(next_version "$current" "$kind")"

    write_version "$version_file" "$new"

    local entry
    entry="$(changelog "$commits_file" "$new")"

    # Prepend, preserving any prior changelog body underneath.
    local tmp
    tmp="$(mktemp)"
    {
        printf '%s\n' "$entry"
        if [[ -f "$changelog_file" ]]; then
            cat "$changelog_file"
        fi
    } > "$tmp"
    mv "$tmp" "$changelog_file"

    printf '%s\n' "$new"
}

# -- dispatch ---------------------------------------------------------------

main() {
    if [[ $# -eq 0 ]]; then
        usage >&2
        exit 1
    fi

    local cmd="$1"; shift
    case "$cmd" in
        read)      [[ $# -eq 1 ]] || die "read: expected <file>"
                   read_version "$1" ;;
        detect)    [[ $# -eq 1 ]] || die "detect: expected <commits-file>"
                   detect_bump "$1" ;;
        next)      [[ $# -eq 2 ]] || die "next: expected <version> <kind>"
                   next_version "$1" "$2" ;;
        write)     [[ $# -eq 2 ]] || die "write: expected <file> <new-version>"
                   write_version "$1" "$2" ;;
        changelog) [[ $# -eq 2 ]] || die "changelog: expected <commits-file> <version>"
                   changelog "$1" "$2" ;;
        bump)      [[ $# -eq 3 ]] || die "bump: expected <version-file> <commits-file> <changelog-file>"
                   bump_all "$1" "$2" "$3" ;;
        -h|--help|help) usage ;;
        *)         usage >&2; exit 1 ;;
    esac
}

main "$@"
