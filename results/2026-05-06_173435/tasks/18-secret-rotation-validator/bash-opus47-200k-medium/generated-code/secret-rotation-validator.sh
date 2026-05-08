#!/usr/bin/env bash
# secret-rotation-validator.sh — classify secrets by rotation status.
#
# Reads a JSON config describing secrets (name, last_rotated date, rotation
# policy in days, services that depend on the secret), then groups each
# secret into expired / warning / ok buckets relative to a "now" date and
# a configurable warning window. Emits either a Markdown report or a JSON
# document. Exits non-zero when expired secrets are present so the script
# can gate CI pipelines.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: secret-rotation-validator.sh --config FILE [options]

Options:
  --config FILE         Path to JSON file describing secrets (required).
  --warning-days N      Warning window in days (default: 14).
  --format FORMAT       Output format: markdown | json (default: markdown).
  --now YYYY-MM-DD      Reference "today" date (default: current UTC date).
  -h, --help            Show this help text.

Exit codes:
  0  no expired secrets
  1  one or more secrets are expired
  2  invalid invocation / configuration error
EOF
}

die() { echo "Error: $*" >&2; exit 2; }

config=""
warning_days=14
format="markdown"
now=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)        [[ $# -ge 2 ]] || die "--config requires a value"; config="$2"; shift 2 ;;
    --warning-days)  [[ $# -ge 2 ]] || die "--warning-days requires a value"; warning_days="$2"; shift 2 ;;
    --format)        [[ $# -ge 2 ]] || die "--format requires a value"; format="$2"; shift 2 ;;
    --now)           [[ $# -ge 2 ]] || die "--now requires a value"; now="$2"; shift 2 ;;
    -h|--help)       usage; exit 0 ;;
    *)               echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$config" ]] || die "--config is required"
[[ -f "$config" ]] || die "config file not found: $config"
[[ "$warning_days" =~ ^[0-9]+$ ]] || die "--warning-days must be a non-negative integer (got: $warning_days)"
case "$format" in
  markdown|json) ;;
  *) die "unknown --format: $format (expected markdown|json)" ;;
esac

[[ -n "$now" ]] || now=$(date -u +%Y-%m-%d)
[[ "$now" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "invalid --now date: $now"

command -v jq >/dev/null 2>&1 || die "jq is required but not installed"

# date(1) accepts YYYY-MM-DD; converting to epoch seconds in UTC keeps math
# free of DST/timezone surprises.
if ! now_epoch=$(date -u -d "$now" +%s 2>/dev/null); then
  die "invalid --now date: $now"
fi

jq -e 'type == "array"' "$config" >/dev/null 2>&1 \
  || die "config must be a JSON array of secret objects"

# Read secrets as TSV rows so we can iterate in pure bash without re-parsing
# JSON per record. Services are joined with a comma here and re-split below.
mapfile -t rows < <(
  jq -r '.[] | [
    .name,
    .last_rotated,
    (.rotation_days|tostring),
    (.services // [] | join(","))
  ] | @tsv' "$config"
)

# Per-bucket arrays of pipe-delimited records:
#   name|last_rotated|rotation_days|days_until|services_csv
expired=()
warning=()
ok=()

for row in "${rows[@]}"; do
  IFS=$'\t' read -r name last_rotated rotation_days services <<< "$row"
  [[ -n "$name" ]] || die "secret with empty name in $config"
  [[ "$last_rotated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
    || die "invalid last_rotated for $name: $last_rotated"
  [[ "$rotation_days" =~ ^[0-9]+$ ]] \
    || die "invalid rotation_days for $name: $rotation_days"

  if ! last_epoch=$(date -u -d "$last_rotated" +%s 2>/dev/null); then
    die "invalid last_rotated for $name: $last_rotated"
  fi

  days_since=$(( (now_epoch - last_epoch) / 86400 ))
  days_until=$(( rotation_days - days_since ))
  record="${name}|${last_rotated}|${rotation_days}|${days_until}|${services}"

  if (( days_until < 0 )); then
    expired+=("$record")
  elif (( days_until <= warning_days )); then
    warning+=("$record")
  else
    ok+=("$record")
  fi
done

emit_markdown_section() {
  local title="$1"; shift
  local -a entries=("$@")
  echo "## ${title} (${#entries[@]})"
  echo
  if (( ${#entries[@]} == 0 )); then
    echo "_None._"
    echo
    return
  fi
  echo "| Name | Last Rotated | Policy (days) | Days Until Expiry | Services |"
  echo "| --- | --- | --- | --- | --- |"
  local rec name last rot du svc svc_pretty
  for rec in "${entries[@]}"; do
    IFS='|' read -r name last rot du svc <<< "$rec"
    svc_pretty="${svc//,/, }"
    echo "| ${name} | ${last} | ${rot} | ${du} | ${svc_pretty} |"
  done
  echo
}

emit_markdown() {
  echo "# Secret Rotation Report"
  echo
  echo "_Reference date: ${now} — warning window: ${warning_days} days._"
  echo
  emit_markdown_section "Expired" "${expired[@]+"${expired[@]}"}"
  emit_markdown_section "Warning" "${warning[@]+"${warning[@]}"}"
  emit_markdown_section "OK" "${ok[@]+"${ok[@]}"}"
}

# Convert a single pipe-delimited record into a JSON object via jq.
record_to_json() {
  local rec="$1" name last rot du svc
  IFS='|' read -r name last rot du svc <<< "$rec"
  jq -n \
    --arg name "$name" \
    --arg last_rotated "$last" \
    --argjson rotation_days "$rot" \
    --argjson days_until_expiry "$du" \
    --arg services_csv "$svc" \
    '{
       name: $name,
       last_rotated: $last_rotated,
       rotation_days: $rotation_days,
       days_until_expiry: $days_until_expiry,
       services: ($services_csv | if . == "" then [] else split(",") end)
     }'
}

bucket_to_json_array() {
  local -a entries=("$@")
  if (( ${#entries[@]} == 0 )); then
    echo '[]'
    return
  fi
  local rec
  {
    for rec in "${entries[@]}"; do
      record_to_json "$rec"
    done
  } | jq -s '.'
}

emit_json() {
  local exp_json warn_json ok_json
  exp_json=$(bucket_to_json_array "${expired[@]+"${expired[@]}"}")
  warn_json=$(bucket_to_json_array "${warning[@]+"${warning[@]}"}")
  ok_json=$(bucket_to_json_array "${ok[@]+"${ok[@]}"}")
  jq -n \
    --arg now "$now" \
    --argjson warning_days "$warning_days" \
    --argjson expired "$exp_json" \
    --argjson warning "$warn_json" \
    --argjson ok "$ok_json" \
    '{
       generated_at: $now,
       warning_days: $warning_days,
       summary: {
         expired: ($expired | length),
         warning: ($warning | length),
         ok:      ($ok      | length)
       },
       expired: $expired,
       warning: $warning,
       ok:      $ok
     }'
}

case "$format" in
  markdown) emit_markdown ;;
  json)     emit_json ;;
esac

# Gate CI: any expired secret is a failure.
if (( ${#expired[@]} > 0 )); then
  exit 1
fi
exit 0
