#!/usr/bin/env bash
set -euo pipefail

# Validates secret rotation status against configured policies.
# Reads a JSON config of secrets with rotation metadata, categorizes each
# as expired/warning/ok, and outputs a report in markdown or JSON format.

usage() {
  cat <<'USAGE'
Usage: secret-rotation-validator.sh [OPTIONS]

Options:
  --config FILE          Path to JSON secrets config file (required)
  --warning-days N       Days before expiry to trigger warning (default: 14)
  --format FORMAT        Output format: markdown or json (default: markdown)
  --reference-date DATE  Reference date as YYYY-MM-DD (default: today)
  -h, --help             Show this help message

Config file format (JSON):
  {
    "secrets": [
      {
        "name": "SECRET_NAME",
        "last_rotated": "YYYY-MM-DD",
        "rotation_policy_days": 90,
        "required_by": ["service-a", "service-b"]
      }
    ]
  }
USAGE
}

die() {
  echo "ERROR: $1" >&2
  exit 1
}

# Force UTC to avoid DST-induced off-by-one errors in day arithmetic
date_to_epoch() {
  TZ=UTC date -d "$1" +%s 2>/dev/null || die "Invalid date: $1"
}

# Defaults
CONFIG_FILE=""
WARNING_DAYS=14
OUTPUT_FORMAT="markdown"
REFERENCE_DATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      [[ -n "${2:-}" ]] || die "--config requires a file path"
      CONFIG_FILE="$2"; shift 2 ;;
    --warning-days)
      [[ -n "${2:-}" ]] || die "--warning-days requires a number"
      [[ "$2" =~ ^[0-9]+$ ]] || die "--warning-days must be a non-negative integer"
      WARNING_DAYS="$2"; shift 2 ;;
    --format)
      [[ -n "${2:-}" ]] || die "--format requires a value"
      OUTPUT_FORMAT="$2"; shift 2 ;;
    --reference-date)
      [[ -n "${2:-}" ]] || die "--reference-date requires a date (YYYY-MM-DD)"
      REFERENCE_DATE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "Unknown option: $1" ;;
  esac
done

[[ -n "$CONFIG_FILE" ]] || die "Missing required option: --config"
[[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
[[ "$OUTPUT_FORMAT" == "markdown" || "$OUTPUT_FORMAT" == "json" ]] || \
  die "Invalid format '$OUTPUT_FORMAT'. Must be 'markdown' or 'json'"

if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  die "Config file is not valid JSON: $CONFIG_FILE"
fi

SECRET_COUNT=$(jq '.secrets | length' "$CONFIG_FILE")
[[ "$SECRET_COUNT" =~ ^[0-9]+$ ]] || die "Config file missing 'secrets' array"

if [[ -n "$REFERENCE_DATE" ]]; then
  REF_EPOCH=$(date_to_epoch "$REFERENCE_DATE")
else
  REFERENCE_DATE=$(TZ=UTC date +%Y-%m-%d)
  REF_EPOCH=$(TZ=UTC date +%s)
fi

SECONDS_PER_DAY=86400

# Arrays to hold categorized secrets as JSON fragments
EXPIRED_ITEMS=()
WARNING_ITEMS=()
OK_ITEMS=()

for i in $(seq 0 $((SECRET_COUNT - 1))); do
  NAME=$(jq -r ".secrets[$i].name" "$CONFIG_FILE")
  LAST_ROTATED=$(jq -r ".secrets[$i].last_rotated" "$CONFIG_FILE")
  POLICY_DAYS=$(jq -r ".secrets[$i].rotation_policy_days" "$CONFIG_FILE")
  REQUIRED_BY=$(jq -c ".secrets[$i].required_by" "$CONFIG_FILE")

  ROTATED_EPOCH=$(date_to_epoch "$LAST_ROTATED")
  DAYS_SINCE=$(( (REF_EPOCH - ROTATED_EPOCH) / SECONDS_PER_DAY ))
  EXPIRES_IN=$(( POLICY_DAYS - DAYS_SINCE ))

  EXPIRY_DATE=$(TZ=UTC date -d "$LAST_ROTATED + $POLICY_DAYS days" +%Y-%m-%d)

  ITEM=$(jq -n \
    --arg name "$NAME" \
    --arg last_rotated "$LAST_ROTATED" \
    --argjson policy_days "$POLICY_DAYS" \
    --argjson days_since "$DAYS_SINCE" \
    --argjson expires_in "$EXPIRES_IN" \
    --arg expiry_date "$EXPIRY_DATE" \
    --argjson required_by "$REQUIRED_BY" \
    '{
      name: $name,
      last_rotated: $last_rotated,
      rotation_policy_days: $policy_days,
      days_since_rotation: $days_since,
      expires_in_days: $expires_in,
      expiry_date: $expiry_date,
      required_by: $required_by
    }')

  if (( EXPIRES_IN < 0 )); then
    EXPIRED_ITEMS+=("$ITEM")
  elif (( EXPIRES_IN <= WARNING_DAYS )); then
    WARNING_ITEMS+=("$ITEM")
  else
    OK_ITEMS+=("$ITEM")
  fi
done

build_json_array() {
  local items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  local result="["
  for i in "${!items[@]}"; do
    [[ $i -gt 0 ]] && result+=","
    result+="${items[$i]}"
  done
  result+="]"
  echo "$result" | jq '.'
}

output_json() {
  local expired_json warning_json ok_json
  expired_json=$(build_json_array "${EXPIRED_ITEMS[@]+"${EXPIRED_ITEMS[@]}"}")
  warning_json=$(build_json_array "${WARNING_ITEMS[@]+"${WARNING_ITEMS[@]}"}")
  ok_json=$(build_json_array "${OK_ITEMS[@]+"${OK_ITEMS[@]}"}")

  jq -n \
    --arg ref_date "$REFERENCE_DATE" \
    --argjson warning_days "$WARNING_DAYS" \
    --argjson total "$SECRET_COUNT" \
    --argjson expired_count "${#EXPIRED_ITEMS[@]}" \
    --argjson warning_count "${#WARNING_ITEMS[@]}" \
    --argjson ok_count "${#OK_ITEMS[@]}" \
    --argjson expired "$expired_json" \
    --argjson warning "$warning_json" \
    --argjson ok "$ok_json" \
    '{
      report: {
        reference_date: $ref_date,
        warning_window_days: $warning_days,
        total_secrets: $total,
        summary: {
          expired: $expired_count,
          warning: $warning_count,
          ok: $ok_count
        }
      },
      expired: $expired,
      warning: $warning,
      ok: $ok
    }'
}

print_table_section() {
  local label="$1"
  shift
  local items=("$@")

  echo ""
  echo "### $label (${#items[@]})"
  echo ""
  if [[ ${#items[@]} -eq 0 ]]; then
    echo "_None_"
    return
  fi
  echo "| Secret | Last Rotated | Policy (days) | Days Since | Expires In | Expiry Date | Required By |"
  echo "|--------|-------------|---------------|------------|------------|-------------|-------------|"
  for item in "${items[@]}"; do
    local name last_rotated policy days_since expires_in expiry_date services
    name=$(echo "$item" | jq -r '.name')
    last_rotated=$(echo "$item" | jq -r '.last_rotated')
    policy=$(echo "$item" | jq -r '.rotation_policy_days')
    days_since=$(echo "$item" | jq -r '.days_since_rotation')
    expires_in=$(echo "$item" | jq -r '.expires_in_days')
    expiry_date=$(echo "$item" | jq -r '.expiry_date')
    services=$(echo "$item" | jq -r '.required_by | join(", ")')
    echo "| $name | $last_rotated | $policy | $days_since | $expires_in | $expiry_date | $services |"
  done
}

output_markdown() {
  echo "# Secret Rotation Report"
  echo ""
  echo "**Reference Date:** $REFERENCE_DATE"
  echo "**Warning Window:** $WARNING_DAYS days"
  echo "**Total Secrets:** $SECRET_COUNT"
  echo ""
  echo "## Summary"
  echo ""
  echo "- **Expired:** ${#EXPIRED_ITEMS[@]}"
  echo "- **Warning:** ${#WARNING_ITEMS[@]}"
  echo "- **OK:** ${#OK_ITEMS[@]}"

  print_table_section "EXPIRED" "${EXPIRED_ITEMS[@]+"${EXPIRED_ITEMS[@]}"}"
  print_table_section "WARNING" "${WARNING_ITEMS[@]+"${WARNING_ITEMS[@]}"}"
  print_table_section "OK" "${OK_ITEMS[@]+"${OK_ITEMS[@]}"}"
}

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  output_json
else
  output_markdown
fi

if [[ ${#EXPIRED_ITEMS[@]} -gt 0 ]]; then
  exit 2
elif [[ ${#WARNING_ITEMS[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
