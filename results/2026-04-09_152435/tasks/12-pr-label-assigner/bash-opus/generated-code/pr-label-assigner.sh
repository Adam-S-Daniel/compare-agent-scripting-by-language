#!/usr/bin/env bash
# PR Label Assigner
#
# Given a list of changed file paths and a config of path-to-label mapping rules,
# applies labels based on glob pattern matching. Supports:
# - Glob patterns (e.g., docs/**, src/api/**, *.test.*)
# - Multiple labels per file
# - Priority ordering when rules conflict (lower index = higher priority)
#
# Usage:
#   pr-label-assigner.sh --config <config-file> --files <files-file>
#   pr-label-assigner.sh --config <config-file> --files-stdin
#
# Config format (one rule per line, priority = line order, first = highest):
#   <glob-pattern>:<label>
#
# Output: one label per line, sorted, deduplicated

set -euo pipefail

# Print an error message and exit
die() {
  echo "ERROR: $1" >&2
  exit 1
}

# Print usage info
usage() {
  cat <<'EOF'
Usage: pr-label-assigner.sh --config <config-file> --files <files-file>
       pr-label-assigner.sh --config <config-file> --files-stdin

Options:
  --config <file>   Path to label config file (glob:label, one per line)
  --files <file>    Path to file containing changed file paths (one per line)
  --files-stdin     Read changed file paths from stdin
  --max-labels <n>  Maximum number of labels to output (uses priority order)
  -h, --help        Show this help message
EOF
}

# Match a file path against a glob pattern
# Uses bash extglob and fnmatch-style matching
# Supports: **, *, ?, and character classes
match_glob() {
  local pattern="$1"
  local filepath="$2"

  # If pattern has no directory separators, match against basename only
  # This means *.ts matches src/foo.ts, *.test.* matches src/app.test.js
  local match_target="$filepath"
  if [[ "$pattern" != */* ]]; then
    match_target="${filepath##*/}"
  fi

  local regex
  regex=$(glob_to_regex "$pattern")

  if [[ "$match_target" =~ ^${regex}$ ]]; then
    return 0
  fi
  return 1
}

# Convert a glob pattern to a regex
glob_to_regex() {
  local glob="$1"
  local regex=""
  local i=0
  local len=${#glob}

  while (( i < len )); do
    local c="${glob:$i:1}"
    case "$c" in
      '*')
        if (( i + 1 < len )) && [[ "${glob:$((i+1)):1}" == "*" ]]; then
          # ** matches any path segments
          if (( i + 2 < len )) && [[ "${glob:$((i+2)):1}" == "/" ]]; then
            regex+="(.+/)?"
            i=$((i + 3))
          else
            regex+=".*"
            i=$((i + 2))
          fi
        else
          # * matches anything except /
          regex+="[^/]*"
          i=$((i + 1))
        fi
        ;;
      '?')
        regex+="[^/]"
        i=$((i + 1))
        ;;
      '.')
        regex+="\\."
        i=$((i + 1))
        ;;
      '[')
        # Pass through character classes
        regex+="["
        i=$((i + 1))
        ;;
      ']')
        regex+="]"
        i=$((i + 1))
        ;;
      '/')
        regex+="/"
        i=$((i + 1))
        ;;
      *)
        regex+="$c"
        i=$((i + 1))
        ;;
    esac
  done

  echo "$regex"
}

# Parse the config file and return rules as pattern:label pairs
# Rules are returned in priority order (first line = highest priority)
parse_config() {
  local config_file="$1"

  [[ -f "$config_file" ]] || die "Config file not found: $config_file"

  local line_num=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Validate format: pattern:label
    if [[ "$line" != *:* ]]; then
      die "Invalid config at line $line_num: missing ':' separator in '$line'"
    fi

    # Extract pattern and label (split on first colon)
    local pattern="${line%%:*}"
    local label="${line#*:}"

    # Trim whitespace
    pattern="$(echo "$pattern" | xargs)"
    label="$(echo "$label" | xargs)"

    [[ -n "$pattern" ]] || die "Empty pattern at line $line_num"
    [[ -n "$label" ]] || die "Empty label at line $line_num"

    echo "${pattern}:${label}"
  done < "$config_file"
}

# Main label assignment logic
# Reads rules and files, outputs matched labels
assign_labels() {
  local config_file="$1"
  local files_source="$2"  # file path or "-" for stdin
  local max_labels="${3:-0}"  # 0 = no limit

  # Parse config into arrays
  local -a patterns=()
  local -a labels=()

  while IFS=: read -r pattern label; do
    patterns+=("$pattern")
    labels+=("$label")
  done < <(parse_config "$config_file")

  if [[ ${#patterns[@]} -eq 0 ]]; then
    die "No rules found in config file"
  fi

  # Read changed files (trim leading/trailing whitespace from each path)
  local -a files=()
  if [[ "$files_source" == "-" ]]; then
    while IFS= read -r f; do
      f="$(echo "$f" | xargs)"
      [[ -n "$f" ]] && files+=("$f")
    done
  else
    [[ -f "$files_source" ]] || die "Files list not found: $files_source"
    while IFS= read -r f; do
      f="$(echo "$f" | xargs)"
      [[ -n "$f" ]] && files+=("$f")
    done < "$files_source"
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    die "No changed files provided"
  fi

  # Match files against rules, collecting labels in priority order
  # Use associative array for dedup, regular array for order
  local -A seen_labels=()
  local -a ordered_labels=()

  for (( r=0; r < ${#patterns[@]}; r++ )); do
    local pattern="${patterns[$r]}"
    local label="${labels[$r]}"

    for file in "${files[@]}"; do
      if match_glob "$pattern" "$file"; then
        if [[ -z "${seen_labels[$label]+x}" ]]; then
          seen_labels[$label]=1
          ordered_labels+=("$label")
        fi
        # Once a label is added, no need to check more files for same rule
        break
      fi
    done
  done

  # Apply max_labels limit (uses priority order)
  local count=0
  for label in "${ordered_labels[@]}"; do
    if [[ "$max_labels" -gt 0 && "$count" -ge "$max_labels" ]]; then
      break
    fi
    echo "$label"
    count=$((count + 1))
  done
}

# Entry point
main() {
  local config_file=""
  local files_file=""
  local files_stdin=false
  local max_labels=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        [[ -n "${2:-}" ]] || die "--config requires a value"
        config_file="$2"
        shift 2
        ;;
      --files)
        [[ -n "${2:-}" ]] || die "--files requires a value"
        files_file="$2"
        shift 2
        ;;
      --files-stdin)
        files_stdin=true
        shift
        ;;
      --max-labels)
        [[ -n "${2:-}" ]] || die "--max-labels requires a value"
        max_labels="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  [[ -n "$config_file" ]] || die "Missing required --config option"

  if $files_stdin; then
    assign_labels "$config_file" "-" "$max_labels"
  elif [[ -n "$files_file" ]]; then
    assign_labels "$config_file" "$files_file" "$max_labels"
  else
    die "Must specify either --files or --files-stdin"
  fi
}

# Only run main if not being sourced (allows testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
