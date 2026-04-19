#!/usr/bin/env bash
# Test harness for running the workflow through act
# Tests various input combinations and validates output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="act-result.txt"
TEMP_WORKSPACE=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_WORKSPACE"
}

trap cleanup EXIT

# Initialize act result file
> "$ACT_RESULT_FILE"

log_test() {
  local test_name="$1"
  local status="$2"
  echo "=== TEST: $test_name ($status) ===" >> "$ACT_RESULT_FILE"
}

run_act_test() {
  local test_name="$1"
  local test_case="$2"

  log_test "$test_name" "START"

  # Create a temporary workspace
  local test_dir="$TEMP_WORKSPACE/test-$test_case"
  mkdir -p "$test_dir/.github/workflows"

  # Copy project files to test workspace
  cp -r "$SCRIPT_DIR"/{aggregate-results.sh,fixtures,tests} "$test_dir/" || true
  cp "$SCRIPT_DIR/.github/workflows/test-results-aggregator.yml" "$test_dir/.github/workflows/"

  # Initialize git repo in test workspace
  cd "$test_dir"
  git init > /dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add . > /dev/null 2>&1
  git commit -m "Initial commit" > /dev/null 2>&1

  # Run act for push event (default)
  local act_output
  act_output=$(act push --rm 2>&1) || {
    log_test "$test_name" "FAILED - act exited with error"
    echo "$act_output" >> "$ACT_RESULT_FILE"
    echo "" >> "$ACT_RESULT_FILE"
    return 1
  }

  # Log the output
  echo "$act_output" >> "$ACT_RESULT_FILE"
  echo "" >> "$ACT_RESULT_FILE"

  # Validate output
  if echo "$act_output" | grep -q "Job succeeded"; then
    log_test "$test_name" "PASSED"
    return 0
  else
    log_test "$test_name" "FAILED - Job did not succeed"
    return 1
  fi
}

# Test case 1: Basic workflow with fixtures
echo "Running workflow tests through act..."
echo ""
echo "Test Case 1: Basic Aggregation Workflow"
run_act_test "basic_aggregation" "case1" || true

echo ""
echo "✓ Workflow tests complete"
echo "✓ Results saved to $ACT_RESULT_FILE"

# Validate that act-result.txt was created
if [ ! -f "$ACT_RESULT_FILE" ]; then
  echo "✗ ERROR: $ACT_RESULT_FILE was not created"
  exit 1
fi

# Count passed tests
passed_count=$(grep -c "PASSED" "$ACT_RESULT_FILE" || echo 0)
failed_count=$(grep -c "FAILED" "$ACT_RESULT_FILE" || echo 0)

echo ""
echo "Summary:"
echo "  Passed: $passed_count"
echo "  Failed: $failed_count"

if [ "$failed_count" -gt 0 ]; then
  echo ""
  echo "Failed test output:"
  grep -A 20 "FAILED" "$ACT_RESULT_FILE" | head -40
  exit 1
fi

exit 0
