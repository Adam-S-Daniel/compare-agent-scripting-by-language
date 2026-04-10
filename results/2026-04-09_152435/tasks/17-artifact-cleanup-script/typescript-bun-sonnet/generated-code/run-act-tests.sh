#!/usr/bin/env bash
# Integration test harness: runs the GitHub Actions workflow via act and
# asserts on exact expected values in the output.
#
# Usage: bash run-act-tests.sh
# Output: act-result.txt (required artifact)

set -euo pipefail

OUTPUT_FILE="act-result.txt"

# Clear and start the output file
{
  echo "======================================================"
  echo "  ARTIFACT CLEANUP SCRIPT - ACT INTEGRATION TESTS"
  echo "======================================================"
  echo "Run date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
} > "$OUTPUT_FILE"

echo "Running: act push --rm"
echo "(This executes the GitHub Actions workflow in Docker)"
echo ""

# Run act, capturing all output
if act push --rm --pull=false 2>&1 | tee -a "$OUTPUT_FILE"; then
  ACT_EXIT=0
else
  ACT_EXIT=$?
fi

{
  echo ""
  echo "======================================================"
  echo "  ACT EXIT CODE: $ACT_EXIT"
  echo "======================================================"
  echo ""
} | tee -a "$OUTPUT_FILE"

if [ "$ACT_EXIT" -ne 0 ]; then
  echo "FAIL: act exited with code $ACT_EXIT" | tee -a "$OUTPUT_FILE"
  exit 1
fi

# ---- Assertion helpers ----

PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local pattern="$1"
  local description="$2"
  if grep -qF "$pattern" "$OUTPUT_FILE"; then
    echo "  PASS: $description" | tee -a "$OUTPUT_FILE"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $description" | tee -a "$OUTPUT_FILE"
    echo "        Expected pattern: '$pattern'" | tee -a "$OUTPUT_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

{
  echo "======================================================"
  echo "  ASSERTIONS"
  echo "======================================================"
} | tee -a "$OUTPUT_FILE"

# Job success checks
assert_contains "Job succeeded" "At least one job succeeded"

# Test case 1: Max Age Policy
assert_contains "TEST-1-PASS" "Test 1 (Max Age Policy): deleted=4 retained=2 reclaimed=4718592"

# Test case 2: Max Total Size Policy
assert_contains "TEST-2-PASS" "Test 2 (Max Total Size Policy): deleted=3 retained=3 reclaimed=3670016"

# Test case 3: Keep Latest N Per Workflow
assert_contains "TEST-3-PASS" "Test 3 (Keep Latest N Per Workflow): deleted=1 retained=5 reclaimed=2097152"

{
  echo ""
  echo "======================================================"
  echo "  RESULTS: $PASS_COUNT passed, $FAIL_COUNT failed"
  echo "======================================================"
} | tee -a "$OUTPUT_FILE"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: $FAIL_COUNT assertion(s) failed" | tee -a "$OUTPUT_FILE"
  exit 1
fi

echo "SUCCESS: All integration tests passed!" | tee -a "$OUTPUT_FILE"
