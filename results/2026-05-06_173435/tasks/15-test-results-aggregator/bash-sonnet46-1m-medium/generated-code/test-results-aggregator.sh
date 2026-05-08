#!/usr/bin/env bash
# test-results-aggregator.sh
# Parses JUnit XML and JSON test result files, aggregates across matrix runs,
# detects flaky tests (pass in some runs, fail in others), and outputs a
# GitHub-Actions-compatible markdown summary to stdout.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: test-results-aggregator.sh <file1> [file2] ...

Accepts JUnit XML (.xml) and JSON (.json) test result files.
Aggregates totals across all files, detects flaky tests, and writes
a markdown summary to stdout.
EOF
    exit 1
}

# Parse a JUnit XML file. Outputs: name<TAB>status<TAB>duration per testcase.
parse_junit() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

filepath = sys.argv[1]
try:
    tree = ET.parse(filepath)
except ET.ParseError as e:
    print(f"ERROR: Cannot parse XML '{filepath}': {e}", file=sys.stderr)
    sys.exit(1)

root = tree.getroot()
# Support both <testsuites> root and bare <testsuite> root
suites = [root] if root.tag == 'testsuite' else list(root.iter('testsuite'))

for suite in suites:
    for tc in suite.findall('testcase'):
        classname = tc.get('classname', '')
        name = tc.get('name', '')
        full_name = f"{classname}.{name}" if classname else name
        duration = tc.get('time', '0') or '0'

        if tc.find('failure') is not None or tc.find('error') is not None:
            status = 'failed'
        elif tc.find('skipped') is not None:
            status = 'skipped'
        else:
            status = 'passed'

        print(f"{full_name}\t{status}\t{duration}")
PYEOF
}

# Parse a JSON test results file. Outputs: name<TAB>status<TAB>duration per test.
parse_json() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys
import json

filepath = sys.argv[1]
try:
    with open(filepath) as f:
        data = json.load(f)
except (json.JSONDecodeError, OSError) as e:
    print(f"ERROR: Cannot parse JSON '{filepath}': {e}", file=sys.stderr)
    sys.exit(1)

for t in data.get('tests', []):
    name = str(t.get('name', 'unknown'))
    status = str(t.get('status', 'unknown')).lower()
    duration = str(t.get('duration', 0))
    print(f"{name}\t{status}\t{duration}")
PYEOF
}

# Read a results accumulation file (name<TAB>status per line) and print
# the names of tests that are flaky: passed in some runs, failed in others.
detect_flaky() {
    local results_file="$1"
    python3 - "$results_file" <<'PYEOF'
import sys
from collections import defaultdict

statuses = defaultdict(set)
with open(sys.argv[1]) as f:
    for line in f:
        parts = line.rstrip('\n').split('\t')
        if len(parts) >= 2 and parts[0]:
            statuses[parts[0]].add(parts[1])

for name in sorted(statuses):
    s = statuses[name]
    if 'passed' in s and 'failed' in s:
        print(name)
PYEOF
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    # Validate all inputs before processing any of them
    for f in "$@"; do
        if [[ ! -f "$f" ]]; then
            echo "ERROR: File not found: '$f'" >&2
            exit 1
        fi
    done

    local tmpdir
    tmpdir=$(mktemp -d)
    # Expand $tmpdir now so the trap uses the correct path
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT

    local results_file="$tmpdir/results.tsv"
    touch "$results_file"

    local total_passed=0
    local total_failed=0
    local total_skipped=0
    local total_duration="0"
    local file_count=0

    for file in "$@"; do
        file_count=$((file_count + 1))
        local ext="${file##*.}"
        local parsed_output

        if [[ "$ext" == "xml" ]]; then
            parsed_output=$(parse_junit "$file")
        elif [[ "$ext" == "json" ]]; then
            parsed_output=$(parse_json "$file")
        else
            echo "ERROR: Unknown format for '$file' (expected .xml or .json)" >&2
            exit 1
        fi

        # Accumulate per-testcase results for aggregation and flaky detection
        while IFS=$'\t' read -r name status duration; do
            [[ -z "$name" ]] && continue
            printf '%s\t%s\n' "$name" "$status" >> "$results_file"

            case "$status" in
                passed)  total_passed=$((total_passed + 1)) ;;
                failed)  total_failed=$((total_failed + 1)) ;;
                skipped) total_skipped=$((total_skipped + 1)) ;;
            esac

            # Accumulate duration using awk for floating-point arithmetic
            total_duration=$(awk -v a="$total_duration" -v b="$duration" \
                'BEGIN { printf "%.3f", a + b }')
        done <<< "$parsed_output"
    done

    local total_tests=$((total_passed + total_failed + total_skipped))

    # Detect flaky tests from the accumulated results
    local flaky_output=""
    if [[ -s "$results_file" ]]; then
        flaky_output=$(detect_flaky "$results_file")
    fi
    local flaky_count=0
    if [[ -n "$flaky_output" ]]; then
        flaky_count=$(echo "$flaky_output" | grep -c '[^[:space:]]')
    fi

    local status_badge
    if [[ $total_failed -gt 0 ]]; then
        status_badge="FAILED"
    else
        status_badge="PASSED"
    fi

    # Output GitHub-Actions-compatible markdown summary
    cat <<EOF
# Test Results Summary

**Status: ${status_badge}**

## Overview

| Metric | Value |
|--------|-------|
| Files Processed | ${file_count} |
| Total Tests | ${total_tests} |
| Passed | ${total_passed} |
| Failed | ${total_failed} |
| Skipped | ${total_skipped} |
| Duration | ${total_duration}s |

## Flaky Tests
EOF

    if [[ "$flaky_count" -eq 0 ]]; then
        printf '\nNo flaky tests detected.\n'
    else
        printf '\nThe following tests had inconsistent results across matrix runs:\n\n'
        printf '| Test Name | Issue |\n'
        printf '|-----------|-------|\n'
        while IFS= read -r test_name; do
            [[ -z "$test_name" ]] && continue
            echo "| \`${test_name}\` | Passed in some runs, failed in others |"
        done <<< "$flaky_output"
    fi

    printf '\n## Files Analyzed\n\n'
    for f in "$@"; do
        echo "- \`${f}\`"
    done
}

main "$@"
