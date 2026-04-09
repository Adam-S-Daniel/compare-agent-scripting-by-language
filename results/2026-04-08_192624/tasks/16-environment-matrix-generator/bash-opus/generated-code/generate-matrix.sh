#!/usr/bin/env bash
# generate-matrix.sh — Generate a GitHub Actions strategy.matrix JSON from a config file.
#
# Usage: ./generate-matrix.sh <config.json>
#
# Config format (JSON):
#   {
#     "os": ["ubuntu-latest", "macos-latest"],
#     "language_version": ["3.9", "3.10"],
#     "feature_flags": ["flag-a", "flag-b"],
#     "include": [ {"os": "windows-latest", "language_version": "3.11"} ],
#     "exclude": [ {"os": "macos-latest", "language_version": "3.9"} ],
#     "max-parallel": 4,
#     "fail-fast": true,
#     "max-combinations": 256
#   }
#
# Outputs complete strategy.matrix JSON to stdout.
# Exit codes:
#   0 — success
#   1 — invalid input / config error
#   2 — matrix exceeds max-combinations limit

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Check that jq is available
command -v jq >/dev/null 2>&1 || die "jq is required but not installed"

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  die "Usage: generate-matrix.sh <config.json>"
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
  die "Config file not found: $CONFIG_FILE"
fi

# Validate JSON syntax
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  die "Invalid JSON in config file: $CONFIG_FILE"
fi

CONFIG=$(cat "$CONFIG_FILE")

# ---------------------------------------------------------------------------
# Extract configuration values
# ---------------------------------------------------------------------------

# Read the dimension arrays (os, language_version, feature_flags, or any
# top-level array that isn't a reserved key).
RESERVED_KEYS='["include","exclude","max-parallel","fail-fast","max-combinations"]'

# Get dimension keys — every top-level key whose value is an array and is not reserved.
DIMENSION_KEYS=$(echo "$CONFIG" | jq -r --argjson reserved "$RESERVED_KEYS" '
  [to_entries[]
   | select(.value | type == "array")
   | select(.key as $k | $reserved | index($k) | not)
   | .key
  ] | .[]
')

# Read reserved settings with defaults
MAX_PARALLEL=$(echo "$CONFIG" | jq -r '.["max-parallel"] // empty')
FAIL_FAST=$(echo "$CONFIG" | jq -r '.["fail-fast"] // empty')
MAX_COMBINATIONS=$(echo "$CONFIG" | jq -r '.["max-combinations"] // 256')

# ---------------------------------------------------------------------------
# Build the Cartesian product of all dimensions
# ---------------------------------------------------------------------------

# Start with a single empty object, then fold in each dimension.
MATRIX_ENTRIES='[{}]'

for key in $DIMENSION_KEYS; do
  VALUES=$(echo "$CONFIG" | jq -c --arg k "$key" '.[$k]')
  # For each existing entry, pair it with every value of this dimension.
  MATRIX_ENTRIES=$(echo "$MATRIX_ENTRIES" | jq -c --arg k "$key" --argjson vals "$VALUES" '
    [.[] as $entry | $vals[] as $v | $entry + {($k): $v}]
  ')
done

# ---------------------------------------------------------------------------
# Apply exclude rules — remove matching entries
# ---------------------------------------------------------------------------

EXCLUDES=$(echo "$CONFIG" | jq -c '.exclude // []')

if [[ "$EXCLUDES" != "[]" ]]; then
  MATRIX_ENTRIES=$(echo "$MATRIX_ENTRIES" | jq -c --argjson excludes "$EXCLUDES" '
    [.[] as $entry |
     select(
       [$excludes[] as $ex |
        ([$ex | to_entries[] | select($entry[.key] == .value)] | length) == ($ex | length)
       ] | any | not
     )
    ]
  ')
fi

# ---------------------------------------------------------------------------
# Apply include rules — add extra entries
# ---------------------------------------------------------------------------

INCLUDES=$(echo "$CONFIG" | jq -c '.include // []')

if [[ "$INCLUDES" != "[]" ]]; then
  MATRIX_ENTRIES=$(echo "$MATRIX_ENTRIES" | jq -c --argjson includes "$INCLUDES" '. + $includes')
fi

# ---------------------------------------------------------------------------
# Validate matrix size
# ---------------------------------------------------------------------------

ENTRY_COUNT=$(echo "$MATRIX_ENTRIES" | jq 'length')

if [[ "$ENTRY_COUNT" -eq 0 ]]; then
  die "Matrix is empty after applying include/exclude rules"
fi

if [[ "$ENTRY_COUNT" -gt "$MAX_COMBINATIONS" ]]; then
  die "Matrix has $ENTRY_COUNT combinations, exceeding max-combinations limit of $MAX_COMBINATIONS"
fi

# ---------------------------------------------------------------------------
# Build the final output JSON
# ---------------------------------------------------------------------------

# The output mirrors GitHub Actions strategy format:
# {
#   "matrix": { ... dimensions ..., "include": [...entries...] },
#   "max-parallel": N,
#   "fail-fast": bool
# }

# We express the matrix using the "include" form — a flat list of explicit
# combinations. This is the most portable representation.
OUTPUT=$(jq -n --argjson entries "$MATRIX_ENTRIES" '{ "matrix": { "include": $entries } }')

# Add max-parallel if specified
if [[ -n "$MAX_PARALLEL" ]]; then
  OUTPUT=$(echo "$OUTPUT" | jq --argjson mp "$MAX_PARALLEL" '. + {"max-parallel": $mp}')
fi

# Add fail-fast if specified
if [[ -n "$FAIL_FAST" ]]; then
  OUTPUT=$(echo "$OUTPUT" | jq --argjson ff "$FAIL_FAST" '. + {"fail-fast": $ff}')
fi

# Print the final JSON
echo "$OUTPUT" | jq .

echo "Matrix generated successfully with $ENTRY_COUNT combination(s)" >&2
