#!/usr/bin/env bash

# Secret Rotation Validator
# Identifies expired or expiring secrets and generates rotation reports
# Supports multiple output formats (JSON, markdown)

set -euo pipefail

# Default configuration
DEFAULT_WARNING_DAYS=7
OUTPUT_FORMAT="json"
CONFIG_FILE=""
WARNING_DAYS=$DEFAULT_WARNING_DAYS

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --warning-days)
      WARNING_DAYS="$2"
      shift 2
      ;;
    *)
      CONFIG_FILE="$1"
      shift
      ;;
  esac
done

# Validate configuration file
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Error: Configuration file required" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Configuration file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Get today's date
today=$(date +%Y-%m-%d)
today_epoch=$(date -d "$today" +%s)

# Function to calculate days since a date
days_since() {
  local date="$1"
  local date_epoch
  date_epoch=$(date -d "$date" +%s)
  echo $(( (today_epoch - date_epoch) / 86400 ))
}

# Function to convert JSON to simpler format for processing
parse_config() {
  jq -r '.secrets | to_entries | .[] | "\(.value.name)|\(.value.last_rotated)|\(.value.rotation_policy_days)|\(.value.required_by | join(","))"' "$CONFIG_FILE"
}

# Function to categorize secret status
categorize_secret() {
  local name="$1"
  local last_rotated="$2"
  local rotation_policy="$3"
  local required_by="$4"

  local days_elapsed
  days_elapsed=$(days_since "$last_rotated")
  local days_remaining=$(( rotation_policy - days_elapsed ))

  local urgency="ok"
  if [[ $days_remaining -lt 0 ]]; then
    urgency="expired"
  elif [[ $days_remaining -le $WARNING_DAYS ]]; then
    urgency="warning"
  fi

  echo "$urgency|$name|$last_rotated|$rotation_policy|$days_elapsed|$days_remaining|$required_by"
}

# Function to output JSON format
output_json() {
  local -a expired=()
  local -a warning=()
  local -a ok=()

  while IFS='|' read -r name last_rotated rotation_policy required_by; do
    local categorized
    categorized=$(categorize_secret "$name" "$last_rotated" "$rotation_policy" "$required_by")
    local IFS='|'
    read -r urgency sec_name sec_rotated sec_policy sec_days sec_remaining sec_services <<< "$categorized"

    case "$urgency" in
      expired)
        expired+=("{\"name\":\"$sec_name\",\"last_rotated\":\"$sec_rotated\",\"days_since_rotation\":$sec_days,\"rotation_policy_days\":$sec_policy,\"required_by\":\"$sec_services\"}")
        ;;
      warning)
        warning+=("{\"name\":\"$sec_name\",\"last_rotated\":\"$sec_rotated\",\"days_since_rotation\":$sec_days,\"rotation_policy_days\":$sec_policy,\"required_by\":\"$sec_services\"}")
        ;;
      ok)
        ok+=("{\"name\":\"$sec_name\",\"last_rotated\":\"$sec_rotated\",\"days_since_rotation\":$sec_days,\"rotation_policy_days\":$sec_policy,\"required_by\":\"$sec_services\"}")
        ;;
    esac
  done < <(parse_config)

  # Output JSON report
  echo "{"
  echo "  \"report\": {"
  echo "    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "    \"warning_window_days\": $WARNING_DAYS,"
  echo "    \"expired\": ["
  if [[ ${#expired[@]} -gt 0 ]]; then
    printf '      %s' "${expired[0]}"
    for i in "${!expired[@]}"; do
      [[ $i -eq 0 ]] && continue
      printf ',\n      %s' "${expired[$i]}"
    done
    echo ""
  fi
  echo "    ],"
  echo "    \"warning\": ["
  if [[ ${#warning[@]} -gt 0 ]]; then
    printf '      %s' "${warning[0]}"
    for i in "${!warning[@]}"; do
      [[ $i -eq 0 ]] && continue
      printf ',\n      %s' "${warning[$i]}"
    done
    echo ""
  fi
  echo "    ],"
  echo "    \"ok\": ["
  if [[ ${#ok[@]} -gt 0 ]]; then
    printf '      %s' "${ok[0]}"
    for i in "${!ok[@]}"; do
      [[ $i -eq 0 ]] && continue
      printf ',\n      %s' "${ok[$i]}"
    done
    echo ""
  fi
  echo "    ]"
  echo "  }"
  echo "}"
}

# Function to output markdown format
output_markdown() {
  local -a rows=()

  while IFS='|' read -r name last_rotated rotation_policy required_by; do
    local categorized
    categorized=$(categorize_secret "$name" "$last_rotated" "$rotation_policy" "$required_by")
    local IFS='|'
    read -r urgency sec_name sec_rotated sec_policy sec_days sec_remaining sec_services <<< "$categorized"

    rows+=("| $sec_name | $sec_rotated | $sec_days | $sec_remaining | $sec_policy | $urgency |")
  done < <(parse_config)

  # Output markdown report
  echo "# Secret Rotation Report"
  echo ""
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  echo "**Warning Window:** $WARNING_DAYS days"
  echo ""
  echo "| Name | Last Rotated | Days Since | Days Remaining | Policy (days) | Urgency |"
  echo "|------|--------------|-----------|----------------|---------------|---------|"
  for row in "${rows[@]}"; do
    echo "$row"
  done
}

# Main execution
case "$OUTPUT_FORMAT" in
  json)
    output_json
    ;;
  markdown)
    output_markdown
    ;;
  *)
    echo "Error: Unsupported output format: $OUTPUT_FORMAT" >&2
    exit 1
    ;;
esac
