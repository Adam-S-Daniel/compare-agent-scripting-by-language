#!/usr/bin/env bash
# Secret rotation validator.
#
# Reads a JSON config of secrets, computes rotation status (expired/warning/ok)
# against the rotation policy and a warning window, and prints a report.
#
# Usage:
#   secret-rotation.sh -c config.json [-w 14] [-f markdown|json] [--today YYYY-MM-DD]
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: secret-rotation.sh -c CONFIG [-w DAYS] [-f markdown|json] [--today DATE]

Options:
  -c, --config FILE    Path to secrets config JSON (required).
  -w, --warning DAYS   Warning window in days (default: 14).
  -f, --format FMT     Output format: markdown (default) or json.
      --today DATE     Override "today" as YYYY-MM-DD (for deterministic tests).
  -h, --help           Show this help.
EOF
}

config=""
warning=14
format="markdown"
today=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config)   config="${2:-}"; shift 2 ;;
    -w|--warning)  warning="${2:-}"; shift 2 ;;
    -f|--format)   format="${2:-}"; shift 2 ;;
    --today)       today="${2:-}"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$config" ]] || { usage >&2; die "missing --config"; }
[[ -f "$config" ]] || die "config not found: $config"
[[ "$warning" =~ ^[0-9]+$ ]] || die "warning must be a non-negative integer: $warning"
case "$format" in markdown|json) ;; *) die "format must be markdown or json: $format" ;; esac

command -v jq >/dev/null || die "jq is required but not installed"

# Resolve "today" as epoch seconds. GNU date handles both "now" and ISO dates.
if [[ -z "$today" ]]; then
  today_epoch=$(date -u +%s)
  today_iso=$(date -u +%Y-%m-%d)
else
  [[ "$today" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "--today must be YYYY-MM-DD"
  today_epoch=$(date -u -d "$today" +%s) || die "invalid date: $today"
  today_iso="$today"
fi

# Validate JSON up front; also ensure the expected shape.
jq -e '.secrets | type == "array"' "$config" >/dev/null \
  || die "config must contain a 'secrets' array"

# Build an enriched records stream: {name, last_rotated, rotation_days, services,
# age_days, days_until_due, status}. Status classification:
#   age >= rotation_days             -> expired
#   age >= rotation_days - warning   -> warning
#   otherwise                        -> ok
enriched=$(jq --arg today_epoch "$today_epoch" --argjson warning "$warning" '
  def status(age; rot; warn):
    if age >= rot then "expired"
    elif age >= (rot - warn) then "warning"
    else "ok" end;
  .secrets
  | map(
      . as $s
      | ($today_epoch | tonumber) as $te
      | (($s.last_rotated + "T00:00:00Z") | fromdateiso8601) as $le
      | (($te - $le) / 86400 | floor) as $age
      | {
          name: $s.name,
          last_rotated: $s.last_rotated,
          rotation_days: $s.rotation_days,
          services: ($s.services // []),
          age_days: $age,
          days_until_due: ($s.rotation_days - $age),
          status: status($age; $s.rotation_days; $warning)
        }
    )
' "$config")

# Partition counts are derived, keeping the main stream the single source of truth.
counts=$(jq '
  {
    expired: (map(select(.status=="expired")) | length),
    warning: (map(select(.status=="warning")) | length),
    ok:      (map(select(.status=="ok"))      | length),
    total:   length
  }
' <<<"$enriched")

if [[ "$format" == "json" ]]; then
  jq -n \
    --arg today "$today_iso" \
    --argjson warning "$warning" \
    --argjson secrets "$enriched" \
    --argjson counts "$counts" \
    '{today: $today, warning_days: $warning, counts: $counts, secrets: $secrets}'
  exit 0
fi

# Markdown output: header + summary + sections grouped by urgency.
printf '# Secret Rotation Report\n\n'
printf -- '- Date: %s\n' "$today_iso"
printf -- '- Warning window: %s days\n' "$warning"
printf -- '- Expired: %s\n' "$(jq -r '.expired' <<<"$counts")"
printf -- '- Warning: %s\n' "$(jq -r '.warning' <<<"$counts")"
printf -- '- OK: %s\n\n' "$(jq -r '.ok' <<<"$counts")"

render_section() {
  local label="$1" status="$2"
  local rows
  rows=$(jq -r --arg s "$status" '
    map(select(.status == $s))
    | sort_by(.days_until_due)
    | .[]
    | "| \(.name) | \(.last_rotated) | \(.rotation_days) | \(.age_days) | \(.days_until_due) | \((.services // []) | join(", ")) |"
  ' <<<"$enriched")
  printf '## %s\n\n' "$label"
  if [[ -z "$rows" ]]; then
    printf '_None._\n\n'
    return
  fi
  printf '| Name | Last Rotated | Policy (days) | Age (days) | Days Until Due | Services |\n'
  printf '| --- | --- | --- | --- | --- | --- |\n'
  printf '%s\n\n' "$rows"
}

render_section "Expired" "expired"
render_section "Warning" "warning"
render_section "OK" "ok"
