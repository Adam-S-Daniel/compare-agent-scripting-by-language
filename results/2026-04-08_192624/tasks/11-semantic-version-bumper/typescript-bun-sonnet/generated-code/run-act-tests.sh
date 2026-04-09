#!/usr/bin/env bash
# Test harness: runs all test cases through act and captures results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT_FILE="${SCRIPT_DIR}/act-result.txt"

# Clear previous results
> "${ACT_RESULT_FILE}"

run_act_test() {
  local test_name="$1"
  local job="$2"

  echo "======================================================" | tee -a "${ACT_RESULT_FILE}"
  echo "TEST CASE: ${test_name}" | tee -a "${ACT_RESULT_FILE}"
  echo "JOB: ${job}" | tee -a "${ACT_RESULT_FILE}"
  echo "======================================================" | tee -a "${ACT_RESULT_FILE}"

  local exit_code=0
  act push \
    --job "${job}" \
    --rm \
    --platform ubuntu-latest=catthehacker/ubuntu:act-latest \
    --no-cache-server \
    2>&1 | tee -a "${ACT_RESULT_FILE}" || exit_code=$?

  echo "" | tee -a "${ACT_RESULT_FILE}"
  echo "--- Exit code: ${exit_code} ---" | tee -a "${ACT_RESULT_FILE}"

  if [ "${exit_code}" -ne 0 ]; then
    echo "FAIL: ${test_name} exited with code ${exit_code}" | tee -a "${ACT_RESULT_FILE}"
    return 1
  fi

  # Check for job succeeded in output
  if ! grep -q "Job succeeded" "${ACT_RESULT_FILE}"; then
    echo "FAIL: ${test_name} - 'Job succeeded' not found in output" | tee -a "${ACT_RESULT_FILE}"
    return 1
  fi

  echo "PASS: ${test_name}" | tee -a "${ACT_RESULT_FILE}"
  echo "" | tee -a "${ACT_RESULT_FILE}"
}

cd "${SCRIPT_DIR}"

echo "Starting act test suite..."
echo "Output will be saved to: ${ACT_RESULT_FILE}"
echo ""

overall_exit=0

run_act_test "Unit Tests" "test" || overall_exit=1
run_act_test "Patch Version Bump (1.1.0 -> 1.1.1)" "bump-patch" || overall_exit=1
run_act_test "Minor Version Bump (1.1.0 -> 1.2.0)" "bump-minor" || overall_exit=1
run_act_test "Major Version Bump (1.1.0 -> 2.0.0)" "bump-major" || overall_exit=1
run_act_test "Workflow Structure Check" "workflow-structure-check" || overall_exit=1

echo "======================================================" | tee -a "${ACT_RESULT_FILE}"
echo "ALL TESTS COMPLETE" | tee -a "${ACT_RESULT_FILE}"
echo "Results saved to: ${ACT_RESULT_FILE}" | tee -a "${ACT_RESULT_FILE}"
echo "======================================================" | tee -a "${ACT_RESULT_FILE}"

exit "${overall_exit}"
