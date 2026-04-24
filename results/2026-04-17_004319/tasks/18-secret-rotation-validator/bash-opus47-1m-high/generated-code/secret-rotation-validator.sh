#!/usr/bin/env bash
# secret-rotation-validator.sh
#
# Reads a JSON config of secrets and reports which are expired, in a
# rotation warning window, or still ok. Outputs markdown or JSON.
#
# Each secret entry must have:
#   name                  string   identifier
#   last_rotated          string   YYYY-MM-DD date
#   rotation_policy_days  number   days between required rotations
#   services              array    services that depend on the secret
#
# Approach:
#   * Parse args, load+validate JSON via jq.
#   * For each secret, compute days_until_expiry = policy - (today - last_rotated).
#   * Bucket by urgency: <=0 expired, <=warning_days warning, else ok.
#   * Emit markdown or JSON; --strict makes exit code reflect the worst bucket
#     so the script can gate CI builds.

set -euo pipefail

# ---------- defaults ---------------------------------------------------------
CONFIG=""
WARNING_DAYS=14
FORMAT="markdown"
TODAY=""
STRICT=0

usage() {
    cat <<'EOF'
Usage: secret-rotation-validator.sh --config <file> [options]

Identify expired or expiring secrets and emit a rotation report.

Options:
  --config <file>          Path to JSON file with secret metadata (required)
  --warning-days <N>       Days before expiry to count as "warning" (default 14)
  --format <markdown|json> Output format (default markdown)
  --today <YYYY-MM-DD>     Override "today" for deterministic runs (testing)
  --strict                 Exit 2 on any expired, 1 on any warning, else 0
  -h, --help               Show this help and exit

Config file is a JSON array of objects:
  [{"name":"api-token","last_rotated":"2025-12-01",
    "rotation_policy_days":90,"services":["web-api"]}]
EOF
}

# ---------- arg parsing ------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)        CONFIG="${2:-}"; shift 2 ;;
        --warning-days)  WARNING_DAYS="${2:-}"; shift 2 ;;
        --format)        FORMAT="${2:-}"; shift 2 ;;
        --today)         TODAY="${2:-}"; shift 2 ;;
        --strict)        STRICT=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
    esac
done

# ---------- validate args ----------------------------------------------------
if [[ -z "${CONFIG}" ]]; then
    echo "ERROR: --config is required" >&2
    exit 64
fi
if [[ ! -f "${CONFIG}" ]]; then
    echo "ERROR: config file not found: ${CONFIG}" >&2
    exit 66
fi
if [[ "${FORMAT}" != "markdown" && "${FORMAT}" != "json" ]]; then
    echo "ERROR: invalid --format '${FORMAT}'; must be markdown or json" >&2
    exit 64
fi
if ! [[ "${WARNING_DAYS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --warning-days must be a non-negative integer" >&2
    exit 64
fi

# Default today to system date if not provided.
if [[ -z "${TODAY}" ]]; then
    TODAY="$(date -u +%Y-%m-%d)"
fi
if ! date -d "${TODAY}" +%s >/dev/null 2>&1; then
    echo "ERROR: invalid --today date: ${TODAY}" >&2
    exit 64
fi

# ---------- validate JSON shape ---------------------------------------------
if ! jq -e . "${CONFIG}" >/dev/null 2>&1; then
    echo "ERROR: failed to parse JSON in ${CONFIG}" >&2
    exit 65
fi
if ! jq -e 'type == "array"' "${CONFIG}" >/dev/null 2>&1; then
    echo "ERROR: config must be a JSON array" >&2
    exit 65
fi

# Verify every entry has the required fields with the right types.
missing=$(jq -r '
    to_entries[]
    | select(
        (.value | type) != "object"
        or (.value | has("name") | not)
        or (.value | has("last_rotated") | not)
        or (.value | has("rotation_policy_days") | not)
        or (.value | has("services") | not)
        or (.value.services | type) != "array"
        or (.value.rotation_policy_days | type) != "number"
      )
    | "entry \(.key) is missing required field(s)"
' "${CONFIG}")
if [[ -n "${missing}" ]]; then
    echo "ERROR: ${missing}" >&2
    exit 65
fi

# ---------- compute buckets --------------------------------------------------
today_epoch=$(date -d "${TODAY}" +%s)
day_secs=86400

# Build an "augmented" JSON document with computed urgency + days_until_expiry.
augmented="[]"
count=$(jq 'length' "${CONFIG}")
for ((i=0; i<count; i++)); do
    name=$(jq -r ".[$i].name" "${CONFIG}")
    last=$(jq -r ".[$i].last_rotated" "${CONFIG}")
    policy=$(jq -r ".[$i].rotation_policy_days" "${CONFIG}")
    services_json=$(jq -c ".[$i].services" "${CONFIG}")

    if ! last_epoch=$(date -d "${last}" +%s 2>/dev/null); then
        echo "ERROR: invalid last_rotated date for ${name}: ${last}" >&2
        exit 65
    fi

    days_since=$(( (today_epoch - last_epoch) / day_secs ))
    days_until=$(( policy - days_since ))

    if (( days_until <= 0 )); then
        urgency="expired"
    elif (( days_until <= WARNING_DAYS )); then
        urgency="warning"
    else
        urgency="ok"
    fi

    entry=$(jq -n \
        --arg name "${name}" \
        --arg last "${last}" \
        --argjson policy "${policy}" \
        --argjson services "${services_json}" \
        --argjson days_until "${days_until}" \
        --arg urgency "${urgency}" \
        '{name:$name, last_rotated:$last, rotation_policy_days:$policy,
          services:$services, days_until_expiry:$days_until, urgency:$urgency}')
    augmented=$(jq --argjson e "${entry}" '. + [$e]' <<<"${augmented}")
done

# ---------- emit output ------------------------------------------------------
emit_json() {
    jq '{
        generated_at: $today,
        warning_days: ($wd | tonumber),
        expired: [.[] | select(.urgency=="expired")],
        warning: [.[] | select(.urgency=="warning")],
        ok:      [.[] | select(.urgency=="ok")]
    }' --arg today "${TODAY}" --arg wd "${WARNING_DAYS}" <<<"${augmented}"
}

emit_markdown_section() {
    local heading="$1" filter="$2"
    local rows
    rows=$(jq -r --arg f "${filter}" '
        [.[] | select(.urgency==$f)] as $g
        | if ($g|length) == 0 then "_(none)_"
          else
            ( "| Name | Last Rotated | Policy (days) | Days Until Expiry | Services |\n" +
              "|------|--------------|---------------|-------------------|----------|\n" +
              ([$g[] | "| \(.name) | \(.last_rotated) | \(.rotation_policy_days) | \(.days_until_expiry) | \(.services | join(", ")) |"] | join("\n"))
            )
          end
    ' <<<"${augmented}")
    printf '## %s\n\n%s\n\n' "${heading}" "${rows}"
}

emit_markdown() {
    printf '# Secret Rotation Report\n\n'
    printf '_Generated for %s with warning window of %s days._\n\n' \
        "${TODAY}" "${WARNING_DAYS}"
    emit_markdown_section "Expired" "expired"
    emit_markdown_section "Warning" "warning"
    emit_markdown_section "OK" "ok"
}

if [[ "${FORMAT}" == "json" ]]; then
    emit_json
else
    emit_markdown
fi

# ---------- strict exit codes ------------------------------------------------
if (( STRICT )); then
    expired_n=$(jq '[.[] | select(.urgency=="expired")] | length' <<<"${augmented}")
    warning_n=$(jq '[.[] | select(.urgency=="warning")] | length' <<<"${augmented}")
    if (( expired_n > 0 )); then
        exit 2
    elif (( warning_n > 0 )); then
        exit 1
    fi
fi
exit 0
