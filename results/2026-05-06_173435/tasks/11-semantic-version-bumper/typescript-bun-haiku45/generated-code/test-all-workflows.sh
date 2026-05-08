#!/bin/bash

# Semantic Version Bumper - Comprehensive Act Integration Tests
# This script runs all test cases through the GitHub Actions workflow

RESULT_FILE="act-result.txt"
DOCKER_IMAGE="ghcr.io/catthehacker/ubuntu:full-latest"
ACT_ARGS="-P ubuntu-latest=${DOCKER_IMAGE}"

# Clean up previous results
rm -f "$RESULT_FILE"

# Write header
{
  echo "================================================================================"
  echo "SEMANTIC VERSION BUMPER - ACT INTEGRATION TEST RESULTS"
  echo "================================================================================"
  echo "Date: $(date)"
  echo "Docker Image: ${DOCKER_IMAGE}"
  echo ""
} | tee "$RESULT_FILE"

# Function to run a test job and capture results
run_test_job() {
  local job_name="$1"
  local description="$2"

  echo "================================================================================" | tee -a "$RESULT_FILE"
  echo "TEST: $description" | tee -a "$RESULT_FILE"
  echo "Job: $job_name" | tee -a "$RESULT_FILE"
  echo "================================================================================" | tee -a "$RESULT_FILE"

  # Run the workflow job
  if act push --rm -j "$job_name" $ACT_ARGS 2>&1 | tee -a "$RESULT_FILE" | grep -q "🏁  Job failed"; then
    echo "✗ JOB FAILED: $job_name" | tee -a "$RESULT_FILE"
    return 1
  else
    echo "✓ JOB PASSED: $job_name" | tee -a "$RESULT_FILE"
    return 0
  fi
}

# Run all test jobs
echo "" | tee -a "$RESULT_FILE"
echo "Running workflow test jobs..." | tee -a "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Patch bump
if run_test_job "version-bump" "Patch Version Bump"; then
  ((PASS_COUNT++))
else
  ((FAIL_COUNT++))
fi

echo "" | tee -a "$RESULT_FILE"

# Test 2: Minor bump
if run_test_job "test-minor-bump" "Minor Version Bump"; then
  ((PASS_COUNT++))
else
  ((FAIL_COUNT++))
fi

echo "" | tee -a "$RESULT_FILE"

# Test 3: Major bump
if run_test_job "test-major-bump" "Major Version Bump"; then
  ((PASS_COUNT++))
else
  ((FAIL_COUNT++))
fi

echo "" | tee -a "$RESULT_FILE"

# Test 4: VERSION file
if run_test_job "test-version-file" "VERSION File Handling"; then
  ((PASS_COUNT++))
else
  ((FAIL_COUNT++))
fi

echo "" | tee -a "$RESULT_FILE"

# Test 5: Workflow structure validation
if run_test_job "test-workflow-structure" "Workflow Structure Validation"; then
  ((PASS_COUNT++))
else
  ((FAIL_COUNT++))
fi

# Summary
{
  echo ""
  echo "================================================================================"
  echo "TEST SUMMARY"
  echo "================================================================================"
  echo "Total Tests: 5"
  echo "Passed: $PASS_COUNT"
  echo "Failed: $FAIL_COUNT"
  echo ""

  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "✓ ALL TESTS PASSED"
  else
    echo "✗ SOME TESTS FAILED"
  fi
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

echo ""
echo "Results written to: $RESULT_FILE"
echo ""

exit "$FAIL_COUNT"
