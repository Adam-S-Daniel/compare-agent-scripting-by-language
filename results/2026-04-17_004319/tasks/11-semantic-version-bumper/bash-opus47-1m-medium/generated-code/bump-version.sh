#!/usr/bin/env bash
#
# Semantic version bumper driven by conventional commit messages.
#
# Reads a semver string from VERSION (or package.json's "version" field),
# classifies each commit in $COMMITS_FILE (or `git log` output) as
# major/minor/patch per the conventional-commits spec, writes the bumped
# version back, appends a CHANGELOG.md entry, and prints NEW_VERSION=X.Y.Z
# to stdout for downstream CI consumption.
#
# Bump precedence: BREAKING > feat > fix. Non-matching commits are ignored
# (no bump if nothing qualifies).

set -euo pipefail

VERSION_FILE="${VERSION_FILE:-VERSION}"
COMMITS_FILE="${COMMITS_FILE:-commits.txt}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"

die() { echo "error: $*" >&2; exit 1; }

# Extract current version from VERSION file or package.json.
read_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        tr -d '[:space:]' < "$VERSION_FILE"
    elif [[ -f package.json ]]; then
        # Grep the "version": "x.y.z" line — avoids a jq dependency.
        sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            package.json | head -n1
    else
        die "no VERSION file or package.json found"
    fi
}

# Validate x.y.z form and split into the BUMP_MAJOR/MINOR/PATCH globals.
parse_semver() {
    local v="$1"
    [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] \
        || die "invalid semver: '$v' (expected MAJOR.MINOR.PATCH)"
    BUMP_MAJOR="${BASH_REMATCH[1]}"
    BUMP_MINOR="${BASH_REMATCH[2]}"
    BUMP_PATCH="${BASH_REMATCH[3]}"
}

# Walk commit lines and set BUMP_KIND to the highest-precedence change seen.
classify_commits() {
    local src="$1" line
    # Using variables dodges shellcheck's parser choking on "!:" literals.
    local breaking_re='^(feat|fix|chore|docs|refactor|perf|test|build|ci|style)(\([^)]*\))?!:'
    local feat_re='^feat(\([^)]*\))?:'
    local fix_re='^fix(\([^)]*\))?:'
    BUMP_KIND="none"
    while IFS= read -r line; do
        # "!" after type/scope OR a "BREAKING CHANGE:" footer => major.
        if [[ "$line" =~ $breaking_re ]] \
           || [[ "$line" == *"BREAKING CHANGE:"* ]]; then
            BUMP_KIND="major"
            return
        fi
        if [[ "$line" =~ $feat_re ]]; then
            # Bare && trips `set -e` when the LHS is false; use if/fi instead.
            if [[ "$BUMP_KIND" == "none" || "$BUMP_KIND" == "patch" ]]; then
                BUMP_KIND="minor"
            fi
        elif [[ "$line" =~ $fix_re ]]; then
            if [[ "$BUMP_KIND" == "none" ]]; then
                BUMP_KIND="patch"
            fi
        fi
    done < "$src"
}

apply_bump() {
    case "$BUMP_KIND" in
        major) BUMP_MAJOR=$((BUMP_MAJOR + 1)); BUMP_MINOR=0; BUMP_PATCH=0 ;;
        minor) BUMP_MINOR=$((BUMP_MINOR + 1)); BUMP_PATCH=0 ;;
        patch) BUMP_PATCH=$((BUMP_PATCH + 1)) ;;
        none)  ;;  # Leave version untouched.
        *)     die "internal: bad bump kind '$BUMP_KIND'" ;;
    esac
    NEW_VERSION="${BUMP_MAJOR}.${BUMP_MINOR}.${BUMP_PATCH}"
}

write_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        printf '%s\n' "$NEW_VERSION" > "$VERSION_FILE"
    elif [[ -f package.json ]]; then
        # In-place rewrite of the first "version": "..." occurrence.
        sed -i.bak "0,/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/s//\"version\": \"${NEW_VERSION}\"/" \
            package.json
        rm -f package.json.bak
    fi
}

write_changelog() {
    local src="$1" tmp
    tmp="$(mktemp)"
    {
        printf '## %s - %s\n\n' "$NEW_VERSION" "$(date -u +%Y-%m-%d)"
        # Emit headed sections only when the relevant commits exist.
        if grep -qE '(^feat|BREAKING CHANGE:)' "$src" \
           && grep -qE '!:|BREAKING CHANGE:' "$src"; then
            printf '### BREAKING CHANGES\n\n'
            grep -E '!:|BREAKING CHANGE:' "$src" | sed 's/^/- /'
            printf '\n'
        fi
        if grep -qE '^feat(\([^)]*\))?!?:' "$src"; then
            printf '### Features\n\n'
            grep -E '^feat(\([^)]*\))?!?:' "$src" | sed 's/^/- /'
            printf '\n'
        fi
        if grep -qE '^fix(\([^)]*\))?!?:' "$src"; then
            printf '### Bug Fixes\n\n'
            grep -E '^fix(\([^)]*\))?!?:' "$src" | sed 's/^/- /'
            printf '\n'
        fi
    } > "$tmp"
    # Prepend new entry to existing changelog (or create fresh).
    if [[ -f "$CHANGELOG_FILE" ]]; then
        cat "$CHANGELOG_FILE" >> "$tmp"
    fi
    mv "$tmp" "$CHANGELOG_FILE"
}

main() {
    local current commit_src
    current="$(read_current_version)"
    parse_semver "$current"

    # Prefer the fixture file when present (easier for CI/tests); otherwise
    # fall back to real git log subject lines since the last tag.
    if [[ -f "$COMMITS_FILE" ]]; then
        commit_src="$COMMITS_FILE"
    else
        commit_src="$(mktemp)"
        local range="HEAD"
        if git describe --tags --abbrev=0 >/dev/null 2>&1; then
            range="$(git describe --tags --abbrev=0)..HEAD"
        fi
        git log --pretty=%B "$range" > "$commit_src" 2>/dev/null || true
    fi

    classify_commits "$commit_src"
    apply_bump
    write_version
    write_changelog "$commit_src"

    echo "NEW_VERSION=${NEW_VERSION}"
    echo "BUMP_KIND=${BUMP_KIND}"
}

main "$@"
