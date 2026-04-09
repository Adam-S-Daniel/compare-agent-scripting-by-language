#!/usr/bin/env bash
# pr_label_assigner.sh - Assign labels to a PR based on changed file paths
#
# Usage:
#   pr_label_assigner.sh --config <rules.conf> --files <changed_files.txt>
#
# Config file format (one rule per line):
#   pattern:label:priority
#   Example:
#     docs/**:documentation:10
#     src/api/**:api:20
#     *.test.*:tests:30
#   Lines starting with # are treated as comments.
#
# Output:
#   One label per line, sorted by priority descending (highest first)
#   Duplicate labels are removed.

set -euo pipefail

# Enable extended glob patterns and globstar for ** matching
shopt -s extglob globstar 2>/dev/null || true

# ============================================================
# Usage / help
# ============================================================
usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") --config <rules.conf> --files <changed_files.txt>

Options:
  --config FILE   Path to label rules config file
  --files FILE    Path to file containing list of changed files (one per line)
  --help          Show this help message

Config file format:
  pattern:label:priority
  # Lines starting with # are comments

Example config:
  docs/**:documentation:10
  src/api/**:api:20
  *.test.*:tests:30
EOF
    exit 1
}

# ============================================================
# Argument parsing
# ============================================================
CONFIG_FILE=""
FILES_LIST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --files)
            FILES_LIST="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: --config is required" >&2
    usage
fi

if [[ -z "$FILES_LIST" ]]; then
    echo "Error: --files is required" >&2
    usage
fi

# Validate files exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

if [[ ! -f "$FILES_LIST" ]]; then
    echo "Error: Files list not found: $FILES_LIST" >&2
    exit 1
fi

# ============================================================
# match_glob: Check if a file path matches a glob pattern
#
# In bash [[ == ]] pattern matching, * matches any string
# including path separators, so docs/** effectively matches
# any path under docs/. We use this property for glob matching.
# ============================================================
match_glob() {
    local pattern="$1"
    local filepath="$2"

    # Use bash pattern matching: * and ** both match any string
    # (including slashes) in [[ == ]] context
    # This means docs/** matches docs/README.md and docs/sub/dir/file.md
    # shellcheck disable=SC2053
    if [[ "$filepath" == $pattern ]]; then
        return 0
    fi
    return 1
}

# ============================================================
# Main logic: read rules, match files, collect labels
# ============================================================

# Associative array: label -> priority
declare -A label_priority

# Read config file, skipping comments and empty lines
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments (lines starting with #) and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Parse rule: pattern:label:priority
    IFS=':' read -r pattern label priority <<< "$line"

    # Validate the rule has all three fields
    if [[ -z "$pattern" || -z "$label" || -z "$priority" ]]; then
        echo "Warning: Skipping malformed rule: '$line'" >&2
        continue
    fi

    # For each changed file, check if it matches this rule
    while IFS= read -r filepath || [[ -n "$filepath" ]]; do
        # Skip empty lines in file list
        [[ -z "${filepath// }" ]] && continue

        if match_glob "$pattern" "$filepath"; then
            # Record the label with the highest priority seen
            # (if the same label appears in multiple rules, keep the highest priority)
            if [[ -z "${label_priority[$label]+set}" ]] || \
               [[ "$priority" -gt "${label_priority[$label]}" ]]; then
                label_priority["$label"]="$priority"
            fi
        fi
    done < "$FILES_LIST"

done < "$CONFIG_FILE"

# ============================================================
# Output: sort labels by priority descending, one per line
# ============================================================

# Build a sortable list: "priority label" then sort numerically descending
# Note: iterating "${!arr[@]}" on empty associative arrays is safe with set -u;
# getting ${#arr[@]} is not (bash treats empty assoc arrays as unbound).
for label in "${!label_priority[@]}"; do
    printf '%d %s\n' "${label_priority[$label]}" "$label"
done | sort -rn | awk '{print $2}'
