#!/usr/bin/env bash

# Environment Matrix Generator for GitHub Actions
# Generates a build matrix suitable for GitHub Actions strategy.matrix
# from a configuration with OS options, language versions, and feature flags

set -o pipefail

# Default maximum matrix size (256 combinations)
MAX_MATRIX_SIZE=${MAX_MATRIX_SIZE:-256}

# Usage message
usage() {
  cat >&2 <<'EOF'
Usage: generate-matrix.sh <config-json>

Generates a GitHub Actions build matrix from a JSON configuration.

Config format:
{
  "os": ["ubuntu-latest", "macos-latest"],
  "node-version": ["18", "20"],
  "max-parallel": 5,
  "fail-fast": true,
  "include": [...],
  "exclude": [...]
}

Environment variables:
  MAX_MATRIX_SIZE  Maximum number of matrix combinations (default: 256)
EOF
  exit 1
}

# Error handler
error() {
  echo "ERROR: $1" >&2
  exit 1
}

# Main function to generate matrix
generate_matrix() {
  local config="$1"

  # Validate JSON input
  if ! jq empty <<<"$config" 2>/dev/null; then
    error "Invalid JSON input"
  fi

  # Extract all custom matrix dimensions (exclude special keys)
  local matrix_dimensions
  matrix_dimensions=$(jq 'del(.["max-parallel"], .["fail-fast"], .include, .exclude)' <<<"$config")

  # Calculate total combinations from base dimensions
  local total_combos=1
  while IFS= read -r count; do
    [ "$count" -gt 0 ] && total_combos=$((total_combos * count))
  done < <(jq -r '.[] | arrays | length' <<<"$matrix_dimensions")

  # Apply exclude rules to reduce count
  local exclude_count
  exclude_count=$(jq '.exclude // [] | length' <<<"$config")
  total_combos=$((total_combos - exclude_count))

  # Validate matrix size (only if we have dimensions)
  if [ "$total_combos" -gt 0 ] && [ "$total_combos" -gt "$MAX_MATRIX_SIZE" ]; then
    error "Matrix size ($total_combos combinations) exceeds maximum ($MAX_MATRIX_SIZE)"
  fi

  # Build the base matrix object from dimensions (only include non-empty arrays)
  local base_matrix
  base_matrix=$(jq 'with_entries(select(.value | type == "array" and length > 0))' <<<"$matrix_dimensions")

  # Extract optional fields if present (use null as default)
  local include_rules
  local exclude_rules
  local max_parallel
  local fail_fast

  include_rules=$(jq 'if has("include") then .include else null end' <<<"$config")
  exclude_rules=$(jq 'if has("exclude") then .exclude else null end' <<<"$config")
  max_parallel=$(jq 'if has("max-parallel") then .["max-parallel"] else null end' <<<"$config")
  fail_fast=$(jq 'if has("fail-fast") then .["fail-fast"] else null end' <<<"$config")

  # Build the complete output object
  # Use a single jq invocation to construct everything atomically
  local output
  output=$(jq -n \
    --argjson matrix "$base_matrix" \
    --argjson include_rules "$include_rules" \
    --argjson exclude_rules "$exclude_rules" \
    --argjson max_parallel "$max_parallel" \
    --argjson fail_fast "$fail_fast" \
    '
    {
      matrix: (
        $matrix |
        if ($include_rules | type) == "array" and ($include_rules | length) > 0 then
          . + {include: $include_rules}
        else
          .
        end |
        if ($exclude_rules | type) == "array" and ($exclude_rules | length) > 0 then
          . + {exclude: $exclude_rules}
        else
          .
        end
      )
    } |
    if ($max_parallel | type) == "number" then
      . + {"max-parallel": $max_parallel}
    else
      .
    end |
    if ($fail_fast | type) == "boolean" then
      . + {"fail-fast": $fail_fast}
    else
      .
    end
    ')

  echo "$output"
}

# Entry point
if [ $# -lt 1 ]; then
  usage
fi

generate_matrix "$1"
