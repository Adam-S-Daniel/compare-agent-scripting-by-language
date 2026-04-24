#!/usr/bin/env bash
# Semantic Version Bumper
# Reads a version file (version.json or package.json), determines the next
# version based on conventional commit messages, updates the file, and
# optionally generates a CHANGELOG entry.
#
# Conventional commit → bump rules:
#   BREAKING CHANGE or feat! or fix!  → major
#   feat                               → minor
#   fix                                → patch
#   anything else                      → no bump
#
# Usage:
#   version_bumper.sh --file FILE --commits FILE [--changelog FILE] [--dry-run]

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────
VERSION_FILE=""
COMMITS_FILE=""
CHANGELOG_FILE=""
DRY_RUN=false

usage() {
    echo "Usage: $0 --file VERSION_FILE --commits COMMITS_FILE [--changelog CHANGELOG_FILE] [--dry-run]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)      VERSION_FILE="$2";    shift 2 ;;
        --commits)   COMMITS_FILE="$2";   shift 2 ;;
        --changelog) CHANGELOG_FILE="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=true;        shift   ;;
        *) echo "Error: unknown option '$1'" >&2; usage ;;
    esac
done

[[ -n "$VERSION_FILE"  ]] || { echo "Error: --file is required"    >&2; exit 1; }
[[ -n "$COMMITS_FILE"  ]] || { echo "Error: --commits is required"  >&2; exit 1; }

# ── Validate inputs exist ─────────────────────────────────────────────────
[[ -f "$VERSION_FILE"  ]] || { echo "Error: version file not found: $VERSION_FILE"  >&2; exit 1; }
[[ -f "$COMMITS_FILE"  ]] || { echo "Error: commits file not found: $COMMITS_FILE"  >&2; exit 1; }

# ── Parse current version from JSON ──────────────────────────────────────
# Works for both version.json {"version":"x.y.z"} and package.json
parse_version() {
    local file="$1"
    # Extract the value of "version" key — handles spaces around colon/quotes
    grep -oP '"version"\s*:\s*"\K[^"]+' "$file" || true
}

CURRENT_VERSION="$(parse_version "$VERSION_FILE")"

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "Error: could not find \"version\" field in $VERSION_FILE" >&2
    exit 1
fi

# Validate semver format (major.minor.patch, digits only for each component)
if ! [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid semver '$CURRENT_VERSION' in $VERSION_FILE" >&2
    exit 1
fi

echo "current version: $CURRENT_VERSION"

# ── Split semver components ───────────────────────────────────────────────
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# ── Analyse commits to determine bump level ───────────────────────────────
# bump_level: 0=none, 1=patch, 2=minor, 3=major
bump_level=0

# Store regexes in variables to avoid bash parsing issues with ')' inside [[ ]]
re_breaking_footer='^BREAKING[[:space:]]CHANGE'
re_breaking_bang='^[a-z]+(\([^)]*\))?!:'
re_feat='^feat(\([^)]*\))?:'
re_fix='^fix(\([^)]*\))?:'

while IFS= read -r line || [[ -n "$line" ]]; do
    # BREAKING CHANGE footer or ! suffix → major
    if [[ "$line" =~ $re_breaking_footer ]] || \
       [[ "$line" =~ $re_breaking_bang ]]; then
        bump_level=3
        break   # can't go higher
    fi

    # feat → minor (but only upgrade, never downgrade)
    if [[ "$line" =~ $re_feat ]] && [[ $bump_level -lt 2 ]]; then
        bump_level=2
    fi

    # fix → patch
    if [[ "$line" =~ $re_fix ]] && [[ $bump_level -lt 1 ]]; then
        bump_level=1
    fi
done < "$COMMITS_FILE"

# ── Compute new version ───────────────────────────────────────────────────
case $bump_level in
    3) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
    2) NEW_VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
    1) NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
    *) NEW_VERSION="$CURRENT_VERSION" ;;
esac

echo "new version: $NEW_VERSION"

# ── Update version file (unless --dry-run) ────────────────────────────────
if ! $DRY_RUN; then
    # Use sed to replace the version value in-place
    sed -i "s/\"version\": \"${CURRENT_VERSION}\"/\"version\": \"${NEW_VERSION}\"/" "$VERSION_FILE"
fi

# ── Generate changelog entry ──────────────────────────────────────────────
if [[ -n "$CHANGELOG_FILE" ]] && ! $DRY_RUN; then
    DATE="$(date +%Y-%m-%d)"
    {
        echo "## [${NEW_VERSION}] - ${DATE}"
        echo ""
        # List each conventional commit line as a bullet
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            echo "- ${line}"
        done < "$COMMITS_FILE"
        echo ""
    } > /tmp/new_changelog_entry.$$

    if [[ -f "$CHANGELOG_FILE" ]]; then
        # Prepend new entry to existing changelog
        cat /tmp/new_changelog_entry.$$ "$CHANGELOG_FILE" > /tmp/changelog_merged.$$
        mv /tmp/changelog_merged.$$ "$CHANGELOG_FILE"
    else
        mv /tmp/new_changelog_entry.$$ "$CHANGELOG_FILE"
    fi
    rm -f /tmp/new_changelog_entry.$$
fi

# ── Final output: new version on its own line (for machine consumption) ───
echo "$NEW_VERSION"
