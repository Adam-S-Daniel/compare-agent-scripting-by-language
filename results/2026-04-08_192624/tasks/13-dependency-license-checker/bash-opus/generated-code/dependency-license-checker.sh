#!/usr/bin/env bash
# dependency-license-checker.sh
#
# Parses a dependency manifest (package.json or requirements.txt),
# looks up each dependency's license via a mock license database,
# checks it against an allow-list / deny-list from a config file,
# and produces a compliance report.
#
# Usage:
#   ./dependency-license-checker.sh \
#       --manifest <path>          \
#       --config   <path>          \
#       --license-db <path>        \
#       [--format text|json]
#
# Exit codes:
#   0  - all dependencies approved or unknown (no denied)
#   1  - one or more dependencies denied
#   2  - usage / input error

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

die() {
  echo "ERROR: $*" >&2
  exit 2
}

usage() {
  echo "Usage: $0 --manifest <file> --config <file> --license-db <file> [--format text|json]" >&2
  exit 2
}

# ── Argument parsing ─────────────────────────────────────────────────────────

MANIFEST=""
CONFIG=""
LICENSE_DB=""
FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)   MANIFEST="$2";    shift 2 ;;
    --config)     CONFIG="$2";      shift 2 ;;
    --license-db) LICENSE_DB="$2";  shift 2 ;;
    --format)     FORMAT="$2";      shift 2 ;;
    -h|--help)    usage ;;
    *)            die "Unknown option: $1" ;;
  esac
done

[[ -n "$MANIFEST" ]]   || die "Missing --manifest"
[[ -n "$CONFIG" ]]     || die "Missing --config"
[[ -n "$LICENSE_DB" ]] || die "Missing --license-db"
[[ -f "$MANIFEST" ]]   || die "Manifest not found: $MANIFEST"
[[ -f "$CONFIG" ]]     || die "Config not found: $CONFIG"
[[ -f "$LICENSE_DB" ]] || die "License DB not found: $LICENSE_DB"

# ── Parse config (allowed / denied license lists) ───────────────────────────
# Uses a minimal jq-free JSON array parser for simple flat arrays.

# parse_json_array extracts values from a simple JSON array field.
# $1 = file, $2 = field name
parse_json_array() {
  local file="$1" field="$2"
  # Extract the array contents, then strip quotes / whitespace
  sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\[//p" "$file" \
    | sed 's/\].*//' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//' \
    | grep -v '^$'
}

mapfile -t ALLOWED < <(parse_json_array "$CONFIG" "allowed_licenses")
mapfile -t DENIED  < <(parse_json_array "$CONFIG" "denied_licenses")

# ── Detect manifest type and extract dependencies ────────────────────────────
# Each dependency is output as "name version" on its own line.

parse_package_json() {
  local file="$1"
  # Extract keys from "dependencies" and "devDependencies" blocks.
  # Handles the simple format:  "name": "version"
  local in_deps=0
  local brace_depth=0
  while IFS= read -r line; do
    # Detect section start
    if [[ "$line" =~ \"(dependencies|devDependencies)\" ]]; then
      in_deps=1
      brace_depth=0
      continue
    fi
    if [[ $in_deps -eq 1 ]]; then
      # Track braces
      if [[ "$line" =~ \{ ]]; then
        (( brace_depth++ ))
      fi
      if [[ "$line" =~ \} ]]; then
        (( brace_depth-- ))
        if [[ $brace_depth -le 0 ]]; then
          in_deps=0
          continue
        fi
      fi
      # Extract "name": "version"
      if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
      fi
    fi
  done < "$file"
}

parse_requirements_txt() {
  local file="$1"
  while IFS= read -r line; do
    # Skip blank lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Handle ==, >=, ~= etc.
    if [[ "$line" =~ ^([a-zA-Z0-9_-]+)[=\>\<\~!]+(.+)$ ]]; then
      echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^([a-zA-Z0-9_-]+)$ ]]; then
      echo "${BASH_REMATCH[1]} *"
    fi
  done < "$file"
}

BASENAME="$(basename "$MANIFEST")"
case "$BASENAME" in
  package.json)      DEPS="$(parse_package_json "$MANIFEST")" ;;
  requirements.txt)  DEPS="$(parse_requirements_txt "$MANIFEST")" ;;
  *)                 die "Unsupported manifest type: $BASENAME" ;;
esac

if [[ -z "$DEPS" ]]; then
  die "No dependencies found in $MANIFEST"
fi

# ── License lookup (mock) ────────────────────────────────────────────────────
# Reads from the mock JSON license database.

lookup_license() {
  local name="$1"
  # Simple extraction: find "name": "license" in the JSON
  local license
  license="$(sed -n "s/.*\"${name}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$LICENSE_DB" | head -1)"
  echo "${license:-UNKNOWN}"
}

# ── Classify each dependency ─────────────────────────────────────────────────

classify_license() {
  local license="$1"
  if [[ "$license" == "UNKNOWN" ]]; then
    echo "unknown"
    return
  fi
  local l
  for l in "${DENIED[@]}"; do
    if [[ "$l" == "$license" ]]; then
      echo "denied"
      return
    fi
  done
  for l in "${ALLOWED[@]}"; do
    if [[ "$l" == "$license" ]]; then
      echo "approved"
      return
    fi
  done
  echo "unknown"
}

# ── Build report ─────────────────────────────────────────────────────────────

APPROVED_COUNT=0
DENIED_COUNT=0
UNKNOWN_COUNT=0
REPORT_LINES=()

while IFS=' ' read -r dep_name dep_version; do
  license="$(lookup_license "$dep_name")"
  status="$(classify_license "$license")"
  case "$status" in
    approved) APPROVED_COUNT=$(( APPROVED_COUNT + 1 )) ;;
    denied)   DENIED_COUNT=$(( DENIED_COUNT + 1 )) ;;
    unknown)  UNKNOWN_COUNT=$(( UNKNOWN_COUNT + 1 )) ;;
  esac
  REPORT_LINES+=("${dep_name}|${dep_version}|${license}|${status}")
done <<< "$DEPS"

TOTAL=$(( APPROVED_COUNT + DENIED_COUNT + UNKNOWN_COUNT ))

# ── Output ───────────────────────────────────────────────────────────────────

if [[ "$FORMAT" == "json" ]]; then
  echo "{"
  echo "  \"summary\": {"
  echo "    \"total\": ${TOTAL},"
  echo "    \"approved\": ${APPROVED_COUNT},"
  echo "    \"denied\": ${DENIED_COUNT},"
  echo "    \"unknown\": ${UNKNOWN_COUNT}"
  echo "  },"
  echo "  \"dependencies\": ["
  for i in "${!REPORT_LINES[@]}"; do
    IFS='|' read -r name ver lic stat <<< "${REPORT_LINES[$i]}"
    comma=","
    if [[ $i -eq $(( ${#REPORT_LINES[@]} - 1 )) ]]; then
      comma=""
    fi
    echo "    {\"name\": \"${name}\", \"version\": \"${ver}\", \"license\": \"${lic}\", \"status\": \"${stat}\"}${comma}"
  done
  echo "  ]"
  echo "}"
else
  echo "=== Dependency License Compliance Report ==="
  echo ""
  printf "%-20s %-12s %-15s %s\n" "DEPENDENCY" "VERSION" "LICENSE" "STATUS"
  printf "%-20s %-12s %-15s %s\n" "----------" "-------" "-------" "------"
  for entry in "${REPORT_LINES[@]}"; do
    IFS='|' read -r name ver lic stat <<< "$entry"
    printf "%-20s %-12s %-15s %s\n" "$name" "$ver" "$lic" "$stat"
  done
  echo ""
  echo "--- Summary ---"
  echo "Total: ${TOTAL} | Approved: ${APPROVED_COUNT} | Denied: ${DENIED_COUNT} | Unknown: ${UNKNOWN_COUNT}"
fi

# Exit 1 if any dependency is denied
if [[ $DENIED_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
