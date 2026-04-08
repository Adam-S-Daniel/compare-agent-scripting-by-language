#!/usr/bin/env bash
# semver_bump.sh — Semantic version bumper based on conventional commits.
#
# Reads a version from a VERSION file or package.json, analyzes conventional
# commit messages to determine the bump type (major/minor/patch), updates the
# version file, and optionally generates a changelog.
#
# Usage:
#   semver_bump.sh --version-file <path> --commits <path> [--changelog <path>]
#                  [--dry-run] [--quiet]
#
# Options:
#   --version-file  Path to VERSION file or package.json (required)
#   --commits       Path to file containing conventional commit messages (required)
#   --changelog     Path to write changelog (optional)
#   --dry-run       Show what would happen without modifying files
#   --quiet         Output only the new version string (no informational messages)

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

die() {
    echo "Error: $1" >&2
    exit 1
}

info() {
    # Print informational messages unless --quiet is set
    if [[ "$QUIET" != "true" ]]; then
        echo "$1"
    fi
}

usage() {
    die "Usage: semver_bump.sh --version-file <path> --commits <path> [--changelog <path>] [--dry-run] [--quiet]
Required: --version-file and --commits"
}

# ── Argument parsing ─────────────────────────────────────────────────────────

VERSION_FILE=""
COMMITS_FILE=""
CHANGELOG_FILE=""
DRY_RUN="false"
QUIET="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version-file)
            VERSION_FILE="${2:-}"
            shift 2
            ;;
        --commits)
            COMMITS_FILE="${2:-}"
            shift 2
            ;;
        --changelog)
            CHANGELOG_FILE="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --quiet)
            QUIET="true"
            shift
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

# Validate required arguments
[[ -z "$VERSION_FILE" ]] && usage
[[ -z "$COMMITS_FILE" ]] && usage

# ── Parse version from file ──────────────────────────────────────────────────

# Determine file type and extract the semver string
[[ -f "$VERSION_FILE" ]] || die "Version file not found: $VERSION_FILE"

filename="$(basename "$VERSION_FILE")"

if [[ "$filename" == "package.json" ]]; then
    # Extract version from JSON — uses grep + sed to avoid jq dependency
    raw_version="$(grep '"version"' "$VERSION_FILE" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)"
else
    # Plain VERSION file: read the first non-empty line
    raw_version="$(grep -m1 '[0-9]' "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
fi

# Validate semver format (MAJOR.MINOR.PATCH)
if [[ ! "$raw_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "Invalid version format: '${raw_version:-<empty>}'. Expected MAJOR.MINOR.PATCH"
fi

# Split into components
IFS='.' read -r MAJOR MINOR PATCH <<< "$raw_version"
info "Current version: ${MAJOR}.${MINOR}.${PATCH}"

# ── Analyze commits ──────────────────────────────────────────────────────────

# Read commit messages from the log file. Each line is one commit subject,
# optionally followed by blank lines and body text (for footer detection).
[[ -f "$COMMITS_FILE" ]] || die "Commits file not found: $COMMITS_FILE"

commit_content="$(cat "$COMMITS_FILE")"

# Track the highest bump level found: 0=none, 1=patch, 2=minor, 3=major
bump_level=0

# Collect commits by category for changelog
declare -a feat_commits=()
declare -a fix_commits=()
declare -a breaking_commits=()
declare -a other_commits=()

# Check for BREAKING CHANGE footer anywhere in the commit log
if grep -q "^BREAKING CHANGE:" <<< "$commit_content" 2>/dev/null; then
    bump_level=3
fi

# Process each non-empty line that looks like a commit subject
while IFS= read -r line; do
    # Skip blank lines and footer lines
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^BREAKING\ CHANGE: ]] && continue

    # Extract the conventional commit type and optional scope
    # Pattern: type[(scope)][!]: description
    if [[ "$line" =~ ^([a-z]+)(\([a-z_-]*\))?(!)?\:\ (.+)$ ]]; then
        type="${BASH_REMATCH[1]}"
        bang="${BASH_REMATCH[3]}"
        description="${BASH_REMATCH[4]}"

        # Breaking change via "!" suffix takes highest priority
        if [[ "$bang" == "!" ]]; then
            bump_level=3
            breaking_commits+=("$description")
        elif [[ "$type" == "feat" ]]; then
            # feat -> minor bump (level 2)
            [[ $bump_level -lt 2 ]] && bump_level=2
            feat_commits+=("$description")
        elif [[ "$type" == "fix" ]]; then
            # fix -> patch bump (level 1)
            [[ $bump_level -lt 1 ]] && bump_level=1
            fix_commits+=("$description")
        else
            # docs, chore, refactor, etc. — no bump on their own
            other_commits+=("$description")
        fi
    fi
done <<< "$commit_content"

# If no version-relevant commits were found, exit with an error
if [[ $bump_level -eq 0 ]]; then
    die "No version-relevant commits found (need feat, fix, or breaking change)"
fi

# ── Compute new version ──────────────────────────────────────────────────────

case $bump_level in
    3)  # Major: reset minor and patch
        NEW_MAJOR=$((MAJOR + 1))
        NEW_MINOR=0
        NEW_PATCH=0
        ;;
    2)  # Minor: reset patch
        NEW_MAJOR=$MAJOR
        NEW_MINOR=$((MINOR + 1))
        NEW_PATCH=0
        ;;
    1)  # Patch
        NEW_MAJOR=$MAJOR
        NEW_MINOR=$MINOR
        NEW_PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
info "New version: ${NEW_VERSION}"

# ── Update files ─────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
    # In quiet mode during dry-run, still output the version
    if [[ "$QUIET" == "true" ]]; then
        echo "$NEW_VERSION"
    fi
    exit 0
fi

# Write updated version back to the file
if [[ "$filename" == "package.json" ]]; then
    # Replace the version field in package.json using sed
    sed -i "s/\"version\": \"${MAJOR}\.${MINOR}\.${PATCH}\"/\"version\": \"${NEW_VERSION}\"/" "$VERSION_FILE"
else
    # Plain VERSION file — overwrite with new version
    echo "$NEW_VERSION" > "$VERSION_FILE"
fi

info "Updated $VERSION_FILE"

# ── Generate changelog ───────────────────────────────────────────────────────

if [[ -n "$CHANGELOG_FILE" ]]; then
    {
        echo "## ${NEW_VERSION}"
        echo ""

        if [[ ${#breaking_commits[@]} -gt 0 ]]; then
            echo "### Breaking Changes"
            echo ""
            for msg in "${breaking_commits[@]}"; do
                echo "- $msg"
            done
            echo ""
        fi

        if [[ ${#feat_commits[@]} -gt 0 ]]; then
            echo "### Features"
            echo ""
            for msg in "${feat_commits[@]}"; do
                echo "- $msg"
            done
            echo ""
        fi

        if [[ ${#fix_commits[@]} -gt 0 ]]; then
            echo "### Bug Fixes"
            echo ""
            for msg in "${fix_commits[@]}"; do
                echo "- $msg"
            done
            echo ""
        fi
    } > "$CHANGELOG_FILE"

    info "Generated changelog at $CHANGELOG_FILE"
fi

# In quiet mode, output only the bare version string
if [[ "$QUIET" == "true" ]]; then
    echo "$NEW_VERSION"
fi
