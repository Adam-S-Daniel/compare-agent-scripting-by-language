#!/usr/bin/env bash
# Test harness: runs all tests through act (GitHub Actions) and validates output.
# Produces act-result.txt with full output and exits non-zero on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
FAILURES=0

# Clear previous results
> "$RESULT_FILE"

log() {
    echo "$1" | tee -a "$RESULT_FILE"
}

# ============================================================
# SECTION 1: Workflow structure tests (YAML parsing + actionlint)
# ============================================================
log "========================================"
log "WORKFLOW STRUCTURE TESTS"
log "========================================"

# Test: workflow YAML exists
log ""
log "--- Test: Workflow file exists ---"
WF_FILE="$SCRIPT_DIR/.github/workflows/artifact-cleanup-script.yml"
if [ -f "$WF_FILE" ]; then
    log "PASS: Workflow file exists at .github/workflows/artifact-cleanup-script.yml"
else
    log "FAIL: Workflow file not found"
    FAILURES=$((FAILURES + 1))
fi

# Test: workflow references script files that exist
log ""
log "--- Test: Script files referenced in workflow exist ---"
if grep -q "Invoke-ArtifactCleanup.ps1" "$WF_FILE" && [ -f "$SCRIPT_DIR/Invoke-ArtifactCleanup.ps1" ]; then
    log "PASS: Invoke-ArtifactCleanup.ps1 referenced and exists"
else
    log "FAIL: Script file reference mismatch"
    FAILURES=$((FAILURES + 1))
fi

if grep -q "Invoke-ArtifactCleanup.Tests.ps1" "$WF_FILE" && [ -f "$SCRIPT_DIR/Invoke-ArtifactCleanup.Tests.ps1" ]; then
    log "PASS: Invoke-ArtifactCleanup.Tests.ps1 referenced and exists"
else
    log "FAIL: Test file reference mismatch"
    FAILURES=$((FAILURES + 1))
fi

# Test: workflow has expected triggers
log ""
log "--- Test: Workflow has expected triggers ---"
TRIGGERS_OK=true
for trigger in "push:" "pull_request:" "workflow_dispatch:"; do
    if ! grep -q "$trigger" "$WF_FILE"; then
        log "FAIL: Missing trigger: $trigger"
        TRIGGERS_OK=false
        FAILURES=$((FAILURES + 1))
    fi
done
if [ "$TRIGGERS_OK" = true ]; then
    log "PASS: All expected triggers present (push, pull_request, workflow_dispatch)"
fi

# Test: workflow has expected job
log ""
log "--- Test: Workflow has artifact-cleanup job ---"
if grep -q "artifact-cleanup:" "$WF_FILE"; then
    log "PASS: artifact-cleanup job found"
else
    log "FAIL: artifact-cleanup job not found"
    FAILURES=$((FAILURES + 1))
fi

# Test: workflow has expected steps
log ""
log "--- Test: Workflow has expected steps ---"
STEPS_OK=true
for step in "actions/checkout@v4" "Install PowerShell" "Install Pester" "Run Pester tests" "Run cleanup"; do
    if ! grep -q "$step" "$WF_FILE"; then
        log "FAIL: Missing step: $step"
        STEPS_OK=false
        FAILURES=$((FAILURES + 1))
    fi
done
if [ "$STEPS_OK" = true ]; then
    log "PASS: All expected steps present"
fi

# Test: actionlint passes
log ""
log "--- Test: actionlint validation ---"
LINT_OUTPUT=$(actionlint "$WF_FILE" 2>&1) || true
if [ -z "$LINT_OUTPUT" ]; then
    log "PASS: actionlint passed with no errors"
else
    log "FAIL: actionlint found errors:"
    log "$LINT_OUTPUT"
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# SECTION 2: Run workflow through act for each test case
# ============================================================
log ""
log "========================================"
log "ACT EXECUTION TESTS"
log "========================================"

# Set up a temp git repo with project files
setup_temp_repo() {
    local tmpdir
    tmpdir=$(mktemp -d)
    cd "$tmpdir"
    git init -b main > /dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test"

    # Copy project files
    cp "$SCRIPT_DIR/Invoke-ArtifactCleanup.ps1" .
    cp "$SCRIPT_DIR/Invoke-ArtifactCleanup.Tests.ps1" .
    mkdir -p .github/workflows
    cp "$SCRIPT_DIR/.github/workflows/artifact-cleanup-script.yml" .github/workflows/

    git add -A > /dev/null 2>&1
    git commit -m "initial" > /dev/null 2>&1

    echo "$tmpdir"
}

run_act_test() {
    local test_name="$1"
    local tmpdir

    log ""
    log "--- Act Test: $test_name ---"

    tmpdir=$(setup_temp_repo)
    cd "$tmpdir"

    local act_output
    local act_exit=0
    act_output=$(act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-latest 2>&1) || act_exit=$?

    log "Act exit code: $act_exit"
    log ""
    log "$act_output"

    # Assert exit code 0
    if [ "$act_exit" -ne 0 ]; then
        log "FAIL: act exited with code $act_exit (expected 0)"
        FAILURES=$((FAILURES + 1))
        rm -rf "$tmpdir"
        cd "$SCRIPT_DIR"
        return
    fi
    log "PASS: act exited with code 0"

    # Assert job succeeded
    if echo "$act_output" | grep -q "Job succeeded"; then
        log "PASS: Job succeeded message found"
    else
        log "FAIL: 'Job succeeded' not found in output"
        FAILURES=$((FAILURES + 1))
    fi

    # Return output for per-case assertions
    echo "$act_output" > "$tmpdir/act_output.txt"
    ACT_OUTPUT_FILE="$tmpdir/act_output.txt"
    TEMP_DIR="$tmpdir"
}

assert_output_contains() {
    local pattern="$1"
    local label="$2"
    if grep -qF "$pattern" "$ACT_OUTPUT_FILE"; then
        log "PASS: Output contains '$label'"
    else
        log "FAIL: Output missing '$label' (expected: $pattern)"
        FAILURES=$((FAILURES + 1))
    fi
}

assert_output_regex() {
    local pattern="$1"
    local label="$2"
    if grep -qE "$pattern" "$ACT_OUTPUT_FILE"; then
        log "PASS: Output matches '$label'"
    else
        log "FAIL: Output missing '$label' (pattern: $pattern)"
        FAILURES=$((FAILURES + 1))
    fi
}

# ------------------------------------------------------------------
# Test Case: Full workflow run with all steps
# ------------------------------------------------------------------
run_act_test "Full workflow run"

# Pester test assertions - verify test count
assert_output_contains "Tests Passed: 19" "All 19 Pester tests passed"
assert_output_contains "Failed: 0" "No Pester tests failed"

# Max age policy step assertions
assert_output_contains "DRY RUN MODE" "Dry run mode indicated"
assert_output_contains "To delete: 2" "Max age policy: 2 artifacts to delete"
assert_output_contains "To retain: 3" "Max age policy: 3 artifacts retained"
assert_output_contains "Space reclaimed: 1500 bytes" "Max age: 1500 bytes reclaimed"

# Keep latest N policy assertions
assert_output_contains "To delete: 3" "Keep-latest-1 policy: 3 artifacts deleted"

# Max total size policy assertions
assert_output_contains "Space reclaimed: 3500 bytes" "Max total size: 3500 bytes reclaimed"

# Combined policies assertions
assert_output_contains "Space retained: 4500 bytes" "Combined: 4500 bytes retained"

# Artifact names in output
assert_output_contains "build-log-1" "build-log-1 artifact referenced"
assert_output_contains "build-log-3" "build-log-3 artifact referenced"
assert_output_contains "test-results-2" "test-results-2 artifact referenced"

# Cleanup temp
rm -rf "$TEMP_DIR"
cd "$SCRIPT_DIR"

# ============================================================
# SUMMARY
# ============================================================
log ""
log "========================================"
log "TEST SUMMARY"
log "========================================"
if [ "$FAILURES" -eq 0 ]; then
    log "ALL TESTS PASSED"
else
    log "FAILURES: $FAILURES"
fi

log "Results saved to: $RESULT_FILE"

exit "$FAILURES"
