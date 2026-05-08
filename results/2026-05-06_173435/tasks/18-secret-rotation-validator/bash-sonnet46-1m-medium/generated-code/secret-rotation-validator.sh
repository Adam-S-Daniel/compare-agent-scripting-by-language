#!/usr/bin/env bash
# Secret Rotation Validator
# Reads a JSON config of secrets, computes rotation status, and outputs a report.
# Uses jq for JSON parsing; requires Linux date (date -d).

set -euo pipefail

# ── defaults ────────────────────────────────────────────────────────────────
FORMAT="markdown"
WARNING_DAYS=14
REFERENCE_DATE=""
CONFIG_FILE=""

usage() {
  cat <<'EOF'
Usage: secret-rotation-validator.sh [OPTIONS] <config.json>

Options:
  --format <markdown|json>   Output format (default: markdown)
  --warning-days <N>         Days before expiry to warn (default: 14)
  --date <YYYY-MM-DD>        Reference date for calculations (default: today)
  -h, --help                 Show this help message

Config JSON format:
  [
    {
      "name": "SECRET_NAME",
      "last_rotated": "YYYY-MM-DD",
      "rotation_days": 90,
      "required_by": ["service1", "service2"]
    }
  ]
EOF
}

# ── argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"; shift 2 ;;
    --warning-days)
      WARNING_DAYS="$2"; shift 2 ;;
    --date)
      REFERENCE_DATE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    -*)
      echo "Error: Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      CONFIG_FILE="$1"; shift ;;
  esac
done

# ── validation ───────────────────────────────────────────────────────────────
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Error: config file argument is required" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

if [[ "$FORMAT" != "markdown" && "$FORMAT" != "json" ]]; then
  echo "Error: invalid format '$FORMAT' — must be 'markdown' or 'json'" >&2
  exit 1
fi

# ── date helpers ─────────────────────────────────────────────────────────────
REF_DATE="${REFERENCE_DATE:-$(date +%Y-%m-%d)}"

# Return Unix epoch for a YYYY-MM-DD string (always UTC to avoid DST skew)
date_epoch() {
  TZ=UTC date -d "$1" +%s
}

# Add N days to a YYYY-MM-DD and return the result as YYYY-MM-DD (UTC)
add_days() {
  TZ=UTC date -d "$1 + $2 days" +%Y-%m-%d
}

# ── classify each secret ─────────────────────────────────────────────────────
ref_epoch=$(date_epoch "$REF_DATE")

# Build three arrays: expired, warning, ok — each element is a JSON object
expired_items="[]"
warning_items="[]"
ok_items="[]"

# Read JSON array into a temporary file so we can iterate safely with jq
tmp_in=$(mktemp)
cp "$CONFIG_FILE" "$tmp_in"

# Get count of secrets
count=$(jq 'length' "$tmp_in")

for (( i=0; i<count; i++ )); do
  name=$(jq -r ".[$i].name" "$tmp_in")
  last_rotated=$(jq -r ".[$i].last_rotated" "$tmp_in")
  rotation_days=$(jq -r ".[$i].rotation_days" "$tmp_in")
  required_by=$(jq -c ".[$i].required_by" "$tmp_in")

  expires=$(add_days "$last_rotated" "$rotation_days")
  expires_epoch=$(date_epoch "$expires")
  days_diff=$(( (expires_epoch - ref_epoch) / 86400 ))

  if (( days_diff < 0 )); then
    # Expired: past the rotation deadline
    days_overdue=$(( -days_diff ))
    item=$(jq -n \
      --arg name "$name" \
      --arg last_rotated "$last_rotated" \
      --arg expires "$expires" \
      --argjson days_overdue "$days_overdue" \
      --argjson rotation_days "$rotation_days" \
      --argjson required_by "$required_by" \
      '{name: $name, last_rotated: $last_rotated, expires: $expires,
        days_overdue: $days_overdue, rotation_days: $rotation_days,
        required_by: $required_by}')
    expired_items=$(echo "$expired_items" | jq ". + [$item]")
  elif (( days_diff <= WARNING_DAYS )); then
    # Warning: expiring within the warning window
    days_until_expiry=$days_diff
    item=$(jq -n \
      --arg name "$name" \
      --arg last_rotated "$last_rotated" \
      --arg expires "$expires" \
      --argjson days_until_expiry "$days_until_expiry" \
      --argjson rotation_days "$rotation_days" \
      --argjson required_by "$required_by" \
      '{name: $name, last_rotated: $last_rotated, expires: $expires,
        days_until_expiry: $days_until_expiry, rotation_days: $rotation_days,
        required_by: $required_by}')
    warning_items=$(echo "$warning_items" | jq ". + [$item]")
  else
    # OK: plenty of time remaining
    days_until_expiry=$days_diff
    item=$(jq -n \
      --arg name "$name" \
      --arg last_rotated "$last_rotated" \
      --arg expires "$expires" \
      --argjson days_until_expiry "$days_until_expiry" \
      --argjson rotation_days "$rotation_days" \
      --argjson required_by "$required_by" \
      '{name: $name, last_rotated: $last_rotated, expires: $expires,
        days_until_expiry: $days_until_expiry, rotation_days: $rotation_days,
        required_by: $required_by}')
    ok_items=$(echo "$ok_items" | jq ". + [$item]")
  fi
done

rm -f "$tmp_in"

# ── output ───────────────────────────────────────────────────────────────────
if [[ "$FORMAT" == "json" ]]; then
  jq -n \
    --arg generated "$REF_DATE" \
    --argjson expired "$expired_items" \
    --argjson warning "$warning_items" \
    --argjson ok "$ok_items" \
    '{generated: $generated, expired: $expired, warning: $warning, ok: $ok}'
  exit 0
fi

# ── markdown output ──────────────────────────────────────────────────────────
expired_count=$(echo "$expired_items" | jq 'length')
warning_count=$(echo "$warning_items" | jq 'length')
ok_count=$(echo "$ok_items" | jq 'length')

echo "# Secret Rotation Report"
echo "Generated: $REF_DATE | Warning window: ${WARNING_DAYS} days"
echo ""

echo "## EXPIRED ($expired_count)"
if (( expired_count > 0 )); then
  echo "| Secret | Last Rotated | Expires | Days Overdue | Required By |"
  echo "|--------|-------------|---------|-------------|-------------|"
  while IFS= read -r row; do
    name=$(echo "$row" | jq -r '.name')
    lr=$(echo "$row" | jq -r '.last_rotated')
    exp=$(echo "$row" | jq -r '.expires')
    overdue=$(echo "$row" | jq -r '.days_overdue')
    req=$(echo "$row" | jq -r '.required_by | join(", ")')
    echo "| $name | $lr | $exp | $overdue | $req |"
  done < <(echo "$expired_items" | jq -c '.[]')
else
  echo "_No expired secrets_"
fi
echo ""

echo "## WARNING ($warning_count)"
if (( warning_count > 0 )); then
  echo "| Secret | Last Rotated | Expires | Days Until Expiry | Required By |"
  echo "|--------|-------------|---------|------------------|-------------|"
  while IFS= read -r row; do
    name=$(echo "$row" | jq -r '.name')
    lr=$(echo "$row" | jq -r '.last_rotated')
    exp=$(echo "$row" | jq -r '.expires')
    until=$(echo "$row" | jq -r '.days_until_expiry')
    req=$(echo "$row" | jq -r '.required_by | join(", ")')
    echo "| $name | $lr | $exp | $until | $req |"
  done < <(echo "$warning_items" | jq -c '.[]')
else
  echo "_No warning secrets_"
fi
echo ""

echo "## OK ($ok_count)"
if (( ok_count > 0 )); then
  echo "| Secret | Last Rotated | Expires | Days Until Expiry | Required By |"
  echo "|--------|-------------|---------|------------------|-------------|"
  while IFS= read -r row; do
    name=$(echo "$row" | jq -r '.name')
    lr=$(echo "$row" | jq -r '.last_rotated')
    exp=$(echo "$row" | jq -r '.expires')
    until=$(echo "$row" | jq -r '.days_until_expiry')
    req=$(echo "$row" | jq -r '.required_by | join(", ")')
    echo "| $name | $lr | $exp | $until | $req |"
  done < <(echo "$ok_items" | jq -c '.[]')
else
  echo "_No ok secrets_"
fi
