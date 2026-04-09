#!/usr/bin/env bash
# pr-label-assigner.sh
#
# Given a config file of path-to-label rules and a list of changed files,
# outputs the set of labels that should be applied to a PR.
#
# Usage:
#   pr-label-assigner.sh <config-file> [file1 file2 ...]
#   echo "file1" | pr-label-assigner.sh <config-file>
#
# Config format (one rule per line):
#   glob-pattern:label     # pattern uses bash pattern matching
#   # lines starting with # are comments
#   # blank lines are ignored
#
# Behavior:
#   - Rules are evaluated in order; earlier rules have higher priority.
#   - A single file can match multiple rules → receives all matching labels.
#   - If the same label would be added by multiple rules, the first (highest
#     priority) occurrence wins and subsequent duplicates are dropped.
#   - Output: one label per line, in rule-priority order, deduplicated.
#   - Exit 0 in all success cases (including zero-label matches).
#   - Exit non-zero on config errors or missing arguments.

set -euo pipefail

# ---------------------------------------------------------------------------
# usage: print usage message to stderr and exit 1
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 <config-file> [file1 file2 ...]" >&2
    echo "       echo 'file1' | $0 <config-file>" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# match_pattern PATTERN FILEPATH
#
# Returns 0 (match) or 1 (no match) using bash's built-in case statement
# pattern matching.
#
# In bash case/[[ ]] patterns, '*' matches ANY string including path
# separators ('/').  This means:
#   docs/**  →  matches docs/README.md, docs/api/guide.md, docs/a/b/c.txt
#   *.test.* →  matches utils.test.ts, src/api/users.test.ts
#
# The '**' in patterns is treated the same as '*' in bash pattern context
# (globstar only affects filename expansion, not pattern matching).
#
# ---------------------------------------------------------------------------
match_pattern() {
    local pattern="$1"
    local filepath="$2"
    # Unquoted $pattern is intentional: enables glob matching in case statement.
    # shellcheck disable=SC2254
    case "$filepath" in
        $pattern) return 0 ;;
    esac
    return 1
}

# ---------------------------------------------------------------------------
# main: parse arguments, load config, match files, output labels
# ---------------------------------------------------------------------------
main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi

    local config_file="$1"
    shift

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Config file '$config_file' not found" >&2
        exit 1
    fi

    # Collect changed files: from positional args or from stdin
    local -a files=()
    if [[ $# -gt 0 ]]; then
        files=("$@")
    else
        # Read one file path per line from stdin
        while IFS= read -r line; do
            [[ -n "$line" ]] && files+=("$line")
        done
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Warning: No files provided" >&2
        exit 0
    fi

    # Load rules from the config file, skipping comments and blank lines.
    # Each rule is stored as "pattern:label".
    local -a rules=()
    while IFS= read -r line; do
        # Skip comment lines (optional leading whitespace + #)
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        # Skip blank / whitespace-only lines
        [[ -z "${line//[[:space:]]/}" ]] && continue
        rules+=("$line")
    done < "$config_file"

    if [[ ${#rules[@]} -eq 0 ]]; then
        echo "Warning: No rules found in config file '$config_file'" >&2
        exit 0
    fi

    # Iterate rules in priority order.
    # For each rule: if ANY file matches its pattern, add the label (once).
    # An associative array tracks which labels have been seen so that
    # higher-priority rules win and duplicates are dropped.
    declare -A seen_labels=()
    local -a ordered_labels=()

    for rule in "${rules[@]}"; do
        # Split on the FIRST colon only: "src/api/**:api" → pattern="src/api/**", label="api"
        local pattern="${rule%%:*}"
        local label="${rule#*:}"

        if [[ -z "$pattern" || -z "$label" ]]; then
            echo "Warning: Skipping invalid rule '$rule' (expected pattern:label)" >&2
            continue
        fi

        # Check whether any of the changed files triggers this rule
        local matched=0
        for file in "${files[@]}"; do
            if match_pattern "$pattern" "$file"; then
                matched=1
                break  # One matching file is sufficient to activate the rule
            fi
        done

        if [[ "$matched" -eq 1 ]]; then
            # Add label only if not yet in the output set (preserves priority order)
            if [[ -z "${seen_labels[$label]+x}" ]]; then
                seen_labels["$label"]=1
                ordered_labels+=("$label")
            fi
        fi
    done

    # Output the final label set: one label per line.
    # Empty output (no matches) is valid — exit 0, print nothing.
    if [[ ${#ordered_labels[@]} -gt 0 ]]; then
        printf '%s\n' "${ordered_labels[@]}"
    fi
}

main "$@"
