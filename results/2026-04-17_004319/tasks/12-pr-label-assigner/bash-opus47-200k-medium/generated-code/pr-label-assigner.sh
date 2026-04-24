#!/usr/bin/env bash
# pr-label-assigner.sh
#
# Assigns labels to a pull request based on the set of changed file paths,
# using a configurable rules file of glob-pattern -> label mappings.
#
# Rules file format (one rule per line):
#   <glob-pattern>|<label>[|<priority>]
# - Lines that are blank or start with `#` are ignored.
# - `**` in a glob matches any sequence of characters including `/`.
# - `*` and `?` match anything except `/`.
# - Multiple rules may match one file (all their labels apply).
# - Labels are de-duplicated in the final output.
# - Priority is an integer (default 100); lower numbers sort earlier.
#   Among equal priorities, labels are sorted alphabetically.
#
# Usage: pr-label-assigner.sh <rules_file> <files_file>

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: pr-label-assigner.sh <rules_file> <files_file>
  rules_file : path to rules config. Each non-blank, non-# line is
               "<glob>|<label>[|<priority>]".
  files_file : newline-separated list of changed file paths.
EOF
}

# glob_to_regex <glob> -> prints an anchored POSIX-ish ERE regex.
# We translate the glob ourselves because bash's [[ == ]] pattern match
# does not treat `**` specially (it won't cross `/`).
glob_to_regex() {
  local glob=$1 out='' i ch next
  for ((i = 0; i < ${#glob}; i++)); do
    ch=${glob:i:1}
    case $ch in
      '*')
        next=${glob:i+1:1}
        if [[ $next == '*' ]]; then
          out+='.*'   # ** matches anything including /
          ((i++))
        else
          out+='[^/]*' # * matches anything except /
        fi
        ;;
      '?')
        out+='[^/]'
        ;;
      # Regex metacharacters that must be escaped to be treated literally.
      '.'|'+'|'('|')'|'{'|'}'|'['|']'|'^'|'$'|'|')
        out+="\\$ch"
        ;;
      *)
        out+=$ch
        ;;
    esac
  done
  printf '^%s$' "$out"
}

# trim leading/trailing ASCII whitespace.
trim() {
  local s=$1
  # shellcheck disable=SC2001
  s=$(printf '%s' "$s" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  printf '%s' "$s"
}

main() {
  if [[ $# -ne 2 ]]; then
    usage
    return 2
  fi

  local rules_file=$1 files_file=$2

  if [[ ! -f $rules_file ]]; then
    printf 'error: rules file not found: %s\n' "$rules_file" >&2
    return 1
  fi
  if [[ ! -f $files_file ]]; then
    printf 'error: files list not found: %s\n' "$files_file" >&2
    return 1
  fi

  # Load all changed files once (ignore blanks).
  local -a files=()
  local line
  while IFS= read -r line || [[ -n $line ]]; do
    line=$(trim "$line")
    [[ -z $line ]] && continue
    files+=("$line")
  done < "$files_file"

  # For each label we'll remember the lowest priority seen, so the
  # final sort places it correctly.
  declare -A label_prio=()

  local pattern label priority regex file
  while IFS= read -r line || [[ -n $line ]]; do
    # Strip comment and blank lines.
    local stripped
    stripped=$(trim "$line")
    [[ -z $stripped ]] && continue
    [[ ${stripped:0:1} == '#' ]] && continue

    # Split on the first two '|' separators.
    pattern=${stripped%%|*}
    local rest=${stripped#*|}
    if [[ $rest == "$stripped" ]]; then
      printf 'error: invalid rule (missing label): %s\n' "$stripped" >&2
      return 1
    fi
    if [[ $rest == *'|'* ]]; then
      label=${rest%%|*}
      priority=${rest#*|}
    else
      label=$rest
      priority=100
    fi
    pattern=$(trim "$pattern")
    label=$(trim "$label")
    priority=$(trim "$priority")

    if [[ -z $pattern || -z $label ]]; then
      printf 'error: invalid rule (empty pattern or label): %s\n' "$stripped" >&2
      return 1
    fi
    if ! [[ $priority =~ ^-?[0-9]+$ ]]; then
      printf 'error: priority must be integer in rule: %s\n' "$stripped" >&2
      return 1
    fi

    regex=$(glob_to_regex "$pattern")

    for file in "${files[@]}"; do
      if [[ $file =~ $regex ]]; then
        if [[ -z ${label_prio[$label]+x} ]] || (( priority < label_prio[$label] )); then
          label_prio[$label]=$priority
        fi
      fi
    done
  done < "$rules_file"

  # Emit labels, sorted by priority asc then name asc.
  if ((${#label_prio[@]} == 0)); then
    return 0
  fi
  local key
  for key in "${!label_prio[@]}"; do
    printf '%s\t%s\n' "${label_prio[$key]}" "$key"
  done | sort -k1,1n -k2,2 | cut -f2-
}

main "$@"
