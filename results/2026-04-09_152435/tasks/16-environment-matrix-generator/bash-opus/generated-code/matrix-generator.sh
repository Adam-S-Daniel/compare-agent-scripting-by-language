#!/usr/bin/env bash
# matrix-generator.sh — Generate a GitHub Actions strategy.matrix from a JSON config.
#
# Usage: matrix-generator.sh <config.json>
#
# The config JSON has this shape:
# {
#   "os": ["ubuntu-latest", "macos-latest"],
#   "language_version": ["3.9", "3.10"],
#   "feature_flags": ["flag-a"],        // optional axis
#   "include": [ { "os": "windows-latest", "language_version": "3.11" } ],
#   "exclude": [ { "os": "macos-latest", "language_version": "3.9" } ],
#   "max_parallel": 4,                  // optional
#   "fail_fast": true,                  // optional (default true)
#   "max_combinations": 256             // optional cap (default 256)
# }
#
# Output (stdout): complete JSON with "matrix", "fail-fast", and "max-parallel" keys.

set -euo pipefail

# ---------- helpers ----------------------------------------------------------

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# ---------- argument validation ----------------------------------------------

if [[ $# -lt 1 ]]; then
  die "Usage: matrix-generator.sh <config.json>"
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
  die "Config file not found: $CONFIG_FILE"
fi

# Validate JSON syntax
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  die "Invalid JSON in config file: $CONFIG_FILE"
fi

# ---------- read config fields -----------------------------------------------

# Extract the matrix axes — any top-level arrays that are NOT include/exclude
# These become the cartesian-product dimensions.
AXES_JSON=$(jq -c '
  to_entries
  | map(select(.value | type == "array" and (. | all(type != "object"))))
  | map(select(.key != "include" and .key != "exclude"))
  | from_entries
' "$CONFIG_FILE")

INCLUDE_JSON=$(jq -c '.include // []' "$CONFIG_FILE")
EXCLUDE_JSON=$(jq -c '.exclude // []' "$CONFIG_FILE")
MAX_PARALLEL=$(jq -r '.max_parallel // empty' "$CONFIG_FILE")
FAIL_FAST=$(jq -r 'if has("fail_fast") then .fail_fast else true end' "$CONFIG_FILE")
MAX_COMBINATIONS=$(jq -r '.max_combinations // 256' "$CONFIG_FILE")

# ---------- generate cartesian product ---------------------------------------

# Build the cartesian product of all axes using jq.
# Strategy: reduce over each axis, expanding the accumulator.
MATRIX_ENTRIES=$(jq -c '
  # Start with a single empty object, then for each axis expand.
  to_entries | reduce .[] as $axis (
    [{}];
    . as $acc |
    [ $acc[] as $row |
      $axis.value[] as $val |
      ($row + {($axis.key): $val})
    ]
  )
' <<< "$AXES_JSON")

# ---------- apply exclude rules ----------------------------------------------

# An entry matches an exclude rule if every key in the rule matches the entry.
MATRIX_ENTRIES=$(jq -c --argjson excludes "$EXCLUDE_JSON" '
  [ .[] | . as $entry |
    if ($excludes | length) == 0 then $entry
    else
      # Keep the entry only if it does NOT match any exclude rule
      if [ $excludes[] | . as $rule |
           [ to_entries[] | select($entry[.key] == .value) ] | length == ($rule | length)
         ] | any
      then empty
      else $entry
      end
    end
  ]
' <<< "$MATRIX_ENTRIES")

# ---------- apply include rules ----------------------------------------------

# Includes add extra entries to the matrix unconditionally.
MATRIX_ENTRIES=$(jq -c --argjson includes "$INCLUDE_JSON" '
  . + $includes
' <<< "$MATRIX_ENTRIES")

# ---------- validate matrix size ---------------------------------------------

ENTRY_COUNT=$(jq 'length' <<< "$MATRIX_ENTRIES")

if [[ "$ENTRY_COUNT" -eq 0 ]]; then
  die "Matrix is empty after applying include/exclude rules"
fi

if [[ "$ENTRY_COUNT" -gt "$MAX_COMBINATIONS" ]]; then
  die "Matrix has $ENTRY_COUNT combinations, exceeding max of $MAX_COMBINATIONS"
fi

# ---------- build final output -----------------------------------------------

# Construct the strategy object exactly as GitHub Actions expects.
OUTPUT=$(jq -n \
  --argjson matrix "$MATRIX_ENTRIES" \
  --argjson fail_fast "$FAIL_FAST" \
  '{
    "fail-fast": $fail_fast,
    "matrix": {
      "include": $matrix
    }
  }')

# Add max-parallel only if specified
if [[ -n "$MAX_PARALLEL" ]]; then
  OUTPUT=$(jq --argjson mp "$MAX_PARALLEL" '. + {"max-parallel": $mp}' <<< "$OUTPUT")
fi

echo "$OUTPUT"
