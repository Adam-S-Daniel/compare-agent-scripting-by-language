#!/usr/bin/env bash
# run_tests.sh — Test harness for the Environment Matrix Generator.
#
# Strategy:
#   For each test case a fresh temporary git repository is created containing
#   all project files plus the case-specific test-input.json fixture.  act is
#   then run against that repository.  Output is appended (clearly delimited)
#   to act-result.txt, and exact-value assertions are checked in the captured
#   output before moving on to the next case.
#
# Usage:
#   cd <project-root>
#   bash run_tests.sh
#
# Prerequisites: act, docker, git, python3, actionlint, grep

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"
ACT_IMAGE="catthehacker/ubuntu:act-latest"
ACT_FLAGS=(-P "ubuntu-latest=${ACT_IMAGE}" --rm --no-cache-server)

# ── Result counters ──────────────────────────────────────────────────────────
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_NAMES=()

# ── Helpers ──────────────────────────────────────────────────────────────────

log() { echo "$*" | tee -a "$ACT_RESULT"; }

separator() {
    log ""
    log "================================================================"
    log "$1"
    log "================================================================"
}

# assert_contains <test_name> <output_variable_content> <expected_string>
assert_contains() {
    local name="$1" output="$2" expected="$3"
    if echo "$output" | grep -qF -- "$expected"; then
        log "  [ASSERT PASS] found: ${expected}"
    else
        log "  [ASSERT FAIL] expected to find: ${expected}"
        FAILED_NAMES+=("$name:missing='$expected'")
        return 1
    fi
}

# assert_not_contains <test_name> <output> <string>
assert_not_contains() {
    local name="$1" output="$2" not_expected="$3"
    if ! echo "$output" | grep -qF -- "$not_expected"; then
        log "  [ASSERT PASS] not found (as expected): ${not_expected}"
    else
        log "  [ASSERT FAIL] unexpectedly found: ${not_expected}"
        FAILED_NAMES+=("$name:unexpectedly_present='$not_expected'")
        return 1
    fi
}

# run_act_test <test_name> <fixture_relative_path>
# Returns the captured act output via the global RUN_OUTPUT variable.
run_act_test() {
    local test_name="$1"
    local fixture_path="$SCRIPT_DIR/$2"

    separator "TEST: ${test_name}  |  fixture: $2"

    # ── Create an isolated temp git repo ────────────────────────────────────
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Ensure cleanup even on early exit
    local _cleanup_done=0
    cleanup_tmpdir() {
        if [ "$_cleanup_done" -eq 0 ]; then
            _cleanup_done=1
            rm -rf "$tmpdir"
        fi
    }
    trap cleanup_tmpdir EXIT

    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "test@matrix-generator.ci"
    git -C "$tmpdir" config user.name "Matrix Generator Tests"

    # Copy project files
    cp "$SCRIPT_DIR/matrix_generator.py"       "$tmpdir/"
    cp "$SCRIPT_DIR/test_matrix_generator.py"  "$tmpdir/"
    cp -r "$SCRIPT_DIR/fixtures"               "$tmpdir/"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml" \
       "$tmpdir/.github/workflows/"

    # Place this test case's fixture as test-input.json
    cp "$fixture_path" "$tmpdir/test-input.json"

    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "ci: test case ${test_name}"

    # ── Run act ─────────────────────────────────────────────────────────────
    local exit_code=0
    local raw_output
    raw_output="$(cd "$tmpdir" && act push "${ACT_FLAGS[@]}" 2>&1)" || exit_code=$?

    # Strip ANSI escape codes for reliable text matching
    local clean_output
    clean_output="$(echo "$raw_output" | sed 's/\x1b\[[0-9;]*[mKHJsurABCDEFGnRSTlh]//g')"

    # Append to the cumulative results file
    log ""
    log "--- act output ---"
    echo "$clean_output" >> "$ACT_RESULT"
    log "--- end act output ---"

    # ── Mandatory assertions (apply to every test case) ──────────────────────
    local case_failed=0

    # 1. act must exit 0
    if [ "$exit_code" -ne 0 ]; then
        log "  [ASSERT FAIL] act exited with code ${exit_code} (expected 0)"
        FAILED_NAMES+=("${test_name}:act_exit_code=${exit_code}")
        case_failed=1
    else
        log "  [ASSERT PASS] act exit code 0"
    fi

    # 2. Every job must show "Job succeeded"
    local job_success_count
    job_success_count="$(echo "$clean_output" | grep -c "Job succeeded" || true)"
    if [ "$job_success_count" -lt 2 ]; then
        log "  [ASSERT FAIL] expected 2 'Job succeeded' lines, found ${job_success_count}"
        FAILED_NAMES+=("${test_name}:job_success_count=${job_success_count}")
        case_failed=1
    else
        log "  [ASSERT PASS] ${job_success_count} 'Job succeeded' lines"
    fi

    # Store output for caller assertions
    RUN_OUTPUT="$clean_output"

    trap - EXIT
    cleanup_tmpdir

    return "$case_failed"
}

# ════════════════════════════════════════════════════════════════════════════
# Phase 1 — Workflow structure tests (no act required)
# ════════════════════════════════════════════════════════════════════════════

# Initialise the results file fresh for this run
> "$ACT_RESULT"

separator "PHASE 1: Workflow Structure Tests"

WORKFLOW="$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"

# ── Test S1: workflow file exists ────────────────────────────────────────────
if [ -f "$WORKFLOW" ]; then
    log "PASS S1: workflow file exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL S1: workflow file not found at $WORKFLOW"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("S1:workflow_file_missing")
fi

# ── Test S2: script file exists ───────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/matrix_generator.py" ]; then
    log "PASS S2: matrix_generator.py exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL S2: matrix_generator.py not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("S2:script_missing")
fi

# ── Test S3: fixture files exist ─────────────────────────────────────────────
for fixture in basic complex large; do
    fpath="$SCRIPT_DIR/fixtures/${fixture}.json"
    if [ -f "$fpath" ]; then
        log "PASS S3: fixtures/${fixture}.json exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log "FAIL S3: fixtures/${fixture}.json missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_NAMES+=("S3:missing_fixture_${fixture}.json")
    fi
done

# ── Test S4: actionlint passes ────────────────────────────────────────────────
actionlint_output="$(actionlint "$WORKFLOW" 2>&1)" && actionlint_exit=0 || actionlint_exit=$?
echo "$actionlint_output" >> "$ACT_RESULT"
if [ "$actionlint_exit" -eq 0 ]; then
    log "PASS S4: actionlint validation passed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL S4: actionlint found errors"
    log "$actionlint_output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("S4:actionlint_failed")
fi

# ── Test S5: workflow references expected triggers ────────────────────────────
triggers_ok=true
for trigger in "push:" "pull_request:" "workflow_dispatch:" "schedule:"; do
    if ! grep -qF "$trigger" "$WORKFLOW"; then
        log "FAIL S5: trigger '$trigger' not found in workflow"
        triggers_ok=false
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_NAMES+=("S5:missing_trigger_${trigger}")
    fi
done
if [ "$triggers_ok" = "true" ]; then
    log "PASS S5: all expected triggers present"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# ── Test S6: workflow references the script ───────────────────────────────────
if grep -qF "matrix_generator.py" "$WORKFLOW"; then
    log "PASS S6: workflow references matrix_generator.py"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL S6: workflow does not reference matrix_generator.py"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("S6:script_not_referenced")
fi

# ════════════════════════════════════════════════════════════════════════════
# Phase 2 — Act-based integration tests
# ════════════════════════════════════════════════════════════════════════════

separator "PHASE 2: Act Integration Tests"

RUN_OUTPUT=""   # populated by run_act_test

# ── Test A: Basic matrix generation ─────────────────────────────────────────
#
# Input: fixtures/basic.json
#   { "os": ["ubuntu-latest","windows-latest"],
#     "language_versions": { "python": ["3.9","3.10","3.11"] },
#     "fail_fast": false }
#
# Expected exact values in output:
#   "ubuntu-latest"             (OS dimension)
#   "windows-latest"            (OS dimension)
#   "python-version"            (dimension key)
#   "3.9"                       (version value)
#   "3.11"                      (version value)
#   "fail-fast": false          (strategy setting)
#   MATRIX_GENERATION_SUCCESS   (sentinel from workflow)
# ─────────────────────────────────────────────────────────────────────────────
test_name="A_basic_matrix"
act_failed=0
run_act_test "$test_name" "fixtures/basic.json" || act_failed=$?

case_ok=true
assert_contains "$test_name" "$RUN_OUTPUT" "MATRIX_GENERATION_SUCCESS" || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"ubuntu-latest"'            || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"windows-latest"'           || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"python-version"'           || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"3.9"'                      || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"3.11"'                     || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"fail-fast": false'         || case_ok=false
# fail-fast: true must NOT be present (config sets it false)
assert_not_contains "$test_name" "$RUN_OUTPUT" '"fail-fast": true'      || case_ok=false

if [ "$act_failed" -eq 0 ] && [ "$case_ok" = "true" ]; then
    log "PASS ${test_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL ${test_name}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ── Test B: Complex matrix (includes, excludes, max-parallel, feature flags) ─
#
# Input: fixtures/complex.json
#   { "os": ["ubuntu-latest","windows-latest","macos-latest"],
#     "language_versions": { "python": ["3.10","3.11","3.12"] },
#     "feature_flags": { "experimental": [true,false] },
#     "include": [ {..., "nightly": true} ],
#     "exclude": [ {"os":"windows-latest","python-version":"3.10"} ],
#     "max_parallel": 4, "fail_fast": false }
#
# Exact expected values:
#   "macos-latest"           "3.10"  "3.12"  "experimental"
#   "include"                "exclude"       "nightly"
#   "max-parallel": 4        "fail-fast": false
# ─────────────────────────────────────────────────────────────────────────────
test_name="B_complex_matrix"
act_failed=0
run_act_test "$test_name" "fixtures/complex.json" || act_failed=$?

case_ok=true
assert_contains "$test_name" "$RUN_OUTPUT" "MATRIX_GENERATION_SUCCESS"  || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"macos-latest"'              || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"3.10"'                      || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"3.12"'                      || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"experimental"'              || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"include"'                   || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"exclude"'                   || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"nightly": true'             || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"max-parallel": 4'           || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" '"fail-fast": false'          || case_ok=false

if [ "$act_failed" -eq 0 ] && [ "$case_ok" = "true" ]; then
    log "PASS ${test_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL ${test_name}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ── Test C: Size validation — matrix exceeds max_size ────────────────────────
#
# Input: fixtures/large.json
#   { "os": [3 items], "language_versions": {"python":[4],"node":[3]},
#     "max_size": 5 }
#   Cartesian product: 3 * 4 * 3 = 36  >  5 → must fail
#
# Exact expected values:
#   MATRIX_GENERATION_FAILED             (sentinel from workflow shell)
#   "Matrix size 36 exceeds maximum allowed size 5"  (from MatrixTooLargeError)
#
# act must still exit 0 (the workflow handles the error gracefully).
# ─────────────────────────────────────────────────────────────────────────────
test_name="C_size_validation"
act_failed=0
run_act_test "$test_name" "fixtures/large.json" || act_failed=$?

case_ok=true
assert_contains "$test_name" "$RUN_OUTPUT" "MATRIX_GENERATION_FAILED"                      || case_ok=false
assert_contains "$test_name" "$RUN_OUTPUT" "Matrix size 36 exceeds maximum allowed size 5" || case_ok=false
# Sanity: should not report success
assert_not_contains "$test_name" "$RUN_OUTPUT" "MATRIX_GENERATION_SUCCESS" || case_ok=false

if [ "$act_failed" -eq 0 ] && [ "$case_ok" = "true" ]; then
    log "PASS ${test_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log "FAIL ${test_name}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ════════════════════════════════════════════════════════════════════════════
# Results summary
# ════════════════════════════════════════════════════════════════════════════

separator "RESULTS SUMMARY"
log "PASSED : ${TESTS_PASSED}"
log "FAILED : ${TESTS_FAILED}"
log "TOTAL  : $((TESTS_PASSED + TESTS_FAILED))"

if [ "${#FAILED_NAMES[@]}" -gt 0 ]; then
    log ""
    log "Failed test details:"
    for name in "${FAILED_NAMES[@]}"; do
        log "  - ${name}"
    done
fi

log ""
if [ "$TESTS_FAILED" -gt 0 ]; then
    log "RESULT: SOME TESTS FAILED"
    exit 1
else
    log "RESULT: ALL TESTS PASSED"
fi
