#!/usr/bin/env bash
# PR Label Assigner
# Maps changed file paths to PR labels using configurable glob-pattern rules.
#
# Usage: pr-label-assigner.sh <config-file> <files-input>
#   config-file  – rules file: one "glob_pattern:label" per line, # for comments
#   files-input  – file containing changed paths (one per line), or "-" for stdin
#
# Glob matching: uses bash [[ ]] pattern matching where * matches any chars
# including "/", so "docs/**" and "docs/*" both match nested paths like
# "docs/en/getting-started/intro.md".
#
# Priority: rules are applied in config-file order (top = highest priority).
# ALL matching rules contribute labels; duplicate labels are deduplicated.
# Output: sorted, unique label list, one per line, or "No labels matched".

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <config-file> <files-input>" >&2
    echo "  config-file:  path to label rules config (pattern:label per line)" >&2
    echo "  files-input:  file with changed paths (one per line), or '-' for stdin" >&2
    exit 1
}

# Check whether a file path matches a glob pattern.
# Uses bash [[ ]] pattern matching: * matches any chars including /
# $1 = pattern   $2 = file path
match_pattern() {
    local pattern="$1" filepath="$2"
    # SC2053: unquoted right-hand side is intentional — we WANT glob expansion
    # shellcheck disable=SC2053
    [[ "$filepath" == $pattern ]]
}

main() {
    if [[ $# -lt 2 ]]; then
        echo "Error: missing required arguments" >&2
        usage
    fi

    local config_file="$1"
    local files_input="$2"

    if [[ ! -f "$config_file" ]]; then
        echo "Error: config file '$config_file' not found" >&2
        exit 1
    fi

    # Read changed file paths into an array
    local -a files=()
    local filepath
    if [[ "$files_input" == "-" ]]; then
        while IFS= read -r filepath || [[ -n "$filepath" ]]; do
            [[ -n "$filepath" ]] && files+=("$filepath")
        done
    else
        if [[ ! -f "$files_input" ]]; then
            echo "Error: files input '$files_input' not found" >&2
            exit 1
        fi
        while IFS= read -r filepath || [[ -n "$filepath" ]]; do
            [[ -n "$filepath" ]] && files+=("$filepath")
        done < "$files_input"
    fi

    # Walk config rules in priority order; accumulate matched labels in a set
    local -A label_set=()
    local line line_num pattern label
    line_num=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$(( line_num + 1 ))

        # Skip blank lines and comment lines
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Require "pattern:label" format
        if [[ "$line" != *:* ]]; then
            echo "Warning: line $line_num has no ':' separator — skipped: $line" >&2
            continue
        fi

        pattern="${line%%:*}"
        label="${line#*:}"

        if [[ -z "$pattern" || -z "$label" ]]; then
            echo "Warning: empty pattern or label on line $line_num — skipped" >&2
            continue
        fi

        # Check each changed file against this rule
        if (( ${#files[@]} > 0 )); then
            for filepath in "${files[@]}"; do
                if match_pattern "$pattern" "$filepath"; then
                    label_set["$label"]=1
                fi
            done
        fi
    done < "$config_file"

    # Output sorted, unique labels
    if [[ ${#label_set[@]} -eq 0 ]]; then
        echo "No labels matched"
    else
        for label in "${!label_set[@]}"; do
            echo "$label"
        done | sort
    fi
}

main "$@"
