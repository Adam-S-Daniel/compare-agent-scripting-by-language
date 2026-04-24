#!/usr/bin/env bash
# secret-rotation-validator.sh
# Validates secret rotation schedules and generates rotation reports.
# Secrets are classified as EXPIRED, WARNING, or OK based on rotation policy.

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
FORMAT="json"
REFERENCE_DATE=""
WARNING_DAYS_OVERRIDE=""
CONFIG_FILE=""

# ─── Usage ───────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") --config <file> [OPTIONS]

Validates secret rotation schedules and generates a rotation report.

Options:
  --config <file>          Path to secrets configuration JSON file (required)
  --format <format>        Output format: json (default) or markdown
  --reference-date <date>  Reference date YYYY-MM-DD (default: today)
  --warning-days <n>       Override warning window in days (default: from config)
  --help                   Show this help message

Exit codes:
  0  Success
  1  Error (missing file, invalid arguments, etc.)

Config file format:
  {
    "warning_days": 7,
    "secrets": [
      {
        "name": "MY_SECRET",
        "last_rotated": "YYYY-MM-DD",
        "rotation_days": 30,
        "required_by": ["service-a", "service-b"]
      }
    ]
  }
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        CONFIG_FILE="$2"; shift 2 ;;
      --format)
        FORMAT="$2"; shift 2 ;;
      --reference-date)
        REFERENCE_DATE="$2"; shift 2 ;;
      --warning-days)
        WARNING_DAYS_OVERRIDE="$2"; shift 2 ;;
      --help)
        usage; exit 0 ;;
      *)
        echo "Error: Unknown option: $1" >&2
        usage >&2
        exit 1 ;;
    esac
  done
}

# ─── Validation ───────────────────────────────────────────────────────────────
validate_args() {
  if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: --config is required" >&2
    usage >&2
    exit 1
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  if [[ "$FORMAT" != "json" && "$FORMAT" != "markdown" ]]; then
    echo "Error: invalid format '$FORMAT'. Must be 'json' or 'markdown'" >&2
    exit 1
  fi
}

# ─── Date utilities ────────────────────────────────────────────────────────────

# Compute the number of days between two dates (date2 - date1).
# Uses UTC noon to avoid DST-induced off-by-one errors.
# Positive means date2 is after date1.
days_between() {
  local date1="$1"
  local date2="$2"
  local epoch1 epoch2
  epoch1=$(date -u -d "${date1}T12:00:00Z" +%s)
  epoch2=$(date -u -d "${date2}T12:00:00Z" +%s)
  echo $(( (epoch2 - epoch1) / 86400 ))
}

# ─── Classification ───────────────────────────────────────────────────────────

# Classify a secret given days_since_rotation, rotation_days, warning_days.
# Outputs: EXPIRED, WARNING, or OK
classify_secret() {
  local days_since="$1"
  local rotation_days="$2"
  local warning_days="$3"

  local days_remaining=$(( rotation_days - days_since ))

  if (( days_remaining < 0 )); then
    echo "EXPIRED"
  elif (( days_remaining <= warning_days )); then
    echo "WARNING"
  else
    echo "OK"
  fi
}

# ─── JSON output ──────────────────────────────────────────────────────────────

output_json() {
  local config_file="$1"
  local reference_date="$2"
  local warning_days="$3"

  local count expired_count=0 warning_count=0 ok_count=0
  count=$(jq '.secrets | length' "$config_file")

  # Build the secrets array as JSON
  local secrets_json="["
  local first=true

  for (( i=0; i<count; i++ )); do
    local name last_rotated rotation_days required_by_json
    name=$(jq -r ".secrets[$i].name" "$config_file")
    last_rotated=$(jq -r ".secrets[$i].last_rotated" "$config_file")
    rotation_days=$(jq -r ".secrets[$i].rotation_days" "$config_file")
    required_by_json=$(jq -c ".secrets[$i].required_by" "$config_file")

    local days_since days_remaining status
    days_since=$(days_between "$last_rotated" "$reference_date")
    days_remaining=$(( rotation_days - days_since ))
    status=$(classify_secret "$days_since" "$rotation_days" "$warning_days")

    case "$status" in
      EXPIRED) expired_count=$(( expired_count + 1 )) ;;
      WARNING) warning_count=$(( warning_count + 1 )) ;;
      OK)      ok_count=$(( ok_count + 1 )) ;;
    esac

    local entry
    if [[ "$status" == "EXPIRED" ]]; then
      local days_overdue=$(( -days_remaining ))
      entry=$(cat <<EOF
    {
      "name": "$name",
      "status": "$status",
      "last_rotated": "$last_rotated",
      "rotation_days": $rotation_days,
      "days_overdue": $days_overdue,
      "required_by": $required_by_json
    }
EOF
)
    else
      entry=$(cat <<EOF
    {
      "name": "$name",
      "status": "$status",
      "last_rotated": "$last_rotated",
      "rotation_days": $rotation_days,
      "days_remaining": $days_remaining,
      "required_by": $required_by_json
    }
EOF
)
    fi

    if [[ "$first" == "true" ]]; then
      secrets_json+=$'\n'"$entry"
      first=false
    else
      secrets_json+=","$'\n'"$entry"
    fi
  done

  secrets_json+=$'\n'"  ]"

  local total=$(( expired_count + warning_count + ok_count ))

  cat <<EOF
{
  "generated_at": "$reference_date",
  "warning_days": $warning_days,
  "summary": {
    "expired": $expired_count,
    "warning": $warning_count,
    "ok": $ok_count,
    "total": $total
  },
  "secrets": $secrets_json
}
EOF
}

# ─── Markdown output ──────────────────────────────────────────────────────────

output_markdown() {
  local config_file="$1"
  local reference_date="$2"
  local warning_days="$3"

  local count
  count=$(jq '.secrets | length' "$config_file")

  # Collect secrets by status into arrays
  local expired_rows=() warning_rows=() ok_rows=()
  local expired_count=0 warning_count=0 ok_count=0

  for (( i=0; i<count; i++ )); do
    local name last_rotated rotation_days required_by
    name=$(jq -r ".secrets[$i].name" "$config_file")
    last_rotated=$(jq -r ".secrets[$i].last_rotated" "$config_file")
    rotation_days=$(jq -r ".secrets[$i].rotation_days" "$config_file")
    required_by=$(jq -r ".secrets[$i].required_by | join(\", \")" "$config_file")

    local days_since days_remaining status
    days_since=$(days_between "$last_rotated" "$reference_date")
    days_remaining=$(( rotation_days - days_since ))
    status=$(classify_secret "$days_since" "$rotation_days" "$warning_days")

    local expiry_info
    if [[ "$status" == "EXPIRED" ]]; then
      local days_overdue=$(( -days_remaining ))
      expiry_info="${days_overdue} days overdue"
    else
      expiry_info="${days_remaining} days remaining"
    fi

    local row="| ${name} | ${status} | ${last_rotated} | ${expiry_info} | ${required_by} |"

    case "$status" in
      EXPIRED) expired_rows+=("$row"); expired_count=$(( expired_count + 1 )) ;;
      WARNING) warning_rows+=("$row"); warning_count=$(( warning_count + 1 )) ;;
      OK)      ok_rows+=("$row"); ok_count=$(( ok_count + 1 )) ;;
    esac
  done

  local total=$(( expired_count + warning_count + ok_count ))

  cat <<EOF
# Secret Rotation Report

Generated: ${reference_date} | Warning Window: ${warning_days} days

## Summary

| Status | Count |
|--------|-------|
| EXPIRED | ${expired_count} |
| WARNING | ${warning_count} |
| OK | ${ok_count} |
| **Total** | **${total}** |

EOF

  # Table header used in each section
  local header="| Name | Status | Last Rotated | Days Until/Since Expiry | Required By |"
  local divider="|------|--------|--------------|------------------------|-------------|"

  echo "## EXPIRED"
  echo ""
  echo "$header"
  echo "$divider"
  if (( expired_count == 0 )); then
    echo "| _(none)_ | | | | |"
  else
    for row in "${expired_rows[@]}"; do
      echo "$row"
    done
  fi
  echo ""

  echo "## WARNING"
  echo ""
  echo "$header"
  echo "$divider"
  if (( warning_count == 0 )); then
    echo "| _(none)_ | | | | |"
  else
    for row in "${warning_rows[@]}"; do
      echo "$row"
    done
  fi
  echo ""

  echo "## OK"
  echo ""
  echo "$header"
  echo "$divider"
  if (( ok_count == 0 )); then
    echo "| _(none)_ | | | | |"
  else
    for row in "${ok_rows[@]}"; do
      echo "$row"
    done
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"
  validate_args

  # Use today if reference date not specified
  if [[ -z "$REFERENCE_DATE" ]]; then
    REFERENCE_DATE=$(date +%Y-%m-%d)
  fi

  # Get warning_days from config, allow override via flag
  local warning_days
  warning_days=$(jq -r '.warning_days // 7' "$CONFIG_FILE")
  if [[ -n "$WARNING_DAYS_OVERRIDE" ]]; then
    warning_days="$WARNING_DAYS_OVERRIDE"
  fi

  case "$FORMAT" in
    json)
      output_json "$CONFIG_FILE" "$REFERENCE_DATE" "$warning_days" ;;
    markdown)
      output_markdown "$CONFIG_FILE" "$REFERENCE_DATE" "$warning_days" ;;
  esac
}

main "$@"
