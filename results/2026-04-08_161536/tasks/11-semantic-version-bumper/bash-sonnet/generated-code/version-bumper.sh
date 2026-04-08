#!/usr/bin/env bash
# version-bumper.sh — Semantic version bumper using conventional commits
#
# Usage:
#   version-bumper.sh parse-version <file>
#   version-bumper.sh determine-bump <commits-file>
#   version-bumper.sh bump-version <version> <patch|minor|major>
#   version-bumper.sh update-version-file <file> <new-version>
#   version-bumper.sh generate-changelog <new-version> <commits-file>
#   version-bumper.sh run <version-file> <commits-file>
#
# Conventional commit types -> bump level:
#   feat!  / fix!  / any! (breaking)  -> major
#   BREAKING CHANGE in footer          -> major
#   feat                               -> minor
#   fix / chore / docs / style / etc.  -> patch

set -euo pipefail

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Print to stderr
err() { echo "Error: $*" >&2; }

# Validate that a string matches semver X.Y.Z
is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ─── parse-version ────────────────────────────────────────────────────────────
# Read the current version from a version.txt or package.json file.

cmd_parse_version() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        err "File does not exist: $file"
        exit 1
    fi

    local version
    if [[ "$file" == *.json ]]; then
        # Extract version field from package.json using grep + sed (no jq required)
        version=$(grep -E '"version"\s*:\s*"[^"]*"' "$file" | sed 's/.*"version"\s*:\s*"\([^"]*\)".*/\1/')
    else
        # Plain version file: first non-empty line
        version=$(grep -m1 '[^[:space:]]' "$file")
    fi

    if [[ -z "$version" ]]; then
        err "Invalid version: could not parse version from $file"
        exit 1
    fi

    if ! is_semver "$version"; then
        err "Invalid version: '$version' is not a valid semantic version (X.Y.Z)"
        exit 1
    fi

    echo "$version"
}

# ─── determine-bump ───────────────────────────────────────────────────────────
# Read a file of conventional commit messages and return the required bump level.
# Priority: major > minor > patch

cmd_determine_bump() {
    local commits_file="$1"

    if [[ ! -f "$commits_file" ]]; then
        err "Commit file does not exist: $commits_file"
        exit 1
    fi

    local bump="patch"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Breaking change footer: "BREAKING CHANGE: ..."
        if [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
            bump="major"
            break
        fi

        # Conventional commit with ! (breaking): "feat!: ..." or "fix!: ..."
        # Store regex in variable to avoid bash parsing issues with parens
        local breaking_re='^[a-zA-Z]+(\([^)]*\))?!:'
        if [[ "$line" =~ $breaking_re ]]; then
            bump="major"
            break
        fi

        # Feature commit: "feat: ..." or "feat(scope): ..."
        local feat_re='^feat(\([^)]*\))?:'
        if [[ "$line" =~ $feat_re ]] && [[ "$bump" != "major" ]]; then
            bump="minor"
        fi
    done < "$commits_file"

    echo "$bump"
}

# ─── bump-version ─────────────────────────────────────────────────────────────
# Given a semver string and bump type, return the next version.

cmd_bump_version() {
    local version="$1"
    local bump_type="$2"

    if ! is_semver "$version"; then
        err "Invalid version: '$version' is not valid semver"
        exit 1
    fi

    # Split into components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    case "$bump_type" in
        patch)
            patch=$(( patch + 1 ))
            ;;
        minor)
            minor=$(( minor + 1 ))
            patch=0
            ;;
        major)
            major=$(( major + 1 ))
            minor=0
            patch=0
            ;;
        *)
            err "Invalid bump type: '$bump_type'. Must be patch, minor, or major."
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# ─── update-version-file ──────────────────────────────────────────────────────
# Write the new version back to a version.txt or package.json file.

cmd_update_version_file() {
    local file="$1"
    local new_version="$2"

    if [[ ! -f "$file" ]]; then
        err "File does not exist: $file"
        exit 1
    fi

    if ! is_semver "$new_version"; then
        err "Invalid version: '$new_version' is not valid semver"
        exit 1
    fi

    if [[ "$file" == *.json ]]; then
        # Replace the version field value in-place using sed
        sed -i "s/\"version\"\s*:\s*\"[^\"]*\"/\"version\": \"${new_version}\"/" "$file"
    else
        # Plain version file: overwrite with the new version
        echo "$new_version" > "$file"
    fi
}

# ─── generate-changelog ───────────────────────────────────────────────────────
# Generate a changelog entry for the new version from the list of commits.

cmd_generate_changelog() {
    local new_version="$1"
    local commits_file="$2"

    if [[ ! -f "$commits_file" ]]; then
        err "Commit file does not exist: $commits_file"
        exit 1
    fi

    local date
    date=$(date +%Y-%m-%d)

    echo "## Changelog"
    echo ""
    echo "### [${new_version}] - ${date}"
    echo ""

    # Collect commit lines by category
    local features=()
    local fixes=()
    local breaking=()
    local others=()

    # Store regex patterns in variables to avoid bash parsing issues
    local re_breaking_bang='^[a-zA-Z]+(\([^)]*\))?!:'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
            breaking+=("$line")
        elif [[ "$line" =~ $re_breaking_bang ]]; then
            # Extract message after the type prefix
            local msg="${line#*: }"
            breaking+=("$msg (breaking)")
        elif [[ "$line" =~ $re_feat ]]; then
            local msg="${line#*: }"
            features+=("$msg")
        elif [[ "$line" =~ $re_fix ]]; then
            local msg="${line#*: }"
            fixes+=("$msg")
        else
            others+=("$line")
        fi
    done < "$commits_file"

    if [[ ${#breaking[@]} -gt 0 ]]; then
        echo "#### Breaking Changes"
        for item in "${breaking[@]}"; do
            echo "- $item"
        done
        echo ""
    fi

    if [[ ${#features[@]} -gt 0 ]]; then
        echo "#### Features"
        for item in "${features[@]}"; do
            echo "- $item"
        done
        echo ""
    fi

    if [[ ${#fixes[@]} -gt 0 ]]; then
        echo "#### Bug Fixes"
        for item in "${fixes[@]}"; do
            echo "- $item"
        done
        echo ""
    fi

    if [[ ${#others[@]} -gt 0 ]]; then
        echo "#### Other Changes"
        for item in "${others[@]}"; do
            echo "- $item"
        done
        echo ""
    fi
}

# ─── run (full pipeline) ──────────────────────────────────────────────────────
# End-to-end: parse version, determine bump, bump version, update file, output.

cmd_run() {
    local version_file="$1"
    local commits_file="$2"

    # Step 1: Parse current version
    local current_version
    current_version=$(cmd_parse_version "$version_file")

    # Step 2: Determine bump type from commits
    local bump_type
    bump_type=$(cmd_determine_bump "$commits_file")

    # Step 3: Calculate new version
    local new_version
    new_version=$(cmd_bump_version "$current_version" "$bump_type")

    # Step 4: Update the version file
    cmd_update_version_file "$version_file" "$new_version"

    # Step 5: Generate and output changelog
    cmd_generate_changelog "$new_version" "$commits_file"

    # Step 6: Output the new version (last line for easy capture)
    echo ""
    echo "New version: ${new_version}"
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <command> [args...]" >&2
    echo "Commands: parse-version, determine-bump, bump-version, update-version-file, generate-changelog, run" >&2
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    parse-version)
        [[ $# -ge 1 ]] || { err "parse-version requires <file>"; exit 1; }
        cmd_parse_version "$1"
        ;;
    determine-bump)
        [[ $# -ge 1 ]] || { err "determine-bump requires <commits-file>"; exit 1; }
        cmd_determine_bump "$1"
        ;;
    bump-version)
        [[ $# -ge 2 ]] || { err "bump-version requires <version> <patch|minor|major>"; exit 1; }
        cmd_bump_version "$1" "$2"
        ;;
    update-version-file)
        [[ $# -ge 2 ]] || { err "update-version-file requires <file> <new-version>"; exit 1; }
        cmd_update_version_file "$1" "$2"
        ;;
    generate-changelog)
        [[ $# -ge 2 ]] || { err "generate-changelog requires <new-version> <commits-file>"; exit 1; }
        cmd_generate_changelog "$1" "$2"
        ;;
    run)
        [[ $# -ge 2 ]] || { err "run requires <version-file> <commits-file>"; exit 1; }
        cmd_run "$1" "$2"
        ;;
    *)
        err "Unknown command: '$COMMAND'"
        exit 1
        ;;
esac
