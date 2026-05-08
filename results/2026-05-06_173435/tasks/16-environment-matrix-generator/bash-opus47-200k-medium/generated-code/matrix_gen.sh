#!/usr/bin/env bash
# matrix_gen.sh - generate a GitHub Actions strategy.matrix from a JSON config.
#
# Approach:
#   1. Read a JSON config file (path arg or - for stdin).
#   2. Identify dimension keys (every top-level key except the reserved
#      keys: include, exclude, max-parallel, fail-fast, max-size).
#   3. Compute the cartesian product of those dimensions with jq.
#   4. Drop combinations that match any exclude rule (all rule keys equal).
#   5. Append include entries verbatim.
#   6. Validate total size against max-size (default 256, GH's hard cap).
#   7. Emit a JSON object suitable to feed straight into a workflow:
#        { "matrix": { "include": [...] },
#          "max-parallel": <n>,
#          "fail-fast": <bool> }
#
# Errors are written to stderr with non-zero exit codes.

set -euo pipefail

err() { echo "matrix_gen: error: $*" >&2; }

usage() {
  cat >&2 <<'EOF'
Usage: matrix_gen.sh <config.json>
       matrix_gen.sh -          # read JSON from stdin
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

input="$1"
if [[ "$input" == "-" ]]; then
  config=$(cat)
else
  if [[ ! -f "$input" ]]; then
    err "config file not found: $input"
    exit 1
  fi
  config=$(cat "$input")
fi

# Validate JSON.
if ! echo "$config" | jq -e . >/dev/null 2>&1; then
  err "invalid JSON in config"
  exit 1
fi

# Identify dimension keys.
dim_keys=$(echo "$config" | jq -r '
  keys[]
  | select(. as $k | ["include","exclude","max-parallel","fail-fast","max-size"] | index($k) | not)
')

if [[ -z "$dim_keys" ]]; then
  err "no matrix dimensions found (need at least one non-reserved key)"
  exit 1
fi

# Compute cartesian product. Build a jq program that reduces the dimensions.
# Result: array of objects, one per combination.
combos=$(echo "$config" | jq --argjson keys "$(printf '%s\n' "$dim_keys" | jq -R . | jq -s .)" '
  . as $cfg
  | reduce $keys[] as $k ([{}];
      [ .[] as $base
        | $cfg[$k][] as $v
        | $base + {($k): $v}
      ])
')

# Apply exclude rules: drop combos for which some rule matches all its keys.
combos=$(echo "$config" | jq --argjson combos "$combos" '
  ($combos) as $list
  | (.exclude // []) as $excludes
  | $list
  | map(. as $c
        | select(
            ($excludes | map(
              . as $e
              | ($e | to_entries | all(.value == $c[.key]))
            ) | any | not)
          ))
')

# Append includes (verbatim).
combos=$(echo "$config" | jq --argjson combos "$combos" '
  $combos + (.include // [])
')

total=$(echo "$combos" | jq 'length')

# Validate size. Default cap mirrors GitHub Actions (256).
max_size=$(echo "$config" | jq -r '."max-size" // 256')
if (( total > max_size )); then
  err "matrix size $total exceeds max-size $max_size"
  exit 1
fi
if (( total == 0 )); then
  err "matrix is empty after applying excludes"
  exit 1
fi

# Pull through optional knobs.
fail_fast=$(echo "$config" | jq 'if has("fail-fast") then ."fail-fast" else true end')
max_parallel=$(echo "$config" | jq '."max-parallel" // null')

jq -n \
  --argjson inc "$combos" \
  --argjson failfast "$fail_fast" \
  --argjson maxpar "$max_parallel" \
  '{
     "matrix": { "include": $inc },
     "fail-fast": $failfast,
     "max-parallel": $maxpar
   }'
