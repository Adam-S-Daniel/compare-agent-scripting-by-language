#!/usr/bin/env bash
#
# pr-label-assigner.sh
#
# Reads a configuration of glob-to-label rules and a list of changed file
# paths (one per line), then prints the deduplicated set of labels that the
# rules assign. Labels are emitted highest-priority first; ties break
# alphabetically. Each rule line is `<priority>:<glob>:<label>`. Lines
# beginning with `#` and blank lines are ignored.
#
# Usage:
#   pr-label-assigner.sh --config <rules-file> --files <files-list>

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pr-label-assigner.sh --config <rules-file> --files <files-list>

  --config FILE   path to rules config (lines: <priority>:<glob>:<label>)
  --files  FILE   path to list of changed files (one per line)
  -h, --help      show this help

Output: deduplicated labels, sorted by descending priority then label name,
        one per line.
EOF
}

die() {
  printf 'pr-label-assigner: %s\n' "$1" >&2
  exit 2
}

# Translate a glob (supporting ** and *) to a POSIX-ERE regex anchored
# with ^...$. Used because bash's [[ == ]] handling of ** is unreliable
# across versions; an explicit translation keeps semantics predictable.
glob_to_regex() {
  local glob="$1"
  local re=""
  local i=0
  local len=${#glob}
  local c next2 next3
  while [ "$i" -lt "$len" ]; do
    c="${glob:$i:1}"
    next2="${glob:$i:2}"
    next3="${glob:$i:3}"
    if [ "$next3" = "**/" ]; then
      # zero-or-more path components, including the trailing slash
      re+='(.*/)?'
      i=$((i + 3))
    elif [ "$next2" = "**" ]; then
      re+='.*'
      i=$((i + 2))
    elif [ "$c" = "*" ]; then
      re+='[^/]*'
      i=$((i + 1))
    elif [ "$c" = "?" ]; then
      re+='[^/]'
      i=$((i + 1))
    else
      # Escape regex metacharacters so the literal glob char becomes
      # a literal regex char. Backslash handled separately to dodge an
      # SC1003 warning about a backslash inside a case pattern.
      if [ "$c" = $'\\' ]; then
        re+="\\\\"
      else
        case "$c" in
          '.'|'+'|'('|')'|'{'|'}'|'^'|'$'|'|'|'['|']') re+="\\${c}" ;;
          *) re+="$c" ;;
        esac
      fi
      i=$((i + 1))
    fi
  done
  printf '^%s$' "$re"
}

main() {
  local config="" files=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --config) config="${2:-}"; shift 2 ;;
      --files)  files="${2:-}";  shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "unknown argument: $1" ;;
    esac
  done

  if [ -z "$config" ] || [ -z "$files" ]; then
    usage >&2
    exit 2
  fi
  [ -r "$config" ] || die "config file not found or unreadable: $config"
  [ -r "$files" ]  || die "files list not found or unreadable: $files"

  # Parse rules. Each retained rule becomes a row "<priority>\t<regex>\t<label>".
  local rules=()
  local lineno=0
  local raw priority glob label re
  while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    # strip leading/trailing whitespace
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    [ -z "$raw" ] && continue
    case "$raw" in '#'*) continue ;; esac
    # Split into 3 fields on ':'.
    if [[ "$raw" != *:*:* ]]; then
      die "invalid rule on line $lineno of $config: $raw"
    fi
    priority="${raw%%:*}"
    local rest="${raw#*:}"
    glob="${rest%:*}"
    label="${rest##*:}"
    if ! [[ "$priority" =~ ^-?[0-9]+$ ]]; then
      die "invalid priority on line $lineno of $config: $raw"
    fi
    if [ -z "$glob" ] || [ -z "$label" ]; then
      die "invalid rule on line $lineno of $config: $raw"
    fi
    re="$(glob_to_regex "$glob")"
    rules+=("${priority}"$'\t'"${re}"$'\t'"${label}")
  done < "$config"

  # For each (file, rule) pair, emit "<priority>\t<label>" if the file
  # matches the rule. Then sort by descending priority then label, dedup.
  local f rule p lab
  local matches=()
  while IFS= read -r f || [ -n "$f" ]; do
    f="${f#"${f%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    [ -z "$f" ] && continue
    for rule in "${rules[@]}"; do
      p="${rule%%$'\t'*}"
      local tail="${rule#*$'\t'}"
      re="${tail%$'\t'*}"
      lab="${tail##*$'\t'}"
      if [[ "$f" =~ $re ]]; then
        matches+=("${p}"$'\t'"${lab}")
      fi
    done
  done < "$files"

  [ "${#matches[@]}" -eq 0 ] && return 0

  # Reduce to one row per label, keeping the maximum priority seen.
  printf '%s\n' "${matches[@]}" \
    | awk -F'\t' '
        { if (!($2 in best) || $1 > best[$2]) best[$2] = $1 }
        END { for (l in best) printf "%s\t%s\n", best[l], l }
      ' \
    | sort -t$'\t' -k1,1nr -k2,2 \
    | cut -f2-
}

main "$@"
