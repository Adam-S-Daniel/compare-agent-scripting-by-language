#!/usr/bin/env bash
# pr-label-assigner.sh
#
# Given a list of changed file paths and a configuration file mapping
# glob patterns to labels (with priorities), produce the deduplicated set
# of labels that should be applied. Labels are emitted in priority order
# (lower priority value first), with ties broken by first-occurrence.
#
# Config format (one rule per line, '#' for comments):
#   <priority>|<glob-pattern>|<label1>[,<label2>...]
#
# Example:
#   10|docs/**|documentation
#   20|src/api/**|api,backend
#   30|*.test.*|tests
#
# Usage:
#   pr-label-assigner.sh --config RULES --files CHANGED_FILES
#
# The glob matcher supports `**` (any number of path segments) using
# bash's globstar option together with extglob.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: pr-label-assigner.sh --config RULES --files CHANGED_FILES

Options:
  --config FILE   Path to rule configuration file.
  --files FILE    Path to file containing changed paths, one per line.
  --help          Show this message.

Output: deduplicated labels, one per line, ordered by best priority.
EOF
}

err() {
    printf 'pr-label-assigner: %s\n' "$*" >&2
}

config=""
files=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) config="${2:-}"; shift 2 ;;
        --files)  files="${2:-}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$config" ]]; then err "missing --config"; exit 2; fi
if [[ -z "$files" ]]; then err "missing --files"; exit 2; fi
if [[ ! -r "$config" ]]; then err "cannot read config file: $config"; exit 2; fi
if [[ ! -r "$files" ]];  then err "cannot read files list: $files"; exit 2; fi

# Enable globstar so `**` matches across path segments in pattern matching.
shopt -s globstar extglob nullglob

# Parse rules into parallel arrays.
priorities=()
patterns=()
labelsets=()
lineno=0
while IFS= read -r raw || [[ -n "$raw" ]]; do
    lineno=$((lineno + 1))
    # strip trailing CR (in case of CRLF input)
    raw="${raw%$'\r'}"
    # skip blank/comment lines
    [[ -z "${raw// /}" ]] && continue
    [[ "$raw" =~ ^[[:space:]]*# ]] && continue

    # Validate format: <int>|<pattern>|<labels>
    if [[ ! "$raw" =~ ^[[:space:]]*([0-9]+)\|([^|]+)\|([^|]+)[[:space:]]*$ ]]; then
        err "invalid rule on line $lineno of $config: $raw"
        exit 1
    fi
    priorities+=("${BASH_REMATCH[1]}")
    patterns+=("${BASH_REMATCH[2]}")
    labelsets+=("${BASH_REMATCH[3]}")
done <"$config"

# match_path PATTERN PATH -> exit 0 if PATH matches PATTERN, else 1.
# Uses bash extended pathname matching with globstar enabled.
match_path() {
    local pattern="$1" path="$2"
    # shellcheck disable=SC2053  # we want glob match, not literal
    [[ "$path" == $pattern ]]
}

# For each label, track the best (lowest) priority and its first-seen order
# so we can emit a deterministic, priority-sorted, deduplicated list.
declare -A best_priority=()
declare -A first_order=()
order_counter=0

# Walk rules in declared order; for each rule, check every changed file.
n_rules=${#priorities[@]}
while IFS= read -r path || [[ -n "$path" ]]; do
    path="${path%$'\r'}"
    [[ -z "$path" ]] && continue
    for ((i = 0; i < n_rules; i++)); do
        if match_path "${patterns[i]}" "$path"; then
            prio="${priorities[i]}"
            IFS=',' read -ra labels <<<"${labelsets[i]}"
            for lbl in "${labels[@]}"; do
                # trim whitespace
                lbl="${lbl#"${lbl%%[![:space:]]*}"}"
                lbl="${lbl%"${lbl##*[![:space:]]}"}"
                [[ -z "$lbl" ]] && continue
                if [[ -z "${best_priority[$lbl]:-}" ]] || (( prio < best_priority[$lbl] )); then
                    best_priority[$lbl]="$prio"
                fi
                if [[ -z "${first_order[$lbl]:-}" ]]; then
                    first_order[$lbl]="$order_counter"
                    order_counter=$((order_counter + 1))
                fi
            done
        fi
    done
done <"$files"

# Emit labels sorted by (priority asc, first-seen asc).
if (( ${#best_priority[@]} == 0 )); then
    exit 0
fi

for lbl in "${!best_priority[@]}"; do
    printf '%s\t%s\t%s\n' "${best_priority[$lbl]}" "${first_order[$lbl]}" "$lbl"
done | sort -k1,1n -k2,2n | cut -f3-
