#!/usr/bin/env bash
# Aggregates test results from JUnit XML and JSON files across multiple runs.
# Computes totals, detects flaky tests, and generates a markdown summary.
set -euo pipefail

OUTPUT_FILE="${OUTPUT_FILE:-test-results-summary.md}"

# Associative arrays to track per-test outcomes across runs
declare -A TEST_OUTCOMES  # "test_name" -> "pass,fail,pass"
declare -A TEST_SUITES    # "test_name" -> "SuiteName"

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
TOTAL_DURATION="0"

usage() {
  echo "Usage: $0 <run_dir1> [run_dir2] [run_dir3] ..."
  echo "Each run directory should contain junit.xml and/or results.json files."
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

add_duration() {
  TOTAL_DURATION=$(awk "BEGIN {printf \"%.3f\", $TOTAL_DURATION + $1}")
}

record_outcome() {
  local test_name="$1"
  local suite_name="$2"
  local outcome="$3"

  TEST_SUITES["$test_name"]="$suite_name"
  if [[ -n "${TEST_OUTCOMES[$test_name]:-}" ]]; then
    TEST_OUTCOMES["$test_name"]="${TEST_OUTCOMES[$test_name]},$outcome"
  else
    TEST_OUTCOMES["$test_name"]="$outcome"
  fi
}

# Parse JUnit XML using Python's xml.etree (universally available)
parse_junit_xml() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "WARNING: JUnit XML file not found: $file" >&2
    return 0
  fi

  local parse_output
  if ! parse_output=$(python3 -c "
import xml.etree.ElementTree as ET, sys
tree = ET.parse('$file')
root = tree.getroot()
total_time = root.get('time', '0')
print('TIME:' + total_time)
for tc in root.iter('testcase'):
    cn = tc.get('classname', '')
    name = tc.get('name', '')
    t = tc.get('time', '0')
    if tc.find('failure') is not None:
        status = 'failed'
    elif tc.find('skipped') is not None:
        status = 'skipped'
    else:
        status = 'passed'
    print(f'TC:{cn}|{name}|{t}|{status}')
" 2>&1); then
    echo "ERROR: Failed to parse XML file: $file" >&2
    echo "$parse_output" >&2
    return 1
  fi

  while IFS= read -r line; do
    if [[ "$line" == TIME:* ]]; then
      add_duration "${line#TIME:}"
    elif [[ "$line" == TC:* ]]; then
      local data="${line#TC:}"
      IFS='|' read -r classname name _time status <<< "$data"
      case "$status" in
        passed)  ((TOTAL_PASSED++)) || true ;;
        failed)  ((TOTAL_FAILED++)) || true ;;
        skipped) ((TOTAL_SKIPPED++)) || true ;;
      esac
      record_outcome "$name" "$classname" "$status"
    fi
  done <<< "$parse_output"
}

# Parse a JSON test results file using jq
parse_json_results() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "WARNING: JSON results file not found: $file" >&2
    return 0
  fi

  if ! jq empty "$file" 2>/dev/null; then
    echo "ERROR: Invalid JSON file: $file" >&2
    return 1
  fi

  local entries
  entries=$(jq -r '.testSuites[] | .name as $suite | .tests[] |
    "\($suite)|\(.name)|\(.status)|\(.duration)"' "$file" 2>/dev/null || echo "")

  while IFS='|' read -r suite name status duration; do
    [[ -z "$name" ]] && continue
    case "$status" in
      passed)  ((TOTAL_PASSED++)) || true ;;
      failed)  ((TOTAL_FAILED++)) || true ;;
      skipped) ((TOTAL_SKIPPED++)) || true ;;
    esac
    add_duration "${duration:-0}"
    record_outcome "$name" "$suite" "$status"
  done <<< "$entries"
}

detect_flaky_tests() {
  local flaky_tests=()
  for test_name in "${!TEST_OUTCOMES[@]}"; do
    local outcomes="${TEST_OUTCOMES[$test_name]}"
    local has_pass=false
    local has_fail=false
    IFS=',' read -ra parts <<< "$outcomes"
    for part in "${parts[@]}"; do
      case "$part" in
        passed) has_pass=true ;;
        failed) has_fail=true ;;
      esac
    done
    if $has_pass && $has_fail; then
      flaky_tests+=("$test_name")
    fi
  done

  local sorted=()
  if [[ ${#flaky_tests[@]} -gt 0 ]]; then
    mapfile -t sorted < <(printf '%s\n' "${flaky_tests[@]}" | sort)
  fi

  echo "${sorted[@]:-}"
}

generate_markdown() {
  local total=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_SKIPPED))
  local flaky_list
  flaky_list=$(detect_flaky_tests)

  local flaky_count=0
  if [[ -n "$flaky_list" ]]; then
    flaky_count=$(echo "$flaky_list" | wc -w)
  fi

  {
    echo "# Test Results Summary"
    echo ""
    echo "## Totals"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Total Tests | $total |"
    echo "| Passed | $TOTAL_PASSED |"
    echo "| Failed | $TOTAL_FAILED |"
    echo "| Skipped | $TOTAL_SKIPPED |"
    echo "| Duration | ${TOTAL_DURATION}s |"
    echo "| Flaky Tests | $flaky_count |"
    echo ""

    if [[ $TOTAL_FAILED -gt 0 ]]; then
      echo "## Failed Tests"
      echo ""
      for test_name in $(echo "${!TEST_OUTCOMES[@]}" | tr ' ' '\n' | sort); do
        local outcomes="${TEST_OUTCOMES[$test_name]}"
        if [[ "$outcomes" == *"failed"* ]]; then
          local suite="${TEST_SUITES[$test_name]}"
          if [[ "$flaky_list" != *"$test_name"* ]]; then
            echo "- **${suite}::${test_name}** — failed in all runs"
          fi
        fi
      done
      echo ""
    fi

    if [[ $flaky_count -gt 0 ]]; then
      echo "## Flaky Tests"
      echo ""
      echo "These tests produced inconsistent results across runs:"
      echo ""
      for test_name in $flaky_list; do
        local suite="${TEST_SUITES[$test_name]}"
        local outcomes="${TEST_OUTCOMES[$test_name]}"
        echo "- **${suite}::${test_name}** — outcomes: ${outcomes}"
      done
      echo ""
    fi

    echo "## Per-Test Results"
    echo ""
    echo "| Test | Suite | Outcomes |"
    echo "|------|-------|----------|"
    for test_name in $(echo "${!TEST_OUTCOMES[@]}" | tr ' ' '\n' | sort); do
      local suite="${TEST_SUITES[$test_name]}"
      local outcomes="${TEST_OUTCOMES[$test_name]}"
      echo "| ${test_name} | ${suite} | ${outcomes} |"
    done
  } > "$OUTPUT_FILE"

  echo "Summary written to $OUTPUT_FILE"
}

for run_dir in "$@"; do
  if [[ ! -d "$run_dir" ]]; then
    echo "ERROR: Run directory does not exist: $run_dir" >&2
    exit 1
  fi

  echo "Processing: $run_dir"

  for xml_file in "$run_dir"/*.xml; do
    [[ -f "$xml_file" ]] && parse_junit_xml "$xml_file"
  done

  for json_file in "$run_dir"/*.json; do
    [[ -f "$json_file" ]] && parse_json_results "$json_file"
  done
done

generate_markdown

total=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_SKIPPED))
echo "TOTAL_TESTS=$total"
echo "TOTAL_PASSED=$TOTAL_PASSED"
echo "TOTAL_FAILED=$TOTAL_FAILED"
echo "TOTAL_SKIPPED=$TOTAL_SKIPPED"
echo "TOTAL_DURATION=${TOTAL_DURATION}s"

flaky_list=$(detect_flaky_tests)
if [[ -n "$flaky_list" ]]; then
  echo "FLAKY_TESTS=$flaky_list"
fi
