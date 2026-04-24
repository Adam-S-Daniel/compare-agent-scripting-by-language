#!/usr/bin/env bash
# pr-label-assigner.sh
# Assigns labels to a PR based on changed file paths and configurable glob rules.
#
# Usage:
#   pr-label-assigner.sh --rules <rules-file> [--files <files-file>]
#   (reads file list from stdin if --files is not specified)
#
# Rules file format (one rule per line):
#   <glob-pattern>:<label>:<priority>
#   Lines starting with # are comments; blank lines are ignored.
#
# Output: labels sorted by priority (descending), then alphabetically, one per line.

set -euo pipefail

usage() {
    echo "Usage: $0 --rules <rules-file> [--files <files-file>]" >&2
    echo "  --rules  Path to the rules configuration file (required)" >&2
    echo "  --files  Path to file containing changed paths (default: stdin)" >&2
    exit 1
}

# --- Argument parsing ---
RULES_FILE=""
FILES_INPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rules)
            RULES_FILE="$2"
            shift 2
            ;;
        --files)
            FILES_INPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage
            ;;
    esac
done

if [[ -z "$RULES_FILE" ]]; then
    echo "Error: --rules is required" >&2
    usage
fi

if [[ ! -f "$RULES_FILE" ]]; then
    echo "Error: Rules file not found: $RULES_FILE" >&2
    exit 1
fi

# --- Load rules: array of "priority:label:glob" for easy sorting ---
# We store as "priority|label|glob" to allow sorting numerically by priority.
declare -a RULES=()

while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Expect format: glob:label:priority
    IFS=':' read -r glob label priority <<< "$line"

    # Validate all three fields are present
    if [[ -z "$glob" || -z "$label" || -z "$priority" ]]; then
        echo "Warning: Skipping malformed rule line: $line" >&2
        continue
    fi

    RULES+=("${priority}|${label}|${glob}")
done < "$RULES_FILE"

# Sort rules by priority descending (highest first)
# Use mapfile + process substitution with sort
mapfile -t RULES < <(printf '%s\n' "${RULES[@]}" | sort -t'|' -k1,1rn)

# --- Read file list ---
declare -a FILES=()

if [[ -n "$FILES_INPUT" ]]; then
    if [[ ! -f "$FILES_INPUT" ]]; then
        echo "Error: Files list not found: $FILES_INPUT" >&2
        exit 1
    fi
    while IFS= read -r f; do
        [[ -n "$f" ]] && FILES+=("$f")
    done < "$FILES_INPUT"
else
    while IFS= read -r f; do
        [[ -n "$f" ]] && FILES+=("$f")
    done
fi

# Exit cleanly if no files
if [[ ${#FILES[@]} -eq 0 ]]; then
    exit 0
fi

# --- Match files against rules ---
# fnmatch-style glob matching via bash's [[ ... == glob ]] with extglob.
# We track: priority -> label, deduplicated by label.

declare -A LABEL_PRIORITY=()    # label -> highest priority

shopt -s extglob globstar nullglob

match_glob() {
    local pattern="$1"
    local path="$2"

    # Try direct bash glob match (handles ** via globstar).
    # SC2053: unquoted RHS is intentional — we want glob/pattern matching.
    # shellcheck disable=SC2053
    if [[ "$path" == $pattern ]]; then
        return 0
    fi

    # Also try matching just the basename for patterns without a slash.
    if [[ "$pattern" != */* ]]; then
        local base="${path##*/}"
        # shellcheck disable=SC2053
        if [[ "$base" == $pattern ]]; then
            return 0
        fi
    fi

    return 1
}

for filepath in "${FILES[@]}"; do
    for rule in "${RULES[@]}"; do
        IFS='|' read -r priority label glob <<< "$rule"

        if match_glob "$glob" "$filepath"; then
            # Record the label with the highest priority seen
            if [[ -z "${LABEL_PRIORITY[$label]+_}" ]] || \
               [[ "$priority" -gt "${LABEL_PRIORITY[$label]}" ]]; then
                LABEL_PRIORITY["$label"]="$priority"
            fi
        fi
    done
done

# --- Output labels sorted by priority descending, then alphabetically ---
if [[ ${#LABEL_PRIORITY[@]} -eq 0 ]]; then
    exit 0
fi

# Build sortable list: "priority label"
declare -a OUTPUT_PAIRS=()
for label in "${!LABEL_PRIORITY[@]}"; do
    OUTPUT_PAIRS+=("${LABEL_PRIORITY[$label]} $label")
done

# Sort: primary by priority descending (-k1,1rn), secondary by label ascending (-k2)
printf '%s\n' "${OUTPUT_PAIRS[@]}" \
    | sort -k1,1rn -k2,2 \
    | awk '{print $2}'
