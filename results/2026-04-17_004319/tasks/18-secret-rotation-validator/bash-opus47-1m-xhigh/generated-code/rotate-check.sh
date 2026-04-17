#!/usr/bin/env bash
#
# rotate-check.sh — secret-rotation validator.
#
# Reads a JSON configuration describing secrets (name, last_rotated date,
# rotation_policy_days, required_by services), classifies each by urgency
# (expired | warning | ok), and prints a report in markdown or JSON.
#
# The "today" reference date and the warning window are configurable so the
# tool is deterministic under test and flexible in CI (e.g. a tighter warning
# window when running nightly).
#
# Exit code is always 0 on successful report generation, regardless of
# urgency counts; that keeps the workflow's job green while still surfacing
# expired secrets in the printed report. Callers who want hard failure on
# expired secrets can pipe the output and grep, or parse the JSON summary.
#
# Usage:
#   rotate-check.sh --config <path> [--format markdown|json]
#                   [--today YYYY-MM-DD] [--warning-days N]

set -euo pipefail

# -- defaults ---------------------------------------------------------------
config=""
format="markdown"
today=""
warning_days="14"

die() {
  # Emit a clear error to stderr and exit non-zero.
  echo "rotate-check: error: $*" >&2
  exit 2
}

usage() {
  cat <<'EOF'
Usage: rotate-check.sh --config <path> [--format markdown|json]
                       [--today YYYY-MM-DD] [--warning-days N]

Options:
  --config        Path to JSON config file (required).
  --format        Output format: "markdown" (default) or "json".
  --today         Reference date in YYYY-MM-DD. Defaults to current UTC date.
  --warning-days  Warning window size in days. Default: 14.
  -h, --help      Show this message.
EOF
}

# -- argument parsing -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)        config="${2:-}"; shift 2 ;;
    --format)        format="${2:-}"; shift 2 ;;
    --today)         today="${2:-}"; shift 2 ;;
    --warning-days)  warning_days="${2:-}"; shift 2 ;;
    -h|--help)       usage; exit 0 ;;
    *)               die "unknown argument: $1" ;;
  esac
done

[[ -n "$config" ]] || { usage >&2; die "--config is required"; }
[[ -f "$config" ]] || die "config file not found: $config"
[[ "$format" == "markdown" || "$format" == "json" ]] \
  || die "invalid --format '$format' (expected markdown or json)"
[[ "$warning_days" =~ ^[0-9]+$ ]] || die "--warning-days must be a non-negative integer"

command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
command -v date >/dev/null 2>&1 || die "date is required but not installed"

# Pin the timezone for *all* date math so results are deterministic
# regardless of where the tool runs (local dev, CI container, etc.).
# Without this, DST transitions between two dates skew day-count math
# and the same config would yield different reports on different hosts.
export TZ=UTC

# Default today to current UTC date if not supplied.
if [[ -z "$today" ]]; then
  today="$(date +%F)"
fi

# Validate date strings early so we fail fast with a friendly message.
if ! date -d "$today" +%s >/dev/null 2>&1; then
  die "invalid --today date: $today"
fi

# -- classification helpers -------------------------------------------------

# days_between <start YYYY-MM-DD> <end YYYY-MM-DD> -> integer days (end-start)
days_between() {
  local start_s end_s
  start_s=$(date -d "$1" +%s) || return 1
  end_s=$(date -d "$2" +%s) || return 1
  # Use integer division. Time-of-day is always 00:00:00 for -d "YYYY-MM-DD".
  echo $(( (end_s - start_s) / 86400 ))
}

# classify <days_since> <policy_days> <warning_days> -> expired|warning|ok
classify() {
  local since="$1" policy="$2" warn="$3"
  if (( since > policy )); then
    echo expired
  elif (( since >= policy - warn )); then
    echo warning
  else
    echo ok
  fi
}

# -- load and validate config ----------------------------------------------

if ! jq -e '.secrets | type == "array"' "$config" >/dev/null 2>&1; then
  die "config must contain a top-level 'secrets' array"
fi

# Build a normalised, TSV-style intermediate representation so we can sort
# and group without re-running jq multiple times.  Columns:
#   name \t last_rotated \t policy \t required_by_csv \t days_since \t
#     delta (positive=overdue, negative/zero=not-yet-expired) \t urgency
normalised=$(mktemp)
trap 'rm -f "$normalised"' EXIT

# We read each secret with jq, computing days_since here in bash so that
# `--today` fully controls the reference point (jq has no built-in date-diff
# on GNU environments without extensions).
while IFS=$'\t' read -r name last_rotated policy required_csv; do
  # Validate the row has the four expected fields and a parseable date.
  [[ -n "$name" && -n "$last_rotated" && -n "$policy" ]] \
    || die "secret entry missing required field (name/last_rotated/rotation_policy_days)"
  [[ "$policy" =~ ^[0-9]+$ ]] \
    || die "rotation_policy_days for '$name' must be a non-negative integer"
  if ! date -d "$last_rotated" +%s >/dev/null 2>&1; then
    die "invalid last_rotated date for '$name': $last_rotated"
  fi

  days_since=$(days_between "$last_rotated" "$today")
  overdue=$(( days_since - policy ))
  urgency=$(classify "$days_since" "$policy" "$warning_days")

  printf '%s\t%s\t%s\t%s\t%d\t%d\t%s\n' \
    "$name" "$last_rotated" "$policy" "$required_csv" \
    "$days_since" "$overdue" "$urgency" >>"$normalised"
done < <(
  jq -r '.secrets[]
         | [ .name,
             .last_rotated,
             (.rotation_policy_days|tostring),
             (.required_by // [] | join(",")) ]
         | @tsv' "$config"
)

# -- helpers for rendering --------------------------------------------------

# Filter rows by urgency, preserving input order.
rows_for() {
  awk -v u="$1" -F '\t' '$7 == u' "$normalised"
}

count_for() {
  rows_for "$1" | wc -l | awk '{print $1}'
}

# -- rendering: markdown ----------------------------------------------------
render_markdown() {
  local exp warn ok
  exp=$(count_for expired)
  warn=$(count_for warning)
  ok=$(count_for ok)

  echo "# Secret Rotation Report"
  echo
  echo "Generated: $today"
  echo "Warning window: $warning_days day(s)"
  echo
  echo "## Summary"
  echo
  echo "- Expired: $exp"
  echo "- Warning: $warn"
  echo "- OK: $ok"
  echo

  # Expired section — always printed so consumers can assert its presence.
  echo "## Expired (action required)"
  echo
  if [[ "$exp" -gt 0 ]]; then
    echo "| Secret | Last Rotated | Policy (days) | Days Overdue | Required By |"
    echo "|--------|--------------|---------------|--------------|-------------|"
    rows_for expired | while IFS=$'\t' read -r name last policy req _ overdue _; do
      req_human=${req//,/, }
      printf '| %s | %s | %s | %s | %s |\n' \
        "$name" "$last" "$policy" "$overdue" "$req_human"
    done
  else
    echo "_None_"
  fi
  echo

  echo "## Warning (rotate soon)"
  echo
  if [[ "$warn" -gt 0 ]]; then
    echo "| Secret | Last Rotated | Policy (days) | Days Until Expiry | Required By |"
    echo "|--------|--------------|---------------|-------------------|-------------|"
    rows_for warning | while IFS=$'\t' read -r name last policy req _ overdue _; do
      until_expiry=$(( -overdue ))
      req_human=${req//,/, }
      printf '| %s | %s | %s | %s | %s |\n' \
        "$name" "$last" "$policy" "$until_expiry" "$req_human"
    done
  else
    echo "_None_"
  fi
  echo

  echo "## OK"
  echo
  if [[ "$ok" -gt 0 ]]; then
    echo "| Secret | Last Rotated | Policy (days) | Days Until Expiry | Required By |"
    echo "|--------|--------------|---------------|-------------------|-------------|"
    rows_for ok | while IFS=$'\t' read -r name last policy req _ overdue _; do
      until_expiry=$(( -overdue ))
      req_human=${req//,/, }
      printf '| %s | %s | %s | %s | %s |\n' \
        "$name" "$last" "$policy" "$until_expiry" "$req_human"
    done
  else
    echo "_None_"
  fi
}

# -- rendering: JSON --------------------------------------------------------
render_json() {
  # Build the JSON by streaming the normalised rows back into jq. Using
  # --slurp with a simple schema keeps the output stable and easy to assert.
  local exp warn ok
  exp=$(count_for expired)
  warn=$(count_for warning)
  ok=$(count_for ok)

  # Emit each row as a JSON object on its own line, then re-aggregate.
  awk -F '\t' '
    {
      name=$1; last=$2; policy=$3; req=$4; since=$5; overdue=$6; urg=$7;
      # Split required_by CSV into JSON array.
      n = split(req, parts, ",");
      arr = "[";
      for (i=1; i<=n; i++) {
        if (parts[i] == "") continue;
        gsub(/"/, "\\\"", parts[i]);
        arr = arr (arr=="[" ? "" : ",") "\"" parts[i] "\"";
      }
      arr = arr "]";
      # until_expiry = -overdue; days_overdue is +overdue (only for expired).
      printf "{\"name\":\"%s\",\"last_rotated\":\"%s\",\"policy_days\":%s,\"required_by\":%s,\"days_since\":%s,\"days_until_expiry\":%s,\"days_overdue\":%s,\"urgency\":\"%s\"}\n",
        name, last, policy, arr, since, -overdue, overdue, urg;
    }
  ' "$normalised" | jq -s \
    --arg today "$today" \
    --argjson warning "$warning_days" \
    --argjson exp "$exp" \
    --argjson warn "$warn" \
    --argjson ok "$ok" '
    {
      generated: $today,
      warning_window_days: $warning,
      summary: { expired: $exp, warning: $warn, ok: $ok },
      expired: [ .[] | select(.urgency=="expired")
                 | {name, last_rotated, policy_days, days_overdue, required_by} ],
      warning: [ .[] | select(.urgency=="warning")
                 | {name, last_rotated, policy_days, days_until_expiry, required_by} ],
      ok:      [ .[] | select(.urgency=="ok")
                 | {name, last_rotated, policy_days, days_until_expiry, required_by} ]
    }'
}

# -- dispatch ---------------------------------------------------------------
case "$format" in
  markdown) render_markdown ;;
  json)     render_json ;;
  *)        die "internal: unexpected format $format" ;;  # defensive
esac
