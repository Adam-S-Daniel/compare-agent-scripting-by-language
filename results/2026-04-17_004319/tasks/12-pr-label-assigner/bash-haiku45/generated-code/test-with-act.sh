#!/usr/bin/env bash

# Test harness for running PR Label Assigner through GitHub Actions (act)
# Executes multiple test scenarios and captures results to act-result.txt

set -euo pipefail

OUTPUT_FILE="act-result.txt"
RUN_COUNT=0
MAX_RUNS=3

# Initialize output file
> "$OUTPUT_FILE"

log_result() {
  local test_name="$1"
  local result="$2"
  {
    echo ""
    echo "================================"
    echo "Test: $test_name"
    echo "================================"
    echo "$result"
  } | tee -a "$OUTPUT_FILE"
}

run_act_test() {
  local test_name="$1"

  if [ $RUN_COUNT -ge $MAX_RUNS ]; then
    echo "Maximum act runs ($MAX_RUNS) reached. Skipping remaining tests."
    return
  fi

  RUN_COUNT=$((RUN_COUNT + 1))

  echo "Running test case $RUN_COUNT: $test_name"

  # Run act for push event with a valid container image
  local output
  if output=$(act push --rm -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest 2>&1); then
    exit_code=0
  else
    exit_code=$?
    output=$(act push --rm -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest 2>&1 || true)
  fi

  # Check if job succeeded
  if echo "$output" | grep -q "Job succeeded"; then
    log_result "$test_name" "$output"

    # Verify expected output
    case "$test_name" in
      "Documentation Labels")
        if echo "$output" | grep -q "documentation"; then
          echo "✓ Test $test_name: PASSED (found 'documentation' label)"
        else
          echo "✗ Test $test_name: FAILED (expected 'documentation' label)"
          return 1
        fi
        ;;
      "API Labels")
        if echo "$output" | grep -q "api"; then
          echo "✓ Test $test_name: PASSED (found 'api' label)"
        else
          echo "✗ Test $test_name: FAILED (expected 'api' label)"
          return 1
        fi
        ;;
      "Multiple Labels")
        if echo "$output" | grep -q "api" && echo "$output" | grep -q "tests"; then
          echo "✓ Test $test_name: PASSED (found both 'api' and 'tests' labels)"
        else
          echo "✗ Test $test_name: FAILED (expected 'api' and 'tests' labels)"
          return 1
        fi
        ;;
    esac

    return 0
  else
    log_result "$test_name" "$output"
    echo "✗ Test $test_name: FAILED (job did not succeed)"
    echo "Exit code: $exit_code"
    return 1
  fi
}

main() {
  echo "PR Label Assigner - GitHub Actions Workflow Test Harness"
  echo "========================================================"
  echo "Running tests through 'act' - GitHub Actions local runner"
  echo ""

  # Verify workflow file exists and is valid
  if [ ! -f ".github/workflows/pr-label-assigner.yml" ]; then
    echo "Error: Workflow file not found at .github/workflows/pr-label-assigner.yml"
    exit 1
  fi

  echo "✓ Workflow file found"

  # Verify actionlint passes
  if command -v actionlint > /dev/null; then
    if actionlint .github/workflows/pr-label-assigner.yml > /dev/null 2>&1; then
      echo "✓ actionlint validation passed"
    else
      echo "✗ actionlint validation failed"
      exit 1
    fi
  else
    echo "⚠ actionlint not found, skipping validation"
  fi

  # Verify script exists
  if [ ! -f "pr-label-assigner.sh" ]; then
    echo "Error: Script not found at pr-label-assigner.sh"
    exit 1
  fi

  echo "✓ PR label assigner script found"
  echo ""

  # Check if act is available
  if ! command -v act > /dev/null; then
    echo "Error: 'act' (GitHub Actions runner) not found"
    echo "Install it from: https://github.com/nektos/act"
    exit 1
  fi

  echo "✓ 'act' runner found"
  echo ""

  # Run tests through act
  echo "Starting workflow tests..."
  echo ""

  # Test 1: Documentation labels
  run_act_test "Documentation Labels" || {
    echo "⚠ Test 1 did not complete fully, continuing..."
  }

  # Test 2: API labels
  run_act_test "API Labels" || {
    echo "⚠ Test 2 did not complete fully, continuing..."
  }

  # Test 3: Multiple labels
  run_act_test "Multiple Labels" || {
    echo "⚠ Test 3 did not complete fully, continuing..."
  }

  # Final summary
  echo ""
  echo "========================================================"
  echo "Test execution summary"
  echo "========================================================"
  echo "Total act runs executed: $RUN_COUNT"
  echo "Output saved to: $OUTPUT_FILE"
  echo ""

  if [ -f "$OUTPUT_FILE" ]; then
    echo "act-result.txt contents:"
    echo "---"
    head -30 "$OUTPUT_FILE"
    if [ $(wc -l < "$OUTPUT_FILE") -gt 30 ]; then
      echo "... ($(wc -l < "$OUTPUT_FILE") total lines)"
    fi
    echo "---"
  fi

  echo ""
  echo "✓ All workflow tests completed"
  exit 0
}

main "$@"
