#!/usr/bin/env bats

# Test suite for test-results-aggregator.sh
# Uses red/green TDD: each test fails first, then implementation makes it pass

setup() {
  # Set up test environment
  export TEST_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  export SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
  export FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

  # Source the main script
  source "${SCRIPT_DIR}/test-results-aggregator.sh"
}

# Test 1: Parse a single JUnit XML file
@test "can parse a single JUnit XML file" {
  local xml_file="${FIXTURES_DIR}/build-1-tests.xml"
  local result

  result=$(parse_junit_xml "$xml_file")

  # Check that we got output
  [ -n "$result" ]

  # Check for expected test counts
  echo "$result" | grep -q "passed:3"
  echo "$result" | grep -q "failed:1"
  echo "$result" | grep -q "skipped:1"
}

# Test 2: Parse a JSON test result file
@test "can parse a JSON test result file" {
  local json_file="${FIXTURES_DIR}/build-3-tests.json"
  local result

  result=$(parse_json_tests "$json_file")

  [ -n "$result" ]
  echo "$result" | grep -q "passed:4"
  echo "$result" | grep -q "failed:1"
  echo "$result" | grep -q "skipped:0"
}

# Test 3: Aggregate results from multiple files
@test "can aggregate results from multiple XML files" {
  local result

  result=$(aggregate_test_results "${FIXTURES_DIR}/build-1-tests.xml" "${FIXTURES_DIR}/build-2-tests.xml")

  [ -n "$result" ]
  # build-1: 3 passed, 1 failed, 1 skipped
  # build-2: 3 passed, 2 failed, 0 skipped
  # Total: 6 passed, 3 failed, 1 skipped
  echo "$result" | grep -q "total_passed:6"
  echo "$result" | grep -q "total_failed:3"
  echo "$result" | grep -q "total_skipped:1"
}

# Test 4: Identify flaky tests (passed in one build, failed in another)
@test "can identify flaky tests" {
  local result

  result=$(find_flaky_tests "${FIXTURES_DIR}/build-1-tests.xml" "${FIXTURES_DIR}/build-2-tests.xml")

  [ -n "$result" ]
  # testSubtract passes in build-1 but fails in build-2, and testConcat fails in build-2 but passes in build-1
  echo "$result" | grep -q "testSubtract"
  echo "$result" | grep -q "testConcat"
}

# Test 5: Generate markdown summary
@test "can generate markdown summary" {
  local result

  result=$(generate_markdown_summary "${FIXTURES_DIR}/build-1-tests.xml" "${FIXTURES_DIR}/build-2-tests.xml")

  [ -n "$result" ]
  # Check for markdown headers and sections
  echo "$result" | grep -q "^##"
  echo "$result" | grep -q -i "passed\|failed\|skipped"
}

# Test 6: Handle mixed XML and JSON files
@test "can handle mixed XML and JSON test result files" {
  local result

  result=$(aggregate_test_results "${FIXTURES_DIR}/build-1-tests.xml" "${FIXTURES_DIR}/build-3-tests.json")

  [ -n "$result" ]
  # build-1: 3 passed, 1 failed, 1 skipped
  # build-3: 4 passed, 1 failed, 0 skipped
  # Total: 7 passed, 2 failed, 1 skipped
  echo "$result" | grep -q "total_passed:7"
  echo "$result" | grep -q "total_failed:2"
  echo "$result" | grep -q "total_skipped:1"
}

# Test 7: Error handling for missing files
@test "returns error for missing file" {
  # This test expects the function to fail
  run parse_junit_xml "/nonexistent/file.xml"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q -i "error\|not found"
}

# Test 8: Compute total duration from all test results
@test "can compute total duration across all files" {
  local result

  result=$(aggregate_test_results "${FIXTURES_DIR}/build-1-tests.xml" "${FIXTURES_DIR}/build-2-tests.xml")

  [ -n "$result" ]
  # build-1: 2.5 seconds, build-2: 2.3 seconds
  # Total: 4.8 seconds
  echo "$result" | grep -q "total_duration:4.8"
}
