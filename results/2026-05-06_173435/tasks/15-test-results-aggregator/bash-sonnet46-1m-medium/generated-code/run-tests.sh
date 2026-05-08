#!/usr/bin/env bash
# run-tests.sh
# External test harness: sets up isolated git repos and runs the workflow
# through act for each test case. Appends all output to act-result.txt.
#
# Usage: bash run-tests.sh
# Requires: act, docker, git
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="${SCRIPT_DIR}/act-result.txt"

# Initialize (truncate) the result file
: > "$ACT_RESULT"

log() {
    echo "$*" | tee -a "$ACT_RESULT"
}

# Assert a fixed string is present in act-result.txt; fail with message if not
assert_contains() {
    local expected="$1"
    if grep -qF "$expected" "$ACT_RESULT"; then
        echo "ASSERT PASS: '${expected}'"
    else
        echo "ASSERT FAIL: expected to find '${expected}' in act output" >&2
        exit 1
    fi
}

# Set up a fresh git repo in a temp dir, copy project files, run act, capture output
run_act_test() {
    local test_name="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    log ""
    log "========================================"
    log "TEST CASE: ${test_name}"
    log "========================================"

    # Copy all project files (including hidden files like .actrc and .github/)
    cp -r "${SCRIPT_DIR}/." "${tmpdir}/"

    cd "$tmpdir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test Runner"
    git add -A
    git commit -q -m "test: ${test_name}"

    local act_exit=0
    act push --rm 2>&1 | tee -a "$ACT_RESULT" || act_exit=$?

    cd "$SCRIPT_DIR"
    rm -rf "$tmpdir"

    if [[ $act_exit -ne 0 ]]; then
        log ""
        log "FAIL: act exited with code ${act_exit} for test case: ${test_name}"
        exit 1
    fi

    log "ACT EXIT CODE: 0"
}

# ---------------------------------------------------------------------------
# Test Case 1: Basic aggregation - verifies totals and flaky detection
# ---------------------------------------------------------------------------
run_act_test "basic-aggregation"

# ---------------------------------------------------------------------------
# Assertions on the captured act output
# ---------------------------------------------------------------------------
log ""
log "=== ASSERTIONS ==="

# Aggregation counts from all 3 fixture files
assert_contains "| Files Processed | 3 |"
assert_contains "| Total Tests | 11 |"
assert_contains "| Passed | 6 |"
assert_contains "| Failed | 3 |"
assert_contains "| Skipped | 2 |"

# Flaky tests detected across ubuntu/windows matrix runs
assert_contains "test.core.TestB"
assert_contains "test.core.TestC"

# Workflow completed successfully
assert_contains "Job succeeded"

log ""
log "All assertions passed!"
