#!/usr/bin/env bash
# generate-matrix.sh — Generate a GitHub Actions strategy.matrix JSON blob
#
# Usage: generate-matrix.sh <config.json>
#
# Config fields:
#   os               (required) array of OS strings
#   language_versions (optional) object: key → array of version strings
#   feature_flags    (optional) object: key → array of values (bool/string/number)
#   excludes         (optional) array of partial-match objects to remove
#   includes         (optional) array of extra combination objects to add
#   max_parallel     (optional, default 10) integer
#   fail_fast        (optional, default false) boolean
#   max_size         (optional, default 256) max number of combinations allowed
#
# Output: JSON to stdout with shape:
#   {
#     "strategy": {
#       "fail-fast": <bool>,
#       "max-parallel": <int>,
#       "matrix": { "include": [ {os, ...versions, ...flags}, ... ] }
#     }
#   }
#
# Errors go to stderr; script exits non-zero on any error.

set -euo pipefail

# ---------------------------------------------------------------------------
# Usage / argument validation
# ---------------------------------------------------------------------------

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <config.json>" >&2
  exit 1
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Validate JSON syntax before doing anything else.
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  echo "Error: Invalid JSON in config file: $CONFIG_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read config values with safe defaults
# ---------------------------------------------------------------------------

OS_LIST=$(jq -c '.os // []' "$CONFIG_FILE")
LANG_VERSIONS=$(jq -c '.language_versions // {}' "$CONFIG_FILE")
FEATURE_FLAGS=$(jq -c '.feature_flags // {}' "$CONFIG_FILE")
EXCLUDES=$(jq -c '.excludes // []' "$CONFIG_FILE")
INCLUDES=$(jq -c '.includes // []' "$CONFIG_FILE")
MAX_PARALLEL=$(jq '.max_parallel // 10' "$CONFIG_FILE")
FAIL_FAST=$(jq '.fail_fast // false' "$CONFIG_FILE")
MAX_SIZE=$(jq '.max_size // 256' "$CONFIG_FILE")

# Require at least one OS entry.
OS_COUNT=$(jq 'length' <<< "$OS_LIST")
if [[ "$OS_COUNT" -eq 0 ]]; then
  echo "Error: At least one OS must be specified in config" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Build cartesian product
#
# Strategy: start with one empty combination {}, then for each dimension
# (OS, then each language version key, then each feature flag key) expand
# every existing combination with each possible value in that dimension.
# ---------------------------------------------------------------------------

# Seed: one empty object
COMBOS='[{}]'

# Dimension 1 — OS
COMBOS=$(jq -n \
  --argjson combos "$COMBOS" \
  --argjson vals "$OS_LIST" \
  '[$combos[] | . as $c | $vals[] | $c + {"os": .}]')

# Dimension 2 — language versions (iterate keys in sorted order for determinism)
while IFS= read -r lang; do
  [[ -z "$lang" ]] && continue
  values=$(jq -c --arg lang "$lang" '.[$lang]' <<< "$LANG_VERSIONS")
  COMBOS=$(jq -n \
    --argjson combos "$COMBOS" \
    --argjson vals "$values" \
    --arg key "$lang" \
    '[$combos[] | . as $c | $vals[] | $c + {($key): .}]')
done < <(jq -r 'keys[]' <<< "$LANG_VERSIONS")

# Dimension 3 — feature flags (same iteration strategy)
while IFS= read -r flag; do
  [[ -z "$flag" ]] && continue
  values=$(jq -c --arg flag "$flag" '.[$flag]' <<< "$FEATURE_FLAGS")
  COMBOS=$(jq -n \
    --argjson combos "$COMBOS" \
    --argjson vals "$values" \
    --arg key "$flag" \
    '[$combos[] | . as $c | $vals[] | $c + {($key): .}]')
done < <(jq -r 'keys[]' <<< "$FEATURE_FLAGS")

# ---------------------------------------------------------------------------
# Apply exclude rules
#
# A combination is excluded when ALL key/value pairs in an exclude rule match
# the corresponding fields in the combination.  If ANY exclude rule fully
# matches, the combination is dropped.
# ---------------------------------------------------------------------------

EXCLUDE_COUNT=$(jq 'length' <<< "$EXCLUDES")
if [[ "$EXCLUDE_COUNT" -gt 0 ]]; then
  COMBOS=$(jq -n \
    --argjson combos "$COMBOS" \
    --argjson excludes "$EXCLUDES" \
    '$combos | map(
      . as $combo |
      select(
        ($excludes | map(
          . as $excl |
          $excl | to_entries | all(.value == $combo[.key])
        ) | any) | not
      )
    )')
fi

# ---------------------------------------------------------------------------
# Apply include rules — append additional combinations verbatim
# ---------------------------------------------------------------------------

INCLUDE_COUNT=$(jq 'length' <<< "$INCLUDES")
if [[ "$INCLUDE_COUNT" -gt 0 ]]; then
  COMBOS=$(jq -n \
    --argjson combos "$COMBOS" \
    --argjson includes "$INCLUDES" \
    '$combos + $includes')
fi

# ---------------------------------------------------------------------------
# Validate matrix size
# ---------------------------------------------------------------------------

COMBO_COUNT=$(jq 'length' <<< "$COMBOS")
if [[ "$COMBO_COUNT" -gt "$MAX_SIZE" ]]; then
  echo "Error: Matrix size ${COMBO_COUNT} exceeds maximum size ${MAX_SIZE}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Output complete strategy JSON
# ---------------------------------------------------------------------------

jq -n \
  --argjson combos      "$COMBOS" \
  --argjson maxParallel "$MAX_PARALLEL" \
  --argjson failFast    "$FAIL_FAST" \
  '{
    "strategy": {
      "fail-fast":    $failFast,
      "max-parallel": $maxParallel,
      "matrix": {
        "include": $combos
      }
    }
  }'
