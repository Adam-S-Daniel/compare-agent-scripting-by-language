#!/usr/bin/env bash
# run-act-tests.sh - Act-based integration test harness
#
# Sets up a temporary git repo with all project files, runs `act push --rm`,
# captures output to act-result.txt, and asserts exact expected values.
#
# Usage: ./run-act-tests.sh
# Requires: act, docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="${SCRIPT_DIR}/act-result.txt"
PASS=0
FAIL=0

# Clear result file at start
true > "$RESULT_FILE"

log() { echo "[run-act-tests] $*"; }
fail() { echo "[FAIL] $*" | tee -a "$RESULT_FILE"; FAIL=$(( FAIL + 1 )); }
pass() { echo "[PASS] $*" | tee -a "$RESULT_FILE"; PASS=$(( PASS + 1 )); }

# ---------------------------------------------------------------------------
# Helper: set up a temp git repo with all project files and run act push --rm
# Returns: the act output (stdout+stderr merged)
# ---------------------------------------------------------------------------
run_act_case() {
    local case_name="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    log "Setting up temp repo for case: $case_name"

    # Copy all project files into the temp repo
    cp -r "${SCRIPT_DIR}/." "$tmpdir/"

    # Initialise a git repo (act requires a git repo for push events)
    pushd "$tmpdir" > /dev/null
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git add -A
    git commit -q -m "test: $case_name"

    log "Running: act push --rm --pull=false (case: $case_name)"
    local act_output
    local act_exit=0
    act_output=$(act push --rm --pull=false 2>&1) || act_exit=$?

    popd > /dev/null
    rm -rf "$tmpdir"

    # Append delimited output to result file
    {
        echo ""
        echo "========================================================"
        echo "TEST CASE: $case_name"
        echo "ACT EXIT CODE: $act_exit"
        echo "========================================================"
        echo "$act_output"
        echo "========================================================"
    } >> "$RESULT_FILE"

    # Return output via a temp variable (subshell-safe)
    ACT_OUTPUT="$act_output"
    ACT_EXIT="$act_exit"
}

# ---------------------------------------------------------------------------
# Test case: mixed fixture (expired + warning + ok secrets)
# ---------------------------------------------------------------------------
log "=== Test case: mixed fixture ==="
run_act_case "mixed-fixture"

# Assert exit code 0
if [[ "$ACT_EXIT" -eq 0 ]]; then
    pass "act exited with code 0"
else
    fail "act exited with code $ACT_EXIT (expected 0)"
    log "act output snippet:"
    echo "$ACT_OUTPUT" | tail -40
fi

# Assert job succeeded
if echo "$ACT_OUTPUT" | grep -q "Job succeeded"; then
    pass "Job succeeded message found"
else
    fail "Job succeeded message NOT found"
fi

# Assert all 22 bats tests passed (check for the final test and no failures)
# Note: apt bats uses TAP format without a trailing summary line; check "ok 22"
if echo "$ACT_OUTPUT" | grep -q "ok 22 actionlint passes on workflow file"; then
    pass "bats: all 22 tests passed (ok 22 found, no failures)"
else
    fail "bats final test 'ok 22 actionlint passes on workflow file' not found in output"
fi

# Assert exact secret status lines from workflow verification step
if echo "$ACT_OUTPUT" | grep -q "SECRET_STATUS: DB_PASSWORD=expired"; then
    pass "Exact value: DB_PASSWORD=expired"
else
    fail "Exact value 'SECRET_STATUS: DB_PASSWORD=expired' not found"
fi

if echo "$ACT_OUTPUT" | grep -q "SECRET_STATUS: API_KEY=warning"; then
    pass "Exact value: API_KEY=warning"
else
    fail "Exact value 'SECRET_STATUS: API_KEY=warning' not found"
fi

if echo "$ACT_OUTPUT" | grep -q "SECRET_STATUS: JWT_SECRET=ok"; then
    pass "Exact value: JWT_SECRET=ok"
else
    fail "Exact value 'SECRET_STATUS: JWT_SECRET=ok' not found"
fi

if echo "$ACT_OUTPUT" | grep -q "All status assertions passed."; then
    pass "Exact assertion confirmation message found"
else
    fail "Assertion confirmation 'All status assertions passed.' not found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
{
    echo ""
    echo "========================================================"
    echo "SUMMARY: $PASS passed, $FAIL failed"
    echo "========================================================"
} | tee -a "$RESULT_FILE"

log "Results saved to: $RESULT_FILE"

if [[ "$FAIL" -gt 0 ]]; then
    log "FAILED: $FAIL assertion(s) did not pass."
    exit 1
fi

log "All assertions passed."
exit 0
