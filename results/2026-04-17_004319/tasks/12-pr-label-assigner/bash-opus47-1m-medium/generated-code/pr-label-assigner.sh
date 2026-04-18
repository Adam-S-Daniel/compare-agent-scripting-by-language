#!/usr/bin/env bash
# pr-label-assigner.sh
#
# Read a list of changed file paths and assign labels based on a
# configurable rules file of the form:
#
#   <glob-pattern><TAB><label><TAB><priority>
#
# Labels are deduplicated and emitted one per line, highest priority
# first. Comments (#) and blank lines in the rules file are ignored.
#
# Usage:
#   pr-label-assigner.sh --rules RULES --files FILES
#     FILES may be '-' to read paths from stdin.

set -euo pipefail

die() {
    echo "pr-label-assigner: $*" >&2
    exit 2
}

usage() {
    cat <<'EOF'
Usage: pr-label-assigner.sh --rules RULES_FILE --files FILE_LIST
  FILE_LIST is a newline-delimited list of paths; '-' reads from stdin.
EOF
}

# Convert a glob like 'src/api/**' or '**/*.test.*' into a bash extglob
# regex. We use a simple translator:
#   **  -> .*         (matches across slashes)
#   *   -> [^/]*      (does not cross slashes)
#   ?   -> [^/]
#   .   -> \.
glob_to_regex() {
    local glob="$1" out="" i=0 c next
    local n=${#glob}
    while (( i < n )); do
        c="${glob:i:1}"
        if [[ "$c" == "*" ]]; then
            next="${glob:i+1:1}"
            if [[ "$next" == "*" ]]; then
                out+=".*"
                i=$((i + 2))
                continue
            fi
            out+="[^/]*"
        elif [[ "$c" == "?" ]]; then
            out+="[^/]"
        elif [[ "$c" == "." ]]; then
            out+="\\."
        elif [[ "$c" =~ [\^\$\(\)\+\{\}\|\[\]\\] ]]; then
            out+="\\$c"
        else
            out+="$c"
        fi
        i=$((i + 1))
    done
    printf '^%s$' "$out"
}

main() {
    local rules="" files=""
    while (( $# > 0 )); do
        case "$1" in
            --rules) rules="${2-}"; shift 2 ;;
            --files) files="${2-}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    [[ -n "$rules" ]] || { usage >&2; die "missing --rules"; }
    [[ -n "$files" ]] || { usage >&2; die "missing --files"; }
    [[ -f "$rules" ]] || die "rules file not found: $rules"

    # Read file list.
    local paths=()
    if [[ "$files" == "-" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && paths+=("$line")
        done
    else
        [[ -f "$files" ]] || die "files list not found: $files"
        while IFS= read -r line; do
            [[ -n "$line" ]] && paths+=("$line")
        done < "$files"
    fi

    # Parse rules.
    local -a r_pattern=() r_label=() r_priority=() r_regex=()
    local line pattern label priority
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Split on tabs.
        IFS=$'\t' read -r pattern label priority <<<"$line"
        if [[ -z "${pattern:-}" || -z "${label:-}" || -z "${priority:-}" ]]; then
            die "invalid rule (expected TAB-separated pattern,label,priority): $line"
        fi
        if ! [[ "$priority" =~ ^-?[0-9]+$ ]]; then
            die "invalid priority (not an integer): $priority"
        fi
        r_pattern+=("$pattern")
        r_label+=("$label")
        r_priority+=("$priority")
        r_regex+=("$(glob_to_regex "$pattern")")
    done < "$rules"

    # Match each path against each rule, collecting (priority, label).
    local -A seen=()         # label -> highest priority seen
    local i path regex
    for path in "${paths[@]}"; do
        for i in "${!r_pattern[@]}"; do
            regex="${r_regex[i]}"
            if [[ "$path" =~ $regex ]]; then
                local lbl="${r_label[i]}"
                local pri="${r_priority[i]}"
                if [[ -z "${seen[$lbl]-}" ]] || (( pri > seen[$lbl] )); then
                    seen[$lbl]=$pri
                fi
            fi
        done
    done

    # Emit labels sorted by priority desc, then label asc for stability.
    if (( ${#seen[@]} == 0 )); then
        return 0
    fi
    local lbl
    for lbl in "${!seen[@]}"; do
        printf '%s\t%s\n' "${seen[$lbl]}" "$lbl"
    done | sort -k1,1nr -k2,2 | cut -f2-
}

main "$@"
