#!/usr/bin/env bash
#
# semver_bumper.sh — Semantic Version Bumper
#
# Parses a version file (VERSION or package.json), determines the next version
# based on conventional commit messages, updates the version file, and generates
# a changelog entry.
#
# Usage:
#   ./semver_bumper.sh --version-file <path> [--commits <path>] [--changelog <path>] [--dry-run]
#
# When --commits is omitted, reads from `git log` in the current repo.

set -euo pipefail

# Regex for validating a semantic version string (major.minor.patch)
readonly SEMVER_REGEX='^[0-9]+\.[0-9]+\.[0-9]+$'

# ---------------------------------------------------------------------------
# parse_version — Extract semver from a VERSION file or package.json
#   $1: path to version file
#   Prints: the version string (without v prefix)
# ---------------------------------------------------------------------------
parse_version() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: version file not found: $file" >&2
        return 1
    fi

    local version=""

    if [[ "$file" == *.json ]]; then
        # Extract version from package.json using grep+sed (no jq dependency)
        version=$(grep '"version"' "$file" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    else
        # Plain text VERSION file — read first non-empty line
        version=$(head -1 "$file" | tr -d '[:space:]')
    fi

    # Strip optional 'v' prefix
    version="${version#v}"

    if [[ ! "$version" =~ $SEMVER_REGEX ]]; then
        echo "Error: invalid semver '$version' in $file" >&2
        return 1
    fi

    echo "$version"
}

# ---------------------------------------------------------------------------
# classify_commits — Scan commit messages and determine the bump type
#   $1: path to a file containing commit messages (one per line)
#   Prints: "major", "minor", or "patch"
# ---------------------------------------------------------------------------
classify_commits() {
    local commit_file="$1"

    if [[ ! -f "$commit_file" ]]; then
        echo "Error: commit log not found: $commit_file" >&2
        return 1
    fi

    local bump="patch"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for breaking changes: "!" after type, or "BREAKING CHANGE" anywhere
        if [[ "$line" =~ ^[a-z]+(\(.+\))?!: ]] || [[ "$line" == *"BREAKING CHANGE"* ]]; then
            bump="major"
            break  # major is the highest — no need to continue
        fi

        # Check for feat (new feature → minor bump)
        if [[ "$line" =~ ^feat(\(.+\))?: ]]; then
            bump="minor"
            # Don't break — a later line might be a breaking change
        fi
    done < "$commit_file"

    echo "$bump"
}

# ---------------------------------------------------------------------------
# bump_version — Compute the next version given current version and bump type
#   $1: current version (e.g. "1.2.3")
#   $2: bump type ("major", "minor", "patch")
#   Prints: the new version string
# ---------------------------------------------------------------------------
bump_version() {
    local version="$1"
    local bump_type="$2"

    # Split version into components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Error: Invalid bump type '$bump_type'. Must be major, minor, or patch." >&2
            return 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# ---------------------------------------------------------------------------
# generate_changelog — Build a markdown changelog entry from commit messages
#   $1: new version string
#   $2: path to commit log file
#   Prints: formatted markdown changelog
# ---------------------------------------------------------------------------
generate_changelog() {
    local version="$1"
    local commit_file="$2"
    local date
    date=$(date +%Y-%m-%d)

    local breaking="" features="" fixes="" other=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^[a-z]+(\(.+\))?!: ]] || [[ "$line" == *"BREAKING CHANGE"* ]]; then
            breaking+="- ${line}
"
        elif [[ "$line" =~ ^feat(\(.+\))?: ]]; then
            # Strip the conventional commit prefix for cleaner output
            local msg="${line#feat: }"
            msg="${msg#feat\(*\): }"
            features+="- ${line}
"
        elif [[ "$line" =~ ^fix(\(.+\))?: ]]; then
            fixes+="- ${line}
"
        else
            other+="- ${line}
"
        fi
    done < "$commit_file"

    echo "## ${version} (${date})"
    echo ""

    if [[ -n "$breaking" ]]; then
        echo "### Breaking Changes"
        echo ""
        echo -n "$breaking"
        echo ""
    fi

    if [[ -n "$features" ]]; then
        echo "### Features"
        echo ""
        echo -n "$features"
        echo ""
    fi

    if [[ -n "$fixes" ]]; then
        echo "### Bug Fixes"
        echo ""
        echo -n "$fixes"
        echo ""
    fi

    if [[ -n "$other" ]]; then
        echo "### Other"
        echo ""
        echo -n "$other"
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# update_version_file — Write the new version back to the version file
#   $1: path to version file
#   $2: new version string
# ---------------------------------------------------------------------------
update_version_file() {
    local file="$1"
    local new_version="$2"

    if [[ "$file" == *.json ]]; then
        # Update the "version" field in package.json using sed
        sed -i "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${new_version}\"/" "$file"
    else
        # Plain VERSION file — overwrite contents
        echo "$new_version" > "$file"
    fi
}

# ---------------------------------------------------------------------------
# main — Orchestrate the version bump pipeline
# ---------------------------------------------------------------------------
main() {
    local version_file="" commit_file="" changelog_file="" dry_run=false

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version-file)
                version_file="$2"
                shift 2
                ;;
            --commits)
                commit_file="$2"
                shift 2
                ;;
            --changelog)
                changelog_file="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 --version-file <path> [--commits <path>] [--changelog <path>] [--dry-run]"
                exit 0
                ;;
            *)
                echo "Error: unknown argument '$1'" >&2
                echo "Usage: $0 --version-file <path> [--commits <path>] [--changelog <path>] [--dry-run]" >&2
                exit 1
                ;;
        esac
    done

    if [[ -z "$version_file" ]]; then
        echo "Error: --version-file is required" >&2
        echo "Usage: $0 --version-file <path> [--commits <path>] [--changelog <path>] [--dry-run]" >&2
        exit 1
    fi

    # Step 1: Parse current version
    local current_version
    current_version=$(parse_version "$version_file")
    echo "Current version: $current_version"

    # Step 2: Get commit messages (from file or git log)
    local tmp_commits=""
    if [[ -z "$commit_file" ]]; then
        # No commit file provided — use git log since last tag or all commits
        tmp_commits=$(mktemp)
        local last_tag
        last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
        if [[ -n "$last_tag" ]]; then
            git log "${last_tag}..HEAD" --pretty=format:"%s" > "$tmp_commits"
        else
            git log --pretty=format:"%s" > "$tmp_commits"
        fi
        commit_file="$tmp_commits"
    fi

    # Step 3: Classify commits to determine bump type
    local bump_type
    bump_type=$(classify_commits "$commit_file")
    echo "Bump type: $bump_type"

    # Step 4: Calculate new version
    local new_version
    new_version=$(bump_version "$current_version" "$bump_type")
    echo "New version: $new_version"

    # Step 5: Generate changelog
    local changelog_content
    changelog_content=$(generate_changelog "$new_version" "$commit_file")

    if [[ "$dry_run" == true ]]; then
        echo ""
        echo "--- Changelog Preview ---"
        echo "$changelog_content"
        echo "--- (dry run, no files modified) ---"
    else
        # Step 6: Update version file
        update_version_file "$version_file" "$new_version"

        # Step 7: Write changelog if requested
        if [[ -n "$changelog_file" ]]; then
            if [[ -f "$changelog_file" ]]; then
                # Prepend new entry to existing changelog
                local existing
                existing=$(cat "$changelog_file")
                {
                    echo "$changelog_content"
                    echo ""
                    echo "$existing"
                } > "$changelog_file"
            else
                echo "$changelog_content" > "$changelog_file"
            fi
            echo "Changelog written to: $changelog_file"
        fi
    fi

    # Clean up temp file if we created one
    [[ -n "$tmp_commits" ]] && rm -f "$tmp_commits"

    echo "$new_version"
}

# Allow sourcing as a library (for unit tests) vs running as a script
if [[ "${SEMVER_LIB:-}" != "1" ]]; then
    main "$@"
fi
