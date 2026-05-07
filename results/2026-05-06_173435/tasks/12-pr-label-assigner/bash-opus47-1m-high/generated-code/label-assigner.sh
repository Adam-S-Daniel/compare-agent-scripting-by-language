#!/usr/bin/env bash
#
# label-assigner.sh - Assign labels to a PR based on its changed files.
#
# Reads two text files:
#   --rules <path>   one rule per line, format:  <glob> -> <label>[!]
#                    The trailing ! marks the rule as exclusive: when it
#                    matches a file, all other labels for that same file
#                    are suppressed (priority resolution).
#   --files <path>   one changed file path per line (mocked PR file list)
#
# Lines starting with # and blank lines in the rules file are ignored.
# Globs use bash [[ == ]] pattern matching, which behaves like shell
# globbing except that * matches across path separators - this gives
# us simple ** semantics without needing globstar.
#
# Output: the union of all matched labels, deduplicated and sorted, one
# per line on stdout. Errors go to stderr; exit code is non-zero on any
# usage / parse / IO error.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: label-assigner.sh --rules <rules-file> --files <files-list>

  --rules FILE   path to rules file (glob -> label[!] per line)
  --files FILE   path to list of changed files (one per line)
  --help         show this help

Rule file format:
  <glob> -> <label>          # add label when glob matches a file
  <glob> -> <label>!         # exclusive: suppress other labels for matched file
  # comments and blank lines are ignored

Outputs: deduplicated, sorted labels (one per line) for the changed files.
EOF
}

err() {
    printf 'error: %s\n' "$*" >&2
}

# Parse a single rule line into pattern, label, exclusive flag.
# Sets globals: RULE_PATTERN, RULE_LABEL, RULE_EXCLUSIVE (0/1).
# Returns non-zero if the line is malformed.
parse_rule_line() {
    local line=$1
    # Require " -> " separator. Use bash regex to extract.
    if [[ ! $line =~ ^[[:space:]]*(.+[^[:space:]])[[:space:]]+-\>[[:space:]]+(.+[^[:space:]])[[:space:]]*$ ]]; then
        return 1
    fi
    RULE_PATTERN=${BASH_REMATCH[1]}
    local rhs=${BASH_REMATCH[2]}
    if [[ $rhs == *! ]]; then
        RULE_EXCLUSIVE=1
        RULE_LABEL=${rhs%!}
    else
        RULE_EXCLUSIVE=0
        RULE_LABEL=$rhs
    fi
    # Trim any trailing whitespace from label.
    RULE_LABEL=${RULE_LABEL%"${RULE_LABEL##*[![:space:]]}"}
    [[ -n $RULE_LABEL && -n $RULE_PATTERN ]]
}

# Pattern-match a file path against a glob using bash's [[ == ]].
# Note: $pattern must remain unquoted to be treated as a pattern.
glob_match() {
    local file=$1
    local pattern=$2
    # shellcheck disable=SC2053  # intentional unquoted RHS for glob match
    [[ $file == $pattern ]]
}

main() {
    local rules_file="" files_file=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --rules)
                [[ $# -ge 2 ]] || { err "--rules requires an argument"; return 2; }
                rules_file=$2; shift 2;;
            --files)
                [[ $# -ge 2 ]] || { err "--files requires an argument"; return 2; }
                files_file=$2; shift 2;;
            --help|-h)
                usage; return 0;;
            *)
                err "unknown argument: $1"; usage >&2; return 2;;
        esac
    done

    [[ -n $rules_file ]] || { err "missing required --rules <file>"; return 2; }
    [[ -n $files_file ]] || { err "missing required --files <file>"; return 2; }
    [[ -f $rules_file ]] || { err "rules file not found: $rules_file"; return 2; }
    [[ -f $files_file ]] || { err "files list not found: $files_file"; return 2; }

    # Load rules into parallel arrays. Skip blanks and comments.
    local -a patterns=() labels=() exclusives=()
    local lineno=0 line
    while IFS= read -r line || [[ -n $line ]]; do
        lineno=$((lineno + 1))
        # Strip leading whitespace for comment / blank detection.
        local trimmed=${line#"${line%%[![:space:]]*}"}
        [[ -z $trimmed || ${trimmed:0:1} == "#" ]] && continue
        if ! parse_rule_line "$line"; then
            err "malformed rule on line $lineno of $rules_file: $line"
            return 1
        fi
        patterns+=("$RULE_PATTERN")
        labels+=("$RULE_LABEL")
        exclusives+=("$RULE_EXCLUSIVE")
    done < "$rules_file"

    # For each file, collect matching labels. If any matched rule was
    # exclusive, drop all non-exclusive labels for that file.
    local -A label_set=()
    local file
    while IFS= read -r file || [[ -n $file ]]; do
        # Trim CRLF and surrounding whitespace; skip blanks.
        file=${file%$'\r'}
        local file_trim=${file#"${file%%[![:space:]]*}"}
        [[ -z $file_trim ]] && continue

        local -a matched_labels=()
        local -a matched_exclusive=()
        local i has_exclusive=0
        for ((i=0; i<${#patterns[@]}; i++)); do
            if glob_match "$file_trim" "${patterns[i]}"; then
                matched_labels+=("${labels[i]}")
                matched_exclusive+=("${exclusives[i]}")
                if [[ ${exclusives[i]} -eq 1 ]]; then
                    has_exclusive=1
                fi
            fi
        done

        local j
        for ((j=0; j<${#matched_labels[@]}; j++)); do
            if [[ $has_exclusive -eq 1 && ${matched_exclusive[j]} -eq 0 ]]; then
                continue
            fi
            label_set["${matched_labels[j]}"]=1
        done
    done < "$files_file"

    # Print sorted, unique labels.
    if [[ ${#label_set[@]} -gt 0 ]]; then
        printf '%s\n' "${!label_set[@]}" | LC_ALL=C sort -u
    fi
}

main "$@"
