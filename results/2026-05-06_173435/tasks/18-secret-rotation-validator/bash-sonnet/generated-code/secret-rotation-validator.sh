#!/usr/bin/env bash
# secret-rotation-validator.sh
# Classifies secrets as expired/warning/ok based on rotation policy metadata.
# Uses jq for JSON I/O and date(1) for calendar arithmetic.

# Force UTC so day-count arithmetic is consistent regardless of host timezone.
export TZ=UTC
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: secret-rotation-validator.sh --config FILE [OPTIONS]

Options:
  --config FILE        Path to secrets configuration JSON file (required)
  --format FORMAT      Output format: markdown (default) or json
  --warning-days DAYS  Days before expiry to warn (overrides config value)
  --date DATE          Reference date YYYY-MM-DD (default: today)
  --help               Show this help

Config file format (JSON):
  {
    "warning_days": 14,
    "secrets": [
      {
        "name": "MY_SECRET",
        "last_rotated": "2024-01-15",
        "rotation_days": 90,
        "required_by": ["service-a", "service-b"]
      }
    ]
  }

Output groups:
  EXPIRED  - Past their rotation deadline
  WARNING  - Expiring within the warning window
  OK       - Healthy, not yet in warning window
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────

CONFIG_FILE=""
FORMAT="markdown"
CLI_WARNING_DAYS=""   # empty means "use config value"
REFERENCE_DATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --warning-days)
            CLI_WARNING_DAYS="$2"
            shift 2
            ;;
        --date)
            REFERENCE_DATE="$2"
            shift 2
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ── Validate inputs ───────────────────────────────────────────────────────────

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: --config FILE is required" >&2
    usage >&2
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file '$CONFIG_FILE' not found" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required but not installed" >&2
    exit 1
fi

case "$FORMAT" in
    markdown | json) ;;
    *)
        echo "Error: Unknown format '$FORMAT' — use 'markdown' or 'json'" >&2
        exit 1
        ;;
esac

# ── Setup ─────────────────────────────────────────────────────────────────────

if [[ -z "$REFERENCE_DATE" ]]; then
    REFERENCE_DATE=$(date +%Y-%m-%d)
fi

REF_EPOCH=$(date -d "$REFERENCE_DATE" +%s)

# CLI --warning-days takes priority over the config file value.
if [[ -n "$CLI_WARNING_DAYS" ]]; then
    WARNING_DAYS="$CLI_WARNING_DAYS"
else
    WARNING_DAYS=$(jq -r '.warning_days // 14' "$CONFIG_FILE")
fi

# ── Temp files for classified secrets ─────────────────────────────────────────

TMP_EXPIRED=$(mktemp)
TMP_WARNING=$(mktemp)
TMP_OK=$(mktemp)
cleanup() { rm -f "$TMP_EXPIRED" "$TMP_WARNING" "$TMP_OK"; }
trap cleanup EXIT

# ── Process secrets ───────────────────────────────────────────────────────────

while IFS= read -r secret_json; do
    name=$(jq -r '.name' <<< "$secret_json")
    last_rotated=$(jq -r '.last_rotated' <<< "$secret_json")
    rotation_days=$(jq -r '.rotation_days' <<< "$secret_json")
    required_by=$(jq -r '.required_by | join(", ")' <<< "$secret_json")

    expiry_date=$(date -d "$last_rotated +${rotation_days} days" +%Y-%m-%d)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    days_remaining=$(( (expiry_epoch - REF_EPOCH) / 86400 ))

    # -c produces compact single-line JSON so wc -l counts entries correctly
    entry=$(jq -cn \
        --arg name          "$name" \
        --arg last_rotated  "$last_rotated" \
        --arg expires       "$expiry_date" \
        --argjson days_remaining "$days_remaining" \
        --arg required_by   "$required_by" \
        '{name: $name, last_rotated: $last_rotated, expires: $expires,
          days_remaining: $days_remaining, required_by: $required_by}')

    if [[ "$days_remaining" -lt 0 ]]; then
        echo "$entry" >> "$TMP_EXPIRED"
    elif [[ "$days_remaining" -le "$WARNING_DAYS" ]]; then
        echo "$entry" >> "$TMP_WARNING"
    else
        echo "$entry" >> "$TMP_OK"
    fi
done < <(jq -c '.secrets[]' "$CONFIG_FILE")

# ── Helper: read a temp file as a JSON array ──────────────────────────────────

load_json_array() {
    local file="$1"
    local urgency="$2"
    if [[ -s "$file" ]]; then
        jq -s --arg u "$urgency" 'map(. + {urgency: $u})' "$file"
    else
        echo '[]'
    fi
}

count_lines() {
    local file="$1"
    if [[ -s "$file" ]]; then
        wc -l < "$file"
    else
        echo 0
    fi
}

EXPIRED_COUNT=$(count_lines "$TMP_EXPIRED")
WARNING_COUNT=$(count_lines "$TMP_WARNING")
OK_COUNT=$(count_lines "$TMP_OK")

# ── Markdown output ───────────────────────────────────────────────────────────

output_markdown() {
    echo "# Secret Rotation Report"
    echo ""
    echo "**Reference Date:** $REFERENCE_DATE | **Warning Window:** ${WARNING_DAYS} days"
    echo ""

    if [[ "$EXPIRED_COUNT" -gt 0 ]]; then
        echo "## EXPIRED (${EXPIRED_COUNT})"
        echo ""
        echo "| Secret | Last Rotated | Expired On | Days Overdue | Required By |"
        echo "|--------|--------------|------------|--------------|-------------|"
        while IFS= read -r row; do
            n=$(jq -r '.name'         <<< "$row")
            lr=$(jq -r '.last_rotated' <<< "$row")
            ex=$(jq -r '.expires'      <<< "$row")
            dr=$(jq -r '.days_remaining' <<< "$row")
            rb=$(jq -r '.required_by'  <<< "$row")
            overdue=$(( -dr ))
            echo "| $n | $lr | $ex | $overdue | $rb |"
        done < "$TMP_EXPIRED"
        echo ""
    fi

    if [[ "$WARNING_COUNT" -gt 0 ]]; then
        echo "## WARNING (${WARNING_COUNT})"
        echo ""
        echo "| Secret | Last Rotated | Expires On | Days Remaining | Required By |"
        echo "|--------|--------------|------------|----------------|-------------|"
        while IFS= read -r row; do
            n=$(jq -r '.name'         <<< "$row")
            lr=$(jq -r '.last_rotated' <<< "$row")
            ex=$(jq -r '.expires'      <<< "$row")
            dr=$(jq -r '.days_remaining' <<< "$row")
            rb=$(jq -r '.required_by'  <<< "$row")
            echo "| $n | $lr | $ex | $dr | $rb |"
        done < "$TMP_WARNING"
        echo ""
    fi

    if [[ "$OK_COUNT" -gt 0 ]]; then
        echo "## OK (${OK_COUNT})"
        echo ""
        echo "| Secret | Last Rotated | Expires On | Days Remaining | Required By |"
        echo "|--------|--------------|------------|----------------|-------------|"
        while IFS= read -r row; do
            n=$(jq -r '.name'         <<< "$row")
            lr=$(jq -r '.last_rotated' <<< "$row")
            ex=$(jq -r '.expires'      <<< "$row")
            dr=$(jq -r '.days_remaining' <<< "$row")
            rb=$(jq -r '.required_by'  <<< "$row")
            echo "| $n | $lr | $ex | $dr | $rb |"
        done < "$TMP_OK"
        echo ""
    fi

    echo "---"
    echo "_Total: ${EXPIRED_COUNT} expired, ${WARNING_COUNT} warning, ${OK_COUNT} ok_"
}

# ── JSON output ───────────────────────────────────────────────────────────────

output_json() {
    expired_json=$(load_json_array "$TMP_EXPIRED" "expired")
    warning_json=$(load_json_array "$TMP_WARNING" "warning")
    ok_json=$(load_json_array "$TMP_OK" "ok")

    jq -n \
        --arg  reference_date  "$REFERENCE_DATE" \
        --argjson warning_days "$WARNING_DAYS" \
        --argjson expired       "$expired_json" \
        --argjson warning       "$warning_json" \
        --argjson ok            "$ok_json" \
        '{
            reference_date: $reference_date,
            warning_days:   $warning_days,
            summary: {
                expired: ($expired | length),
                warning: ($warning | length),
                ok:      ($ok      | length)
            },
            notifications: {
                expired: $expired,
                warning: $warning,
                ok:      $ok
            }
        }'
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "$FORMAT" in
    markdown) output_markdown ;;
    json)     output_json     ;;
esac
