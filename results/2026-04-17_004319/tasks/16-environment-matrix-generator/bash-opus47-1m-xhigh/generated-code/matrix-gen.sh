#!/usr/bin/env bash
# matrix-gen.sh - Generate a GitHub Actions strategy.matrix from a JSON config.
#
# Input JSON schema:
#   {
#     "dimensions":      { "<key>": [values, ...], ... },   # required, >=1 non-empty
#     "include":         [ {<key>: <value>, ...}, ... ],    # optional
#     "exclude":         [ {<key>: <value>, ...}, ... ],    # optional
#     "max-parallel":    <int>,                             # optional
#     "fail-fast":       <bool>,                            # optional, default true
#     "max-matrix-size": <int>                              # optional, enforced if set
#   }
#
# Output: a JSON object shaped like a GitHub Actions `strategy` block:
#   {
#     "strategy": {
#       "matrix":       { <dim>: [values], ..., "include": [...], "exclude": [...] },
#       "max-parallel": <int>,
#       "fail-fast":    <bool>
#     }
#   }
#
# Size validation: counts product(dimensions) + len(include) - len(exclude)
# and errors if that exceeds max-matrix-size.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: matrix-gen.sh <config.json>
       matrix-gen.sh --help

Generate a GitHub Actions strategy.matrix JSON block from a config file.

Config fields:
  dimensions       Map of dimension name -> list of values (required).
  include          List of extra matrix entries.
  exclude          List of matrix entries to remove.
  max-parallel     Integer limit on concurrent jobs.
  fail-fast        Boolean, default true.
  max-matrix-size  Integer. If the computed matrix count exceeds this,
                   the script exits with a non-zero status.

Output goes to stdout as a single JSON object: {"strategy": {...}}.
EOF
}

# err prints an error to stderr and exits with code 1.
err() {
  echo "matrix-gen: error: $*" >&2
  exit 1
}

# Ensure jq is available; we rely on it for all JSON work.
command -v jq >/dev/null 2>&1 || err "jq is required but not installed"

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

config_path="$1"

[[ -f "$config_path" ]] || err "config file not found: $config_path"

# Validate JSON parses cleanly; report parse errors from jq.
if ! jq -e . "$config_path" >/dev/null 2>&1; then
  err "invalid JSON in config: $config_path (failed to parse)"
fi

# Require `dimensions` to be a non-empty object.
dim_count=$(jq '(.dimensions // {}) | length' "$config_path")
if [[ "$dim_count" -eq 0 ]]; then
  err "config must declare at least one dimension under .dimensions"
fi

# Every dimension must be a non-empty array.
bad_dim=$(jq -r '
  (.dimensions // {})
  | to_entries
  | map(select((.value | type) != "array" or (.value | length) == 0))
  | map(.key)
  | .[]
' "$config_path")
if [[ -n "$bad_dim" ]]; then
  err "dimension(s) must be non-empty arrays: $(echo "$bad_dim" | tr '\n' ' ')"
fi

# Validate include/exclude are arrays of objects when provided.
bad_listish=$(jq -r '
  def check(name): . as $cfg
    | if ($cfg[name] // null) == null then empty
      elif ($cfg[name] | type) != "array" then "\(name) must be an array"
      elif ($cfg[name] | any(type != "object")) then "\(name) entries must be objects"
      else empty end;
  [check("include"), check("exclude")] | .[]
' "$config_path")
if [[ -n "$bad_listish" ]]; then
  err "$bad_listish"
fi

# Compute matrix cardinality: product of dimension lengths + |include| - |exclude|.
# This is an upper-bound approximation (exclude may target combos not in the base
# product, and include may expand existing rows rather than add new ones), but it
# matches how users reason about "how many jobs will this spawn?".
computed_size=$(jq '
  ((.dimensions // {}) | [.[] | length] | reduce .[] as $n (1; . * $n))
  + ((.include // []) | length)
  - ((.exclude // []) | length)
' "$config_path")

max_size=$(jq 'if has("max-matrix-size") then ."max-matrix-size" else null end' "$config_path")

if [[ "$max_size" != "null" ]]; then
  if [[ "$computed_size" -gt "$max_size" ]]; then
    err "matrix size $computed_size exceeds max-matrix-size $max_size"
  fi
fi

# Build the strategy block. We:
#   - spread the dimension arrays directly into `matrix`
#   - attach include/exclude when present
#   - emit max-parallel only when set
#   - default fail-fast to true
jq '
  def _strategy:
    {
      matrix: (
        (.dimensions // {})
        + (if (.include // null)  then {include: .include}  else {} end)
        + (if (.exclude // null)  then {exclude: .exclude}  else {} end)
      ),
      "fail-fast": (if has("fail-fast") then ."fail-fast" else true end)
    }
    + (if has("max-parallel") then {"max-parallel": ."max-parallel"} else {} end);
  { strategy: _strategy }
' "$config_path"
