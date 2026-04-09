#!/usr/bin/env bash
# pr-label-assigner.sh - Assign PR labels based on changed file paths
#
# Given a list of changed files and a rules config, outputs the set of labels
# that should be applied. Supports glob patterns, multiple labels per file,
# and priority-based conflict resolution.
#
# Usage:
#   pr-label-assigner.sh [-c config_file] [-f files_list | -s "file1 file2 ..."]
#
# Options:
#   -c CONFIG   Path to label rules config (default: label-rules.conf)
#   -f FILE     Path to file containing changed file paths (one per line)
#   -s STRING   Space-separated list of changed files
#   -h          Show help

set -euo pipefail

# Default config location (same directory as script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/label-rules.conf"
FILES_INPUT=""
FILES_STRING=""

# Print usage information
usage() {
    echo "Usage: $(basename "$0") [-c config_file] [-f files_list | -s \"file1 file2 ...\"]"
    echo ""
    echo "Options:"
    echo "  -c CONFIG   Path to label rules config (default: label-rules.conf)"
    echo "  -f FILE     Path to file containing changed file paths (one per line)"
    echo "  -s STRING   Space-separated list of changed files"
    echo "  -h          Show help"
    exit 1
}

# Parse command-line arguments
while getopts "c:f:s:h" opt; do
    case "${opt}" in
        c) CONFIG_FILE="${OPTARG}" ;;
        f) FILES_INPUT="${OPTARG}" ;;
        s) FILES_STRING="${OPTARG}" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate config file exists
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Validate that we have some input
if [[ -z "${FILES_INPUT}" && -z "${FILES_STRING}" ]]; then
    # Read from stdin if no file/string provided
    if [[ -t 0 ]]; then
        echo "Error: No changed files provided. Use -f, -s, or pipe to stdin." >&2
        exit 1
    fi
fi

# match_glob - Check if a file path matches a glob pattern
# Supports ** for recursive directory matching
# Args: $1 = pattern, $2 = filepath
match_glob() {
    local pattern="$1"
    local filepath="$2"

    # Convert glob pattern to regex:
    #   .  -> literal dot
    #   ** -> match anything (including /)
    #   *  -> match anything except /
    #   ?  -> match single char except /
    local regex="${pattern}"

    # Escape dots first
    regex="${regex//./\\.}"
    # Temporarily replace ** with a placeholder
    regex="${regex//\*\*/___DOUBLESTAR___}"
    # Replace single * with [^/]*
    regex="${regex//\*/[^/]*}"
    # Replace placeholder with .*
    regex="${regex//___DOUBLESTAR___/.*}"
    # Replace ? with [^/]
    regex="${regex//\?/[^/]}"

    regex="^${regex}$"

    if [[ "${filepath}" =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

# parse_rules - Parse the config file and output sorted rules
# Output format: priority|pattern|label (sorted by priority ascending)
parse_rules() {
    local config="$1"
    # Strip comments, blank lines, then sort by priority (numeric, ascending)
    grep -v '^\s*#' "${config}" | grep -v '^\s*$' | sort -t'|' -k1,1n
}

# collect_changed_files - Gather changed files from all input sources
collect_changed_files() {
    local files=()

    # From file list
    if [[ -n "${FILES_INPUT}" ]]; then
        if [[ ! -f "${FILES_INPUT}" ]]; then
            echo "Error: Files list not found: ${FILES_INPUT}" >&2
            exit 1
        fi
        while IFS= read -r line; do
            [[ -n "${line}" ]] && files+=("${line}")
        done < "${FILES_INPUT}"
    fi

    # From string argument
    if [[ -n "${FILES_STRING}" ]]; then
        for f in ${FILES_STRING}; do
            files+=("${f}")
        done
    fi

    # From stdin
    if [[ -z "${FILES_INPUT}" && -z "${FILES_STRING}" ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && files+=("${line}")
        done
    fi

    # Output unique files
    printf '%s\n' "${files[@]}" | sort -u
}

# assign_labels - Main logic: match files against rules, collect labels
# Uses priority ordering: lower priority number = higher precedence
assign_labels() {
    local -a rules_priority=()
    local -a rules_pattern=()
    local -a rules_label=()

    # Parse rules into arrays
    while IFS='|' read -r priority pattern label; do
        rules_priority+=("${priority}")
        rules_pattern+=("${pattern}")
        rules_label+=("${label}")
    done < <(parse_rules "${CONFIG_FILE}")

    if [[ ${#rules_priority[@]} -eq 0 ]]; then
        echo "Error: No valid rules found in config" >&2
        exit 1
    fi

    # Track matched labels with their best (lowest) priority
    declare -A label_priority

    # Process each changed file
    while IFS= read -r filepath; do
        [[ -z "${filepath}" ]] && continue

        for i in "${!rules_priority[@]}"; do
            if match_glob "${rules_pattern[$i]}" "${filepath}"; then
                local lbl="${rules_label[$i]}"
                local pri="${rules_priority[$i]}"

                # Track the label - keep the highest priority (lowest number)
                if [[ -z "${label_priority[${lbl}]+x}" ]] || \
                   [[ "${pri}" -lt "${label_priority[${lbl}]}" ]]; then
                    label_priority["${lbl}"]="${pri}"
                fi
            fi
        done
    done < <(collect_changed_files)

    # Output labels sorted by priority then alphabetically
    if [[ ${#label_priority[@]} -eq 0 ]]; then
        echo "No labels matched."
        return 0
    fi

    # Build sortable output: priority|label
    local -a output=()
    for lbl in "${!label_priority[@]}"; do
        output+=("${label_priority[${lbl}]}|${lbl}")
    done

    # Sort by priority (numeric) then label (alpha) and output just labels
    printf '%s\n' "${output[@]}" | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f2
}

# Main execution
main() {
    echo "=== PR Label Assigner ==="
    echo "Config: ${CONFIG_FILE}"
    echo ""

    local labels
    labels=$(assign_labels)

    echo "Assigned labels:"
    echo "${labels}"
    echo ""
    echo "LABELS_OUTPUT=${labels}"
}

main
