#!/usr/bin/env bash
#
# secret-rotation-validator.sh
#
# Inspect a list of secrets (mock metadata) and classify each as one of:
#   expired  - the rotation policy elapsed before the reference date
#   warning  - the rotation policy will elapse within the warning window
#   ok       - everything else
#
# A markdown table report (human-readable) or a JSON document
# (machine-readable) is emitted to stdout.
#
# Input config (one secret per line, '|' delimited):
#     # comments and blank lines are ignored
#     name|last_rotated|policy_days|services
#     prod_db|2026-04-15|90|api,worker
#
# Date math relies on GNU `date -d` semantics. The GitHub Actions
# ubuntu-latest runner used by .github/workflows/secret-rotation-validator.yml
# ships with GNU coreutils, so that contract is satisfied there.
#
# Exit codes:
#   0   success
#   2   invalid arguments / config parse error / file missing

set -euo pipefail

PROG=${0##*/}

# Configuration globals populated by parse_args + validate_args. Keeping
# these script-scoped lets the markdown/json emitters consume them without
# threading the same five arguments through every helper.
CONFIG=""
NOW=""
WARNING_DAYS=7
FORMAT="markdown"

# Each entry below is a single TAB-encoded record built in load_and_classify:
#     name<TAB>last_rotated<TAB>policy_days<TAB>services<TAB>urgency<TAB>days_until_expiry
declare -a EXPIRED=()
declare -a WARN=()
declare -a OK=()

usage() {
    cat <<EOF
Usage: $PROG --config FILE [options]

Identify expired or expiring secrets and produce a rotation report.

Required:
  --config FILE         Path to secrets config (pipe-delimited).

Options:
  --now YYYY-MM-DD      Reference date used for classification.
                        Default: \$SECRET_NOW or today (UTC).
  --warning-days N      Days ahead of expiration to mark as warning.
                        Default: 7. Must be a non-negative integer.
  --format FORMAT       Output format: markdown (default) or json.
  -h, --help            Show this help and exit.

Input format:
  # comments and blank lines are ignored
  name|last_rotated|policy_days|services
  prod_db|2026-04-15|90|api,worker
EOF
}

die() {
    printf '%s: error: %s\n' "$PROG" "$1" >&2
    exit 2
}

# Convert YYYY-MM-DD into days-since-epoch using GNU date.
# Returns non-zero if the date string is unparseable.
date_to_days() {
    local d=$1
    local epoch
    if ! epoch=$(date -u -d "$d" +%s 2>/dev/null); then
        return 1
    fi
    printf '%d\n' $((epoch / 86400))
}

parse_args() {
    while (($#)); do
        case $1 in
            --config)
                [[ $# -ge 2 ]] || die "--config requires a value"
                CONFIG=$2; shift 2 ;;
            --now)
                [[ $# -ge 2 ]] || die "--now requires a value"
                NOW=$2; shift 2 ;;
            --warning-days)
                [[ $# -ge 2 ]] || die "--warning-days requires a value"
                WARNING_DAYS=$2; shift 2 ;;
            --format)
                [[ $# -ge 2 ]] || die "--format requires a value"
                FORMAT=$2; shift 2 ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                die "unknown argument: $1" ;;
        esac
    done
}

validate_args() {
    [[ -n $CONFIG ]] || die "missing required --config"
    [[ -f $CONFIG ]] || die "config file not found: $CONFIG"

    if [[ -z $NOW ]]; then
        NOW=${SECRET_NOW:-$(date -u +%Y-%m-%d)}
    fi
    date_to_days "$NOW" >/dev/null || die "invalid --now date: $NOW"

    [[ $WARNING_DAYS =~ ^[0-9]+$ ]] \
        || die "warning-days must be a non-negative integer: $WARNING_DAYS"

    case $FORMAT in
        markdown|json) ;;
        *) die "unknown format: $FORMAT (allowed: markdown, json)" ;;
    esac
}

load_and_classify() {
    local now_days
    now_days=$(date_to_days "$NOW")

    local lineno=0 raw
    while IFS= read -r raw || [[ -n $raw ]]; do
        lineno=$((lineno + 1))
        # Strip trailing CR if the file was authored on Windows.
        raw=${raw%$'\r'}
        # Skip blank lines and comment lines.
        [[ -z ${raw//[[:space:]]/} ]] && continue
        [[ ${raw:0:1} == '#' ]] && continue

        local name last_rotated policy_days services
        IFS='|' read -r name last_rotated policy_days services <<<"$raw"
        services=${services:-}

        [[ -n $name && -n $last_rotated && -n $policy_days ]] \
            || die "config line $lineno: expected 'name|last_rotated|policy_days|services'"
        [[ $policy_days =~ ^[0-9]+$ ]] \
            || die "config line $lineno: policy_days must be an integer (got '$policy_days')"

        local rotated_days
        rotated_days=$(date_to_days "$last_rotated") \
            || die "config line $lineno: invalid date '$last_rotated'"

        local expires_days=$((rotated_days + policy_days))
        local days_until=$((expires_days - now_days))

        local urgency
        if (( days_until < 0 )); then
            urgency=expired
        elif (( days_until <= WARNING_DAYS )); then
            urgency=warning
        else
            urgency=ok
        fi

        local record
        record=$(printf '%s\t%s\t%s\t%s\t%s\t%s' \
            "$name" "$last_rotated" "$policy_days" "$services" \
            "$urgency" "$days_until")

        case $urgency in
            expired) EXPIRED+=("$record") ;;
            warning) WARN+=("$record") ;;
            ok)      OK+=("$record") ;;
        esac
    done < "$CONFIG"
}

# --- Markdown emission ------------------------------------------------------

emit_markdown() {
    printf '# Secret Rotation Report\n\n'
    printf 'Reference date: %s\n' "$NOW"
    printf 'Warning window: %s day(s)\n\n' "$WARNING_DAYS"
    printf 'Summary: %d expired, %d warning, %d ok\n\n' \
        "${#EXPIRED[@]}" "${#WARN[@]}" "${#OK[@]}"

    emit_md_section 'Expired' ${EXPIRED[@]+"${EXPIRED[@]}"}
    emit_md_section 'Warning' ${WARN[@]+"${WARN[@]}"}
    emit_md_section 'OK'      ${OK[@]+"${OK[@]}"}
}

emit_md_section() {
    local title=$1; shift
    local count=$#
    printf '## %s (%d)\n\n' "$title" "$count"
    if (( count == 0 )); then
        printf '_None._\n\n'
        return
    fi
    printf '| Name | Last Rotated | Policy (days) | Services | Days Until Expiry |\n'
    printf '|------|--------------|---------------|----------|-------------------|\n'
    local rec name last policy services urgency days
    for rec in "$@"; do
        IFS=$'\t' read -r name last policy services urgency days <<<"$rec"
        printf '| %s | %s | %s | %s | %s |\n' \
            "$name" "$last" "$policy" "$services" "$days"
    done
    printf '\n'
}

# --- JSON emission ----------------------------------------------------------

# Escape backslash, double-quote, and the typical control chars for JSON.
# Sufficient for the mock data this script consumes; not a general-purpose
# encoder.
json_escape_string() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

# Build a JSON array literal from a comma-separated services field.
json_services_array() {
    local services=$1
    local out="["
    if [[ -n $services ]]; then
        local first=1 part
        local IFS_OLD=$IFS
        IFS=','
        # Word-splitting on comma is intentional here.
        # shellcheck disable=SC2206
        local -a parts=( $services )
        IFS=$IFS_OLD
        for part in "${parts[@]}"; do
            part=${part# }
            part=${part% }
            if (( first )); then
                first=0
            else
                out+=","
            fi
            out+="\"$(json_escape_string "$part")\""
        done
    fi
    out+="]"
    printf '%s' "$out"
}

emit_json_record() {
    local rec=$1
    local name last policy services urgency days
    IFS=$'\t' read -r name last policy services urgency days <<<"$rec"
    printf '{"name":"%s","last_rotated":"%s","policy_days":%d,"services":%s,"urgency":"%s","days_until_expiry":%d}' \
        "$(json_escape_string "$name")" \
        "$(json_escape_string "$last")" \
        "$policy" \
        "$(json_services_array "$services")" \
        "$(json_escape_string "$urgency")" \
        "$days"
}

emit_json_array() {
    if (( $# == 0 )); then
        printf '[]'
        return
    fi
    local i=0
    printf '['
    while (($#)); do
        if (( i > 0 )); then
            printf ','
        fi
        emit_json_record "$1"
        i=$((i + 1))
        shift
    done
    printf ']'
}

emit_json() {
    printf '{'
    printf '"reference_date":"%s",' "$NOW"
    printf '"warning_days":%d,' "$WARNING_DAYS"
    printf '"summary":{"expired":%d,"warning":%d,"ok":%d},' \
        "${#EXPIRED[@]}" "${#WARN[@]}" "${#OK[@]}"

    printf '"expired":'
    emit_json_array ${EXPIRED[@]+"${EXPIRED[@]}"}
    printf ','

    printf '"warning":'
    emit_json_array ${WARN[@]+"${WARN[@]}"}
    printf ','

    printf '"ok":'
    emit_json_array ${OK[@]+"${OK[@]}"}

    printf '}\n'
}

main() {
    parse_args "$@"
    validate_args
    load_and_classify
    case $FORMAT in
        markdown) emit_markdown ;;
        json)     emit_json ;;
    esac
}

main "$@"
