#!/usr/bin/env bash
# matrix-generator.sh
#
# Generate a GitHub Actions strategy-matrix JSON from a high-level
# configuration file. Supports cartesian products over OS / language / feature
# axes, plus `include` and `exclude` rules, `max_parallel`, `fail_fast`,
# and a `max_size` ceiling for safety.
#
# Usage:
#     matrix-generator.sh <config.json>
#
# The script emits the strategy JSON on stdout and writes errors to stderr.
# Exit codes:
#     0  success
#     1  usage error (no arguments / --help exits 0 separately)
#     2  invalid configuration (bad JSON, missing file, empty axes, ...)
#     3  matrix size exceeds the configured max_size limit
#
# jq does the heavy data-shaping; bash handles I/O, validation, and the
# exit-code contract that the test suite asserts against.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: matrix-generator.sh <config.json>

Generate a GitHub Actions strategy-matrix JSON from a config file.

Config fields (all optional unless noted):
  os                 array of OS runner names          -> matrix dimension 'os'
  language_versions  array of language versions        -> dimension 'language_version'
  features           array of feature flag names       -> dimension 'feature'
  include            array of extra matrix entries (appended verbatim)
  exclude            array of match patterns (entries matching ALL keys are dropped)
  max_parallel       integer, becomes strategy.max-parallel
  fail_fast          boolean, becomes strategy.fail-fast (default: false)
  max_size           integer, error if final include list exceeds this (default: 256)

At least one axis OR at least one include entry is required.
EOF
}

die() {
    local code="${2:-2}"
    echo "error: $1" >&2
    exit "$code"
}

main() {
    if [[ $# -lt 1 ]]; then
        usage >&2
        exit 1
    fi

    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
    esac

    local config_file="$1"
    [[ -f "$config_file" ]] || die "config file not found: $config_file"

    # Validate that the file is syntactically valid JSON up-front. `jq empty`
    # reads and discards the input, returning non-zero on parse errors.
    if ! jq empty "$config_file" >/dev/null 2>&1; then
        die "invalid JSON in config file: $config_file"
    fi

    # Require at least one axis or one explicit include entry. A config with
    # nothing to iterate over is almost always a user mistake.
    local axes_total includes_total
    axes_total=$(jq '
        ((.os // []) | length)
        + ((.language_versions // []) | length)
        + ((.features // []) | length)
    ' "$config_file")
    includes_total=$(jq '(.include // []) | length' "$config_file")
    if [[ "$axes_total" == "0" && "$includes_total" == "0" ]]; then
        die "config must define at least one axis (os, language_versions, features) or an include entry"
    fi

    # Build the strategy JSON. We compute the cartesian product over the
    # declared axes, drop entries matching any `exclude` pattern, then append
    # the user-supplied `include` list. `max-parallel` is only emitted when
    # the user actually set it, matching GitHub's own behavior.
    local strategy
    strategy=$(jq '
        # Cartesian product of an array of {name, values} axes.
        def prod(axes):
            if (axes | length) == 0 then [{}]
            else
                axes[0] as $head
                | prod(axes[1:]) as $tail
                | [ $head.values[] as $v | $tail[] | . + {($head.name): $v} ]
            end;

        # True iff every key in $pattern has an equal value in $entry.
        # An empty pattern matches nothing (treat as a no-op).
        def matches($entry; $pattern):
            ($pattern | length) > 0
            and ($pattern | to_entries | all($entry[.key] == .value));

        . as $c
        | [
            (if (($c.os // []) | length) > 0 then {name: "os", values: $c.os} else empty end),
            (if (($c.language_versions // []) | length) > 0 then {name: "language_version", values: $c.language_versions} else empty end),
            (if (($c.features // []) | length) > 0 then {name: "feature", values: $c.features} else empty end)
          ] as $axes
        | prod($axes) as $base
        | ($c.exclude // []) as $excludes
        | ($c.include // []) as $includes
        | [ $base[] | . as $entry
              | select([ $excludes[] | matches($entry; .) ] | any | not) ]
          as $kept
        | ($kept + $includes) as $final
        | {
            "fail-fast": ($c.fail_fast // false),
            "matrix": { include: $final }
          }
          + (if ($c.max_parallel // null) != null then {"max-parallel": $c.max_parallel} else {} end)
    ' "$config_file")

    # Enforce the max_size ceiling before we print anything. A runaway matrix
    # would otherwise silently schedule hundreds of jobs in CI.
    local max_size size
    max_size=$(jq -r '.max_size // 256' "$config_file")
    size=$(jq '.matrix.include | length' <<<"$strategy")
    if (( size > max_size )); then
        die "matrix size ($size) exceeds max_size ($max_size)" 3
    fi

    # Pretty-print for readability; GitHub Actions accepts either form.
    jq . <<<"$strategy"
}

main "$@"
