#!/usr/bin/env bash
# run_act_tests.sh
# Test harness: runs each workflow job via act, captures output to act-result.txt,
# asserts on exact expected values, and verifies "Job succeeded" for each.

set -euo pipefail

RESULT_FILE="act-result.txt"
WORKFLOW=".github/workflows/pr-label-assigner.yml"
FAILURES=0

# Clear result file
> "$RESULT_FILE"

run_job() {
    local job_id="$1"
    local job_desc="$2"
    shift 2
    local expected_strings=("$@")

    echo ""
    echo "================================================================"
    echo "TEST: ${job_desc} (job: ${job_id})"
    echo "================================================================"

    {
        echo ""
        echo "================================================================"
        echo "TEST CASE: ${job_desc}"
        echo "Job ID: ${job_id}"
        echo "================================================================"
    } >> "$RESULT_FILE"

    # Run act and capture output
    ACT_OUTPUT=$(act push --rm --job "${job_id}" 2>&1)
    ACT_EXIT=$?

    # Append to result file
    echo "$ACT_OUTPUT" >> "$RESULT_FILE"
    echo "--- End of job output ---" >> "$RESULT_FILE"

    # Assert exit code 0
    if [ "$ACT_EXIT" -ne 0 ]; then
        echo "FAIL: act exited with code ${ACT_EXIT} for job ${job_id}"
        echo "ASSERTION FAIL: act exit code was ${ACT_EXIT} (expected 0)" >> "$RESULT_FILE"
        FAILURES=$((FAILURES + 1))
        return
    fi

    # Assert "Job succeeded"
    if echo "$ACT_OUTPUT" | grep -q "Job succeeded"; then
        echo "PASS: Job succeeded found in output"
        echo "ASSERTION PASS: Job succeeded" >> "$RESULT_FILE"
    else
        echo "FAIL: 'Job succeeded' not found in output for ${job_id}"
        echo "ASSERTION FAIL: 'Job succeeded' not found" >> "$RESULT_FILE"
        FAILURES=$((FAILURES + 1))
    fi

    # Assert each expected string
    for expected in "${expected_strings[@]}"; do
        if echo "$ACT_OUTPUT" | grep -qF "$expected"; then
            echo "PASS: Found expected string: '${expected}'"
            echo "ASSERTION PASS: Found '${expected}'" >> "$RESULT_FILE"
        else
            echo "FAIL: Expected string not found: '${expected}'"
            echo "ASSERTION FAIL: Expected '${expected}' not found in output" >> "$RESULT_FILE"
            FAILURES=$((FAILURES + 1))
        fi
    done
}

# ============================================================
# Workflow structure tests
# ============================================================
echo "================================================================"
echo "WORKFLOW STRUCTURE TESTS"
echo "================================================================"
{
    echo ""
    echo "================================================================"
    echo "WORKFLOW STRUCTURE TESTS"
    echo "================================================================"
} >> "$RESULT_FILE"

# Test 1: actionlint validation
echo "--- actionlint validation ---"
{
    echo ""
    echo "--- actionlint validation ---"
} >> "$RESULT_FILE"

ACTIONLINT_OUT=$(actionlint "$WORKFLOW" 2>&1)
ACTIONLINT_EXIT=$?
echo "$ACTIONLINT_OUT" >> "$RESULT_FILE"
if [ "$ACTIONLINT_EXIT" -eq 0 ]; then
    echo "PASS: actionlint passed with exit code 0"
    echo "ASSERTION PASS: actionlint exit code 0" >> "$RESULT_FILE"
else
    echo "FAIL: actionlint failed"
    echo "ASSERTION FAIL: actionlint exit code ${ACTIONLINT_EXIT}" >> "$RESULT_FILE"
    FAILURES=$((FAILURES + 1))
fi

# Test 2: Check workflow triggers
echo "--- Workflow trigger check ---"
{
    echo ""
    echo "--- Workflow trigger check ---"
} >> "$RESULT_FILE"

for trigger in "push" "pull_request" "workflow_dispatch"; do
    if grep -q "$trigger" "$WORKFLOW"; then
        echo "PASS: trigger '${trigger}' found in workflow"
        echo "ASSERTION PASS: trigger '${trigger}' present" >> "$RESULT_FILE"
    else
        echo "FAIL: trigger '${trigger}' missing from workflow"
        echo "ASSERTION FAIL: trigger '${trigger}' missing" >> "$RESULT_FILE"
        FAILURES=$((FAILURES + 1))
    fi
done

# Test 3: Check script files exist
echo "--- Script file existence check ---"
{
    echo ""
    echo "--- Script file existence check ---"
} >> "$RESULT_FILE"

for f in "label_assigner.py" "test_label_assigner.py" "label-config.json"; do
    if [ -f "$f" ]; then
        echo "PASS: File exists: ${f}"
        echo "ASSERTION PASS: ${f} exists" >> "$RESULT_FILE"
    else
        echo "FAIL: File missing: ${f}"
        echo "ASSERTION FAIL: ${f} missing" >> "$RESULT_FILE"
        FAILURES=$((FAILURES + 1))
    fi
done

# Test 4: Check workflow references correct script files
echo "--- Workflow references script files ---"
{
    echo ""
    echo "--- Workflow references script files ---"
} >> "$RESULT_FILE"

for ref in "label_assigner.py" "label-config.json" "test_label_assigner.py"; do
    if grep -q "$ref" "$WORKFLOW"; then
        echo "PASS: Workflow references '${ref}'"
        echo "ASSERTION PASS: workflow references '${ref}'" >> "$RESULT_FILE"
    else
        echo "FAIL: Workflow does not reference '${ref}'"
        echo "ASSERTION FAIL: workflow missing reference to '${ref}'" >> "$RESULT_FILE"
        FAILURES=$((FAILURES + 1))
    fi
done

# ============================================================
# ACT job tests
# ============================================================

# Test: run-tests job - all 17 tests pass
run_job "run-tests" \
    "Unit tests: all 17 pytest tests pass" \
    "17 passed" \
    "test_single_rule_docs PASSED" \
    "test_mock_pr_fixture PASSED"

# Test: test-fixture-docs-only
run_job "test-fixture-docs-only" \
    "Fixture: docs-only PR gets 'documentation' label" \
    "PASS: documentation label found" \
    "PASS: api label correctly absent"

# Test: test-fixture-api-pr
run_job "test-fixture-api-pr" \
    "Fixture: API PR gets 'api' and 'backend' labels" \
    "PASS: api label found" \
    "PASS: backend label found"

# Test: test-fixture-full-pr
run_job "test-fixture-full-pr" \
    "Fixture: mixed PR gets documentation, api, backend, tests labels" \
    "PASS: documentation label found" \
    "PASS: api label found" \
    "PASS: backend label found" \
    "PASS: tests label found" \
    "PASS: at least 4 labels assigned"

# Test: test-fixture-no-match
run_job "test-fixture-no-match" \
    "Fixture: no-match files get 0 labels" \
    "PASS: no labels for unmatched files"

# ============================================================
# Summary
# ============================================================
echo ""
echo "================================================================"
echo "TEST SUMMARY"
echo "================================================================"
{
    echo ""
    echo "================================================================"
    echo "FINAL SUMMARY"
    echo "================================================================"
} >> "$RESULT_FILE"

if [ "$FAILURES" -eq 0 ]; then
    echo "ALL TESTS PASSED"
    echo "ALL TESTS PASSED" >> "$RESULT_FILE"
    exit 0
else
    echo "FAILURES: ${FAILURES} test assertion(s) failed"
    echo "FAILURES: ${FAILURES} test assertion(s) failed" >> "$RESULT_FILE"
    exit 1
fi
