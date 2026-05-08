#!/usr/bin/env bash
# validate-rotation.sh
#
# Reads a JSON inventory of secrets, classifies each one as expired / warning /
# ok based on its rotation policy, and emits a rotation report grouped by
# urgency. Mock data only — this is a CI gate, not a real secrets manager.
#
# Status rules (given --now NOW and --warning-days W):
#   age = floor((NOW - last_rotated) / 1 day)
#   dte = rotation_days - age              # days_until_expiry
#   dte <  0  -> expired
#   dte <= W  -> warning
#   else      -> ok
#
# Usage:
#   validate-rotation.sh --config FILE [--warning-days N] [--format markdown|json]
#                        [--now YYYY-MM-DD] [--strict]
#
# Exit codes:
#   0  report produced (and, if --strict, no expired secrets)
#   1  report produced but --strict and >=1 expired
#   2  argument / input error

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-rotation.sh --config FILE [--warning-days N] [--format markdown|json]
                            [--now YYYY-MM-DD] [--strict]

  --config FILE        JSON file with a top-level { "secrets": [...] } array.
                       Each entry: { name, last_rotated (YYYY-MM-DD),
                       rotation_days (int), services ([str,...]) }.
  --warning-days N     Days-until-expiry threshold for "warning" (default 14).
  --format FMT         markdown (default) or json.
  --now YYYY-MM-DD     Override current date (for deterministic CI/testing).
  --strict             Exit 1 if any secret is expired.
  -h, --help           Show this help.
EOF
}

config=""
warning_days=14
format="markdown"
now_date=""
strict=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)        config="${2:-}";        shift 2 ;;
    --warning-days)  warning_days="${2:-}";  shift 2 ;;
    --format)        format="${2:-}";        shift 2 ;;
    --now)           now_date="${2:-}";      shift 2 ;;
    --strict)        strict=1;               shift ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$config" ]]; then
  echo "Error: --config is required" >&2
  exit 2
fi
if [[ ! -f "$config" ]]; then
  echo "Error: config file not found: $config" >&2
  exit 2
fi
if [[ "$format" != "markdown" && "$format" != "json" ]]; then
  echo "Error: --format must be 'markdown' or 'json' (got: $format)" >&2
  exit 2
fi
if ! [[ "$warning_days" =~ ^[0-9]+$ ]]; then
  echo "Error: --warning-days must be a non-negative integer (got: $warning_days)" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but not installed" >&2
  exit 2
fi

# Resolve "now" to an epoch. We use date -d for portability (GNU date).
if [[ -n "$now_date" ]]; then
  if ! now_epoch=$(date -d "$now_date" +%s 2>/dev/null); then
    echo "Error: invalid --now date: $now_date" >&2
    exit 2
  fi
else
  now_epoch=$(date +%s)
fi

# Validate the config shape before iterating.
if ! jq -e '.secrets | type == "array"' "$config" >/dev/null 2>&1; then
  echo "Error: invalid config: top-level '.secrets' must be an array" >&2
  exit 2
fi

# Build a tab-separated record stream so the rest of the script is
# format-agnostic. Columns:
#   status \t name \t last_rotated \t rotation_days \t age_days \t dte \t services_csv
records=""
secret_count=$(jq -r '.secrets | length' "$config")
for ((i=0; i<secret_count; i++)); do
  name=$(jq -r ".secrets[$i].name // empty"          "$config")
  last=$(jq -r ".secrets[$i].last_rotated // empty"  "$config")
  rot=$( jq -r ".secrets[$i].rotation_days // empty" "$config")
  services=$(jq -r ".secrets[$i].services // [] | join(\",\")" "$config")

  if [[ -z "$name" || -z "$last" || -z "$rot" ]]; then
    echo "Error: secret #$i missing required field (name/last_rotated/rotation_days)" >&2
    exit 2
  fi
  if ! [[ "$rot" =~ ^[0-9]+$ ]]; then
    echo "Error: rotation_days for $name must be a non-negative integer (got: $rot)" >&2
    exit 2
  fi
  if ! last_epoch=$(date -d "$last" +%s 2>/dev/null); then
    echo "Error: invalid last_rotated date for $name: $last" >&2
    exit 2
  fi

  age_days=$(( (now_epoch - last_epoch) / 86400 ))
  dte=$(( rot - age_days ))

  if (( dte < 0 )); then
    status="expired"
  elif (( dte <= warning_days )); then
    status="warning"
  else
    status="ok"
  fi

  records+=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$status" "$name" "$last" "$rot" "$age_days" "$dte" "$services")
  records+=$'\n'
done

# Count expired entries for exit-code logic.
expired_count=0
if [[ -n "$records" ]]; then
  expired_count=$(printf '%s' "$records" | grep -c $'^expired\t' || true)
fi

emit_json() {
  # Convert the TSV stream into a grouped JSON object via jq.
  printf '%s' "$records" | jq -R -s '
    split("\n")
    | map(select(length > 0))
    | map(split("\t") | {
        status:            .[0],
        name:              .[1],
        last_rotated:      .[2],
        rotation_days:     (.[3] | tonumber),
        age_days:          (.[4] | tonumber),
        days_until_expiry: (.[5] | tonumber),
        services:          (if .[6] == "" then [] else (.[6] | split(",")) end)
      })
    | {
        expired: map(select(.status == "expired")),
        warning: map(select(.status == "warning")),
        ok:      map(select(.status == "ok"))
      }
  '
}

emit_markdown_group() {
  local group_status="$1" heading="$2"
  echo "## $heading"
  echo
  echo "| Name | Last Rotated | Rotation (days) | Days Until Expiry | Services |"
  echo "| --- | --- | --- | --- | --- |"
  local found=0
  if [[ -n "$records" ]]; then
    while IFS=$'\t' read -r status name last rot _age dte services; do
      [[ -z "$status" ]] && continue
      if [[ "$status" == "$group_status" ]]; then
        echo "| $name | $last | $rot | $dte | $services |"
        found=1
      fi
    done <<< "$records"
  fi
  if (( found == 0 )); then
    echo "| _none_ |  |  |  |  |"
  fi
  echo
}

emit_markdown() {
  echo "# Secret Rotation Report"
  echo
  echo "_Generated for date: $(date -d "@$now_epoch" +%Y-%m-%d) (warning window: ${warning_days}d)_"
  echo
  emit_markdown_group "expired" "Expired"
  emit_markdown_group "warning" "Warning"
  emit_markdown_group "ok"      "OK"
}

if [[ "$format" == "json" ]]; then
  emit_json
else
  emit_markdown
fi

if (( strict == 1 && expired_count > 0 )); then
  exit 1
fi
exit 0
