#!/usr/bin/env bats
# Test suite for test-results-aggregator.sh
# Uses red/green TDD: tests written before implementation

SCRIPT="$BATS_TEST_DIRNAME/../aggregator.sh"
FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

# --- RED: These tests fail until implementation exists ---

@test "aggregator.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "shows usage when no arguments given" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "parses JUnit XML: counts passed tests" {
  run "$SCRIPT" "$FIXTURES/junit-pass.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"passed=3"* ]]
}

@test "parses JUnit XML: counts failed tests" {
  run "$SCRIPT" "$FIXTURES/junit-fail.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"failed=2"* ]]
}

@test "parses JUnit XML: counts skipped tests" {
  run "$SCRIPT" "$FIXTURES/junit-skip.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped=1"* ]]
}

@test "parses JSON test results" {
  run "$SCRIPT" "$FIXTURES/results.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"passed=4"* ]]
}

@test "aggregates multiple files: sums totals" {
  run "$SCRIPT" "$FIXTURES/junit-pass.xml" "$FIXTURES/junit-fail.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"passed=5"* ]]
  [[ "$output" == *"failed=2"* ]]
}

@test "detects flaky tests across runs" {
  run "$SCRIPT" --flaky "$FIXTURES/run1.json" "$FIXTURES/run2.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"flaky"* ]]
  [[ "$output" == *"TestFlaky"* ]]
}

@test "generates markdown summary" {
  run "$SCRIPT" --markdown "$FIXTURES/junit-pass.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Test Results"* ]]
  [[ "$output" == *"| Passed |"* ]]
}

@test "computes total duration" {
  run "$SCRIPT" "$FIXTURES/junit-pass.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"duration="* ]]
}

@test "handles missing file gracefully" {
  run "$SCRIPT" "/nonexistent/file.xml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]]
}

@test "handles unknown file format gracefully" {
  run "$SCRIPT" "$FIXTURES/unknown.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]]
}
