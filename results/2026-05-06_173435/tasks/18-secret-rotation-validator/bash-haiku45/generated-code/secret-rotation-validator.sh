#!/usr/bin/env bash

# Secret Rotation Validator - Identifies expired and expiring secrets
# TDD Implementation with comprehensive error handling

set -euo pipefail

# Global configuration
SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE=""
WARNING_DAYS=7
OUTPUT_FORMAT="markdown"
CURRENT_DATE=""

# Color codes for output (can be disabled)
# RED='\033[0;31m'
# YELLOW='\033[1;33m'
# GREEN='\033[0;32m'
# NC='\033[0m' # No Color

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Secret rotation validator - identifies expired and expiring secrets

Options:
  --config FILE              Path to JSON config file (required)
  --warning-days DAYS        Days before due date to warn (default: 7)
  --format FORMAT            Output format: markdown or json (default: markdown)
  --current-date DATE        Current date in YYYY-MM-DD format (default: today)
  --help                     Show this help message

Examples:
  $SCRIPT_NAME --config secrets.json --warning-days 7
  $SCRIPT_NAME --config secrets.json --format json --warning-days 14

EOF
}

error() {
  echo "Error: $*" >&2
  exit 1
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      --warning-days)
        WARNING_DAYS="$2"
        shift 2
        ;;
      --format)
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
      --current-date)
        CURRENT_DATE="$2"
        shift 2
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done
}

validate_config() {
  if [[ -z "$CONFIG_FILE" ]]; then
    error "Config file required (use --config)"
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Config file not found: $CONFIG_FILE"
  fi

  # Validate JSON syntax
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    error "Invalid JSON in config file: $CONFIG_FILE"
  fi
}

# Calculate number of days between two dates (YYYY-MM-DD format)
days_between() {
  local date1="$1"
  local date2="$2"
  local seconds1
  local seconds2

  # Convert to seconds since epoch and calculate difference
  seconds1=$(date -d "$date1" +%s 2>/dev/null || echo 0)
  seconds2=$(date -d "$date2" +%s 2>/dev/null || echo 0)

  if [[ $seconds1 -eq 0 || $seconds2 -eq 0 ]]; then
    error "Invalid date format. Use YYYY-MM-DD"
  fi

  echo $(( (seconds2 - seconds1) / 86400 ))
}

# Parse JSON using bash and jq if available, otherwise use regex
parse_json_config() {
  if ! command -v jq &> /dev/null; then
    error "jq is required for JSON parsing. Please install jq."
  fi

  # Return the jq command for extracting secrets in compact format (one object per line)
  jq -c '.secrets[]' "$CONFIG_FILE" 2>/dev/null || error "Failed to parse secrets from config"
}

# Check if all required fields exist in a secret
validate_secret() {
  local secret="$1"

  if ! echo "$secret" | jq -e '.name' >/dev/null 2>&1; then
    error "Secret missing required field: name"
  fi
  if ! echo "$secret" | jq -e '.last_rotated' >/dev/null 2>&1; then
    error "Secret missing required field: last_rotated"
  fi
  if ! echo "$secret" | jq -e '.rotation_policy_days' >/dev/null 2>&1; then
    error "Secret missing required field: rotation_policy_days"
  fi
}

# Determine status: EXPIRED, WARNING, or OK
get_status() {
  local last_rotated="$1"
  local policy_days="$2"
  local current_date="$3"
  local due_date
  local days_until_due

  # Calculate due date (last_rotated + policy_days)
  due_date=$(date -d "$last_rotated + $policy_days days" +%Y-%m-%d 2>/dev/null)

  # Calculate days until due
  days_until_due=$(days_between "$current_date" "$due_date")

  if [[ $days_until_due -lt 0 ]]; then
    echo "EXPIRED"
  elif [[ $days_until_due -lt $WARNING_DAYS ]]; then
    echo "WARNING"
  else
    echo "OK"
  fi
}

# Calculate days until due date
get_days_until_due() {
  local last_rotated="$1"
  local policy_days="$2"
  local current_date="$3"
  local due_date
  local days_until

  due_date=$(date -d "$last_rotated + $policy_days days" +%Y-%m-%d 2>/dev/null)
  days_until=$(days_between "$current_date" "$due_date")
  echo "$days_until"
}

# Output markdown table
output_markdown() {
  local -a expired=()
  local -a warning=()
  local -a ok=()
  local name
  local last_rotated
  local policy_days
  local required_by
  local status
  local days_until

  # Parse all secrets and categorize them
  while read -r secret; do
    validate_secret "$secret"

    name=$(echo "$secret" | jq -r '.name')
    last_rotated=$(echo "$secret" | jq -r '.last_rotated')
    policy_days=$(echo "$secret" | jq -r '.rotation_policy_days')
    required_by=$(echo "$secret" | jq -r '.required_by | join(", ")')
    status=$(get_status "$last_rotated" "$policy_days" "$CURRENT_DATE")
    days_until=$(get_days_until_due "$last_rotated" "$policy_days" "$CURRENT_DATE")

    case "$status" in
      EXPIRED)
        expired+=("$name|$status|$days_until|$last_rotated|$required_by")
        ;;
      WARNING)
        warning+=("$name|$status|$days_until|$last_rotated|$required_by")
        ;;
      OK)
        ok+=("$name|$status|$days_until|$last_rotated|$required_by")
        ;;
    esac
  done < <(parse_json_config)

  # Output grouped by urgency
  output_markdown_section "EXPIRED" "${expired[@]}"
  output_markdown_section "WARNING" "${warning[@]}"
  output_markdown_section "OK" "${ok[@]}"
}

output_markdown_section() {
  local section_name="$1"
  shift
  local -a items=("$@")

  # Only output section if it has items
  if [[ ${#items[@]} -gt 0 ]]; then
    echo ""
    echo "## $section_name"
    echo ""
    echo "| Name | Status | Days Until Due | Last Rotated | Required By |"
    echo "|------|--------|-----------------|--------------|-------------|"

    for item in "${items[@]}"; do
      echo "| $item |"
    done
  fi
}

# Output JSON
output_json() {
  local -a secrets_data=()
  local name
  local last_rotated
  local policy_days
  local required_by
  local status
  local days_until

  while read -r secret; do
    validate_secret "$secret"

    name=$(echo "$secret" | jq -r '.name')
    last_rotated=$(echo "$secret" | jq -r '.last_rotated')
    policy_days=$(echo "$secret" | jq -r '.rotation_policy_days')
    required_by=$(echo "$secret" | jq -r '.required_by')
    status=$(get_status "$last_rotated" "$policy_days" "$CURRENT_DATE")
    days_until=$(get_days_until_due "$last_rotated" "$policy_days" "$CURRENT_DATE")

    secrets_data+=("{\"name\":\"$name\",\"status\":\"$status\",\"days_until_due\":$days_until,\"last_rotated\":\"$last_rotated\",\"required_by\":$required_by}")
  done < <(parse_json_config)

  # Output JSON array
  echo "{"
  echo '  "summary": {'
  echo "    \"warning_days\": $WARNING_DAYS,"
  echo "    \"current_date\": \"$CURRENT_DATE\""
  echo "  },"
  echo '  "secrets": ['

  for i in "${!secrets_data[@]}"; do
    if [[ $i -lt $((${#secrets_data[@]} - 1)) ]]; then
      echo "${secrets_data[$i]},"
    else
      echo "${secrets_data[$i]}"
    fi
  done

  echo "  ]"
  echo "}"
}

# Placeholder for main logic
main() {
  parse_args "$@"
  validate_config

  # Set current date if not provided
  if [[ -z "$CURRENT_DATE" ]]; then
    CURRENT_DATE=$(date +%Y-%m-%d)
  fi

  # Validate current date format
  if ! date -d "$CURRENT_DATE" >/dev/null 2>&1; then
    error "Invalid current date format. Use YYYY-MM-DD"
  fi

  case "$OUTPUT_FORMAT" in
    markdown)
      output_markdown
      ;;
    json)
      output_json
      ;;
    *)
      error "Unknown output format: $OUTPUT_FORMAT"
      ;;
  esac
}

main "$@"
