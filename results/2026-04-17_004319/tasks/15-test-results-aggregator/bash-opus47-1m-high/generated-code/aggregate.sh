#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# aggregate.sh — parse JUnit XML and JSON test result files, aggregate
# totals across files (matrix build), detect flaky tests, and emit a
# summary suitable for a GitHub Actions job summary.
#
# Usage: aggregate.sh [--format text|markdown] <file> [<file> ...]
#
# Strategy:
#   * JUnit XML is parsed by scanning <testcase ...> lines with awk.
#     A <testcase> followed by <failure> or <error> is a failure, a
#     <skipped> tag marks a skip, otherwise it counts as a pass.
#   * JSON is parsed with jq (required dependency). Tests have a status
#     field of passed|failed|skipped.
#   * For flaky detection we record the per-test outcomes across all
#     input files and flag any test that has both pass and fail results.
#   * Output is either a single-line key=value text summary (easy to
#     grep in tests) or a markdown summary for GITHUB_STEP_SUMMARY.

set -euo pipefail

FORMAT="text"
FILES=()

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: aggregate.sh [--format text|markdown] <file> [<file> ...]

Parses JUnit XML (.xml) and JSON (.json) test results, aggregates totals
across input files, identifies flaky tests, and writes a summary.

Options:
  --format text|markdown  Output format (default: text)
  -h, --help              Show this help

If GITHUB_STEP_SUMMARY is set the markdown summary is appended there.
EOF
}

# Parse arguments.
while [ $# -gt 0 ]; do
    case "$1" in
        --format)
            [ $# -ge 2 ] || die "--format requires an argument"
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do FILES+=("$1"); shift; done
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

if [ ${#FILES[@]} -eq 0 ]; then
    usage >&2
    exit 2
fi

case "$FORMAT" in
    text|markdown) ;;
    *) die "Invalid --format: $FORMAT (expected text or markdown)" ;;
esac

command -v jq >/dev/null 2>&1 || die "jq is required but not installed"

# Parse a JUnit XML file. Emits "status<TAB>name<TAB>duration" per test
# to stdout. status is one of passed|failed|skipped.
parse_junit_xml() {
    local file="$1"
    awk '
        BEGIN { in_case=0; name=""; dur=0; status="passed" }
        function attr(tag, key,    s, a, b, val) {
            # Extract key="value" from tag (case-insensitive on key)
            s = tag
            a = index(tolower(s), key "=\"")
            if (a == 0) return ""
            s = substr(s, a + length(key) + 2)
            b = index(s, "\"")
            if (b == 0) return ""
            val = substr(s, 1, b - 1)
            return val
        }
        function flush() {
            if (in_case) {
                printf "%s\t%s\t%s\n", status, name, dur
            }
            in_case=0; name=""; dur=0; status="passed"
        }
        /<testcase[[:space:]>]/ {
            flush()
            in_case=1
            # Join potentially multi-line tag into buffer (simple: this line)
            line = $0
            # Keep reading until we see > if self-close or open tag
            while (index(line, ">") == 0 && (getline more) > 0) {
                line = line " " more
            }
            name = attr(line, "name")
            t = attr(line, "time")
            if (t == "") t = "0"
            dur = t + 0
            status = "passed"
            # If the tag is self-closing (/>) no nested elements
            if (index(line, "/>") > 0) {
                flush()
            }
            next
        }
        /<failure[[:space:]\/>]/ || /<error[[:space:]\/>]/ {
            if (in_case) status="failed"
            next
        }
        /<skipped[[:space:]\/>]/ {
            if (in_case) status="skipped"
            next
        }
        /<\/testcase>/ {
            flush()
            next
        }
        END { flush() }
    ' "$file"
}

# Return total duration (sum of time attributes on testsuite/testsuites).
# Falls back to sum of per-test durations if none found.
junit_duration() {
    local file="$1"
    local t
    t=$(awk '
        /<testsuites[[:space:]>]/ || /<testsuite[[:space:]>]/ {
            line=$0
            while (index(line, ">") == 0 && (getline more) > 0) line = line " " more
            if (match(line, /time="[^"]*"/)) {
                s = substr(line, RSTART+6, RLENGTH-7)
                print s
                exit
            }
        }
    ' "$file")
    if [ -z "$t" ]; then
        t=$(parse_junit_xml "$file" | awk -F'\t' '{s+=$3} END {printf "%f", s+0}')
    fi
    printf '%s' "$t"
}

# Parse a JSON test result file. Same output format as parse_junit_xml.
parse_json() {
    local file="$1"
    jq -r '.tests[] | [.status, .name, (.duration // 0)] | @tsv' "$file"
}

json_duration() {
    local file="$1"
    jq -r '(.duration // ([.tests[].duration // 0] | add // 0))' "$file"
}

# Validate a file exists and has a known extension.
check_file() {
    local f="$1"
    [ -f "$f" ] || die "File not found: $f"
    case "${f,,}" in
        *.xml|*.json) ;;
        *) die "Unsupported file format: $f (expected .xml or .json)" ;;
    esac
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# all.tsv: one line per test observed across all files.
#   columns: status<TAB>name<TAB>duration
: > "$TMP/all.tsv"

TOTAL_DURATION=0

for file in "${FILES[@]}"; do
    check_file "$file"
    case "${file,,}" in
        *.xml)
            parse_junit_xml "$file" >> "$TMP/all.tsv"
            d=$(junit_duration "$file")
            ;;
        *.json)
            # Validate JSON first for a clear error message.
            jq -e . "$file" >/dev/null 2>&1 || die "Malformed JSON: $file"
            parse_json "$file" >> "$TMP/all.tsv"
            d=$(json_duration "$file")
            ;;
    esac
    TOTAL_DURATION=$(awk -v a="$TOTAL_DURATION" -v b="$d" 'BEGIN { printf "%f", a + b }')
done

# Compute totals.
TOTAL=$(wc -l < "$TMP/all.tsv" | tr -d ' ')
PASSED=$(awk -F'\t' '$1=="passed"' "$TMP/all.tsv" | wc -l | tr -d ' ')
FAILED=$(awk -F'\t' '$1=="failed"' "$TMP/all.tsv" | wc -l | tr -d ' ')
SKIPPED=$(awk -F'\t' '$1=="skipped"' "$TMP/all.tsv" | wc -l | tr -d ' ')

# Flaky detection: for each test name, collect the distinct statuses
# observed. A test that has both "passed" and "failed" is flaky.
#   flaky.tsv: one name per line
awk -F'\t' '
    { key=$2; seen[key, $1]=1; names[key]=1 }
    END {
        for (n in names) {
            if ((n SUBSEP "passed") in seen && (n SUBSEP "failed") in seen) {
                print n
            }
        }
    }
' "$TMP/all.tsv" | sort > "$TMP/flaky.tsv"

FLAKY=$(wc -l < "$TMP/flaky.tsv" | tr -d ' ')

# Pass rate (integer percent). Denominator excludes skipped tests.
RUN_TOTAL=$(( PASSED + FAILED ))
if [ "$RUN_TOTAL" -gt 0 ]; then
    PASS_RATE=$(( PASSED * 100 / RUN_TOTAL ))
else
    PASS_RATE=0
fi

DURATION_FMT=$(awk -v d="$TOTAL_DURATION" 'BEGIN { printf "%.2f", d }')

emit_text() {
    printf 'total=%s passed=%s failed=%s skipped=%s flaky=%s duration=%ss pass_rate=%s%%\n' \
        "$TOTAL" "$PASSED" "$FAILED" "$SKIPPED" "$FLAKY" "$DURATION_FMT" "$PASS_RATE"
    if [ "$FLAKY" -gt 0 ]; then
        printf 'flaky_tests:\n'
        while IFS= read -r name; do
            printf '  %s\n' "$name"
        done < "$TMP/flaky.tsv"
    fi
}

emit_markdown() {
    local status_icon="green"
    [ "$FAILED" -gt 0 ] && status_icon="red"
    cat <<EOF
# Test Results Summary

| Metric | Value |
| --- | --- |
| Total | $TOTAL |
| Passed | $PASSED |
| Failed | $FAILED |
| Skipped | $SKIPPED |
| Flaky | $FLAKY |
| Duration | ${DURATION_FMT}s |
| Pass Rate | ${PASS_RATE}% |
| Status | $status_icon |
EOF
    if [ "$FLAKY" -gt 0 ]; then
        printf '\n## Flaky Tests\n\n'
        printf 'The following tests passed in some runs and failed in others:\n\n'
        while IFS= read -r name; do
            printf -- '- `%s`\n' "$name"
        done < "$TMP/flaky.tsv"
    fi
    if [ "$FAILED" -gt 0 ]; then
        printf '\n## Failed Tests\n\n'
        awk -F'\t' '$1=="failed" {print $2}' "$TMP/all.tsv" | sort -u | while IFS= read -r name; do
            printf -- '- `%s`\n' "$name"
        done
    fi
}

if [ "$FORMAT" = "markdown" ]; then
    OUT=$(emit_markdown)
else
    OUT=$(emit_text)
fi

printf '%s\n' "$OUT"

# When running inside GitHub Actions, append to the job summary.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ "$FORMAT" = "markdown" ]; then
    printf '%s\n' "$OUT" >> "$GITHUB_STEP_SUMMARY"
fi
