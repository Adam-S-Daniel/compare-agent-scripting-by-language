#!/usr/bin/env bash
# generate-matrix.sh — read a matrix config JSON and emit an expanded
# GitHub Actions build matrix as JSON.
#
# Config schema:
#   {
#     "axes":         { "<key>": ["v1","v2",...], ... },
#     "include":      [ {<key>: <val>, ...}, ... ],
#     "exclude":      [ {<key>: <val>, ...}, ... ],
#     "max-parallel": <int|null>,
#     "fail-fast":    <bool>,
#     "max-size":     <int|null>
#   }
#
# Output:
#   { "matrix": {"include": [...]}, "count": N,
#     "max-parallel": ..., "fail-fast": ... }
# Exit codes: 0 ok, 2 bad input, 3 matrix exceeds max-size.
set -euo pipefail

usage() { echo "usage: $0 <config.json>   (or pipe JSON to stdin with -)" >&2; }

src="${1:-}"
if [[ -z "$src" ]]; then
    usage; exit 2
fi
if [[ "$src" == "-" ]]; then
    input="$(cat)"
elif [[ -f "$src" ]]; then
    input="$(cat "$src")"
else
    echo "Error: config file not found: $src" >&2
    exit 2
fi

if ! jq -e . >/dev/null 2>&1 <<<"$input"; then
    echo "Error: invalid JSON in config" >&2
    exit 2
fi
if ! jq -e '(.axes // null) | (type == "object") or (. == null)' >/dev/null <<<"$input"; then
    echo "Error: 'axes' must be an object" >&2
    exit 2
fi

# The jq program below does the real work: cartesian product of axes,
# apply excludes (an exclude rule matches a row when every key:value pair
# in the rule equals the row), then append includes.
result=$(jq '
  . as $cfg
  | ($cfg.axes     // {})   as $axes
  | ($cfg.exclude  // [])   as $excludes
  | ($cfg.include  // [])   as $includes
  | ($cfg["max-parallel"] // null) as $mp
  | ($cfg["fail-fast"]    // true) as $ff
  | ($cfg["max-size"]     // null) as $ms

  | ( if ($axes | length) == 0 then []
      else
        $axes
        | to_entries
        | reduce .[] as $e
            ( [{}];
              [ .[] as $acc
                | $e.value[] as $v
                | $acc + {($e.key): $v} ] )
      end
    ) as $combos

  | ( $combos
      | map( . as $row
             | select(
                 ($excludes
                   | map( . as $ex
                          | ([ $ex | to_entries[]
                               | $row[.key] == .value ] | all) )
                   | any) | not ) )
    ) as $filtered

  | ($filtered + $includes) as $entries
  | ($entries | length) as $count
  | if $ms != null and $count > $ms then
      { error: "matrix size \($count) exceeds max-size \($ms)",
        count: $count, "max-size": $ms }
    else
      { matrix: {include: $entries},
        count: $count,
        "max-parallel": $mp,
        "fail-fast": $ff }
    end
' <<<"$input")

echo "$result"

if jq -e '.error' >/dev/null 2>&1 <<<"$result"; then
    echo "Error: $(jq -r '.error' <<<"$result")" >&2
    exit 3
fi
