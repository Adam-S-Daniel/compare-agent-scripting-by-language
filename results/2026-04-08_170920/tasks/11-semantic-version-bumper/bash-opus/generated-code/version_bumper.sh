#!/usr/bin/env bash
# version_bumper.sh - Semantic version bumper based on conventional commits
#
# Usage:
#   version_bumper.sh --version-file <file> --commits <file> [--changelog <file>]
#
# Reads the current version from --version-file (plain text or package.json),
# analyzes conventional commit messages from --commits to determine the bump
# type (major/minor/patch), updates the version file, writes a changelog entry,
# and outputs the new version to stdout.

set -euo pipefail

# Resolve the directory containing this script so we can source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=version_lib.sh
source "${SCRIPT_DIR}/version_lib.sh"

# Print usage information and exit with error
usage() {
    cat >&2 <<'EOF'
Usage: version_bumper.sh --version-file <file> --commits <file> [--changelog <file>]

Options:
  --version-file  Path to version file (plain text or package.json) [required]
  --commits       Path to file containing conventional commit messages [required]
  --changelog     Path to write changelog entry (default: CHANGELOG.md)
  -h, --help      Show this help message
EOF
    exit 1
}

main() {
    local version_file=""
    local commits_file=""
    local changelog_file="CHANGELOG.md"

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
            -h|--help)
                usage
                ;;
            *)
                echo "Error: unknown option: $1" >&2
                usage
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$version_file" ]]; then
        echo "Error: --version-file is required" >&2
        usage
    fi
    if [[ -z "$commits_file" ]]; then
        echo "Error: --commits is required" >&2
        usage
    fi

    # Step 1: Read current version
    local current_version
    current_version="$(read_version_file "$version_file")"

    # Step 2: Detect bump type from commits
    local bump_type
    bump_type="$(detect_bump_type "$commits_file")"

    # Step 3: Compute new version
    local new_version
    new_version="$(bump_version "$current_version" "$bump_type")"

    # Step 4: Generate changelog entry
    local changelog_entry
    changelog_entry="$(generate_changelog "$commits_file" "$new_version")"

    # Step 5: Write changelog if there's content
    if [[ -n "$changelog_entry" ]]; then
        echo "$changelog_entry" > "$changelog_file"
    fi

    # Step 6: Update the version file (only if version changed)
    if [[ "$new_version" != "$current_version" ]]; then
        update_version_file "$version_file" "$new_version"
    fi

    # Output the new version
    echo "$new_version"
}

main "$@"
