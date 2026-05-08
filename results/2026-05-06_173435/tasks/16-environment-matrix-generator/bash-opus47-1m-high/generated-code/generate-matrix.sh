#!/usr/bin/env bash
# generate-matrix.sh — generate a GitHub Actions strategy.matrix JSON from a
# build-matrix configuration. The script reads a JSON config describing axes
# (e.g. os, language version, feature flags) plus optional include/exclude
# rules, max-parallel, fail-fast and max-size, then emits the strategy block
# on stdout. The expanded combination count is reported on stderr as
# "size=<N>"; if max-size is set and exceeded, the script exits non-zero.
#
# All matrix expansion logic runs in jq so this script is just a thin shell
# wrapper for argument parsing, validation, and error reporting.

set -euo pipefail

usage() {
    cat <<'EOF' >&2
Usage: generate-matrix.sh --config FILE

Read a build-matrix config (JSON) and emit a GitHub Actions strategy block.

Config schema:
  {
    "axes":        { "<name>": [<values>], ... },   # required
    "include":     [ {<key>: <val>, ...}, ... ],    # optional, GH-Actions-style
    "exclude":     [ {<key>: <val>, ...}, ... ],    # optional, GH-Actions-style
    "fail-fast":   <bool>,                          # optional, default true
    "max-parallel": <int>,                          # optional
    "max-size":    <int>                            # optional, validation cap
  }
EOF
}

err() { printf 'Error: %s\n' "$*" >&2; }

# --- argument parsing --------------------------------------------------------

CONFIG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG="${2:-}"
            shift 2 || { err "missing value for --config"; exit 2; }
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "unknown argument: $1"
            usage
            exit 2
            ;;
    esac
done

if [[ -z "$CONFIG" ]]; then
    err "missing --config argument"
    usage
    exit 2
fi

if [[ ! -f "$CONFIG" ]]; then
    err "config file not found: $CONFIG"
    exit 2
fi

# --- validation --------------------------------------------------------------

if ! jq empty "$CONFIG" >/dev/null 2>&1; then
    err "invalid JSON in config: $CONFIG"
    exit 2
fi

if ! jq -e '(.axes // empty) | type == "object" and (length > 0)' "$CONFIG" >/dev/null; then
    err "config must contain a non-empty 'axes' object"
    exit 2
fi

# --- size computation --------------------------------------------------------
# We compute the size of the *expanded* matrix by:
#   1. Building the cartesian product of all axis values.
#   2. Filtering out any combo matching at least one exclude rule (a rule
#      matches when every (key, value) pair in the rule equals the combo's).
#   3. Adding the number of include rules (each include contributes one row;
#      GH Actions can fold compatible includes into existing rows but for
#      validation purposes we treat them as additive — the conservative bound).
SIZE="$(jq -r '
    .axes as $axes
    | (.exclude // []) as $excludes
    | (.include // []) as $includes
    | (
        $axes
        | to_entries
        | reduce .[] as $e (
            [{}];
            [ .[] as $combo | $e.value[] as $v | $combo + {($e.key): $v} ]
          )
      ) as $combos
    | (
        $combos
        | map(
            . as $c
            | select(
                ([$excludes[] | [to_entries[] | $c[.key] == .value] | all]
                  | any) | not
              )
          )
        | length
      ) as $base
    | $base + ($includes | length)
' "$CONFIG")"

# --- max-size validation -----------------------------------------------------

MAX_SIZE="$(jq -r '."max-size" // empty' "$CONFIG")"
if [[ -n "$MAX_SIZE" ]] && (( SIZE > MAX_SIZE )); then
    err "matrix size $SIZE exceeds max-size $MAX_SIZE"
    exit 1
fi

# --- emit strategy JSON ------------------------------------------------------

jq '
    .axes as $axes
    | (.include // null) as $inc
    | (.exclude // null) as $exc
    | (if has("fail-fast") then ."fail-fast" else true end) as $ff
    | ."max-parallel" as $mp
    | {
        "fail-fast": $ff,
        "matrix": (
          $axes
          + (if $inc != null then {include: $inc} else {} end)
          + (if $exc != null then {exclude: $exc} else {} end)
        )
      }
      + (if $mp != null then {"max-parallel": $mp} else {} end)
' "$CONFIG"

printf 'size=%s\n' "$SIZE" >&2
