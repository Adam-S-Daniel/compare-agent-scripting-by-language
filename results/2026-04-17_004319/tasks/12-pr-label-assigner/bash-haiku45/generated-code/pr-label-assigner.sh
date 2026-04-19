#!/usr/bin/env bash

# PR Label Assigner - Applies labels to changed files based on configurable rules
# Usage: pr-label-assigner.sh --config <config.yaml> --files <files.txt>

set -euo pipefail

# Configuration
CONFIG_FILE=""
FILES_FILE=""

# Parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      --files)
        FILES_FILE="$2"
        shift 2
        ;;
      *)
        echo "Error: Unknown option $1" >&2
        exit 1
        ;;
    esac
  done
}

# Validate required arguments
validate_args() {
  if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: --config argument is required" >&2
    exit 1
  fi

  if [[ -z "$FILES_FILE" ]]; then
    echo "Error: --files argument is required" >&2
    exit 1
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  if [[ ! -f "$FILES_FILE" ]]; then
    echo "Error: Files file not found: $FILES_FILE" >&2
    exit 1
  fi
}

# Simple YAML rule parser - extracts pattern, labels, and priority from config
# Expects format:
# rules:
#   - pattern: "pattern"
#     labels:
#       - label1
#       - label2
#     priority: 1
parse_yaml_rules() {
  local config_file="$1"
  local current_pattern=""
  local current_priority=""
  local current_labels=()
  local in_labels_section=0

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Strip leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip 'rules:' line
    [[ "$line" == "rules:" ]] && continue

    # Skip rule start marker
    [[ "$line" == "-" ]] && continue

    # Parse pattern (handles "- pattern: " syntax)
    if [[ "$line" =~ ^-\ pattern:\ \"(.*)\"$ ]] || [[ "$line" =~ ^pattern:\ \"(.*)\"$ ]]; then
      current_pattern="${BASH_REMATCH[1]}"
      current_labels=()
      in_labels_section=0
      continue
    fi

    # Parse labels section start
    if [[ "$line" =~ ^-?\ *labels: ]] || [[ "$line" == "labels:" ]]; then
      in_labels_section=1
      current_labels=()
      continue
    fi

    # Parse label items
    if [[ "$in_labels_section" == 1 ]]; then
      if [[ "$line" =~ ^-\ \"(.*)\"$ ]]; then
        current_labels+=("${BASH_REMATCH[1]}")
        continue
      elif [[ "$line" =~ ^-\ (.+)$ ]]; then
        current_labels+=("${BASH_REMATCH[1]}")
        continue
      elif [[ ! "$line" =~ ^- ]]; then
        # End of labels section
        in_labels_section=0
      fi
    fi

    # Parse priority - when we see it, output the complete rule
    if [[ "$line" =~ ^priority:\ ([0-9]+)$ ]]; then
      current_priority="${BASH_REMATCH[1]}"

      if [[ -n "$current_pattern" ]]; then
        echo "$current_pattern|$current_priority|$(IFS=,; echo "${current_labels[*]}")"
      fi

      current_pattern=""
      current_priority=""
      current_labels=()
      in_labels_section=0
    fi
  done < "$config_file"
}

# Check if a file matches a glob pattern
# Supports patterns like: docs/**, src/api/**, *.test.*
matches_pattern() {
  local file="$1"
  local pattern="$2"

  # Handle ** patterns (directory wildcards)
  if [[ "$pattern" == *"**"* ]]; then
    # Pattern ends with **: check if file starts with prefix
    if [[ "$pattern" == *"/**" ]]; then
      local prefix="${pattern%/**}"
      [[ "$file" == "${prefix}"/* ]] && return 0
      return 1
    fi

    # Pattern contains ** elsewhere: convert to regex
    local regex="${pattern//\*/.*}"
    [[ "$file" =~ ^${regex}$ ]] && return 0
    return 1
  fi

  # Regular glob pattern without **
  # shellcheck disable=SC2053
  [[ "$file" == $pattern ]]
}

# Process files and collect labels
process_files() {
  local config_file="$1"
  local files_file="$2"
  local -a all_labels=()
  local -a rules=()

  # Parse all rules from config
  while IFS='|' read -r pattern priority labels_str; do
    rules+=("$pattern|$priority|$labels_str")
  done < <(parse_yaml_rules "$config_file")

  # Process each file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local -a file_labels=()

    # Check file against all rules
    for rule in "${rules[@]}"; do
      IFS='|' read -r pattern priority labels_str <<< "$rule"

      if matches_pattern "$file" "$pattern"; then
        # Split labels and add to array
        IFS=',' read -ra labels_array <<< "$labels_str"
        for label in "${labels_array[@]}"; do
          file_labels+=("$label")
        done
      fi
    done

    # Add file's labels to overall list
    all_labels+=("${file_labels[@]}")
  done < "$files_file"

  # Deduplicate and sort labels
  if [[ ${#all_labels[@]} -gt 0 ]]; then
    printf '%s\n' "${all_labels[@]}" | sort -u | while read -r label; do
      echo "$label"
    done
  fi
}

# Main execution
main() {
  parse_args "$@"
  validate_args
  process_files "$CONFIG_FILE" "$FILES_FILE"
}

main "$@"
