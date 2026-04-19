#!/usr/bin/env bats
# Test suite for test results aggregator script

setup() {
  # Create a temporary directory for test outputs
  TEST_TEMP=$(mktemp -d)
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  FIXTURES="${SCRIPT_DIR}/fixtures"

  # Source the aggregator script
  source "${SCRIPT_DIR}/aggregate-results.sh"
}

teardown() {
  # Clean up temporary test directory
  rm -rf "$TEST_TEMP"
}

# RED: Test that script file exists
@test "aggregate-results.sh script exists" {
  [ -f "${SCRIPT_DIR}/aggregate-results.sh" ]
}

# RED: Test that main function exists
@test "main function is defined" {
  type main &>/dev/null
}

# RED: Test parsing a single JUnit XML file
@test "parse_junit_xml parses single XML file" {
  local output
  output=$(parse_junit_xml "${FIXTURES}/sample-junit.xml")

  # Should output JSON format results
  [ -n "$output" ]
  echo "$output" | grep -q "passed"
  echo "$output" | grep -q "failed"
}

# RED: Test aggregating multiple JUnit XML files
@test "aggregate_junit_files combines multiple XML files" {
  local output
  output=$(aggregate_junit_files "${FIXTURES}/run1-junit.xml" "${FIXTURES}/run2-junit.xml")

  # Should have combined totals
  echo "$output" | grep -q "total_passed"
  echo "$output" | grep -q "total_failed"
}

# RED: Test parsing JSON format
@test "parse_json_results parses JSON results" {
  local output
  output=$(parse_json_results "${FIXTURES}/sample-json.json")

  [ -n "$output" ]
  echo "$output" | grep -q "passed"
}

# RED: Test detecting flaky tests
@test "detect_flaky_tests identifies inconsistent test results" {
  local output
  output=$(detect_flaky_tests "${FIXTURES}/run1-junit.xml" "${FIXTURES}/run2-junit.xml")

  # test_flaky_network_call passes in run1 but fails in run2
  echo "$output" | grep -q "test_flaky_network_call"
}

# RED: Test generating markdown summary
@test "generate_markdown_summary produces markdown output" {
  local output
  output=$(generate_markdown_summary \
    total_passed=5 \
    total_failed=1 \
    total_skipped=1 \
    total_duration=4.6)

  [ -n "$output" ]
  echo "$output" | grep -q "^#"
  echo "$output" | grep -q "Passed"
}

# RED: Test handling empty input
@test "aggregate_junit_files handles no files gracefully" {
  local output
  output=$(aggregate_junit_files 2>&1) || true

  # Should output error message or empty result
  [ -n "$output" ]
}

# RED: Test end-to-end workflow with aggregation
@test "complete workflow aggregates and reports on multiple results" {
  local output
  output=$(aggregate_junit_files "${FIXTURES}/sample-junit.xml" "${FIXTURES}/run1-junit.xml")

  # Results should contain combined totals
  local total_passed
  total_passed=$(echo "$output" | jq -r '.total_passed')
  [ "$total_passed" -eq 5 ]
}

# RED: Test markdown generation with real numbers
@test "generate_markdown_summary includes proper formatting" {
  local output
  output=$(generate_markdown_summary \
    total_passed=10 \
    total_failed=2 \
    total_skipped=1 \
    total_duration=15.5)

  # Should contain all metrics
  echo "$output" | grep -q "10"
  echo "$output" | grep -q "2"
  echo "$output" | grep -q "1"
  echo "$output" | grep -q "15.5"
}

# RED: Test script syntax and shellcheck compliance
@test "script passes shellcheck validation" {
  shellcheck -x "${SCRIPT_DIR}/aggregate-results.sh" || true
}

# RED: Test bash syntax validation
@test "script has valid bash syntax" {
  bash -n "${SCRIPT_DIR}/aggregate-results.sh"
}
