#!/usr/bin/env bash
#
# aggregate.sh — aggregate test result files (JUnit XML + JSON) into a
# single markdown summary suitable for a GitHub Actions job summary.
#
# Approach:
#   * The script is also a library: each piece of functionality
#     (parse_junit_file, parse_json_file, compute_totals, detect_flaky,
#     render_markdown) is a function that can be sourced and unit-tested
#     in isolation.
#   * Records flow through the pipeline as TSV lines:
#         status<TAB>duration<TAB>full_name
#     where status ∈ {passed,failed,skipped} and full_name is
#     "<suite>::<name>" (suite may be empty).
#   * Totals/flaky-detection operate on the merged TSV stream, which keeps
#     each function independent of file format.
#   * jq parses JSON; awk + sed parse JUnit XML (no xmllint dependency).
#
# Usage:
#   aggregate.sh [--fail-on-failures] <file-or-dir> [<file-or-dir> ...]
#
# When GITHUB_STEP_SUMMARY is set, the markdown is also appended there.
#
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: aggregate.sh [OPTIONS] <file-or-dir> [<file-or-dir> ...]

Aggregate JUnit XML and JSON test result files into a markdown summary.

Options:
  --fail-on-failures   Exit non-zero when any test failed.
  -h, --help           Show this help.

Inputs may be individual files (*.xml, *.json) or directories. Directories
are searched recursively for *.xml and *.json files.

When GITHUB_STEP_SUMMARY is set in the environment, the rendered markdown is
also appended to that file (suitable for GitHub Actions job summaries).
EOF
}

# parse_junit_file FILE
#
# Emit one TSV line per testcase: "status<TAB>duration<TAB>suite::name".
# Status is "failed" if a <failure> or <error> child element is present,
# "skipped" if a <skipped> child element is present, "passed" otherwise.
#
# Implementation: normalize the XML to one tag per line, then walk the
# stream with awk maintaining a small state machine. This avoids needing
# xmllint or python.
parse_junit_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "error: file not found: $file" >&2
        return 1
    fi
    if ! grep -q -E '<testsuite|<testcase' "$file"; then
        echo "error: not a JUnit XML document: $file" >&2
        return 1
    fi
    # Split tags onto separate lines so awk can rely on one tag per line.
    sed 's/></>\n</g' "$file" | awk '
        # Pull the value of attr=name out of the current line.
        function extract(line, attr,    re, val) {
            re = attr "=\"[^\"]*\""
            if (match(line, re)) {
                val = substr(line, RSTART + length(attr) + 2,
                             RLENGTH - length(attr) - 3)
                return val
            }
            return ""
        }
        function emit(   full) {
            full = (classname == "") ? name : classname "::" name
            if (time == "") time = "0"
            printf "%s\t%s\t%s\n", status, time, full
        }
        /<testcase[[:space:]>]/ || /<testcase\/>/ {
            name      = extract($0, "name")
            classname = extract($0, "classname")
            time      = extract($0, "time")
            status    = "passed"
            in_case   = 1
            # Self-closing form: <testcase ... />
            if ($0 ~ /\/>[[:space:]]*$/) {
                emit()
                in_case = 0
            }
            next
        }
        in_case && /<failure|<error/ { status = "failed"; next }
        in_case && /<skipped/        { status = "skipped"; next }
        in_case && /<\/testcase>/ {
            emit()
            in_case = 0
        }
    '
}

# parse_json_file FILE
#
# Expected JSON shape:
#   { "tests": [ { "name": "...", "suite": "...",
#                  "status": "passed|failed|skipped",
#                  "duration": <number> }, ... ] }
parse_json_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "error: file not found: $file" >&2
        return 1
    fi
    if ! jq empty "$file" >/dev/null 2>&1; then
        echo "error: invalid JSON: $file" >&2
        return 1
    fi
    jq -r '
        .tests[]
        | "\(.status)\t\(.duration // 0)\t\((.suite // ""))::\(.name)"
    ' "$file"
}

# detect_format PATH -> prints "junit" or "json", or exits non-zero.
detect_format() {
    local p="$1"
    case "${p,,}" in
        *.xml)  echo "junit" ;;
        *.json) echo "json" ;;
        *)
            echo "error: unknown format for $p (expected .xml or .json)" >&2
            return 1
            ;;
    esac
}

# compute_totals — read TSV records on stdin, write key=value totals on stdout.
compute_totals() {
    awk -F'\t' '
        {
            counts[$1]++
            total++
            duration += ($2 + 0)
        }
        END {
            printf "passed=%d\n",  counts["passed"]  + 0
            printf "failed=%d\n",  counts["failed"]  + 0
            printf "skipped=%d\n", counts["skipped"] + 0
            printf "total=%d\n",   total + 0
            # %g trims trailing zeros so 0.6 stays "0.6".
            printf "duration=%g\n", duration + 0
        }
    '
}

# detect_flaky — read TSV records on stdin, print full names of tests that
# show both passed and failed outcomes across the input set.
detect_flaky() {
    awk -F'\t' '
        $1 == "passed" { p[$3] = 1 }
        $1 == "failed" { f[$3] = 1 }
        END {
            for (t in p) if (t in f) print t
        }
    ' | sort
}

# render_markdown TOTALS_FILE FLAKY_FILE -> writes the markdown summary to stdout.
render_markdown() {
    local totals_file="$1"
    local flaky_file="$2"
    local passed=0 failed=0 skipped=0 total=0 duration=0
    local key value
    while IFS='=' read -r key value; do
        case "$key" in
            passed)   passed="$value" ;;
            failed)   failed="$value" ;;
            skipped)  skipped="$value" ;;
            total)    total="$value" ;;
            duration) duration="$value" ;;
        esac
    done < "$totals_file"

    local status_emoji="PASS"
    if [[ "$failed" -gt 0 ]]; then
        status_emoji="FAIL"
    elif [[ "$total" -eq 0 ]]; then
        status_emoji="EMPTY"
    fi

    cat <<EOF
# Test Results

**Status:** ${status_emoji}

| Metric    | Value         |
|-----------|---------------|
| Passed    | ${passed}     |
| Failed    | ${failed}     |
| Skipped   | ${skipped}    |
| **Total** | **${total}**  |
| Duration  | ${duration}s  |
EOF

    if [[ -s "$flaky_file" ]]; then
        printf '\n## Flaky Tests\n\n'
        echo "These tests passed in some runs and failed in others:"
        echo
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            # shellcheck disable=SC2016
            printf -- '- `%s`\n' "$t"
        done < "$flaky_file"
    fi
}

# collect_files INPUT... -> print one input file path per line.
# Directories are searched recursively for *.xml and *.json files.
collect_files() {
    local input
    for input in "$@"; do
        if [[ -d "$input" ]]; then
            find "$input" -type f \( -name '*.xml' -o -name '*.json' \) | sort
        elif [[ -f "$input" ]]; then
            printf '%s\n' "$input"
        else
            echo "error: input not found: $input" >&2
            return 1
        fi
    done
}

main() {
    local fail_on_failures=0
    local inputs=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                return 0
                ;;
            --fail-on-failures)
                fail_on_failures=1
                shift
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do inputs+=("$1"); shift; done
                ;;
            -*)
                echo "error: unknown option: $1" >&2
                usage >&2
                return 2
                ;;
            *)
                inputs+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#inputs[@]} -eq 0 ]]; then
        echo "error: no input files or directories given" >&2
        usage >&2
        return 2
    fi

    local tmpdir
    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

    local records="${tmpdir}/records.tsv"
    local totals="${tmpdir}/totals"
    local flaky="${tmpdir}/flaky"
    : > "$records"

    local files
    if ! files="$(collect_files "${inputs[@]}")"; then
        return 1
    fi
    if [[ -z "$files" ]]; then
        echo "error: no .xml or .json files found in inputs" >&2
        return 1
    fi

    local f fmt
    while IFS= read -r f; do
        fmt="$(detect_format "$f")" || return 1
        case "$fmt" in
            junit) parse_junit_file "$f" >> "$records" ;;
            json)  parse_json_file  "$f" >> "$records" ;;
        esac
    done <<< "$files"

    compute_totals < "$records" > "$totals"
    detect_flaky   < "$records" > "$flaky"

    local md
    md="$(render_markdown "$totals" "$flaky")"
    printf '%s\n' "$md"

    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        printf '%s\n' "$md" >> "${GITHUB_STEP_SUMMARY}"
    fi

    if [[ "$fail_on_failures" -eq 1 ]]; then
        local failed_count
        failed_count="$(awk -F= '$1=="failed" {print $2}' "$totals")"
        if [[ "${failed_count:-0}" -gt 0 ]]; then
            return 1
        fi
    fi
}

# Run main only when executed as a script, never when sourced (e.g. by bats).
if [[ "${BASH_SOURCE[0]}" == "$0" ]] && [[ "${AGGREGATE_LIB:-0}" != "1" ]]; then
    main "$@"
fi
