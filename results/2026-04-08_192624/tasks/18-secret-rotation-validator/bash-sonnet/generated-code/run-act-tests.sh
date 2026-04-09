#!/usr/bin/env bash
# run-act-tests.sh
# Test harness that runs all test cases through GitHub Actions via `act`.
#
# Approach:
#   1. For each test case: set up a temp git repo with project files + that case's fixture
#   2. Run `act push --rm` and capture output
#   3. Assert exit code 0 and parse output for expected values
#   4. Append all output to act-result.txt
#
# Test case fixtures:
#   - Case 1: Standard fixture (secrets.csv with mixed expired/warning/ok secrets)
#   - Case 2: Fresh fixture (all secrets recently rotated → all ok)
#   - Case 3: Near-expiry fixture (secrets expiring in ~3 and ~10 days → all in warning)
#   - Case 4: Markdown-focused (standard fixture, verify markdown section headers)
#
# Key design:
#   - bats tests always use fixtures/secrets.csv (standard fixture) with --reference-date
#   - Custom fixtures go to fixtures/secrets-custom.csv; workflow overrides SECRETS_CONFIG
#     via .env file so bats tests are unaffected

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
pass() { log "PASS: $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { log "FAIL: $*"; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

append_delimiter() {
    local label="$1"
    printf '\n%s\n%s\n%s\n' \
        "════════════════════════════════════════════════════════════════" \
        "  TEST CASE: $label" \
        "════════════════════════════════════════════════════════════════" \
        >> "$ACT_RESULT_FILE"
}

# Assert that a fixed string appears in the act output
assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        pass "$label: output contains '$needle'"
    else
        fail "$label: expected output to contain '$needle' (not found)"
    fi
}

# Assert every job showed succeeded in act output
assert_job_succeeded() {
    local label="$1"
    local output="$2"
    if echo "$output" | grep -qiE "(Job succeeded|✅|succeeded)"; then
        pass "$label: job succeeded"
    else
        fail "$label: job did not succeed (no success marker found)"
    fi
}

# Assert bats test suite passed (look for Success step marker)
assert_bats_passed() {
    local label="$1"
    local output="$2"
    if echo "$output" | grep -qE "Success - Main Run bats test suite"; then
        pass "$label: bats test suite passed"
    else
        fail "$label: bats test suite did not pass"
    fi
}

# ─── Setup temp repo for a test case ─────────────────────────────────────────
# Creates an isolated git repo with project files, then applies optional
# customizations (callback function name).
setup_temp_repo() {
    local tmp
    tmp=$(mktemp -d)

    # Copy all project files
    cp "$SCRIPT_DIR/secret-rotation-validator.sh" "$tmp/"
    cp "$SCRIPT_DIR/test_secret_rotation.bats" "$tmp/"
    cp -r "$SCRIPT_DIR/fixtures" "$tmp/"
    cp -r "$SCRIPT_DIR/.github" "$tmp/"

    # Init git repo (act requires a git repo)
    git -C "$tmp" init -q
    git -C "$tmp" config user.email "test@example.com"
    git -C "$tmp" config user.name "Test Runner"
    git -C "$tmp" add .
    git -C "$tmp" commit -q -m "test: initial commit"

    echo "$tmp"
}

# ─── Workflow structure tests (no act needed) ─────────────────────────────────
run_workflow_structure_tests() {
    local label="workflow-structure"
    append_delimiter "$label"
    log "=== Running workflow structure tests ==="

    local wf_file="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"

    # Test: workflow file exists
    if [[ -f "$wf_file" ]]; then
        pass "workflow file exists at .github/workflows/secret-rotation-validator.yml"
    else
        fail "workflow file missing"
    fi
    echo "  workflow file: $([ -f "$wf_file" ] && echo FOUND || echo MISSING)" >> "$ACT_RESULT_FILE"

    # Test: required trigger events
    local trigger
    for trigger in "push:" "pull_request:" "schedule:" "workflow_dispatch:"; do
        if grep -q "$trigger" "$wf_file"; then
            pass "workflow has $trigger trigger"
        else
            fail "workflow missing $trigger trigger"
        fi
    done

    # Test: workflow references correct script file
    if grep -q "secret-rotation-validator.sh" "$wf_file"; then
        pass "workflow references secret-rotation-validator.sh"
    else
        fail "workflow does not reference secret-rotation-validator.sh"
    fi

    # Test: script file exists
    if [[ -f "$SCRIPT_DIR/secret-rotation-validator.sh" ]]; then
        pass "referenced script file exists"
    else
        fail "referenced script file missing"
    fi

    # Test: fixture file referenced in workflow exists
    if grep -q "fixtures/secrets.csv" "$wf_file"; then
        if [[ -f "$SCRIPT_DIR/fixtures/secrets.csv" ]]; then
            pass "fixtures/secrets.csv referenced in workflow and exists on disk"
        else
            fail "fixtures/secrets.csv referenced in workflow but missing on disk"
        fi
    fi

    # Test: actionlint passes (exit code 0)
    local actionlint_exit=0
    local actionlint_output
    actionlint_output=$(actionlint "$wf_file" 2>&1) || actionlint_exit=$?
    if [[ "$actionlint_exit" -eq 0 ]]; then
        pass "actionlint validation passes (exit code 0)"
    else
        fail "actionlint validation failed: $actionlint_output"
    fi
    echo "actionlint result: exit=$actionlint_exit" >> "$ACT_RESULT_FILE"

    # Test: uses actions/checkout@v4
    if grep -q "actions/checkout@v4" "$wf_file"; then
        pass "workflow uses actions/checkout@v4"
    else
        fail "workflow does not use actions/checkout@v4"
    fi

    # Test: has permissions block
    if grep -q "permissions:" "$wf_file"; then
        pass "workflow has permissions block"
    else
        fail "workflow missing permissions block"
    fi
}

# ─── Test case 1: Standard fixture - verify expired/warning/ok classification ─
run_test_case_1() {
    local label="test-case-1-standard-fixture"
    append_delimiter "$label"
    log "=== Test Case 1: Standard fixture — expired/warning/ok classification ==="

    local tmp
    tmp=$(setup_temp_repo)

    local output exit_code=0
    output=$(cd "$tmp" && act push --rm 2>&1) || exit_code=$?

    echo "$output" >> "$ACT_RESULT_FILE"
    rm -rf "$tmp"

    # Assert: act exited 0
    if [[ "$exit_code" -eq 0 ]]; then
        pass "$label: act exited with code 0"
    else
        fail "$label: act exited with code $exit_code (expected 0)"
    fi

    assert_job_succeeded "$label" "$output"
    assert_bats_passed "$label" "$output"

    # Assert: shellcheck and syntax passed
    assert_contains "$label" "$output" "shellcheck passed"
    assert_contains "$label" "$output" "Syntax check passed"

    # Assert: JSON report has all three urgency groups
    assert_contains "$label" "$output" '"expired"'
    assert_contains "$label" "$output" '"warning"'
    assert_contains "$label" "$output" '"ok"'
    assert_contains "$label" "$output" '"summary"'

    # Assert: DB_PASSWORD appears (it's expired in today's date and reference date)
    assert_contains "$label" "$output" '"DB_PASSWORD"'

    # Assert: validation step passed
    assert_contains "$label" "$output" "All required sections present in JSON report"
    assert_contains "$label" "$output" "Markdown report structure verified"
}

# ─── Test case 2: Fresh fixture - all secrets recently rotated → all ok ───────
run_test_case_2() {
    local label="test-case-2-all-ok-secrets"
    append_delimiter "$label"
    log "=== Test Case 2: Fresh fixture — all secrets OK (recently rotated) ==="

    local tmp
    tmp=$(setup_temp_repo)

    # Add a fresh fixture (recently rotated; bats tests still use secrets.csv)
    # The .env file overrides SECRETS_CONFIG so the validator steps use the fresh fixture
    local today
    today=$(date +%Y-%m-%d)
    cat > "$tmp/fixtures/secrets-fresh.csv" <<EOF
name,last_rotated,rotation_days,required_by
FRESH_SECRET_A,$today,365,"service-a"
FRESH_SECRET_B,$today,180,"service-b,service-c"
FRESH_SECRET_C,$today,90,"service-d"
EOF

    # Write a .env file so act overrides SECRETS_CONFIG
    echo "SECRETS_CONFIG=fixtures/secrets-fresh.csv" > "$tmp/.env"

    # Re-commit with new fixture + .env
    git -C "$tmp" add .
    git -C "$tmp" commit -q -m "test: add fresh fixture and override SECRETS_CONFIG"

    local output exit_code=0
    output=$(cd "$tmp" && act push --rm 2>&1) || exit_code=$?

    echo "$output" >> "$ACT_RESULT_FILE"
    rm -rf "$tmp"

    if [[ "$exit_code" -eq 0 ]]; then
        pass "$label: act exited with code 0"
    else
        fail "$label: act exited with code $exit_code (expected 0)"
    fi

    assert_job_succeeded "$label" "$output"
    assert_bats_passed "$label" "$output"

    # Assert: all three fresh secrets appear in the validator output
    assert_contains "$label" "$output" '"FRESH_SECRET_A"'
    assert_contains "$label" "$output" '"FRESH_SECRET_B"'
    assert_contains "$label" "$output" '"FRESH_SECRET_C"'

    # Assert: no expired secrets (all were just rotated today)
    # JSON has: "expired_count": 0  (note space after colon)
    assert_contains "$label" "$output" '"expired_count": 0'

    # Assert: total is 3
    assert_contains "$label" "$output" '"total": 3'

    # Assert: "No expired secrets found." message
    assert_contains "$label" "$output" "No expired secrets found."
}

# ─── Test case 3: Near-expiry fixture — secrets expiring within warning window ─
run_test_case_3() {
    local label="test-case-3-near-expiry"
    append_delimiter "$label"
    log "=== Test Case 3: Near-expiry fixture — secrets in warning window ==="

    local tmp
    tmp=$(setup_temp_repo)

    # Create fixture: two secrets expiring in ~3 and ~20 days (both in 30-day warning window)
    local today
    today=$(date +%Y-%m-%d)
    # rotated 87 days ago → expires in 3 days (90 - 87 = 3)
    local rotated_87d_ago
    rotated_87d_ago=$(date -d "$today - 87 days" +%Y-%m-%d)
    # rotated 160 days ago → expires in 20 days (180 - 160 = 20)
    local rotated_160d_ago
    rotated_160d_ago=$(date -d "$today - 160 days" +%Y-%m-%d)

    cat > "$tmp/fixtures/secrets-near.csv" <<EOF
name,last_rotated,rotation_days,required_by
ALMOST_EXPIRED,$rotated_87d_ago,90,"svc-a"
NEARING_ROTATION,$rotated_160d_ago,180,"svc-b,svc-c"
EOF

    # Override SECRETS_CONFIG via .env
    echo "SECRETS_CONFIG=fixtures/secrets-near.csv" > "$tmp/.env"

    git -C "$tmp" add .
    git -C "$tmp" commit -q -m "test: add near-expiry fixture"

    local output exit_code=0
    output=$(cd "$tmp" && act push --rm 2>&1) || exit_code=$?

    echo "$output" >> "$ACT_RESULT_FILE"
    rm -rf "$tmp"

    if [[ "$exit_code" -eq 0 ]]; then
        pass "$label: act exited with code 0"
    else
        fail "$label: act exited with code $exit_code (expected 0)"
    fi

    assert_job_succeeded "$label" "$output"
    assert_bats_passed "$label" "$output"

    # Both secrets should appear in the output
    assert_contains "$label" "$output" '"ALMOST_EXPIRED"'
    assert_contains "$label" "$output" '"NEARING_ROTATION"'

    # Total should be 2
    assert_contains "$label" "$output" '"total": 2'

    # No expired secrets (both have days_until_expiry > 0)
    assert_contains "$label" "$output" '"expired_count": 0'

    # Both should be in warning group (within 30-day window)
    assert_contains "$label" "$output" '"warning_count": 2'
}

# ─── Test case 4: Markdown output verification ────────────────────────────────
run_test_case_4() {
    local label="test-case-4-markdown-format"
    append_delimiter "$label"
    log "=== Test Case 4: Markdown output format sections ==="

    local tmp
    tmp=$(setup_temp_repo)
    # Standard fixture (all secrets expired relative to today)

    local output exit_code=0
    output=$(cd "$tmp" && act push --rm 2>&1) || exit_code=$?

    echo "$output" >> "$ACT_RESULT_FILE"
    rm -rf "$tmp"

    if [[ "$exit_code" -eq 0 ]]; then
        pass "$label: act exited with code 0"
    else
        fail "$label: act exited with code $exit_code (expected 0)"
    fi

    assert_job_succeeded "$label" "$output"

    # Assert markdown section headers
    assert_contains "$label" "$output" "## Expired Secrets"
    assert_contains "$label" "$output" "## Warning Secrets"
    assert_contains "$label" "$output" "## OK Secrets"

    # Assert table header
    assert_contains "$label" "$output" "| Secret Name |"
    assert_contains "$label" "$output" "| Status |"

    # Assert report header metadata
    assert_contains "$label" "$output" "Reference Date:"
    assert_contains "$label" "$output" "Warning Window:"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    log "Starting act-based test harness"
    log "Results will be appended to: $ACT_RESULT_FILE"

    # Initialize results file
    {
        echo "Secret Rotation Validator - Act Test Results"
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "============================================================"
    } > "$ACT_RESULT_FILE"

    # Run workflow structure tests (no act, just file/lint checks)
    run_workflow_structure_tests

    # Run act-based test cases
    run_test_case_1
    run_test_case_2
    run_test_case_3
    run_test_case_4

    # Final summary
    local total=$(( PASS_COUNT + FAIL_COUNT ))
    {
        echo ""
        echo "============================================================"
        echo "FINAL SUMMARY"
        echo "============================================================"
        echo "Total assertions: $total"
        echo "Passed: $PASS_COUNT"
        echo "Failed: $FAIL_COUNT"
    } | tee -a "$ACT_RESULT_FILE"

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        log "RESULT: FAILED ($FAIL_COUNT/$total assertions failed)"
        exit 1
    else
        log "RESULT: ALL PASSED ($PASS_COUNT/$total assertions passed)"
        exit 0
    fi
}

main "$@"
