#!/usr/bin/env bash
# secret-rotation-validator.sh
#
# Reads a JSON config of secrets with metadata (name, last-rotated date,
# rotation policy in days, required-by services) and produces a rotation
# report grouping secrets by urgency: expired, warning, or ok.
#
# Usage:
#   ./secret-rotation-validator.sh [OPTIONS] <config-file>
#
# Options:
#   --format markdown|json   Output format (default: markdown)
#   --warning DAYS           Warning window in days (default: 30)
#   --date YYYY-MM-DD        Reference date for age calculation (default: today)
#   --help                   Show this message and exit
#
# Environment variable TODAY (YYYY-MM-DD) may be used instead of --date,
# e.g. for deterministic testing:  TODAY=2026-04-10 ./secret-rotation-validator.sh ...

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
OUTPUT_FORMAT="markdown"
WARNING_WINDOW=30
# Allow TODAY env var as an alternative to --date (useful for testing)
REFERENCE_DATE="${TODAY:-}"
CONFIG_FILE=""

# ---------------------------------------------------------------------------
# usage()  — print help and exit with the given status code
# ---------------------------------------------------------------------------
usage() {
    cat >&2 <<'EOF'
Usage: secret-rotation-validator.sh [OPTIONS] <config-file>

Options:
  --format markdown|json   Output format (default: markdown)
  --warning DAYS           Days before expiry to flag as WARNING (default: 30)
  --date YYYY-MM-DD        Reference date for age calculations (default: today)
  --help                   Show this message

The config file must be JSON with the structure:
  {
    "secrets": [
      {
        "name": "MY_SECRET",
        "last_rotated": "YYYY-MM-DD",
        "rotation_policy_days": 90,
        "required_by": ["service-a", "service-b"]
      }
    ]
  }
EOF
    exit "${1:-0}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --warning)
            WARNING_WINDOW="$2"
            shift 2
            ;;
        --date)
            REFERENCE_DATE="$2"
            shift 2
            ;;
        --help|-h)
            usage 0
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            usage 1
            ;;
        *)
            if [[ -z "$CONFIG_FILE" ]]; then
                CONFIG_FILE="$1"
            else
                echo "ERROR: Unexpected argument: $1 (config file already set to '$CONFIG_FILE')" >&2
                usage 1
            fi
            shift
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------
if [[ -z "$CONFIG_FILE" ]]; then
    echo "ERROR: No config file provided." >&2
    usage 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

if [[ "$OUTPUT_FORMAT" != "markdown" && "$OUTPUT_FORMAT" != "json" ]]; then
    echo "ERROR: Invalid format '$OUTPUT_FORMAT'. Must be 'markdown' or 'json'." >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed." >&2
    exit 1
fi

if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "ERROR: Config file contains invalid JSON: $CONFIG_FILE" >&2
    exit 1
fi

# Default reference date to today if not specified
if [[ -z "$REFERENCE_DATE" ]]; then
    REFERENCE_DATE=$(date +%Y-%m-%d)
fi

# Validate reference date format
if ! date -d "$REFERENCE_DATE" +%Y-%m-%d &>/dev/null; then
    echo "ERROR: Invalid reference date: $REFERENCE_DATE (expected YYYY-MM-DD)" >&2
    exit 1
fi

# Validate warning window is a positive integer
if ! [[ "$WARNING_WINDOW" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Warning window must be a non-negative integer, got: $WARNING_WINDOW" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Process secrets — classify each as expired / warning / ok
# ---------------------------------------------------------------------------
# We write one JSON object per line (NDJSON) to temp files, then slurp them.
WORK_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$WORK_DIR'" EXIT

EXPIRED_FILE="$WORK_DIR/expired.ndjson"
WARNING_FILE="$WORK_DIR/warning.ndjson"
OK_FILE="$WORK_DIR/ok.ndjson"
# Pre-create files so jq -s '.' always reads a valid (possibly empty) file
touch "$EXPIRED_FILE" "$WARNING_FILE" "$OK_FILE"

# Reference date as Unix epoch seconds (for arithmetic)
ref_epoch=$(date -d "$REFERENCE_DATE" +%s)

# Read each secret as tab-separated fields.
# required_by is serialised as a JSON array string to survive the @tsv encoding.
while IFS=$'\t' read -r name last_rotated policy_days required_by_json; do
    # Validate the last_rotated date
    if ! last_epoch=$(date -d "$last_rotated" +%s 2>/dev/null); then
        echo "WARNING: Skipping secret '$name' — invalid last_rotated date: $last_rotated" >&2
        continue
    fi

    days_since=$(( (ref_epoch - last_epoch) / 86400 ))

    # Compute human-readable required_by string for display
    required_by_str=$(printf '%s' "$required_by_json" | jq -r 'join(", ")')

    if (( days_since >= policy_days )); then
        # EXPIRED: rotation is overdue
        days_overdue=$(( days_since - policy_days ))
        jq -n \
            --arg  name            "$name" \
            --arg  last_rotated    "$last_rotated" \
            --argjson policy_days  "$policy_days" \
            --argjson days_overdue "$days_overdue" \
            --arg  required_by     "$required_by_str" \
            '{name: $name, last_rotated: $last_rotated,
              policy_days: $policy_days, days_overdue: $days_overdue,
              required_by: $required_by}' \
            >> "$EXPIRED_FILE"

    elif (( (policy_days - days_since) <= WARNING_WINDOW )); then
        # WARNING: expiry is within the warning window
        days_until_expiry=$(( policy_days - days_since ))
        jq -n \
            --arg  name                 "$name" \
            --arg  last_rotated         "$last_rotated" \
            --argjson policy_days       "$policy_days" \
            --argjson days_until_expiry "$days_until_expiry" \
            --arg  required_by          "$required_by_str" \
            '{name: $name, last_rotated: $last_rotated,
              policy_days: $policy_days, days_until_expiry: $days_until_expiry,
              required_by: $required_by}' \
            >> "$WARNING_FILE"

    else
        # OK: rotation is current
        days_until_expiry=$(( policy_days - days_since ))
        jq -n \
            --arg  name                 "$name" \
            --arg  last_rotated         "$last_rotated" \
            --argjson policy_days       "$policy_days" \
            --argjson days_until_expiry "$days_until_expiry" \
            --arg  required_by          "$required_by_str" \
            '{name: $name, last_rotated: $last_rotated,
              policy_days: $policy_days, days_until_expiry: $days_until_expiry,
              required_by: $required_by}' \
            >> "$OK_FILE"
    fi

done < <(jq -r \
    '.secrets[] | [.name, .last_rotated, (.rotation_policy_days | tostring), (.required_by | tojson)] | @tsv' \
    "$CONFIG_FILE")

# Slurp NDJSON files into JSON arrays (files were pre-created, so always valid)
expired_array=$(jq -s '.' "$EXPIRED_FILE")
warning_array=$(jq -s '.' "$WARNING_FILE")
ok_array=$(jq -s '.' "$OK_FILE")

expired_count=$(echo "$expired_array" | jq 'length')
warning_count=$(echo "$warning_array" | jq 'length')
ok_count=$(echo "$ok_array"      | jq 'length')

# ---------------------------------------------------------------------------
# Output: markdown
# ---------------------------------------------------------------------------
output_markdown() {
    echo "# Secret Rotation Report"
    echo "Report Date: $REFERENCE_DATE | Warning Window: ${WARNING_WINDOW} days"
    echo ""

    echo "## Expired ($expired_count)"
    if (( expired_count > 0 )); then
        echo "| Name | Last Rotated | Policy Days | Days Overdue | Required By |"
        echo "|------|-------------|-------------|--------------|-------------|"
        echo "$expired_array" | jq -r \
            '.[] | "| \(.name) | \(.last_rotated) | \(.policy_days) | \(.days_overdue) | \(.required_by) |"'
    else
        echo "_No expired secrets._"
    fi
    echo ""

    echo "## Warning ($warning_count)"
    if (( warning_count > 0 )); then
        echo "| Name | Last Rotated | Policy Days | Days Until Expiry | Required By |"
        echo "|------|-------------|-------------|-------------------|-------------|"
        echo "$warning_array" | jq -r \
            '.[] | "| \(.name) | \(.last_rotated) | \(.policy_days) | \(.days_until_expiry) | \(.required_by) |"'
    else
        echo "_No secrets in warning window._"
    fi
    echo ""

    echo "## OK ($ok_count)"
    if (( ok_count > 0 )); then
        echo "| Name | Last Rotated | Policy Days | Days Until Expiry | Required By |"
        echo "|------|-------------|-------------|-------------------|-------------|"
        echo "$ok_array" | jq -r \
            '.[] | "| \(.name) | \(.last_rotated) | \(.policy_days) | \(.days_until_expiry) | \(.required_by) |"'
    else
        echo "_No secrets in OK status._"
    fi
}

# ---------------------------------------------------------------------------
# Output: JSON
# ---------------------------------------------------------------------------
output_json() {
    jq -n \
        --arg   report_date    "$REFERENCE_DATE" \
        --argjson warning_window "$WARNING_WINDOW" \
        --argjson expired_count  "$expired_count" \
        --argjson warning_count  "$warning_count" \
        --argjson ok_count       "$ok_count" \
        --argjson expired        "$expired_array" \
        --argjson warning        "$warning_array" \
        --argjson ok             "$ok_array" \
        '{
            report_date:    $report_date,
            warning_window: $warning_window,
            summary: {
                expired: $expired_count,
                warning: $warning_count,
                ok:      $ok_count
            },
            expired: $expired,
            warning: $warning,
            ok:      $ok
        }'
}

# ---------------------------------------------------------------------------
# Dispatch to the requested output function
# ---------------------------------------------------------------------------
if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
    output_markdown
else
    output_json
fi
