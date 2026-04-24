#!/usr/bin/env bash
# validate-secrets.sh - Secret rotation validator
#
# Reads a JSON config of secrets, classifies each as expired/warning/ok based
# on rotation policy, and outputs a report in markdown or JSON format.
#
# Usage:
#   validate-secrets.sh [OPTIONS] <config-file>
#
# Options:
#   --format <markdown|json>   Output format (default: markdown)
#   --warning-days <N>         Warning window in days (overrides config value)
#   --reference-date <YYYY-MM-DD>  Reference date for calculations (default: today)

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
FORMAT="markdown"
WARNING_DAYS=""          # empty = use value from config
REFERENCE_DATE=""        # empty = use today
CONFIG_FILE=""

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --warning-days)
            WARNING_DAYS="$2"
            shift 2
            ;;
        --reference-date)
            REFERENCE_DATE="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
        *)
            CONFIG_FILE="$1"
            shift
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------
if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: No config file specified." >&2
    echo "Usage: $(basename "$0") [OPTIONS] <config-file>" >&2
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

if [[ "$FORMAT" != "markdown" && "$FORMAT" != "json" ]]; then
    echo "Error: Invalid output format '$FORMAT'. Must be 'markdown' or 'json'." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve reference date and its epoch
# ---------------------------------------------------------------------------
if [[ -z "$REFERENCE_DATE" ]]; then
    REFERENCE_DATE=$(date +%Y-%m-%d)
fi
TODAY_TS=$(date -d "$REFERENCE_DATE" +%s)

# ---------------------------------------------------------------------------
# Read config
# ---------------------------------------------------------------------------
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in config file: $CONFIG_FILE" >&2
    exit 1
fi

# Use --warning-days CLI flag if provided; otherwise fall back to config value
if [[ -n "$WARNING_DAYS" ]]; then
    WARN_WINDOW="$WARNING_DAYS"
else
    WARN_WINDOW=$(jq '.warning_window_days // 14' "$CONFIG_FILE")
fi

# ---------------------------------------------------------------------------
# Classify each secret
# ---------------------------------------------------------------------------
# Outputs one JSON object per line: { name, last_rotated, expiry_date,
#   days_until_expiry, days_overdue, rotation_days, required_by, status }
classify_secrets() {
    local config="$1"
    local warn_window="$2"
    local today_ts="$3"

    jq -c '.secrets[]' "$config" | while IFS= read -r secret; do
        local name last_rotated rotation_days required_by
        name=$(echo "$secret" | jq -r '.name')
        last_rotated=$(echo "$secret" | jq -r '.last_rotated')
        rotation_days=$(echo "$secret" | jq -r '.rotation_days')
        required_by=$(echo "$secret" | jq -c '.required_by')

        # Compute expiry as epoch seconds
        local last_ts expiry_ts
        last_ts=$(date -d "$last_rotated" +%s)
        expiry_ts=$(( last_ts + rotation_days * 86400 ))

        # Days until expiry (negative means overdue)
        local days_until
        days_until=$(( (expiry_ts - today_ts) / 86400 ))

        # Human-readable expiry date
        local expiry_date
        expiry_date=$(date -d "@$expiry_ts" +%Y-%m-%d)

        # Determine status
        local status days_overdue
        if [[ "$days_until" -le 0 ]]; then
            status="expired"
            days_overdue=$(( -days_until ))
        elif [[ "$days_until" -le "$warn_window" ]]; then
            status="warning"
            days_overdue=0
        else
            status="ok"
            days_overdue=0
        fi

        # Emit a structured record for this secret
        jq -n \
            --arg name "$name" \
            --arg last_rotated "$last_rotated" \
            --arg expiry_date "$expiry_date" \
            --argjson days_until "$days_until" \
            --argjson days_overdue "$days_overdue" \
            --argjson rotation_days "$rotation_days" \
            --argjson required_by "$required_by" \
            --arg status "$status" \
            '{
                name: $name,
                last_rotated: $last_rotated,
                expiry_date: $expiry_date,
                days_until_expiry: $days_until,
                days_overdue: $days_overdue,
                rotation_days: $rotation_days,
                required_by: $required_by,
                status: $status
            }'
    done
}

# Build arrays per urgency group
ALL_RECORDS=$(classify_secrets "$CONFIG_FILE" "$WARN_WINDOW" "$TODAY_TS")

EXPIRED_JSON=$(echo "$ALL_RECORDS" | jq -s '[.[] | select(.status == "expired")]')
WARNING_JSON=$(echo "$ALL_RECORDS" | jq -s '[.[] | select(.status == "warning")]')
OK_JSON=$(echo "$ALL_RECORDS"      | jq -s '[.[] | select(.status == "ok")]')

EXPIRED_COUNT=$(echo "$EXPIRED_JSON" | jq 'length')
WARNING_COUNT=$(echo "$WARNING_JSON" | jq 'length')
OK_COUNT=$(echo "$OK_JSON"           | jq 'length')
TOTAL_COUNT=$(( EXPIRED_COUNT + WARNING_COUNT + OK_COUNT ))

# ---------------------------------------------------------------------------
# Output: JSON
# ---------------------------------------------------------------------------
output_json() {
    jq -n \
        --arg generated_at "$REFERENCE_DATE" \
        --argjson total "$TOTAL_COUNT" \
        --argjson expired_count "$EXPIRED_COUNT" \
        --argjson warning_count "$WARNING_COUNT" \
        --argjson ok_count "$OK_COUNT" \
        --argjson expired "$EXPIRED_JSON" \
        --argjson warning "$WARNING_JSON" \
        --argjson ok "$OK_JSON" \
        '{
            generated_at: $generated_at,
            summary: {
                total: $total,
                expired: $expired_count,
                warning: $warning_count,
                ok: $ok_count
            },
            expired: $expired,
            warning: $warning,
            ok: $ok
        }'
}

# ---------------------------------------------------------------------------
# Output: Markdown
# ---------------------------------------------------------------------------
output_markdown() {
    echo "# Secret Rotation Report"
    echo ""
    echo "Generated: ${REFERENCE_DATE}"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Status | Count |"
    echo "|--------|-------|"
    echo "| Expired | ${EXPIRED_COUNT} |"
    echo "| Warning | ${WARNING_COUNT} |"
    echo "| OK | ${OK_COUNT} |"
    echo "| **Total** | **${TOTAL_COUNT}** |"

    # Expired section
    echo ""
    echo "## Expired (Action Required)"
    echo ""
    if [[ "$EXPIRED_COUNT" -eq 0 ]]; then
        echo "_No expired secrets._"
    else
        echo "| Secret | Last Rotated | Expiry Date | Days Overdue | Required By |"
        echo "|--------|-------------|-------------|--------------|-------------|"
        echo "$EXPIRED_JSON" | jq -r '.[] | [
            .name,
            .last_rotated,
            .expiry_date,
            (.days_overdue | tostring),
            (.required_by | join(", "))
        ] | "| " + join(" | ") + " |"'
    fi

    # Warning section
    echo ""
    echo "## Warning (Rotation Soon)"
    echo ""
    if [[ "$WARNING_COUNT" -eq 0 ]]; then
        echo "_No secrets expiring soon._"
    else
        echo "| Secret | Last Rotated | Expiry Date | Days Until Expiry | Required By |"
        echo "|--------|-------------|-------------|-------------------|-------------|"
        echo "$WARNING_JSON" | jq -r '.[] | [
            .name,
            .last_rotated,
            .expiry_date,
            (.days_until_expiry | tostring),
            (.required_by | join(", "))
        ] | "| " + join(" | ") + " |"'
    fi

    # OK section
    echo ""
    echo "## OK"
    echo ""
    if [[ "$OK_COUNT" -eq 0 ]]; then
        echo "_No secrets with valid rotation._"
    else
        echo "| Secret | Last Rotated | Expiry Date | Days Until Expiry | Required By |"
        echo "|--------|-------------|-------------|-------------------|-------------|"
        echo "$OK_JSON" | jq -r '.[] | [
            .name,
            .last_rotated,
            .expiry_date,
            (.days_until_expiry | tostring),
            (.required_by | join(", "))
        ] | "| " + join(" | ") + " |"'
    fi
}

# ---------------------------------------------------------------------------
# Dispatch output format
# ---------------------------------------------------------------------------
case "$FORMAT" in
    json)     output_json ;;
    markdown) output_markdown ;;
esac
