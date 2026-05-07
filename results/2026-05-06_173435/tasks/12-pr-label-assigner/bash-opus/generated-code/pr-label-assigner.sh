#!/usr/bin/env bash
# PR Label Assigner - assigns labels to changed files based on glob pattern rules
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: pr-label-assigner.sh -c <config-file> [-f <file-list>]

Options:
  -c <config-file>   Path to label rules config file (required)
  -f <file-list>     Path to file containing changed file paths, one per line
                     If omitted, reads from stdin

Config format (one rule per line):
  priority:glob_pattern:label

  priority     - integer, lower = higher priority (determines output order)
  glob_pattern - shell glob pattern (supports *, **, ?)
  label        - label string to apply

Lines starting with # are comments. Blank lines are ignored.
EOF
  exit 1
}

# Match a file path against a glob pattern supporting ** for directory traversal
glob_match() {
  local pattern="$1"
  local filepath="$2"

  # Build regex char-by-char to avoid bash parameter expansion pitfalls
  local regex=""
  local i=0
  local len=${#pattern}
  while [[ $i -lt $len ]]; do
    local c="${pattern:$i:1}"
    local next="${pattern:$((i+1)):1}"
    case "$c" in
      '*')
        if [[ "$next" == '*' ]]; then
          regex+=".*"
          i=$((i + 2))
          # Skip trailing / after **
          [[ "${pattern:$i:1}" == '/' ]] && i=$((i + 1))
          continue
        else
          regex+="[^/]*"
        fi
        ;;
      '?') regex+="[^/]" ;;
      '.') regex+="\\." ;;
      '+') regex+="\\+" ;;
      '(') regex+="\\(" ;;
      ')') regex+="\\)" ;;
      '[') regex+="\\[" ;;
      ']') regex+="\\]" ;;
      '{') regex+="\\{" ;;
      '}') regex+="\\}" ;;
      '^') regex+="\\^" ;;
      '$') regex+="\\$" ;;
      '|') regex+="\\|" ;;
      *) regex+="$c" ;;
    esac
    i=$((i + 1))
  done

  regex="^${regex}$"
  [[ "$filepath" =~ $regex ]]
}

parse_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    echo "Error: Config file not found: $config_file" >&2
    return 1
  fi

  local line_num=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))
    # Skip comments and blank lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Trim whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    local priority pattern label
    IFS=: read -r priority pattern label <<< "$line"

    if [[ -z "$priority" || -z "$pattern" || -z "$label" ]]; then
      echo "Error: Invalid rule at line $line_num: $line" >&2
      return 1
    fi

    if ! [[ "$priority" =~ ^[0-9]+$ ]]; then
      echo "Error: Priority must be an integer at line $line_num: $line" >&2
      return 1
    fi

    echo "${priority}:${pattern}:${label}"
  done < "$config_file"
}

main() {
  local config_file=""
  local file_list=""

  while getopts "c:f:h" opt; do
    case "$opt" in
      c) config_file="$OPTARG" ;;
      f) file_list="$OPTARG" ;;
      h) usage ;;
      *) usage ;;
    esac
  done

  if [[ -z "$config_file" ]]; then
    echo "Error: Config file is required (-c)" >&2
    usage
  fi

  # Parse and sort rules by priority
  local rules
  rules=$(parse_config "$config_file") || exit 1
  rules=$(echo "$rules" | sort -t: -k1 -n)

  # Read changed files
  local files=()
  if [[ -n "$file_list" ]]; then
    if [[ ! -f "$file_list" ]]; then
      echo "Error: File list not found: $file_list" >&2
      exit 1
    fi
    while IFS= read -r f || [[ -n "$f" ]]; do
      [[ -n "$f" ]] && files+=("$f")
    done < "$file_list"
  else
    while IFS= read -r f || [[ -n "$f" ]]; do
      [[ -n "$f" ]] && files+=("$f")
    done
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "Error: No changed files provided" >&2
    exit 1
  fi

  # Track labels with their best (lowest) priority for ordering
  declare -A label_priority
  local label_count=0

  for file in "${files[@]}"; do
    while IFS=: read -r priority pattern label; do
      if glob_match "$pattern" "$file"; then
        if [[ -z "${label_priority[$label]+x}" ]] || [[ "$priority" -lt "${label_priority[$label]}" ]]; then
          label_priority[$label]="$priority"
          label_count=$((label_count + 1))
        fi
      fi
    done <<< "$rules"
  done

  if [[ "$label_count" -eq 0 ]]; then
    echo "No labels matched."
    exit 0
  fi

  # Sort labels by priority then alphabetically
  local sorted_labels=()
  while IFS= read -r entry; do
    sorted_labels+=("${entry#*:}")
  done < <(
    for label in "${!label_priority[@]}"; do
      echo "${label_priority[$label]}:${label}"
    done | sort -t: -k1 -n -k2
  )

  echo "Labels:"
  for label in "${sorted_labels[@]}"; do
    echo "  - $label"
  done
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
