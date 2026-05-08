#!/usr/bin/env bash
#
# pr-label-assigner.sh
#
# Apply labels to a list of changed file paths based on configurable
# glob -> label mapping rules. Designed to simulate a GitHub PR
# labeling step where each rule contributes one or more labels when
# its glob pattern matches one of the changed files.
#
# Usage:
#     pr-label-assigner.sh -c CONFIG_FILE [-f FILES_FILE]
#
# CONFIG_FILE format: one rule per line, tab-separated:
#     PRIORITY<TAB>PATTERN<TAB>LABEL[,LABEL2,...]
#
# - PRIORITY is a non-negative integer; lower values rank higher
#   (so they appear earlier in the output).
# - PATTERN uses bash extended glob syntax. `*` matches any string
#   (including `/`), `?` matches one character, `**` matches recursively.
# - LABEL list is comma-separated; whitespace around each label is
#   trimmed.
# - Lines starting with `#` and blank lines are ignored.
#
# FILES_FILE is one path per line; if omitted, paths are read from stdin.
#
# Output: one label per line, deduplicated. When the same label is
# produced by multiple rules, the smallest priority value wins.
# Labels are emitted in ascending priority order; ties are broken
# alphabetically. Exit code is 0 on success, 2 on usage / config errors.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: pr-label-assigner.sh -c CONFIG_FILE [-f FILES_FILE]

Reads a list of changed file paths from FILES_FILE (or stdin), matches
each against rules in CONFIG_FILE, and prints the deduplicated set of
applicable labels (priority-sorted, one per line).

Options:
  -c, --config FILE   Path to the rules config (required).
  -f, --files  FILE   Path to the changed-files list (default: stdin).
  -h, --help          Show this help and exit.

Config format (TAB-separated):
  PRIORITY<TAB>PATTERN<TAB>LABEL[,LABEL2,...]
  # Comments and blank lines are ignored.
  # Lower PRIORITY value = higher priority (printed first).
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

config=""
files_file=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            config="$2"
            shift 2
            ;;
        -f|--files)
            [[ $# -ge 2 ]] || die "Missing value for $1"
            files_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ -n "$config" ]] || die "-c CONFIG_FILE is required (see --help)"
[[ -f "$config" ]] || die "Config file not found: $config"

# Load changed file paths.
declare -a changed_files=()
if [[ -n "$files_file" ]]; then
    [[ -f "$files_file" ]] || die "Files list not found: $files_file"
    mapfile -t changed_files < "$files_file"
else
    if [[ ! -t 0 ]]; then
        mapfile -t changed_files
    fi
fi

# Parse config into parallel arrays.
declare -a r_prio=() r_pat=() r_labels=()
lineno=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    lineno=$((lineno + 1))
    # Strip trailing CR (handle CRLF input gracefully).
    raw_line="${raw_line%$'\r'}"
    # Skip blank lines and comments.
    [[ -z "${raw_line//[[:space:]]/}" ]] && continue
    case "$raw_line" in \#*) continue ;; esac

    # Split on TAB into exactly 3 fields.
    IFS=$'\t' read -r prio pat labels <<< "$raw_line"
    if [[ -z "${prio:-}" || -z "${pat:-}" || -z "${labels:-}" ]]; then
        die "Malformed rule on line $lineno of $config (expected PRIORITY<TAB>PATTERN<TAB>LABELS)"
    fi
    if ! [[ "$prio" =~ ^[0-9]+$ ]]; then
        die "Priority must be a non-negative integer on line $lineno (got '$prio')"
    fi
    r_prio+=("$prio")
    r_pat+=("$pat")
    r_labels+=("$labels")
done < "$config"

# Match each changed file against each rule. For every match, record
# (priority, label) pairs. We later collapse duplicates keeping the
# minimum priority per label.
declare -A best_prio=()
for f in "${changed_files[@]}"; do
    [[ -z "$f" ]] && continue
    # Strip trailing CR if present (paths from CRLF files).
    f="${f%$'\r'}"
    for i in "${!r_pat[@]}"; do
        pat="${r_pat[$i]}"
        # shellcheck disable=SC2053  # we WANT pattern matching, not a literal compare.
        if [[ "$f" == $pat ]]; then
            IFS=',' read -ra labs <<< "${r_labels[$i]}"
            for lab in "${labs[@]}"; do
                # Trim surrounding whitespace.
                lab="${lab#"${lab%%[![:space:]]*}"}"
                lab="${lab%"${lab##*[![:space:]]}"}"
                [[ -z "$lab" ]] && continue
                cur="${best_prio[$lab]:-}"
                if [[ -z "$cur" || "${r_prio[$i]}" -lt "$cur" ]]; then
                    best_prio[$lab]="${r_prio[$i]}"
                fi
            done
        fi
    done
done

# Emit deduplicated labels sorted by (priority asc, label asc).
if [[ ${#best_prio[@]} -eq 0 ]]; then
    exit 0
fi
for lab in "${!best_prio[@]}"; do
    printf '%s\t%s\n' "${best_prio[$lab]}" "$lab"
done | sort -k1,1n -k2,2 | cut -f2-
