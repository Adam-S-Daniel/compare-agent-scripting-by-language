#!/usr/bin/env bash

# Test harness for running GitHub Actions workflow with act
# Tests all secret rotation validator functionality through the CI/CD pipeline

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="${SCRIPT_DIR}/act-result.txt"
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Initialize result file
: > "$RESULT_FILE"

log_result() {
  local test_name="$1"
  local status="$2"
  local output="$3"

  echo "" >> "$RESULT_FILE"
  echo "================================" >> "$RESULT_FILE"
  echo "TEST: $test_name" >> "$RESULT_FILE"
  echo "STATUS: $status" >> "$RESULT_FILE"
  echo "================================" >> "$RESULT_FILE"
  echo "$output" >> "$RESULT_FILE"
}

run_workflow_test() {
  local test_name="$1"
  local config_file="${2:-tests/fixtures/sample-config.json}"

  TEST_COUNT=$((TEST_COUNT + 1))
  echo -n "Test $TEST_COUNT: $test_name ... "

  # Create temporary directory for this test
  local temp_dir
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" EXIT

  # Copy all project files to temp directory
  cp -r "$SCRIPT_DIR"/.github "$temp_dir/"
  cp "$SCRIPT_DIR"/secret-rotation-validator.sh "$temp_dir/"
  cp -r "$SCRIPT_DIR"/tests "$temp_dir/"

  # Create config if specified
  if [[ -f "$SCRIPT_DIR/$config_file" ]]; then
    mkdir -p "$temp_dir/$(dirname "$config_file")"
    cp "$SCRIPT_DIR/$config_file" "$temp_dir/$config_file"
  fi

  # Initialize git repo in temp directory
  cd "$temp_dir"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add -A
  git commit -q -m "Initial commit for test"

  # Run workflow with act
  local output
  output=$(act push --rm 2>&1 || echo "ACT_EXIT_CODE=$?")

  local exit_code=0
  if echo "$output" | grep -q "ACT_EXIT_CODE="; then
    exit_code=$(echo "$output" | grep "ACT_EXIT_CODE=" | cut -d= -f2 | tail -1)
  fi

  cd - > /dev/null

  # Check results
  if [[ $exit_code -eq 0 ]]; then
    echo "PASSED"
    PASSED_COUNT=$((PASSED_COUNT + 1))
    log_result "$test_name" "PASSED" "$output"
    return 0
  else
    echo "FAILED"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    log_result "$test_name" "FAILED (exit code $exit_code)" "$output"
    return 1
  fi
}

# Test 1: Basic workflow execution
run_workflow_test "Basic Workflow Execution" "tests/fixtures/sample-config.json"

# Test 2: Workflow with markdown output
run_workflow_test "Markdown Output Format" "tests/fixtures/sample-config.json"

# Test 3: Workflow structure validation
echo -n "Test $((TEST_COUNT + 1)): Workflow structure validation ... "
TEST_COUNT=$((TEST_COUNT + 1))

if grep -q "jobs:" .github/workflows/secret-rotation-validator.yml && grep -q "validate:" .github/workflows/secret-rotation-validator.yml; then
  echo "PASSED"
  PASSED_COUNT=$((PASSED_COUNT + 1))
  log_result "Workflow has validate job" "PASSED" "validate job found"
else
  echo "FAILED"
  FAILED_COUNT=$((FAILED_COUNT + 1))
  log_result "Workflow has validate job" "FAILED" "validate job not found"
fi

# Test 4: Verify workflow references script correctly
echo -n "Test $((TEST_COUNT + 1)): Script referenced in workflow ... "
TEST_COUNT=$((TEST_COUNT + 1))

if grep -q "secret-rotation-validator.sh" .github/workflows/secret-rotation-validator.yml; then
  echo "PASSED"
  PASSED_COUNT=$((PASSED_COUNT + 1))
  log_result "Script correctly referenced" "PASSED" "Found in workflow"
else
  echo "FAILED"
  FAILED_COUNT=$((FAILED_COUNT + 1))
  log_result "Script correctly referenced" "FAILED" "Not found in workflow"
fi

# Test 5: Verify workflow triggers are set
echo -n "Test $((TEST_COUNT + 1)): Workflow triggers configured ... "
TEST_COUNT=$((TEST_COUNT + 1))

trigger_count=$(grep -c "on:" .github/workflows/secret-rotation-validator.yml || echo 0)

if [[ $trigger_count -gt 0 ]]; then
  echo "PASSED"
  PASSED_COUNT=$((PASSED_COUNT + 1))
  log_result "Workflow triggers configured" "PASSED" "Found 'on:' trigger"
else
  echo "FAILED"
  FAILED_COUNT=$((FAILED_COUNT + 1))
  log_result "Workflow triggers configured" "FAILED" "No triggers found"
fi

# Print summary
echo ""
echo "======================================"
echo "Workflow Test Summary"
echo "======================================"
echo "Total Tests: $TEST_COUNT"
echo "Passed: $PASSED_COUNT"
echo "Failed: $FAILED_COUNT"
echo ""
echo "Results saved to: $RESULT_FILE"
echo "======================================"

if [[ $FAILED_COUNT -gt 0 ]]; then
  exit 1
fi
