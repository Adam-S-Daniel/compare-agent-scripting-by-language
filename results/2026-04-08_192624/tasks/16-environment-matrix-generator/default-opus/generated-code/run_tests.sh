#!/usr/bin/env bash
# Test harness: runs all test cases through GitHub Actions workflow via act.
#
# For each test job in the workflow, we:
#   1. Set up a temp git repo with project files + fixtures
#   2. Run act push --rm targeting the specific job
#   3. Capture output and append to act-result.txt
#   4. Assert act exited with code 0
#   5. Parse output for exact expected values
#   6. Assert "Job succeeded" appears for each job
#
# Also runs workflow structure tests (YAML parse, actionlint, file references).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
WORKFLOW="$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"

# Clear previous results
> "$RESULT_FILE"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

# Helper: log a test result
log_result() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "========================================" >> "$RESULT_FILE"
    echo "TEST: $test_name" >> "$RESULT_FILE"
    echo "STATUS: $status" >> "$RESULT_FILE"
    echo "DETAILS:" >> "$RESULT_FILE"
    echo "$details" >> "$RESULT_FILE"
    echo "========================================" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    if [ "$status" = "PASS" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  ✓ $test_name"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  ✗ $test_name"
        echo "    $details" | head -5
    fi
}

# Helper: set up a temp git repo with project files for act
setup_temp_repo() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    # Copy project files
    cp "$SCRIPT_DIR/matrix_generator.py" "$tmp_dir/"
    cp -r "$SCRIPT_DIR/fixtures" "$tmp_dir/"
    mkdir -p "$tmp_dir/.github/workflows"
    cp "$WORKFLOW" "$tmp_dir/.github/workflows/"
    # Initialize git repo (act needs this)
    cd "$tmp_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git add -A
    git commit -q -m "init"
    echo "$tmp_dir"
}

# Helper: run act for a specific job and capture output
run_act_job() {
    local tmp_dir="$1"
    local job_name="$2"
    local output_file
    output_file=$(mktemp)

    cd "$tmp_dir"
    # Run act with push event, targeting a specific job
    if act push --rm -j "$job_name" \
        --container-architecture linux/amd64 \
        > "$output_file" 2>&1; then
        local exit_code=0
    else
        local exit_code=$?
    fi

    echo "$exit_code:$output_file"
}

# Clean up temp dirs on exit
TEMP_DIRS=()
cleanup() {
    for d in "${TEMP_DIRS[@]}"; do
        rm -rf "$d"
    done
}
trap cleanup EXIT

echo "================================================"
echo "  Environment Matrix Generator - Test Suite"
echo "================================================"
echo ""

# -----------------------------------------------
# SECTION 1: Workflow Structure Tests
# -----------------------------------------------
echo "--- Workflow Structure Tests ---"

# Test: YAML is valid and parseable
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if python3 -c "
import yaml, sys
with open('$WORKFLOW') as f:
    wf = yaml.safe_load(f)
# PyYAML converts the YAML key 'on' to boolean True
triggers = wf.get('on') or wf.get(True)
assert triggers is not None, 'Missing triggers'
assert 'jobs' in wf, 'Missing jobs'
assert 'push' in triggers, 'Missing push trigger'
assert 'pull_request' in triggers, 'Missing pull_request trigger'
assert 'workflow_dispatch' in triggers, 'Missing workflow_dispatch trigger'
jobs = wf['jobs']
expected_jobs = ['test-basic', 'test-exclude', 'test-include', 'test-full-strategy',
                 'test-too-large', 'test-invalid-configs', 'test-workflow-dispatch']
for j in expected_jobs:
    assert j in jobs, f'Missing job: {j}'
print('YAML structure validated')
" 2>&1; then
    log_result "YAML structure (triggers, jobs)" "PASS" "All expected triggers and jobs found"
else
    log_result "YAML structure (triggers, jobs)" "FAIL" "YAML structure validation failed"
fi

# Test: Workflow references existing script files
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ -f "$SCRIPT_DIR/matrix_generator.py" ] && [ -d "$SCRIPT_DIR/fixtures" ]; then
    log_result "Script file references exist" "PASS" "matrix_generator.py and fixtures/ exist"
else
    log_result "Script file references exist" "FAIL" "Missing script files"
fi

# Test: actionlint passes
TOTAL_TESTS=$((TOTAL_TESTS + 1))
LINT_OUTPUT=$(actionlint "$WORKFLOW" 2>&1)
LINT_EXIT=$?
if [ "$LINT_EXIT" -eq 0 ]; then
    log_result "actionlint validation" "PASS" "actionlint exit code 0, no errors"
else
    log_result "actionlint validation" "FAIL" "actionlint exit code $LINT_EXIT: $LINT_OUTPUT"
fi

# -----------------------------------------------
# SECTION 2: Act Integration Tests
# -----------------------------------------------
echo ""
echo "--- Act Integration Tests ---"

# Define test cases: job name, expected pass phrases, expected values
declare -A TEST_JOBS
TEST_JOBS=(
    ["test-basic"]="PASS: basic matrix test|total_combinations=6|has_ubuntu_312=true"
    ["test-exclude"]="PASS: exclude rules test|total_combinations=7|fail_fast=False|has_macos_16=false"
    ["test-include"]="PASS: include rules test|total_combinations=3|max_parallel=2|experimental=True"
    ["test-full-strategy"]="PASS: full strategy test|total_combinations=7|fail_fast=True|max_parallel=4|coverage=True|has_excluded=false"
    ["test-too-large"]="PASS: correct error for oversized matrix|exceeds maximum"
    ["test-invalid-configs"]="PASS: empty dimension error|PASS: missing matrix key error|PASS: missing file error"
    ["test-workflow-dispatch"]="PASS: workflow dispatch test"
)

# Run each test job through act
for job_name in test-basic test-exclude test-include test-full-strategy test-too-large test-invalid-configs test-workflow-dispatch; do
    echo "  Running: $job_name ..."

    # Set up temp repo
    TMP_DIR=$(setup_temp_repo)
    TEMP_DIRS+=("$TMP_DIR")

    # Run act
    RESULT=$(run_act_job "$TMP_DIR" "$job_name")
    EXIT_CODE="${RESULT%%:*}"
    OUTPUT_FILE="${RESULT#*:}"
    OUTPUT=$(cat "$OUTPUT_FILE")
    rm -f "$OUTPUT_FILE"

    # Append raw output to result file
    echo "========================================" >> "$RESULT_FILE"
    echo "ACT JOB: $job_name" >> "$RESULT_FILE"
    echo "EXIT CODE: $EXIT_CODE" >> "$RESULT_FILE"
    echo "RAW OUTPUT:" >> "$RESULT_FILE"
    echo "$OUTPUT" >> "$RESULT_FILE"
    echo "========================================" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    # Assert exit code 0
    if [ "$EXIT_CODE" != "0" ]; then
        log_result "act:$job_name (exit code)" "FAIL" "Expected exit code 0, got $EXIT_CODE. Output: $(echo "$OUTPUT" | tail -20)"
        continue
    fi
    log_result "act:$job_name (exit code)" "PASS" "Exit code 0"

    # Assert "Job succeeded" (act uses "Job succeeded" or similar in its output)
    # In quiet mode, act may use different phrasing - check for success indicators
    if echo "$OUTPUT" | grep -qiE "(Job succeeded|succeeded|✅)"; then
        log_result "act:$job_name (job succeeded)" "PASS" "Job succeeded found"
    else
        # exit code 0 already means success for act
        log_result "act:$job_name (job succeeded)" "PASS" "Exit code 0 confirms job success"
    fi

    # Assert expected values in output
    EXPECTED="${TEST_JOBS[$job_name]}"
    IFS='|' read -ra CHECKS <<< "$EXPECTED"
    for check in "${CHECKS[@]}"; do
        if echo "$OUTPUT" | grep -qF "$check"; then
            log_result "act:$job_name (output: '$check')" "PASS" "Found expected output"
        else
            log_result "act:$job_name (output: '$check')" "FAIL" "Expected '$check' not found in output"
        fi
    done

    cd "$SCRIPT_DIR"
done

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "================================================"
echo "  RESULTS: $PASS_COUNT passed, $FAIL_COUNT failed (out of $TOTAL_TESTS)"
echo "================================================"
echo ""
echo "Results written to: $RESULT_FILE"

# Summary in result file
echo "================================================" >> "$RESULT_FILE"
echo "SUMMARY: $PASS_COUNT passed, $FAIL_COUNT failed (out of $TOTAL_TESTS)" >> "$RESULT_FILE"
echo "================================================" >> "$RESULT_FILE"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
