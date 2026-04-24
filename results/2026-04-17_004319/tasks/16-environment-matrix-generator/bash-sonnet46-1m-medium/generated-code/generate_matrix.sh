#!/usr/bin/env bash
# generate_matrix.sh - Generate GitHub Actions strategy.matrix JSON from config
#
# Usage: ./generate_matrix.sh <config-file>
#
# Config JSON format:
#   {
#     "matrix": { "os": [...], "node-version": [...], ... },
#     "include": [ {...}, ... ],      # optional - extra matrix entries
#     "exclude": [ {...}, ... ],      # optional - remove matrix entries
#     "max-parallel": 4,              # optional - limit concurrent jobs
#     "fail-fast": false,             # optional, default true
#     "max-size": 256                 # optional, default 256 (GHA limit)
#   }
#
# Output: GitHub Actions strategy object (matrix + fail-fast + max-parallel)
#
# NOTE: Variables passed to jq via --argjson avoid jq 1.6 reserved keywords.
# 'include' and 'import' are module-system keywords in jq 1.6; use 'inc'/'exc'.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <config-file>" >&2
    exit 1
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Validate JSON before processing
if ! jq '.' "$CONFIG_FILE" > /dev/null 2>&1; then
    echo "Error: invalid JSON in config file: $CONFIG_FILE" >&2
    exit 1
fi

# Use -c (compact output) to keep bash variables single-line — avoids
# potential heredoc issues with multiline JSON in some environments.
MATRIX=$(jq -c '.matrix // {}' "$CONFIG_FILE")
# Avoid jq 1.6 reserved keywords 'include'/'import' — rename to inc/exc
INC=$(jq -c '.include // []' "$CONFIG_FILE")
EXC=$(jq -c '.exclude // []' "$CONFIG_FILE")
MAX_PAR=$(jq -c '.["max-parallel"] // null' "$CONFIG_FILE")
# Use has() instead of // to correctly detect false fail-fast values
FAIL_FAST=$(jq -c 'if has("fail-fast") then .["fail-fast"] else true end' "$CONFIG_FILE")
MAX_SIZE=$(jq -r '.["max-size"] // 256' "$CONFIG_FILE")

# Compute cartesian product size: multiply lengths of all dimension arrays.
# Use printf to pipe MATRIX — more portable than <<< heredoc.
MATRIX_SIZE=$(printf '%s\n' "$MATRIX" | jq \
    '[to_entries[] | .value | if type == "array" then length else 1 end] |
     if length == 0 then 0
     else reduce .[] as $x (1; . * $x)
     end')

# Each include entry adds one row to the final matrix
INC_COUNT=$(printf '%s\n' "$INC" | jq 'length')
TOTAL_SIZE=$((MATRIX_SIZE + INC_COUNT))

if [[ "$TOTAL_SIZE" -gt "$MAX_SIZE" ]]; then
    echo "Error: matrix size ($TOTAL_SIZE) exceeds maximum ($MAX_SIZE)" >&2
    exit 1
fi

# Build the strategy output — jq variable names avoid reserved keywords
jq -n \
    --argjson matrix   "$MATRIX" \
    --argjson inc      "$INC" \
    --argjson exc      "$EXC" \
    --argjson max_par  "$MAX_PAR" \
    --argjson fail_fast "$FAIL_FAST" \
    '{
      matrix: (
        $matrix
        + (if ($inc | length) > 0 then {"include": $inc} else {} end)
        + (if ($exc | length) > 0 then {"exclude": $exc} else {} end)
      ),
      "fail-fast": $fail_fast
    }
    + (if $max_par != null then {"max-parallel": $max_par} else {} end)'
