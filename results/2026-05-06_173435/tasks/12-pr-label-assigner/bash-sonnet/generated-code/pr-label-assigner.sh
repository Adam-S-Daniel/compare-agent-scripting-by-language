#!/usr/bin/env bash
# PR Label Assigner
#
# Applies GitHub PR labels to a set of changed file paths using configurable
# glob-pattern rules.  Multiple labels per file are supported.  Labels are
# deduplicated across all files and output in ascending priority order.
#
# Config file format (one rule per line, # = comment):
#   priority:label:glob-pattern
#   priority  — integer; lower number = higher priority (appears first in output)
#   label     — string to emit (e.g. "documentation", "api")
#   pattern   — bash glob pattern (e.g. "docs/**", "*.test.*")
#
# Usage:
#   pr-label-assigner.sh <config-file> [file-list]
#   Changed file paths are read from <file-list> or from stdin if omitted.

set -euo pipefail

# ---------------------------------------------------------------------------
# Usage / argument validation
# ---------------------------------------------------------------------------
usage() {
    cat >&2 <<'EOF'
Usage: pr-label-assigner.sh <config-file> [file-list]

  config-file  Path to label mapping rules (required)
  file-list    File containing changed paths, one per line (optional; defaults
               to stdin)

Config format: priority:label:pattern
  priority   integer  lower = higher priority (earlier in output)
  label      string   label to assign (e.g. "documentation")
  pattern    glob     bash glob pattern (e.g. "docs/**", "*.test.*")

Lines beginning with # and blank lines are ignored.
EOF
    exit 1
}

CONFIG_FILE="${1:-}"
FILE_LIST="${2:-}"

[[ -z "$CONFIG_FILE" ]] && usage

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Load rules from config file into parallel indexed arrays
# ---------------------------------------------------------------------------
declare -a rule_priorities=()
declare -a rule_labels=()
declare -a rule_patterns=()

while IFS= read -r line; do
    # Skip comment lines (leading # with optional whitespace)
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    # Skip blank / whitespace-only lines
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # Split on the first two colons only so the pattern may contain colons
    priority="${line%%:*}"
    rest="${line#*:}"
    label="${rest%%:*}"
    pattern="${rest#*:}"

    if [[ -z "$priority" || -z "$label" || -z "$pattern" ]]; then
        echo "Warning: Skipping invalid rule (need priority:label:pattern): $line" >&2
        continue
    fi
    if ! [[ "$priority" =~ ^[0-9]+$ ]]; then
        echo "Warning: Priority must be a non-negative integer, skipping: $line" >&2
        continue
    fi

    rule_priorities+=("$priority")
    rule_labels+=("$label")
    rule_patterns+=("$pattern")
done < "$CONFIG_FILE"

# ---------------------------------------------------------------------------
# label_min_priority[label] = minimum priority value that matched this label
# (keeps only the best/lowest priority seen across all files and rules)
# ---------------------------------------------------------------------------
declare -A label_min_priority=()

# Check one file path against every rule; update label_min_priority
check_file() {
    local file="$1"
    local i
    for i in "${!rule_patterns[@]}"; do
        local pat="${rule_patterns[$i]}"
        local lbl="${rule_labels[$i]}"
        local pri="${rule_priorities[$i]}"
        # Intentional glob match: $pat must be unquoted in [[ ]] so bash
        # treats it as a pattern rather than a literal string.
        # shellcheck disable=SC2053
        if [[ "$file" == $pat ]]; then
            local cur="${label_min_priority[$lbl]:-}"
            if [[ -z "$cur" ]] || [[ "$pri" -lt "$cur" ]]; then
                label_min_priority[$lbl]="$pri"
            fi
        fi
    done
}

# Read file paths line-by-line and check each one
process_input() {
    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        check_file "$file"
    done
}

# ---------------------------------------------------------------------------
# Read input: file argument or stdin
# ---------------------------------------------------------------------------
if [[ -n "$FILE_LIST" ]]; then
    if [[ ! -f "$FILE_LIST" ]]; then
        echo "Error: File list not found: $FILE_LIST" >&2
        exit 1
    fi
    process_input < "$FILE_LIST"
else
    process_input
fi

# ---------------------------------------------------------------------------
# Output: labels sorted by minimum matched priority (ascending), then
# alphabetically within the same priority level, one label per line.
# ---------------------------------------------------------------------------
if [[ "${#label_min_priority[@]}" -gt 0 ]]; then
    for lbl in "${!label_min_priority[@]}"; do
        printf '%s\t%s\n' "${label_min_priority[$lbl]}" "$lbl"
    done | sort -t$'\t' -k1,1n -k2,2 | cut -f2
fi
