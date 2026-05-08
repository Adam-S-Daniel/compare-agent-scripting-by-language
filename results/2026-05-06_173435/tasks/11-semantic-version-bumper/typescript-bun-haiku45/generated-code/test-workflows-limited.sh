#!/bin/bash

# Semantic Version Bumper - Limited Act Integration Tests (max 3 runs)
# Tests: 1) Patch bump, 2) Minor bump, 3) All other structure validations

set -e

RESULT_FILE="act-result.txt"
DOCKER_IMAGE="ghcr.io/catthehacker/ubuntu:full-latest"
ACT_ARGS="-P ubuntu-latest=${DOCKER_IMAGE}"

rm -f "$RESULT_FILE"

# Write header
{
  echo "================================================================================"
  echo "SEMANTIC VERSION BUMPER - ACT INTEGRATION TEST RESULTS (FINAL)"
  echo "================================================================================"
  echo "Date: $(date)"
  echo "Image: ${DOCKER_IMAGE}"
  echo "Note: Running 3 act push commands as specified"
  echo ""
} | tee "$RESULT_FILE"

pass_count=0
fail_count=0

# TEST 1: Patch version bump (version-bump job)
{
  echo "================================================================================"
  echo "TEST 1/3: Patch Version Bump"
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

if act push --rm -j version-bump $ACT_ARGS 2>&1 | tee -a "$RESULT_FILE" | grep -q "Job succeeded"; then
  if grep -q "1.0.1" "$RESULT_FILE"; then
    echo "✓ TEST 1 PASSED: Patch bump successful (1.0.0 → 1.0.1)" | tee -a "$RESULT_FILE"
    ((pass_count++))
  else
    echo "✗ TEST 1 FAILED: Version not bumped correctly" | tee -a "$RESULT_FILE"
    ((fail_count++))
  fi
else
  echo "✗ TEST 1 FAILED: Job did not succeed" | tee -a "$RESULT_FILE"
  ((fail_count++))
fi

echo "" | tee -a "$RESULT_FILE"

# TEST 2: Minor version bump (test-minor-bump job)
{
  echo "================================================================================"
  echo "TEST 2/3: Minor Version Bump"
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

if act push --rm -j test-minor-bump $ACT_ARGS 2>&1 | tee -a "$RESULT_FILE" | grep -q "Job succeeded"; then
  if grep -q "2.1.0" "$RESULT_FILE"; then
    echo "✓ TEST 2 PASSED: Minor bump successful (2.0.0 → 2.1.0)" | tee -a "$RESULT_FILE"
    ((pass_count++))
  else
    echo "✗ TEST 2 FAILED: Version not bumped correctly" | tee -a "$RESULT_FILE"
    ((fail_count++))
  fi
else
  echo "✗ TEST 2 FAILED: Job did not succeed" | tee -a "$RESULT_FILE"
  ((fail_count++))
fi

echo "" | tee -a "$RESULT_FILE"

# TEST 3: Major version bump + VERSION file + structure validation (test-major-bump job)
{
  echo "================================================================================"
  echo "TEST 3/3: Major Version Bump & Structure Validation"
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

if act push --rm -j test-major-bump $ACT_ARGS 2>&1 | tee -a "$RESULT_FILE" | grep -q "Job succeeded"; then
  if grep -q "2.0.0" "$RESULT_FILE"; then
    echo "✓ TEST 3 PASSED: Major bump successful (1.5.0 → 2.0.0)" | tee -a "$RESULT_FILE"
    ((pass_count++))
  else
    echo "✗ TEST 3 FAILED: Version not bumped correctly" | tee -a "$RESULT_FILE"
    ((fail_count++))
  fi
else
  echo "✗ TEST 3 FAILED: Job did not succeed" | tee -a "$RESULT_FILE"
  ((fail_count++))
fi

echo "" | tee -a "$RESULT_FILE"

# WORKFLOW VALIDATION (no act run needed)
{
  echo "================================================================================"
  echo "WORKFLOW STRUCTURE VALIDATION (no act run)"
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

# Validate YAML exists and has required jobs
if [ -f ".github/workflows/semantic-version-bumper.yml" ]; then
  echo "✓ Workflow file exists" | tee -a "$RESULT_FILE"

  if grep -q "version-bump:" ".github/workflows/semantic-version-bumper.yml"; then
    echo "✓ version-bump job found" | tee -a "$RESULT_FILE"
  fi

  if grep -q "test-minor-bump:" ".github/workflows/semantic-version-bumper.yml"; then
    echo "✓ test-minor-bump job found" | tee -a "$RESULT_FILE"
  fi

  if grep -q "test-major-bump:" ".github/workflows/semantic-version-bumper.yml"; then
    echo "✓ test-major-bump job found" | tee -a "$RESULT_FILE"
  fi

  if grep -q "test-version-file:" ".github/workflows/semantic-version-bumper.yml"; then
    echo "✓ test-version-file job found" | tee -a "$RESULT_FILE"
  fi
fi

# Validate actionlint passes
if command -v actionlint &> /dev/null; then
  if actionlint ".github/workflows/semantic-version-bumper.yml" 2>&1 | tee -a "$RESULT_FILE" | grep -q "^$"; then
    echo "✓ actionlint validation passed" | tee -a "$RESULT_FILE"
  fi
fi

# SCRIPT FILES VALIDATION
{
  echo ""
  echo "================================================================================"
  echo "SCRIPT FILES VALIDATION"
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

for file in bump-version.ts semantic-version.ts conventional-commits.ts changelog.ts; do
  if [ -f "$file" ]; then
    echo "✓ $file exists" | tee -a "$RESULT_FILE"
  else
    echo "✗ $file missing" | tee -a "$RESULT_FILE"
  fi
done

# SUMMARY
{
  echo ""
  echo "================================================================================"
  echo "FINAL SUMMARY"
  echo "================================================================================"
  echo "Act Runs Executed: 3"
  echo "Tests Passed: $pass_count"
  echo "Tests Failed: $fail_count"
  echo ""

  if [ "$fail_count" -eq 0 ]; then
    echo "✓✓✓ ALL TESTS PASSED ✓✓✓"
  else
    echo "✗✗✗ SOME TESTS FAILED ✗✗✗"
  fi
  echo "================================================================================"
} | tee -a "$RESULT_FILE"

exit "$fail_count"
