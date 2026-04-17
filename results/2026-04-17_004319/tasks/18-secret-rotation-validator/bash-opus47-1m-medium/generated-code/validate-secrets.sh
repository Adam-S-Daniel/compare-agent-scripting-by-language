#!/usr/bin/env bash
# Secret rotation validator.
# Reads a JSON config of secrets, classifies each as expired/warning/ok based on
# last-rotated date + rotation policy + warning window, and emits a report
# grouped by urgency in either markdown or json format.
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 --config FILE [--warning-days N] [--format markdown|json] [--today YYYY-MM-DD]

Options:
  --config FILE       Path to JSON config (required).
  --warning-days N    Warning window in days (default: 14).
  --format FMT        Output format: markdown (default) or json.
  --today DATE        Reference date for testing (default: current date).
  -h, --help          Show this help.
EOF
}

# Parse YYYY-MM-DD to epoch seconds (UTC) using `date -d`.
# Returns non-zero on invalid input.
to_epoch() {
    local d="$1"
    if ! date -u -d "$d" +%s 2>/dev/null; then
        return 1
    fi
}

# Parse arguments.
CONFIG=""
WARNING_DAYS=14
FORMAT="markdown"
TODAY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) CONFIG="${2:-}"; shift 2 ;;
        --warning-days) WARNING_DAYS="${2:-}"; shift 2 ;;
        --format) FORMAT="${2:-}"; shift 2 ;;
        --today) TODAY="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$CONFIG" ]]; then
    echo "Error: --config is required" >&2
    exit 2
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config file not found: $CONFIG" >&2
    exit 2
fi

if ! [[ "$WARNING_DAYS" =~ ^[0-9]+$ ]]; then
    echo "Error: --warning-days must be a non-negative integer" >&2
    exit 2
fi

case "$FORMAT" in
    markdown|json) ;;
    *) echo "Error: --format must be 'markdown' or 'json'" >&2; exit 2 ;;
esac

if [[ -z "$TODAY" ]]; then
    TODAY="$(date -u +%F)"
fi

if ! TODAY_EPOCH="$(to_epoch "$TODAY")"; then
    echo "Error: invalid --today date: $TODAY" >&2
    exit 2
fi

# Validate JSON.
if ! jq -e . "$CONFIG" >/dev/null 2>&1; then
    echo "Error: config is not valid JSON: $CONFIG" >&2
    exit 2
fi

# Classify each secret. jq emits one line per secret:
#   status<TAB>days_until_expiry<TAB>name<TAB>last_rotated<TAB>rotation_days<TAB>services_csv
# status is one of: expired, warning, ok.
SECONDS_PER_DAY=86400

classified="$(
    jq -r '.secrets[] | [
        .name,
        .last_rotated,
        (.rotation_days|tostring),
        ((.services // []) | join(","))
    ] | @tsv' "$CONFIG"
)"

# Build buckets.
expired_rows=()
warning_rows=()
ok_rows=()

while IFS=$'\t' read -r name last_rotated rotation_days services; do
    [[ -z "$name" ]] && continue
    if ! last_epoch="$(to_epoch "$last_rotated")"; then
        echo "Error: invalid last_rotated date for secret '$name': $last_rotated" >&2
        exit 3
    fi
    if ! [[ "$rotation_days" =~ ^[0-9]+$ ]]; then
        echo "Error: rotation_days for secret '$name' must be a non-negative integer" >&2
        exit 3
    fi
    expiry_epoch=$(( last_epoch + rotation_days * SECONDS_PER_DAY ))
    days_until=$(( (expiry_epoch - TODAY_EPOCH) / SECONDS_PER_DAY ))
    if (( days_until < 0 )); then
        status="expired"
    elif (( days_until <= WARNING_DAYS )); then
        status="warning"
    else
        status="ok"
    fi
    row="${name}"$'\t'"${last_rotated}"$'\t'"${rotation_days}"$'\t'"${days_until}"$'\t'"${services}"
    case "$status" in
        expired) expired_rows+=("$row") ;;
        warning) warning_rows+=("$row") ;;
        ok)      ok_rows+=("$row") ;;
    esac
done <<< "$classified"

# Emit report.
emit_markdown_table() {
    local title="$1"; shift
    local rows=("$@")
    echo "## ${title} (${#rows[@]})"
    echo
    if (( ${#rows[@]} == 0 )); then
        echo "_None._"
        echo
        return
    fi
    echo "| Name | Last Rotated | Rotation Days | Days Until Expiry | Services |"
    echo "| --- | --- | --- | --- | --- |"
    local r
    for r in "${rows[@]}"; do
        IFS=$'\t' read -r name last_rotated rotation_days days_until services <<< "$r"
        echo "| ${name} | ${last_rotated} | ${rotation_days} | ${days_until} | ${services} |"
    done
    echo
}

if [[ "$FORMAT" == "markdown" ]]; then
    echo "# Secret Rotation Report"
    echo
    echo "Reference date: ${TODAY}"
    echo "Warning window: ${WARNING_DAYS} days"
    echo
    emit_markdown_table "EXPIRED" "${expired_rows[@]+"${expired_rows[@]}"}"
    emit_markdown_table "WARNING" "${warning_rows[@]+"${warning_rows[@]}"}"
    emit_markdown_table "OK"      "${ok_rows[@]+"${ok_rows[@]}"}"
else
    # JSON output.
    rows_to_json() {
        local rows=("$@")
        if (( ${#rows[@]} == 0 )); then
            echo "[]"
            return
        fi
        printf '%s\n' "${rows[@]}" | jq -R -s '
            split("\n")
            | map(select(length > 0))
            | map(split("\t"))
            | map({
                name: .[0],
                last_rotated: .[1],
                rotation_days: (.[2]|tonumber),
                days_until_expiry: (.[3]|tonumber),
                services: (if .[4] == "" then [] else (.[4]|split(",")) end)
            })
        '
    }

    exp_json="$(rows_to_json "${expired_rows[@]+"${expired_rows[@]}"}")"
    warn_json="$(rows_to_json "${warning_rows[@]+"${warning_rows[@]}"}")"
    ok_json="$(rows_to_json "${ok_rows[@]+"${ok_rows[@]}"}")"

    jq -n \
        --arg today "$TODAY" \
        --argjson warning_days "$WARNING_DAYS" \
        --argjson expired "$exp_json" \
        --argjson warning "$warn_json" \
        --argjson ok "$ok_json" \
        '{
            today: $today,
            warning_days: $warning_days,
            counts: {
                expired: ($expired|length),
                warning: ($warning|length),
                ok: ($ok|length)
            },
            expired: $expired,
            warning: $warning,
            ok: $ok
        }'
fi

# Exit code: 1 if any secret is expired, 0 otherwise.
# Warnings do not fail the pipeline; expired secrets do.
if (( ${#expired_rows[@]} > 0 )); then
    exit 1
fi
exit 0
