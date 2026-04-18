#!/usr/bin/env bash
# bump-version.sh - Semantic Version Bumper
#
# Reads a semver version from a VERSION file or package.json, inspects a
# conventional-commit log, determines the next version, rewrites the file,
# and emits a changelog entry.
#
# Usage:
#   bump-version.sh bump_type [<single-commit-message>]   # no arg -> stdin
#   bump-version.sh bump_version <semver> <patch|minor|major|none>
#   bump-version.sh read_version  <file>
#   bump-version.sh write_version <file> <new-semver>
#   bump-version.sh changelog     <new-semver> [<single-commit-message>]
#   bump-version.sh run --version-file <file> --commits <log> --changelog <out>
#
# Commit log file format (for `run`):
#   One commit per line. Subjects use the usual conventional-commit shape
#   `type(scope)?!?: description`. Multi-line bodies with `BREAKING CHANGE:`
#   footers are supported when passed as a single argument to `bump_type` or
#   `changelog`, but commit-log files are line-oriented for simplicity.

set -euo pipefail

SEMVER_RE='^([0-9]+)\.([0-9]+)\.([0-9]+)$'

die() {
    # Emit to stdout so `run ...` in bats captures it, and to stderr for humans.
    printf '%s\n' "$*"
    printf '%s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Determine the bump precedence for a single commit message.
# Precedence: breaking(3) > feat(2) > fix(1) > none(0). Higher wins.
# ---------------------------------------------------------------------------
_commit_precedence() {
    local msg="$1"
    local subject="${msg%%$'\n'*}"

    # BREAKING CHANGE footer anywhere in the message = major.
    if printf '%s\n' "$msg" | grep -qE '^BREAKING CHANGE:'; then
        echo 3; return
    fi

    local re_breaking='^[a-zA-Z]+(\([^)]+\))?!:'
    local re_feat='^feat(\([^)]+\))?:'
    local re_fix='^fix(\([^)]+\))?:'
    if [[ "$subject" =~ $re_breaking ]]; then echo 3; return; fi
    if [[ "$subject" =~ $re_feat     ]]; then echo 2; return; fi
    if [[ "$subject" =~ $re_fix      ]]; then echo 1; return; fi
    echo 0
}

_precedence_to_type() {
    case "$1" in
        3) echo major ;;
        2) echo minor ;;
        1) echo patch ;;
        *) echo none  ;;
    esac
}

# ---------------------------------------------------------------------------
# bump_type: determine highest-precedence bump.
# With no arg: reads one commit subject per line from stdin.
# With an arg: treats the arg as a single (possibly multi-line) commit message.
# ---------------------------------------------------------------------------
cmd_bump_type() {
    local highest=0 prec
    if [ "$#" -gt 0 ]; then
        prec="$(_commit_precedence "$1")"
        [ "$prec" -gt "$highest" ] && highest="$prec"
    else
        local line
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            prec="$(_commit_precedence "$line")"
            [ "$prec" -gt "$highest" ] && highest="$prec"
        done
    fi
    _precedence_to_type "$highest"
}

# ---------------------------------------------------------------------------
# bump_version: apply a bump type to a semver string.
# ---------------------------------------------------------------------------
cmd_bump_version() {
    local version="${1-}"
    local bump="${2-}"

    if [[ ! "$version" =~ $SEMVER_RE ]]; then
        die "invalid semver: $version"
    fi
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    local patch="${BASH_REMATCH[3]}"

    case "$bump" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
        none)  echo "${major}.${minor}.${patch}" ;;
        *)     die "unknown bump type: $bump" ;;
    esac
}

# ---------------------------------------------------------------------------
# read_version: read from plain file or package.json. No jq dependency.
# ---------------------------------------------------------------------------
cmd_read_version() {
    local file="${1-}"
    [ -f "$file" ] || die "version file not found: $file"

    if [[ "$file" == *package.json ]]; then
        local v
        v="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
        [ -n "$v" ] || die "no version field in $file"
        echo "$v"
    else
        local v
        v="$(tr -d '[:space:]' < "$file")"
        [ -n "$v" ] || die "empty version file: $file"
        echo "$v"
    fi
}

# ---------------------------------------------------------------------------
# write_version: write new semver back preserving file format.
# ---------------------------------------------------------------------------
cmd_write_version() {
    local file="${1-}"
    local new="${2-}"
    [ -f "$file" ] || die "version file not found: $file"
    [[ "$new" =~ $SEMVER_RE ]] || die "invalid semver: $new"

    if [[ "$file" == *package.json ]]; then
        local tmp
        tmp="$(mktemp)"
        awk -v new="$new" '
            BEGIN { replaced = 0 }
            {
                if (!replaced && match($0, /"version"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
                    sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" new "\"")
                    replaced = 1
                }
                print
            }
        ' "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        printf '%s\n' "$new" > "$file"
    fi
}

# ---------------------------------------------------------------------------
# Build arrays of feat/fix/breaking entries for a stream of commit subjects.
# Reads one commit subject (or single multi-line commit) at a time.
# Uses nameref variables so we can append to the caller's arrays.
# ---------------------------------------------------------------------------
_classify_commit() {
    local msg="$1"
    local -n _feats="$2"
    local -n _fixes="$3"
    local -n _breaks="$4"

    local subject="${msg%%$'\n'*}"
    local body=""
    if [[ "$msg" == *$'\n'* ]]; then
        body="${msg#*$'\n'}"
    fi

    # BREAKING CHANGE footer contributes to the BREAKING section using its text.
    if printf '%s\n' "$body" | grep -qE '^BREAKING CHANGE:'; then
        local bc
        bc="$(printf '%s\n' "$body" | sed -n 's/^BREAKING CHANGE:[[:space:]]*//p' | head -n1)"
        [ -n "$bc" ] && _breaks+=("$bc")
    fi

    local re_subject='^([a-zA-Z]+)(\([^)]+\))?(!)?:[[:space:]]*(.*)$'
    if [[ "$subject" =~ $re_subject ]]; then
        local type="${BASH_REMATCH[1]}"
        local bang="${BASH_REMATCH[3]}"
        local desc="${BASH_REMATCH[4]}"
        [ "$bang" = "!" ] && _breaks+=("$desc")
        case "$type" in
            feat) _feats+=("$desc") ;;
            fix)  _fixes+=("$desc") ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# changelog: emit a markdown entry for the new version.
# ---------------------------------------------------------------------------
cmd_changelog() {
    local new_version="${1-}"; shift || true
    local feats=() fixes=() breaks=()

    if [ "$#" -gt 0 ]; then
        _classify_commit "$1" feats fixes breaks
    else
        local line
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            _classify_commit "$line" feats fixes breaks
        done
    fi

    local today
    today="$(date -u +%Y-%m-%d)"
    printf '## %s - %s\n\n' "$new_version" "$today"

    if [ "${#breaks[@]}" -gt 0 ]; then
        printf '### BREAKING CHANGES\n\n'
        local b
        for b in "${breaks[@]}"; do printf -- '- %s\n' "$b"; done
        printf '\n'
    fi
    if [ "${#feats[@]}" -gt 0 ]; then
        printf '### Features\n\n'
        local f
        for f in "${feats[@]}"; do printf -- '- %s\n' "$f"; done
        printf '\n'
    fi
    if [ "${#fixes[@]}" -gt 0 ]; then
        printf '### Bug Fixes\n\n'
        local x
        for x in "${fixes[@]}"; do printf -- '- %s\n' "$x"; done
        printf '\n'
    fi
}

# ---------------------------------------------------------------------------
# run: end-to-end pipeline. Reads/decides/writes/changelogs/prints.
# ---------------------------------------------------------------------------
cmd_run() {
    local version_file="" commits_file="" changelog_file=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --version-file) version_file="$2"; shift 2 ;;
            --commits)      commits_file="$2"; shift 2 ;;
            --changelog)    changelog_file="$2"; shift 2 ;;
            *) die "unknown flag: $1" ;;
        esac
    done

    [ -n "$version_file" ]   || die "missing --version-file"
    [ -n "$commits_file" ]   || die "missing --commits"
    [ -n "$changelog_file" ] || die "missing --changelog"
    [ -f "$commits_file" ]   || die "commits file not found: $commits_file"

    local current
    current="$(cmd_read_version "$version_file")"

    local bump
    bump="$(cmd_bump_type < "$commits_file")"

    local new
    new="$(cmd_bump_version "$current" "$bump")"

    if [ "$new" != "$current" ]; then
        cmd_write_version "$version_file" "$new"

        local entry
        entry="$(cmd_changelog "$new" < "$commits_file")"

        if [ -f "$changelog_file" ]; then
            local tmp
            tmp="$(mktemp)"
            { printf '%s\n' "$entry"; cat "$changelog_file"; } > "$tmp"
            mv "$tmp" "$changelog_file"
        else
            printf '%s\n' "$entry" > "$changelog_file"
        fi
    fi

    echo "$new"
}

main() {
    local cmd="${1-}"
    shift || true
    case "$cmd" in
        bump_type)     cmd_bump_type    "$@" ;;
        bump_version)  cmd_bump_version "$@" ;;
        read_version)  cmd_read_version "$@" ;;
        write_version) cmd_write_version "$@" ;;
        changelog)     cmd_changelog    "$@" ;;
        run)           cmd_run          "$@" ;;
        ""|-h|--help)
            sed -n '2,20p' "$0"
            ;;
        *) die "unknown subcommand: $cmd" ;;
    esac
}

main "$@"
