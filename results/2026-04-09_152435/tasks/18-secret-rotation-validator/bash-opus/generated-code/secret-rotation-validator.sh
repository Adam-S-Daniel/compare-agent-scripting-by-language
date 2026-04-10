#!/usr/bin/env bash
# Secret Rotation Validator
#
# Reads a JSON config of secrets with metadata (name, last-rotated date,
# rotation policy in days, required-by services) and classifies each secret
# as EXPIRED, WARNING, or OK based on a configurable warning window.
# Outputs a rotation report in markdown table or JSON format.
#
# Exit codes:
#   0 - all secrets OK (or only warnings)
#   1 - one or more secrets are expired
#   2 - usage/input error

set -euo pipefail

# --- Defaults ---
WARNING_WINDOW=7
OUTPUT_FORMAT="markdown"
REFERENCE_DATE=""
CONFIG_FILE=""

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") -c CONFIG_FILE [-w WARNING_WINDOW] [-f FORMAT] [-d REFERENCE_DATE]

Options:
  -c CONFIG_FILE     Path to secrets configuration JSON file (required)
  -w WARNING_WINDOW  Days before expiry to trigger warning (default: 7)
  -f FORMAT          Output format: markdown or json (default: markdown)
  -d REFERENCE_DATE  Reference date YYYY-MM-DD (default: today)
  -h                 Show this help message
EOF
    exit 2
}

# --- Parse arguments ---
while getopts "c:w:f:d:h" opt; do
    case "$opt" in
        c) CONFIG_FILE="$OPTARG" ;;
        w) WARNING_WINDOW="$OPTARG" ;;
        f) OUTPUT_FORMAT="$OPTARG" ;;
        d) REFERENCE_DATE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# --- Validate inputs ---
if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: Config file is required (-c)" >&2
    exit 2
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 2
fi

if [[ "$OUTPUT_FORMAT" != "markdown" && "$OUTPUT_FORMAT" != "json" ]]; then
    echo "Error: Invalid output format '$OUTPUT_FORMAT' (must be 'markdown' or 'json')" >&2
    exit 2
fi

if ! [[ "$WARNING_WINDOW" =~ ^[0-9]+$ ]]; then
    echo "Error: Warning window must be a non-negative integer" >&2
    exit 2
fi

if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in config file: $CONFIG_FILE" >&2
    exit 2
fi

# Default reference date to today (UTC)
if [[ -z "$REFERENCE_DATE" ]]; then
    REFERENCE_DATE=$(date -u +%Y-%m-%d)
fi

# Validate date format via jq (UTC, avoids DST issues)
if ! echo '{}' | jq -e --arg d "$REFERENCE_DATE" '$d | strptime("%Y-%m-%d") | mktime' >/dev/null 2>&1; then
    echo "Error: Invalid reference date format: $REFERENCE_DATE (expected YYYY-MM-DD)" >&2
    exit 2
fi

# --- Core logic: classify secrets using jq (all dates UTC) ---
# Produces a structured JSON object with summary, expired, warning, ok arrays.
classified=$(jq --arg ref_date "$REFERENCE_DATE" --argjson warn "$WARNING_WINDOW" '
  ($ref_date | strptime("%Y-%m-%d") | mktime) as $ref_epoch |
  (.secrets // []) | map(
    (.last_rotated | strptime("%Y-%m-%d") | mktime) as $last_epoch |
    ($last_epoch + .rotation_policy_days * 86400) as $exp_epoch |
    (($exp_epoch - $ref_epoch) / 86400 | floor) as $days_until |
    . + {
      expires: ($exp_epoch | strftime("%Y-%m-%d")),
      days_until_expiry: $days_until,
      status: (
        if $days_until < 0 then "EXPIRED"
        elif $days_until <= $warn then "WARNING"
        else "OK"
        end
      ),
      status_text: (
        if $days_until < 0 then "expired \(-$days_until) days ago"
        else "expires in \($days_until) days"
        end
      )
    }
  ) as $all |
  {
    reference_date: $ref_date,
    warning_window_days: $warn,
    summary: {
      total:   ($all | length),
      expired: ([$all[] | select(.status == "EXPIRED")] | length),
      warning: ([$all[] | select(.status == "WARNING")] | length),
      ok:      ([$all[] | select(.status == "OK")]      | length)
    },
    expired: [$all[] | select(.status == "EXPIRED")],
    warning: [$all[] | select(.status == "WARNING")],
    ok:      [$all[] | select(.status == "OK")]
  }
' "$CONFIG_FILE")

# --- Output ---
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "$classified"
else
    # Markdown report
    ref=$(echo "$classified" | jq -r '.reference_date')
    warn=$(echo "$classified" | jq -r '.warning_window_days')
    total=$(echo "$classified" | jq -r '.summary.total')
    n_expired=$(echo "$classified" | jq -r '.summary.expired')
    n_warning=$(echo "$classified" | jq -r '.summary.warning')
    n_ok=$(echo "$classified" | jq -r '.summary.ok')

    echo "# Secret Rotation Report"
    echo ""
    echo "**Reference Date:** $ref"
    echo "**Warning Window:** $warn days"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Status | Count |"
    echo "|--------|-------|"
    echo "| EXPIRED | $n_expired |"
    echo "| WARNING | $n_warning |"
    echo "| OK | $n_ok |"
    echo "| **Total** | **$total** |"

    # Helper to print a section table from a jq array key
    print_section() {
        local key="$1" label="$2"
        local count
        count=$(echo "$classified" | jq ".${key} | length")
        if [[ "$count" -gt 0 ]]; then
            echo ""
            echo "## ${label} Secrets"
            echo ""
            echo "| Name | Last Rotated | Expires | Policy (days) | Status | Required By |"
            echo "|------|-------------|---------|---------------|--------|-------------|"
            echo "$classified" | jq -r ".${key}[] |
                \"| \(.name) | \(.last_rotated) | \(.expires) | \(.rotation_policy_days) | \(.status_text) | \(.required_by | join(\", \")) |\"
            "
        fi
    }

    print_section "expired" "EXPIRED"
    print_section "warning" "WARNING"
    print_section "ok" "OK"
fi

# --- Exit code: 1 if any secrets are expired ---
n_expired=$(echo "$classified" | jq '.summary.expired')
if [[ "$n_expired" -gt 0 ]]; then
    exit 1
fi
exit 0
