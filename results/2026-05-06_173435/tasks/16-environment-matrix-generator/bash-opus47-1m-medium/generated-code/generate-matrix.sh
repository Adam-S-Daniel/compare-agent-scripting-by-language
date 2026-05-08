#!/usr/bin/env bash
# generate-matrix.sh — Generate a GitHub Actions strategy.matrix JSON object
# from a higher-level config file.
#
# Input config (JSON):
#   {
#     "matrix":      { "<dim>": [values, ...], ... }   # required
#     "include":     [ {dim: val, ...}, ... ]          # optional, passthrough
#     "exclude":     [ {dim: val, ...}, ... ]          # optional, passthrough
#     "max_parallel": <int>                            # optional
#     "fail_fast":   <bool>                            # optional
#     "max_size":    <int>                             # optional, validation cap
#   }
#
# Output (stdout): A strategy JSON object with `matrix`, `max-parallel`, and
# `fail-fast` fields suitable for inlining into a GitHub Actions workflow.
#
# Validation: refuses to emit a matrix whose effective combination count
# (cartesian product of dimensions, minus matched excludes, plus includes)
# exceeds `max_size`. Errors go to stderr, exit code 1.

set -euo pipefail

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    echo "Usage: $0 <config.json>" >&2
    exit 2
}

[ $# -ge 1 ] || usage
config="$1"
[ -f "$config" ] || die "config file not found: $config"

# Validate JSON
jq -e . "$config" >/dev/null 2>&1 || die "config is not valid JSON: $config"

# Require matrix key with at least one dimension
have_matrix=$(jq -r 'has("matrix") and (.matrix | type == "object") and (.matrix | length > 0)' "$config")
[ "$have_matrix" = "true" ] || die "config must have a non-empty 'matrix' object"

# Compute effective matrix size:
#   product of dim lengths, minus excludes that match a product entry,
#   plus all includes (treat all as additive for size accounting).
effective_size=$(jq '
    def cart:
        . as $m
        | ($m | keys_unsorted) as $ks
        | reduce $ks[] as $k ([{}];
            . as $acc
            | [ $acc[] as $a | ($m[$k][] | $a + {($k): .}) ]
          );
    (.matrix | cart) as $combos
    | (.exclude // []) as $exc
    | (.include // []) as $inc
    | ($combos
        | map(. as $c
              | select(($exc | map(. as $e | ($e | to_entries | all($c[.key] == .value))) | any | not))))
        as $kept
    | ($kept | length) + ($inc | length)
' "$config")

max_size=$(jq -r '.max_size // empty' "$config")
if [ -n "$max_size" ] && [ "$effective_size" -gt "$max_size" ]; then
    die "effective matrix size ($effective_size) exceeds max_size ($max_size)"
fi

# Build the output strategy object. Defaults: fail-fast=true (GH default),
# max-parallel left unset unless provided.
jq '
    {
        matrix: (
            .matrix
            + (if has("include") then {include: .include} else {} end)
            + (if has("exclude") then {exclude: .exclude} else {} end)
        )
    }
    + (if has("max_parallel") then {"max-parallel": .max_parallel} else {} end)
    + (if has("fail_fast")    then {"fail-fast":    .fail_fast}    else {} end)
' "$config"
