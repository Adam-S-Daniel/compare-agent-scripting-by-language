#!/usr/bin/env bash
# secret-rotation-validator.sh
#
# Validates secret rotation status against policy. Reads a JSON config of
# secrets (name, last_rotated, rotation_policy_days, required_by) and
# classifies each as expired / warning / ok based on the current date and
# a configurable warning window. Outputs a report in markdown or JSON.
#
# Usage:
#   ./secret-rotation-validator.sh [OPTIONS]
#
# Options:
#   -c, --config FILE        Path to secrets config JSON (required)
#   -w, --warning-days DAYS  Warning window in days (default: 7)
#   -f, --format FORMAT      Output format: markdown | json (default: markdown)
#   -d, --date DATE          Override "today" date (YYYY-MM-DD) for testing
#   -h, --help               Show this help message

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
CONFIG_FILE=""
WARNING_DAYS=7
OUTPUT_FORMAT="markdown"
TODAY_OVERRIDE=""

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
    cat <<'USAGE'
Usage: secret-rotation-validator.sh [OPTIONS]

Options:
  -c, --config FILE        Path to secrets config JSON (required)
  -w, --warning-days DAYS  Warning window in days (default: 7)
  -f, --format FORMAT      Output format: markdown | json (default: markdown)
  -d, --date DATE          Override "today" date (YYYY-MM-DD) for testing
  -h, --help               Show this help message
USAGE
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Convert YYYY-MM-DD to epoch seconds. Force UTC to avoid DST skew.
date_to_epoch() {
    TZ=UTC date -d "$1" +%s 2>/dev/null || die "Invalid date: $1"
}

# ── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                [[ -n "${2:-}" ]] || die "Missing value for $1"
                CONFIG_FILE="$2"; shift 2 ;;
            -w|--warning-days)
                [[ -n "${2:-}" ]] || die "Missing value for $1"
                WARNING_DAYS="$2"; shift 2 ;;
            -f|--format)
                [[ -n "${2:-}" ]] || die "Missing value for $1"
                OUTPUT_FORMAT="$2"; shift 2 ;;
            -d|--date)
                [[ -n "${2:-}" ]] || die "Missing value for $1"
                TODAY_OVERRIDE="$2"; shift 2 ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                die "Unknown option: $1" ;;
        esac
    done
}

# ── Validation ───────────────────────────────────────────────────────────────
validate_inputs() {
    [[ -n "$CONFIG_FILE" ]] || die "Config file is required (-c / --config)"
    [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
    [[ "$OUTPUT_FORMAT" == "markdown" || "$OUTPUT_FORMAT" == "json" ]] \
        || die "Invalid format '$OUTPUT_FORMAT'. Use 'markdown' or 'json'."
    [[ "$WARNING_DAYS" =~ ^[0-9]+$ ]] \
        || die "Warning days must be a non-negative integer, got '$WARNING_DAYS'"
}

# ── Core logic ───────────────────────────────────────────────────────────────
# Classify a single secret and echo a JSON object with status info.
classify_secret() {
    local name="$1" last_rotated="$2" policy_days="$3" required_by="$4" today_epoch="$5" warning_days="$6"

    local rotated_epoch expires_epoch days_since days_until status
    rotated_epoch=$(date_to_epoch "$last_rotated")
    expires_epoch=$(( rotated_epoch + policy_days * 86400 ))
    days_since=$(( (today_epoch - rotated_epoch) / 86400 ))
    days_until=$(( (expires_epoch - today_epoch) / 86400 ))

    if (( days_until < 0 )); then
        status="expired"
    elif (( days_until <= warning_days )); then
        status="warning"
    else
        status="ok"
    fi

    # Output a JSON object for this secret
    jq -n \
        --arg name "$name" \
        --arg last_rotated "$last_rotated" \
        --argjson policy_days "$policy_days" \
        --arg required_by "$required_by" \
        --argjson days_since "$days_since" \
        --argjson days_until "$days_until" \
        --arg status "$status" \
        '{name: $name, last_rotated: $last_rotated, policy_days: $policy_days, required_by: $required_by, days_since: $days_since, days_until: $days_until, status: $status}'
}

# Process all secrets from the config file and produce classified results.
process_secrets() {
    local config_file="$1" today_epoch="$2" warning_days="$3"
    local count name last_rotated policy_days required_by

    count=$(jq '.secrets | length' "$config_file")
    [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] || die "No secrets found in config"

    local results="[]"
    for (( i = 0; i < count; i++ )); do
        name=$(jq -r ".secrets[$i].name" "$config_file")
        last_rotated=$(jq -r ".secrets[$i].last_rotated" "$config_file")
        policy_days=$(jq -r ".secrets[$i].rotation_policy_days" "$config_file")
        required_by=$(jq -r ".secrets[$i].required_by | join(\", \")" "$config_file")

        local entry
        entry=$(classify_secret "$name" "$last_rotated" "$policy_days" "$required_by" "$today_epoch" "$warning_days")
        results=$(echo "$results" | jq --argjson e "$entry" '. + [$e]')
    done

    echo "$results"
}

# ── Output formatters ────────────────────────────────────────────────────────

output_json() {
    local results="$1" today="$2" warning_days="$3"
    local expired warning ok
    expired=$(echo "$results" | jq '[.[] | select(.status=="expired")]')
    warning=$(echo "$results" | jq '[.[] | select(.status=="warning")]')
    ok=$(echo "$results" | jq '[.[] | select(.status=="ok")]')

    jq -n \
        --arg report_date "$today" \
        --argjson warning_days "$warning_days" \
        --argjson expired "$expired" \
        --argjson warning "$warning" \
        --argjson ok "$ok" \
        --argjson total "$(echo "$results" | jq 'length')" \
        --argjson expired_count "$(echo "$expired" | jq 'length')" \
        --argjson warning_count "$(echo "$warning" | jq 'length')" \
        --argjson ok_count "$(echo "$ok" | jq 'length')" \
        '{
            report_date: $report_date,
            warning_window_days: $warning_days,
            summary: {total: $total, expired: $expired_count, warning: $warning_count, ok: $ok_count},
            expired: $expired,
            warning: $warning,
            ok: $ok
        }'
}

output_markdown() {
    local results="$1" today="$2" warning_days="$3"

    echo "# Secret Rotation Report"
    echo ""
    echo "**Report Date:** $today"
    echo "**Warning Window:** $warning_days days"
    echo ""

    local total expired_count warning_count ok_count
    total=$(echo "$results" | jq 'length')
    expired_count=$(echo "$results" | jq '[.[] | select(.status=="expired")] | length')
    warning_count=$(echo "$results" | jq '[.[] | select(.status=="warning")] | length')
    ok_count=$(echo "$results" | jq '[.[] | select(.status=="ok")] | length')

    echo "## Summary"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Total Secrets | $total |"
    echo "| Expired | $expired_count |"
    echo "| Warning | $warning_count |"
    echo "| OK | $ok_count |"
    echo ""

    # Expired secrets
    if (( expired_count > 0 )); then
        echo "## EXPIRED Secrets"
        echo ""
        echo "| Name | Last Rotated | Policy (days) | Days Since | Days Until Expiry | Required By |"
        echo "|------|-------------|---------------|------------|-------------------|-------------|"
        echo "$results" | jq -r '.[] | select(.status=="expired") | "| \(.name) | \(.last_rotated) | \(.policy_days) | \(.days_since) | \(.days_until) | \(.required_by) |"'
        echo ""
    fi

    # Warning secrets
    if (( warning_count > 0 )); then
        echo "## WARNING Secrets"
        echo ""
        echo "| Name | Last Rotated | Policy (days) | Days Since | Days Until Expiry | Required By |"
        echo "|------|-------------|---------------|------------|-------------------|-------------|"
        echo "$results" | jq -r '.[] | select(.status=="warning") | "| \(.name) | \(.last_rotated) | \(.policy_days) | \(.days_since) | \(.days_until) | \(.required_by) |"'
        echo ""
    fi

    # OK secrets
    if (( ok_count > 0 )); then
        echo "## OK Secrets"
        echo ""
        echo "| Name | Last Rotated | Policy (days) | Days Since | Days Until Expiry | Required By |"
        echo "|------|-------------|---------------|------------|-------------------|-------------|"
        echo "$results" | jq -r '.[] | select(.status=="ok") | "| \(.name) | \(.last_rotated) | \(.policy_days) | \(.days_since) | \(.days_until) | \(.required_by) |"'
        echo ""
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    validate_inputs

    local today today_epoch
    if [[ -n "$TODAY_OVERRIDE" ]]; then
        today="$TODAY_OVERRIDE"
    else
        today=$(date +%Y-%m-%d)
    fi
    today_epoch=$(date_to_epoch "$today")

    local results
    results=$(process_secrets "$CONFIG_FILE" "$today_epoch" "$WARNING_DAYS")

    case "$OUTPUT_FORMAT" in
        json)     output_json "$results" "$today" "$WARNING_DAYS" ;;
        markdown) output_markdown "$results" "$today" "$WARNING_DAYS" ;;
    esac
}

# Only run main when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
