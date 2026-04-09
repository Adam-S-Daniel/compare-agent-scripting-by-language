#!/usr/bin/env bash
# secret-rotation-validator.sh
# Validates secret rotation policies and generates urgency-grouped reports.
#
# Approach:
#   1. Parse CSV config: name, last_rotated, rotation_days, required_by
#   2. Compute expiry_date = last_rotated + rotation_days
#   3. Compute days_until_expiry = expiry_date - reference_date (today by default)
#   4. Group into: expired (<= 0), warning (<= warning_days), ok (> warning_days)
#   5. Output in requested format: json (default) or markdown

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
DEFAULT_WARNING_DAYS=30
DEFAULT_FORMAT="json"

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validates secret rotation policies and reports urgency status.

Options:
  --config FILE          Path to CSV config file (required)
  --format FORMAT        Output format: json (default) or markdown
  --warning-days DAYS    Days before expiry to trigger warning (default: $DEFAULT_WARNING_DAYS)
  --reference-date DATE  Reference date in YYYY-MM-DD (default: today)
  --help                 Show this help message

CSV Format (header required):
  name,last_rotated,rotation_days,required_by

  - name:          Secret identifier
  - last_rotated:  Date last rotated (YYYY-MM-DD)
  - rotation_days: How often (in days) rotation is required
  - required_by:   Comma-separated services that depend on this secret

Exit codes:
  0  Success
  1  Error (missing/invalid input)

Examples:
  $(basename "$0") --config secrets.csv
  $(basename "$0") --config secrets.csv --format markdown --warning-days 14
EOF
}

# ─── Date utilities ───────────────────────────────────────────────────────────
# Convert YYYY-MM-DD to Unix epoch seconds (portable, no GNU date needed on macOS)
date_to_epoch() {
    local d="$1"
    # Use date command; handle both GNU and BSD date
    if date --version >/dev/null 2>&1; then
        # GNU date
        date -d "$d" +%s
    else
        # BSD date (macOS)
        date -j -f "%Y-%m-%d" "$d" +%s
    fi
}

# Add N days to a YYYY-MM-DD date, return YYYY-MM-DD
add_days_to_date() {
    local d="$1"
    local n="$2"
    local epoch
    epoch=$(date_to_epoch "$d")
    local new_epoch=$(( epoch + n * 86400 ))
    if date --version >/dev/null 2>&1; then
        date -d "@$new_epoch" +%Y-%m-%d
    else
        date -j -f "%s" "$new_epoch" +%Y-%m-%d
    fi
}

# Days between two YYYY-MM-DD dates (date2 - date1), can be negative
days_between() {
    local d1="$1"
    local d2="$2"
    local e1 e2
    e1=$(date_to_epoch "$d1")
    e2=$(date_to_epoch "$d2")
    echo $(( (e2 - e1) / 86400 ))
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    CONFIG_FILE=""
    FORMAT="$DEFAULT_FORMAT"
    WARNING_DAYS="$DEFAULT_WARNING_DAYS"
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
                WARNING_DAYS="$2"
                shift 2
                ;;
            --reference-date)
                REFERENCE_DATE="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    # Validate format
    if [[ "$FORMAT" != "json" && "$FORMAT" != "markdown" ]]; then
        echo "Error: Invalid format '$FORMAT'. Must be 'json' or 'markdown'." >&2
        exit 1
    fi

    # Default reference date to today
    if [[ -z "$REFERENCE_DATE" ]]; then
        REFERENCE_DATE=$(date +%Y-%m-%d)
    fi

    # Validate config file provided
    if [[ -z "$CONFIG_FILE" ]]; then
        echo "Error: --config FILE is required." >&2
        usage >&2
        exit 1
    fi

    # Validate config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found: $CONFIG_FILE" >&2
        exit 1
    fi
}

# ─── CSV parsing ──────────────────────────────────────────────────────────────
# Parse the CSV and populate parallel arrays:
#   SECRET_NAMES[], SECRET_LAST_ROTATED[], SECRET_ROTATION_DAYS[], SECRET_REQUIRED_BY[]
parse_csv() {
    local file="$1"
    SECRET_NAMES=()
    SECRET_LAST_ROTATED=()
    SECRET_ROTATION_DAYS=()
    SECRET_REQUIRED_BY=()

    local line_num=0
    local header_seen=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$(( line_num + 1 ))

        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Skip header row
        if [[ "$header_seen" -eq 0 ]]; then
            header_seen=1
            continue
        fi

        # Parse CSV fields (handle quoted fields with internal commas)
        # We use a simple state machine for quoted field parsing
        local name="" last_rotated="" rotation_days="" required_by=""
        local fields=()

        # Use a temp variable to accumulate field chars
        local field="" in_quote=0 char

        local i
        for (( i=0; i<${#line}; i++ )); do
            char="${line:$i:1}"
            if [[ "$in_quote" -eq 1 ]]; then
                if [[ "$char" == '"' ]]; then
                    in_quote=0
                else
                    field+="$char"
                fi
            else
                if [[ "$char" == '"' ]]; then
                    in_quote=1
                elif [[ "$char" == ',' ]]; then
                    fields+=("$field")
                    field=""
                else
                    field+="$char"
                fi
            fi
        done
        fields+=("$field")  # last field

        # Require exactly 4 fields
        if [[ "${#fields[@]}" -lt 4 ]]; then
            echo "Error: Malformed CSV line $line_num: $line" >&2
            exit 1
        fi

        name="${fields[0]}"
        last_rotated="${fields[1]}"
        rotation_days="${fields[2]}"
        required_by="${fields[3]}"

        # Strip whitespace
        name="${name#"${name%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"
        last_rotated="${last_rotated#"${last_rotated%%[![:space:]]*}"}"
        last_rotated="${last_rotated%"${last_rotated##*[![:space:]]}"}"
        rotation_days="${rotation_days#"${rotation_days%%[![:space:]]*}"}"
        rotation_days="${rotation_days%"${rotation_days##*[![:space:]]}"}"

        # Validate rotation_days is a positive integer
        if ! [[ "$rotation_days" =~ ^[0-9]+$ ]]; then
            echo "Error: rotation_days must be a positive integer for secret '$name', got: '$rotation_days'" >&2
            exit 1
        fi

        SECRET_NAMES+=("$name")
        SECRET_LAST_ROTATED+=("$last_rotated")
        SECRET_ROTATION_DAYS+=("$rotation_days")
        SECRET_REQUIRED_BY+=("$required_by")

    done < "$file"

    if [[ "${#SECRET_NAMES[@]}" -eq 0 ]]; then
        echo "Error: No secrets found in config file: $file" >&2
        exit 1
    fi
}

# ─── Classification ───────────────────────────────────────────────────────────
# Classify all secrets and store results in parallel arrays
classify_secrets() {
    CLASSIFIED_STATUS=()
    CLASSIFIED_EXPIRY=()
    CLASSIFIED_DAYS_UNTIL=()

    local i
    for (( i=0; i<${#SECRET_NAMES[@]}; i++ )); do
        local last_rotated="${SECRET_LAST_ROTATED[$i]}"
        local rotation_days="${SECRET_ROTATION_DAYS[$i]}"

        # Compute expiry date
        local expiry_date
        expiry_date=$(add_days_to_date "$last_rotated" "$rotation_days")

        # Days until expiry (positive = future, negative = past)
        local days_until
        days_until=$(days_between "$REFERENCE_DATE" "$expiry_date")

        # Classify
        local status
        if [[ "$days_until" -le 0 ]]; then
            status="expired"
        elif [[ "$days_until" -le "$WARNING_DAYS" ]]; then
            status="warning"
        else
            status="ok"
        fi

        CLASSIFIED_STATUS+=("$status")
        CLASSIFIED_EXPIRY+=("$expiry_date")
        CLASSIFIED_DAYS_UNTIL+=("$days_until")
    done
}

# ─── JSON output ──────────────────────────────────────────────────────────────
# Escape a string for use inside a JSON double-quoted value
json_escape() {
    local s="$1"
    # Escape backslash, then double-quote, then control chars
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# Convert comma-separated "svc1,svc2,svc3" to JSON array ["svc1","svc2","svc3"]
csv_to_json_array() {
    local csv="$1"
    local result="["
    local first=1
    # Split on comma
    IFS=',' read -ra parts <<< "$csv"
    local part
    for part in "${parts[@]}"; do
        # Trim whitespace
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        [[ "$first" -eq 0 ]] && result+=","
        result+="\"$(json_escape "$part")\""
        first=0
    done
    result+="]"
    printf '%s' "$result"
}

output_json() {
    local expired_list="" warning_list="" ok_list=""
    local expired_count=0 warning_count=0 ok_count=0
    local total="${#SECRET_NAMES[@]}"

    local i
    for (( i=0; i<total; i++ )); do
        local name="${SECRET_NAMES[$i]}"
        local last_rotated="${SECRET_LAST_ROTATED[$i]}"
        local rotation_days="${SECRET_ROTATION_DAYS[$i]}"
        local required_by="${SECRET_REQUIRED_BY[$i]}"
        local status="${CLASSIFIED_STATUS[$i]}"
        local expiry="${CLASSIFIED_EXPIRY[$i]}"
        local days_until="${CLASSIFIED_DAYS_UNTIL[$i]}"

        local required_by_json
        required_by_json=$(csv_to_json_array "$required_by")

        local entry
        entry="{\"name\":\"$(json_escape "$name")\",\"status\":\"$status\",\"last_rotated\":\"$last_rotated\",\"rotation_days\":$rotation_days,\"expiry_date\":\"$expiry\",\"days_until_expiry\":$days_until,\"required_by\":$required_by_json}"

        case "$status" in
            expired)
                [[ -n "$expired_list" ]] && expired_list+=","
                expired_list+="$entry"
                expired_count=$(( expired_count + 1 ))
                ;;
            warning)
                [[ -n "$warning_list" ]] && warning_list+=","
                warning_list+="$entry"
                warning_count=$(( warning_count + 1 ))
                ;;
            ok)
                [[ -n "$ok_list" ]] && ok_list+=","
                ok_list+="$entry"
                ok_count=$(( ok_count + 1 ))
                ;;
        esac
    done

    cat <<EOF
{
  "summary": {
    "total": $total,
    "expired_count": $expired_count,
    "warning_count": $warning_count,
    "ok_count": $ok_count,
    "reference_date": "$REFERENCE_DATE",
    "warning_days": $WARNING_DAYS
  },
  "expired": [$expired_list],
  "warning": [$warning_list],
  "ok": [$ok_list]
}
EOF
}

# ─── Markdown output ──────────────────────────────────────────────────────────
output_markdown() {
    local expired_rows="" warning_rows="" ok_rows=""
    local expired_count=0 warning_count=0 ok_count=0
    local total="${#SECRET_NAMES[@]}"

    local i
    for (( i=0; i<total; i++ )); do
        local name="${SECRET_NAMES[$i]}"
        local last_rotated="${SECRET_LAST_ROTATED[$i]}"
        local rotation_days="${SECRET_ROTATION_DAYS[$i]}"
        local required_by="${SECRET_REQUIRED_BY[$i]}"
        local status="${CLASSIFIED_STATUS[$i]}"
        local expiry="${CLASSIFIED_EXPIRY[$i]}"
        local days_until="${CLASSIFIED_DAYS_UNTIL[$i]}"

        # Format status label with days
        local status_label days_label
        if [[ "$days_until" -le 0 ]]; then
            days_label="$(( -days_until )) days ago"
        else
            days_label="in $days_until days"
        fi
        status_label="${status^^}"

        local row="| $name | $status_label | $last_rotated | $rotation_days | $expiry | $days_label | $required_by |"

        case "$status" in
            expired)
                expired_rows+="$row"$'\n'
                expired_count=$(( expired_count + 1 ))
                ;;
            warning)
                warning_rows+="$row"$'\n'
                warning_count=$(( warning_count + 1 ))
                ;;
            ok)
                ok_rows+="$row"$'\n'
                ok_count=$(( ok_count + 1 ))
                ;;
        esac
    done

    local header="| Secret Name | Status | Last Rotated | Rotation Days | Expiry Date | Time | Required By |"
    local separator="|-------------|--------|--------------|---------------|-------------|------|-------------|"

    cat <<EOF
# Secret Rotation Report

**Reference Date:** $REFERENCE_DATE
**Warning Window:** $WARNING_DAYS days
**Total Secrets:** $total | Expired: $expired_count | Warning: $warning_count | OK: $ok_count

---

## Expired Secrets

$header
$separator
${expired_rows:-| *(none)* | | | | | | |}

## Warning Secrets

$header
$separator
${warning_rows:-| *(none)* | | | | | | |}

## OK Secrets

$header
$separator
${ok_rows:-| *(none)* | | | | | | |}
EOF
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    parse_csv "$CONFIG_FILE"
    classify_secrets

    case "$FORMAT" in
        json)     output_json ;;
        markdown) output_markdown ;;
    esac
}

main "$@"
