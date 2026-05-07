#!/usr/bin/env bash

# Test harness to run all test cases through GitHub Actions via act
# This ensures all tests execute in an isolated Docker container

set -uo pipefail

OUTPUT_FILE="act-result.txt"
WORKFLOW_FILE=".github/workflows/artifact-cleanup-script.yml"
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Initialize output file
: > "$OUTPUT_FILE"

log_result() {
  local test_name="$1"
  local status="$2"
  local details="$3"

  echo "=====================================================================" >> "$OUTPUT_FILE"
  echo "TEST: $test_name" >> "$OUTPUT_FILE"
  echo "STATUS: $status" >> "$OUTPUT_FILE"
  echo "=====================================================================" >> "$OUTPUT_FILE"
  echo "$details" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  (( TEST_COUNT++ ))
  if [[ "$status" == "PASSED" ]]; then
    (( PASSED_COUNT++ ))
  else
    (( FAILED_COUNT++ ))
  fi
}

run_act_test() {
  local test_name="$1"

  echo "Running test via act: $test_name..."

  # Run the workflow through act
  local act_output
  act_output=$(act push \
    --rm \
    --job test \
    -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest \
    2>&1)

  local exit_code=$?

  # Check if the workflow succeeded
  if [[ $exit_code -eq 0 ]] && echo "$act_output" | grep -q "Job succeeded"; then
    log_result "$test_name" "PASSED" "$act_output"
    echo "✓ $test_name PASSED"
  else
    log_result "$test_name" "FAILED" "$act_output"
    echo "✗ $test_name FAILED (exit code: $exit_code)"
    return 1
  fi
}

main() {
  echo "Artifact Cleanup Script - Act Test Harness"
  echo "=========================================="
  echo ""

  # Verify required tools are available
  if ! command -v act &> /dev/null; then
    echo "Error: 'act' is not installed" >&2
    exit 1
  fi

  if ! command -v actionlint &> /dev/null; then
    echo "Error: 'actionlint' is not installed" >&2
    exit 1
  fi

  # Validate workflow with actionlint
  echo "Validating workflow with actionlint..."
  if ! actionlint "$WORKFLOW_FILE"; then
    echo "Error: Workflow validation failed" >&2
    exit 1
  fi
  echo "✓ Workflow is valid"
  echo ""

  # Run all test cases through act
  echo "Running tests through act..."
  echo ""

  run_act_test "Complete Workflow Test (all jobs)"

  # Print summary
  echo ""
  echo "=========================================="
  echo "Test Summary"
  echo "=========================================="
  echo "Total tests: $TEST_COUNT"
  echo "Passed: $PASSED_COUNT"
  echo "Failed: $FAILED_COUNT"
  echo ""
  echo "Results written to: $OUTPUT_FILE"
  echo ""

  if [[ $FAILED_COUNT -gt 0 ]]; then
    echo "Some tests failed. See $OUTPUT_FILE for details."
    exit 1
  else
    echo "All tests passed!"
    exit 0
  fi
}

main "$@"
