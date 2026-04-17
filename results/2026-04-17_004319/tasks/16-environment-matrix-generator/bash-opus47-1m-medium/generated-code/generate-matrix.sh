#!/usr/bin/env bash
# generate-matrix.sh — Generate a GitHub Actions build matrix from a JSON config.
#
# Input (JSON file path as $1):
#   {
#     "axes":       { "os": [...], "node": [...], "feature": [...] },
#     "include":    [ { ... } ],        # extra combinations appended verbatim
#     "exclude":    [ { ... } ],        # combinations to drop (partial match)
#     "max-parallel": 4,                 # optional (integer)
#     "fail-fast":    true|false,        # optional (default true)
#     "max-size":     100                # optional; error if expanded size exceeds
#   }
#
# Output (stdout, JSON):
#   {
#     "combinations": [ { ...axis key/values... }, ... ],
#     "count":        <int>,
#     "max-parallel": <int|null>,
#     "fail-fast":    <bool>,
#     "strategy":     { "matrix": {...}, "max-parallel": ..., "fail-fast": ... }
#   }
#
# Approach: shell out to `jq` for cartesian product + filtering (stdlib-level
# JSON handling in bash is impractical). Exit non-zero on any invalid input.

set -euo pipefail

die() { printf '%s\n' "error: $*" >&2; exit 1; }

[[ $# -ge 1 ]] || die "usage: generate-matrix.sh <config.json>"
CONFIG="$1"
[[ -f "$CONFIG" ]] || die "config file not found: $CONFIG"

# Validate that the config parses as JSON.
if ! jq -e . "$CONFIG" >/dev/null 2>&1; then
  die "invalid JSON in $CONFIG"
fi

# jq program: compute the cartesian product of all axes, then apply
# exclude (partial match: entry excluded if every key in the rule matches)
# and append include entries verbatim.
# shellcheck disable=SC2016  # $vars here are jq variables, not shell
JQ_PROG='
  def cartesian(axes):
    if (axes | length) == 0 then []
    else
      reduce (axes | to_entries[]) as $kv ([{}];
        [ .[] as $acc | $kv.value[] as $v | $acc + {($kv.key): $v} ])
    end;

  . as $cfg
  | (.axes // {})        as $axes
  | (.include // [])     as $inc
  | (.exclude // [])     as $exc
  | (."max-parallel")    as $mp
  | (if has("fail-fast") then ."fail-fast" else true end) as $ff
  | (."max-size")        as $maxsize
  | cartesian($axes)
  | map( . as $row
         | select( [ $exc[] | . as $rule
                     | [ ($rule | to_entries[]) | $row[.key] == .value ]
                     | all ]
                   | any | not ) )
  | . + $inc
  | . as $combos
  | { combinations: $combos,
      count:        ($combos | length),
      "max-parallel": $mp,
      "fail-fast":    $ff,
      "max-size":     $maxsize,
      strategy: {
        matrix: ( $axes
                  + ( if ($inc|length) > 0 then {include: $inc} else {} end )
                  + ( if ($exc|length) > 0 then {exclude: $exc} else {} end ) ),
        "max-parallel": $mp,
        "fail-fast":    $ff
      } }
'

RESULT="$(jq "$JQ_PROG" "$CONFIG")" || die "failed to compute matrix"

# Enforce max-size if present.
max_size="$(jq -r '."max-size" // empty' <<<"$RESULT")"
count="$(jq -r '.count' <<<"$RESULT")"
if [[ -n "$max_size" ]] && (( count > max_size )); then
  die "matrix size $count exceeds max-size $max_size"
fi

# Strip the internal "max-size" key from the output.
jq 'del(."max-size")' <<<"$RESULT"
