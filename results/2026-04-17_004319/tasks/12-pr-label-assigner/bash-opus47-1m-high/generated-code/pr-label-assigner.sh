#!/usr/bin/env bash
#
# pr-label-assigner.sh
#
# Given a list of changed file paths and a label-rule config, emit the set of
# labels that should be applied (one per line, deduplicated, sorted by name
# unless --order priority is given).
#
# Config format (one rule per line):
#   <glob-pattern>:<label1>[,<label2>...][:<priority>]
#
#   - lines starting with "#" and blank lines are ignored
#   - <glob-pattern> uses shell-style globs:
#       *      = any chars except "/"
#       **     = any chars including "/"
#       ?      = any single char except "/"
#   - <priority> is an integer. Lower = higher priority. Default 100.
#
# Output: one label per line (sorted alphabetically by default).

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: pr-label-assigner.sh --config <file> --files <file|-> [--order name|priority]

  --config FILE   Path to the label-rule config.
  --files  FILE   Path to a newline-separated list of changed files; "-" reads stdin.
  --order  KIND   Output ordering: "name" (default) or "priority" (lowest first).
  --help          Show this message.
USAGE
}

# Convert a shell-style glob into a POSIX ERE so we can match with [[ =~ ]].
# Order matters: handle ** before * so it doesn't get split.
glob_to_regex() {
  local glob="$1"
  local out=""
  local i=0
  local len=${#glob}
  local c
  while (( i < len )); do
    c="${glob:i:1}"
    case "$c" in
      '*')
        if (( i + 1 < len )) && [[ "${glob:i+1:1}" == "*" ]]; then
          out+=".*"
          i=$((i + 2))
          continue
        else
          out+="[^/]*"
        fi
        ;;
      '?')
        out+="[^/]"
        ;;
      '.'|'+'|'('|')'|'|'|'^'|'$'|'{'|'}'|'['|']')
        out+="\\${c}"
        ;;
      $'\\')
        out+="\\\\"
        ;;
      *)
        out+="$c"
        ;;
    esac
    i=$((i + 1))
  done
  printf '^%s$' "$out"
}

main() {
  local config=""
  local files=""
  local order="name"

  while (( $# > 0 )); do
    case "$1" in
      --config) config="${2:-}"; shift 2 ;;
      --files)  files="${2:-}";  shift 2 ;;
      --order)  order="${2:-}";  shift 2 ;;
      --help|-h) usage; return 0 ;;
      *) printf 'error: unknown argument: %s\n' "$1" >&2; usage >&2; return 2 ;;
    esac
  done

  if [[ -z "$config" ]]; then
    printf 'error: --config is required\n' >&2
    usage >&2
    return 2
  fi
  if [[ ! -f "$config" ]]; then
    printf 'error: config file not found: %s\n' "$config" >&2
    return 2
  fi
  if [[ -z "$files" ]]; then
    printf 'error: --files is required\n' >&2
    usage >&2
    return 2
  fi
  if [[ "$order" != "name" && "$order" != "priority" ]]; then
    printf 'error: --order must be "name" or "priority"\n' >&2
    return 2
  fi

  # Load file list (from stdin if "-").
  local file_list
  if [[ "$files" == "-" ]]; then
    file_list="$(cat)"
  else
    if [[ ! -f "$files" ]]; then
      printf 'error: files list not found: %s\n' "$files" >&2
      return 2
    fi
    file_list="$(cat "$files")"
  fi

  # Parse config into parallel arrays: regex / labels-csv / priority.
  local -a regexes=() labels_csv=() priorities=()
  local raw_line pattern label_field prio_field labels rest
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    # strip trailing CR if config has CRLF endings
    raw_line="${raw_line%$'\r'}"
    # trim leading/trailing whitespace
    raw_line="${raw_line#"${raw_line%%[![:space:]]*}"}"
    raw_line="${raw_line%"${raw_line##*[![:space:]]}"}"
    [[ -z "$raw_line" ]] && continue
    [[ "$raw_line" == \#* ]] && continue

    # split on ":" — at most three fields
    pattern="${raw_line%%:*}"
    rest="${raw_line#*:}"
    if [[ "$rest" == "$raw_line" ]]; then
      printf 'error: malformed rule (no label): %s\n' "$raw_line" >&2
      return 2
    fi
    if [[ "$rest" == *:* ]]; then
      label_field="${rest%%:*}"
      prio_field="${rest#*:}"
    else
      label_field="$rest"
      prio_field="100"
    fi
    # validate priority is an integer
    if ! [[ "$prio_field" =~ ^-?[0-9]+$ ]]; then
      printf 'error: invalid priority "%s" in rule: %s\n' "$prio_field" "$raw_line" >&2
      return 2
    fi
    labels="$label_field"
    regexes+=("$(glob_to_regex "$pattern")")
    labels_csv+=("$labels")
    priorities+=("$prio_field")
  done < "$config"

  # Walk each file × each rule, accumulating (label, priority) pairs.
  # Use an associative array to dedup labels and track best (lowest) priority.
  declare -A best_prio=()
  local f rgx i lab
  while IFS= read -r f || [[ -n "$f" ]]; do
    f="${f%$'\r'}"
    [[ -z "$f" ]] && continue
    for (( i=0; i < ${#regexes[@]}; i++ )); do
      rgx="${regexes[i]}"
      if [[ "$f" =~ $rgx ]]; then
        IFS=',' read -ra labs <<< "${labels_csv[i]}"
        for lab in "${labs[@]}"; do
          # trim whitespace from each label
          lab="${lab#"${lab%%[![:space:]]*}"}"
          lab="${lab%"${lab##*[![:space:]]}"}"
          [[ -z "$lab" ]] && continue
          if [[ -z "${best_prio[$lab]+x}" ]] || (( priorities[i] < best_prio[$lab] )); then
            best_prio["$lab"]="${priorities[i]}"
          fi
        done
      fi
    done
  done <<< "$file_list"

  # Emit results in the requested order.
  if (( ${#best_prio[@]} == 0 )); then
    return 0
  fi

  if [[ "$order" == "priority" ]]; then
    # Sort by priority asc, then label asc as tiebreaker.
    for lab in "${!best_prio[@]}"; do
      printf '%s\t%s\n' "${best_prio[$lab]}" "$lab"
    done | sort -k1,1n -k2,2 | cut -f2-
  else
    printf '%s\n' "${!best_prio[@]}" | LC_ALL=C sort -u
  fi
}

main "$@"
