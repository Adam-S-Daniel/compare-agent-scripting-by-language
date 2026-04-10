#!/usr/bin/env bash
#
# aggregate-test-results.sh — Parse and aggregate test results from JUnit XML
# and JSON files. Identifies flaky tests and generates a markdown summary
# suitable for GitHub Actions job summaries.
#
# Usage: aggregate-test-results.sh <directory>
#   <directory>  Path containing *.xml (JUnit) and/or *.json test result files
#
# Requires: jq (for JSON parsing), awk, sed, sort (standard Unix tools)

set -euo pipefail
export LC_ALL=C  # Consistent numeric/sort behavior across locales

# Parse a JUnit XML file line-by-line. Extracts individual test results and
# appends a per-file summary. Self-closing <testcase .../> tags are passed
# tests; multi-line blocks with <failure> or <skipped> children are handled.
parse_junit_xml() {
    local file="$1"
    local results_file="$2"
    local summary_file="$3"
    local fname
    fname=$(basename "$file")

    local test_name="" class_name="" test_time=""
    local status="passed"
    local in_testcase="false"
    local file_tests=0 file_passed=0 file_failed=0 file_skipped=0
    local file_duration="0"

    while IFS= read -r line; do
        # Opening of a <testcase> element
        if [[ "$line" =~ \<testcase[[:space:]] ]]; then
            status="passed"
            test_name=$(sed -n 's/.* name="\([^"]*\)".*/\1/p' <<< "$line")
            class_name=$(sed -n 's/.*classname="\([^"]*\)".*/\1/p' <<< "$line")
            test_time=$(sed -n 's/.*time="\([^"]*\)".*/\1/p' <<< "$line")
            test_time="${test_time:-0}"

            # Self-closing tag: <testcase ... /> means passed (no children)
            if [[ "$line" =~ /\> ]]; then
                echo "${class_name}.${test_name}|${status}|${test_time}|${fname}" >> "$results_file"
                file_tests=$((file_tests + 1))
                file_passed=$((file_passed + 1))
                file_duration=$(awk -v a="$file_duration" -v b="$test_time" 'BEGIN {printf "%.2f", a + b}')
            else
                in_testcase="true"
            fi
        elif [[ "$in_testcase" == "true" ]]; then
            # Inside a multi-line testcase — look for failure/skipped children
            if [[ "$line" =~ \<failure ]]; then
                status="failed"
            fi
            if [[ "$line" =~ \<skipped ]]; then
                status="skipped"
            fi
            # Closing tag ends the testcase
            if [[ "$line" =~ \</testcase\> ]]; then
                echo "${class_name}.${test_name}|${status}|${test_time}|${fname}" >> "$results_file"
                file_tests=$((file_tests + 1))
                case "$status" in
                    passed)  file_passed=$((file_passed + 1)) ;;
                    failed)  file_failed=$((file_failed + 1)) ;;
                    skipped) file_skipped=$((file_skipped + 1)) ;;
                esac
                file_duration=$(awk -v a="$file_duration" -v b="$test_time" 'BEGIN {printf "%.2f", a + b}')
                in_testcase="false"
            fi
        fi
    done < "$file"

    echo "${fname}|${file_tests}|${file_passed}|${file_failed}|${file_skipped}|${file_duration}" >> "$summary_file"
}

# Parse a JSON test result file using jq. Expects the structure:
# { "testsuites": [{ "testcases": [{ "name", "classname", "time", "status" }] }] }
parse_json() {
    local file="$1"
    local results_file="$2"
    local summary_file="$3"
    local fname
    fname=$(basename "$file")

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required to parse JSON files" >&2
        exit 1
    fi

    # Extract individual test case results
    jq -r '.testsuites[] | .testcases[] | "\(.classname).\(.name)|\(.status)|\(.time)"' "$file" | \
        while IFS= read -r line; do
            echo "${line}|${fname}" >> "$results_file"
        done

    # Compute per-file summary totals
    local tests passed failed skipped duration
    tests=$(jq '[.testsuites[].testcases | length] | add // 0' "$file")
    passed=$(jq '[.testsuites[].testcases[] | select(.status == "passed")] | length' "$file")
    failed=$(jq '[.testsuites[].testcases[] | select(.status == "failed")] | length' "$file")
    skipped=$(jq '[.testsuites[].testcases[] | select(.status == "skipped")] | length' "$file")
    duration=$(jq '[.testsuites[].testcases[].time] | add // 0' "$file")

    echo "${fname}|${tests}|${passed}|${failed}|${skipped}|${duration}" >> "$summary_file"
}

# Generate a markdown summary from the collected results and per-file summaries.
# Output goes to stdout — pipe to $GITHUB_STEP_SUMMARY in CI.
generate_markdown() {
    local results_file="$1"
    local summary_file="$2"

    # Aggregate totals across all files
    local total_tests total_passed total_failed total_skipped total_duration pass_rate
    total_tests=$(awk -F'|' '{s+=$2} END {print s+0}' "$summary_file")
    total_passed=$(awk -F'|' '{s+=$3} END {print s+0}' "$summary_file")
    total_failed=$(awk -F'|' '{s+=$4} END {print s+0}' "$summary_file")
    total_skipped=$(awk -F'|' '{s+=$5} END {print s+0}' "$summary_file")
    total_duration=$(awk -F'|' '{s+=$6} END {printf "%.2f", s+0}' "$summary_file")

    if [[ "$total_tests" -gt 0 ]]; then
        pass_rate=$(awk -v p="$total_passed" -v t="$total_tests" 'BEGIN {printf "%.1f", (p / t) * 100}')
    else
        pass_rate="0.0"
    fi

    # Totals table
    echo "# Test Results Summary"
    echo ""
    echo "## Totals"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Total Tests | ${total_tests} |"
    echo "| Passed | ${total_passed} |"
    echo "| Failed | ${total_failed} |"
    echo "| Skipped | ${total_skipped} |"
    echo "| Duration | ${total_duration}s |"
    echo "| Pass Rate | ${pass_rate}% |"
    echo ""

    # Per-file breakdown table
    echo "## Files Processed"
    echo ""
    echo "| File | Tests | Passed | Failed | Skipped | Duration |"
    echo "|------|-------|--------|--------|---------|----------|"
    while IFS='|' read -r fname ftests fpassed ffailed fskipped fduration; do
        fduration=$(awk -v d="$fduration" 'BEGIN {printf "%.2f", d + 0}')
        echo "| ${fname} | ${ftests} | ${fpassed} | ${ffailed} | ${fskipped} | ${fduration}s |"
    done < "$summary_file"
    echo ""

    # Flaky tests: same test with both "passed" and "failed" across different runs.
    # We exclude "skipped" from flaky detection (task: "passed in some, failed in others").
    local flaky_output
    flaky_output=$(awk -F'|' '$2 != "skipped" {print $1 "|" $2}' "$results_file" | sort -u | \
        awk -F'|' '{
            count[$1]++
            if (outcomes[$1]) outcomes[$1] = outcomes[$1] ", " $2
            else outcomes[$1] = $2
        } END {
            for (t in count) if (count[t] > 1) print t "|" outcomes[t]
        }' | sort)

    if [[ -n "$flaky_output" ]]; then
        echo "## Flaky Tests"
        echo ""
        echo "| Test | Outcomes |"
        echo "|------|----------|"
        while IFS='|' read -r test_id outcomes; do
            echo "| ${test_id} | ${outcomes} |"
        done <<< "$flaky_output"
        echo ""
    fi

    # List all individually failed test results
    local failed_tests
    failed_tests=$(awk -F'|' '$2 == "failed" {print $1 "|" $4}' "$results_file" | sort)

    if [[ -n "$failed_tests" ]]; then
        echo "## Failed Tests"
        echo ""
        echo "| Test | File |"
        echo "|------|------|"
        while IFS='|' read -r test_id source; do
            echo "| ${test_id} | ${source} |"
        done <<< "$failed_tests"
        echo ""
    fi
}

# Main entry point — validates input and orchestrates parsing + output.
main() {
    local input_dir="${1:-}"

    if [[ -z "$input_dir" ]]; then
        echo "Error: No input directory specified" >&2
        echo "Usage: aggregate-test-results.sh <directory>" >&2
        exit 1
    fi

    if [[ ! -d "$input_dir" ]]; then
        echo "Error: Directory '$input_dir' does not exist" >&2
        exit 1
    fi

    # Temp directory for intermediate pipe-delimited data files (not local so
    # the EXIT trap can access it after main() returns)
    tmpdir=$(mktemp -d)
    trap 'rm -rf "${tmpdir:-}"' EXIT

    # Per-test results: test_id|status|time|source_file
    local results_file="$tmpdir/results.tsv"
    # Per-file summary: file|tests|passed|failed|skipped|duration
    local summary_file="$tmpdir/summary.tsv"
    touch "$results_file" "$summary_file"

    local file_count=0

    # Process JUnit XML files first (alphabetical glob order)
    for f in "$input_dir"/*.xml; do
        [[ -f "$f" ]] || continue
        parse_junit_xml "$f" "$results_file" "$summary_file"
        file_count=$((file_count + 1))
    done

    # Then process JSON files
    for f in "$input_dir"/*.json; do
        [[ -f "$f" ]] || continue
        parse_json "$f" "$results_file" "$summary_file"
        file_count=$((file_count + 1))
    done

    if [[ "$file_count" -eq 0 ]]; then
        echo "Error: No test result files (*.xml, *.json) found in '$input_dir'" >&2
        exit 1
    fi

    generate_markdown "$results_file" "$summary_file"
}

main "$@"
