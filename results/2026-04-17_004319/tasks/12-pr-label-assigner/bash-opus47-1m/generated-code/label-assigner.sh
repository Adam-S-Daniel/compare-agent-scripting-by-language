#!/usr/bin/env bash
# label-assigner.sh - Assign labels to a PR based on its changed files.
#
# Usage: label-assigner.sh RULES_FILE FILES_FILE
#
# RULES_FILE - path-to-label mapping, one rule per line:
#   pattern:label[:priority]
# Lines beginning with '#' and blank lines are ignored. Priority defaults to 0.
#
# FILES_FILE - list of changed file paths, one per line. Pass "-" to read
# from stdin.
#
# Glob syntax: '*' matches within a path segment; '**' crosses segments;
# '?' matches a single non-slash char.
#
# Output: unique labels, one per line, sorted by priority descending then
# by label name ascending.

set -euo pipefail

die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: label-assigner.sh RULES_FILE FILES_FILE

  RULES_FILE  file with lines "pattern:label[:priority]"
  FILES_FILE  file with one changed path per line (or "-" for stdin)
EOF
}

# Convert a glob pattern to an ERE regex anchored at both ends.
# Handles ** (cross-segment wildcard), * (within-segment), ? (single
# non-slash char), and escapes regex metacharacters.
glob_to_regex() {
    local glob="$1"
    local len=${#glob}
    local i=0
    local out=""
    local c next
    while (( i < len )); do
        c="${glob:$i:1}"
        case "$c" in
            '*')
                next="${glob:$((i+1)):1}"
                if [[ "$next" == "*" ]]; then
                    out+=".*"
                    i=$((i+2))
                    continue
                fi
                out+="[^/]*"
                ;;
            '?')
                out+="[^/]"
                ;;
            '.'|'+'|'('|')'|'|'|'{'|'}'|'['|']'|'^'|'$'|"\\")
                out+="\\${c}"
                ;;
            *)
                out+="$c"
                ;;
        esac
        i=$((i+1))
    done
    printf '^%s$' "$out"
}

main() {
    if (( $# < 2 )); then
        usage >&2
        exit 2
    fi

    local rules_file="$1"
    local files_file="$2"

    [[ -f "$rules_file" ]] || die "rules file not found: $rules_file"
    if [[ "$files_file" != "-" ]]; then
        [[ -f "$files_file" ]] || die "files file not found: $files_file"
    fi

    # Parse rules into parallel arrays.
    local -a patterns=() labels=() priorities=() regexes=()
    local lineno=0 line pattern label priority regex
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno+1))
        # Skip blank lines and comments.
        [[ -z "${line// /}" ]] && continue
        [[ "${line#"${line%%[![:space:]]*}"}" == \#* ]] && continue

        # Split on ':' into at most 3 fields.
        IFS=':' read -r pattern label priority <<<"$line"
        if [[ -z "${pattern:-}" || -z "${label:-}" ]]; then
            die "malformed rule at $rules_file:$lineno: '$line'"
        fi
        priority="${priority:-0}"
        if ! [[ "$priority" =~ ^-?[0-9]+$ ]]; then
            die "priority must be an integer at $rules_file:$lineno: '$priority'"
        fi

        patterns+=("$pattern")
        labels+=("$label")
        priorities+=("$priority")
        regex="$(glob_to_regex "$pattern")"
        regexes+=("$regex")
    done < "$rules_file"

    if (( ${#patterns[@]} == 0 )); then
        return 0
    fi

    # Collect matched labels with their priority.
    # Associative array keyed by label -> max-priority seen.
    declare -A label_priority=()

    local filepath i
    while IFS= read -r filepath || [[ -n "$filepath" ]]; do
        [[ -z "$filepath" ]] && continue
        for (( i = 0; i < ${#regexes[@]}; i++ )); do
            if [[ "$filepath" =~ ${regexes[$i]} ]]; then
                local lbl="${labels[$i]}"
                local pri="${priorities[$i]}"
                if [[ -z "${label_priority[$lbl]:-}" ]] \
                   || (( pri > label_priority[$lbl] )); then
                    label_priority["$lbl"]="$pri"
                fi
            fi
        done
    done < <(if [[ "$files_file" == "-" ]]; then cat; else cat "$files_file"; fi)

    # Emit sorted by priority desc, then label asc.
    if (( ${#label_priority[@]} == 0 )); then
        return 0
    fi

    local key
    for key in "${!label_priority[@]}"; do
        printf '%s\t%s\n' "${label_priority[$key]}" "$key"
    done | sort -k1,1nr -k2,2 | awk -F'\t' '{print $2}'
}

main "$@"
