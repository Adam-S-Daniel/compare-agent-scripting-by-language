#!/usr/bin/env bash
# PR Label Assigner - Assigns labels to files based on configurable path-to-label mapping rules
# Supports glob patterns, multiple labels per file, and priority ordering

set -euo pipefail

# Global variables - use indexed arrays for proper iteration
declare -a config_patterns=()
declare -a config_labels=()

# Print error message to stderr and exit
die() {
  echo "Error: $*" >&2
  exit 1
}

# Parse config file: pattern:label pairs
# Each line should be in format: pattern:label
load_config() {
  local config_path="$1"

  if [[ ! -r "$config_path" ]]; then
    die "Config file not found or not readable: $config_path"
  fi

  local line_num=0
  while IFS= read -r line; do
    ((++line_num))

    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse pattern:label
    if [[ ! "$line" =~ : ]]; then
      die "Invalid config format at line $line_num: expected 'pattern:label', got '$line'"
    fi

    local pattern="${line%:*}"
    local label="${line#*:}"

    if [[ -z "$pattern" || -z "$label" ]]; then
      die "Invalid config format at line $line_num: pattern and label cannot be empty"
    fi

    config_patterns+=("$pattern")
    config_labels+=("$label")
  done < "$config_path"
}

# Check if a file path matches a glob pattern
# Returns 0 if match, 1 if no match
match_pattern() {
  local filepath="$1"
  local pattern="$2"

  # If pattern has no /, match against basename
  # Otherwise match against full path
  local match_str="$filepath"
  if [[ "$pattern" != */* ]]; then
    match_str="${filepath##*/}"
  fi

  # Build regex by processing pattern carefully
  local regex_parts=()
  local i len
  len=${#pattern}

  for ((i=0; i<len; i++)); do
    local ch="${pattern:$i:1}"

    case "$ch" in
      '*')
        # Look ahead for **
        if [[ "${pattern:$((i+1)):1}" == "*" ]]; then
          regex_parts+=(".*")
          ((i++))  # Skip the next *
        else
          # Single * - matches any characters
          regex_parts+=(".*")
        fi
        ;;
      '?')
        regex_parts+=(".")
        ;;
      '.')
        regex_parts+=("\\.")
        ;;
      '/')
        regex_parts+=("/")
        ;;
      '[' | ']' | '^' | '$' | '+' | '{' | '}' | '|' | '(' | ')')
        # Escape regex special characters
        regex_parts+=("\\$ch")
        ;;
      *)
        regex_parts+=("$ch")
        ;;
    esac
  done

  local regex_pattern
  regex_pattern="^$(printf '%s' "${regex_parts[@]}")$"
  [[ "$match_str" =~ $regex_pattern ]]
}

# Main function to assign labels
assign_labels() {
  local -a all_labels=()

  # Read file paths from stdin
  while IFS= read -r filepath; do
    # Skip empty lines
    [[ -z "$filepath" ]] && continue

    # Check each pattern in order
    for i in "${!config_patterns[@]}"; do
      local pattern="${config_patterns[$i]}"
      local label="${config_labels[$i]}"

      if match_pattern "$filepath" "$pattern"; then
        all_labels+=("$label")
      fi
    done
  done

  # Deduplicate and sort labels
  if [[ ${#all_labels[@]} -gt 0 ]]; then
    printf '%s\n' "${all_labels[@]}" | sort -u
  fi
}

# Main script entry point
main() {
  local config_file=""

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_file="$2"
        shift 2
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  # Validate config file was provided
  if [[ -z "$config_file" ]]; then
    # If no config provided, just return empty
    return 0
  fi

  # Load configuration
  load_config "$config_file"

  # Assign labels to files from stdin
  assign_labels
}

# Run main function
main "$@"
