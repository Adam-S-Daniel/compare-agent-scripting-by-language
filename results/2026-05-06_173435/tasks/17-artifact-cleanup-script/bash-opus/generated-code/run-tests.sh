#!/usr/bin/env bash
# Test harness: runs all tests through GitHub Actions via act,
# validates workflow structure, and asserts on exact expected values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

# Clear previous results
: > "$RESULT_FILE"

log() {
    echo "$*" | tee -a "$RESULT_FILE"
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        log "  PASS: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "  FAIL: $desc"
        log "    Expected: $expected"
        log "    Actual:   $actual"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        log "  PASS: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "  FAIL: $desc (expected to find '$needle')"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        log "  PASS: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "  FAIL: $desc (did not expect to find '$needle')"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ============================================================
# SECTION 1: Workflow structure tests (no act needed)
# ============================================================
log "============================================"
log "SECTION 1: Workflow Structure Tests"
log "============================================"

WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/artifact-cleanup-script.yml"

# Test: workflow file exists
if [[ -f "$WORKFLOW_FILE" ]]; then
    log "  PASS: Workflow file exists"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: Workflow file not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: workflow has expected triggers
workflow_content=$(cat "$WORKFLOW_FILE")
assert_contains "Workflow has push trigger" "push:" "$workflow_content"
assert_contains "Workflow has pull_request trigger" "pull_request:" "$workflow_content"
assert_contains "Workflow has workflow_dispatch trigger" "workflow_dispatch" "$workflow_content"
assert_contains "Workflow has schedule trigger" "schedule:" "$workflow_content"

# Test: workflow has expected jobs
assert_contains "Workflow has validate job" "validate:" "$workflow_content"
assert_contains "Workflow has test job" "test:" "$workflow_content"
assert_contains "Workflow has integration job" "integration:" "$workflow_content"

# Test: workflow references script correctly
assert_contains "Workflow references artifact-cleanup.sh" "artifact-cleanup.sh" "$workflow_content"
assert_contains "Workflow references test fixtures" "test/fixtures/" "$workflow_content"
assert_contains "Workflow references bats tests" "test/artifact-cleanup.bats" "$workflow_content"

# Test: workflow uses checkout action
assert_contains "Workflow uses actions/checkout" "actions/checkout@v4" "$workflow_content"

# Test: referenced files exist
if [[ -f "$SCRIPT_DIR/artifact-cleanup.sh" ]]; then
    log "  PASS: artifact-cleanup.sh exists"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: artifact-cleanup.sh not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if [[ -f "$SCRIPT_DIR/test/artifact-cleanup.bats" ]]; then
    log "  PASS: test/artifact-cleanup.bats exists"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: test/artifact-cleanup.bats not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

for fixture in basic-artifacts.txt keep-latest-artifacts.txt size-limit-artifacts.txt; do
    if [[ -f "$SCRIPT_DIR/test/fixtures/$fixture" ]]; then
        log "  PASS: test/fixtures/$fixture exists"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "  FAIL: test/fixtures/$fixture not found"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# Test: actionlint passes
if actionlint "$WORKFLOW_FILE" 2>&1; then
    log "  PASS: actionlint passes"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: actionlint found errors"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: shellcheck passes
if shellcheck "$SCRIPT_DIR/artifact-cleanup.sh" 2>&1; then
    log "  PASS: shellcheck passes"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: shellcheck found errors"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: bash -n passes
if bash -n "$SCRIPT_DIR/artifact-cleanup.sh" 2>&1; then
    log "  PASS: bash -n syntax check passes"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: bash -n syntax check failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

log ""

# ============================================================
# SECTION 2: Run tests through act
# ============================================================
log "============================================"
log "SECTION 2: Act Pipeline Execution"
log "============================================"

# Set up a temp git repo with our project files
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SCRIPT_DIR/artifact-cleanup.sh" "$TMPDIR/"
cp -r "$SCRIPT_DIR/test" "$TMPDIR/"
cp -r "$SCRIPT_DIR/.github" "$TMPDIR/"
cp "$SCRIPT_DIR/.actrc" "$TMPDIR/" 2>/dev/null || true

cd "$TMPDIR"
git init -b main --quiet
git add -A
git commit -m "initial" --quiet

log ""
log "--- Act Run 1: Full pipeline (validate + test + integration) ---"
log ""

ACT_OUTPUT=""
ACT_EXIT=0
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || ACT_EXIT=$?

# Save raw act output
echo "$ACT_OUTPUT" >> "$RESULT_FILE"

log ""
log "--- Act Run 1 Analysis ---"
log ""

# Test: act exited successfully
assert_eq "act exit code is 0" "0" "$ACT_EXIT"

# Test: all jobs succeeded
assert_contains "validate job succeeded" "Job succeeded" "$ACT_OUTPUT"

# Count how many jobs succeeded
JOB_SUCCESS_COUNT=$(echo "$ACT_OUTPUT" | grep -c "Job succeeded" || true)
assert_eq "All 3 jobs succeeded" "3" "$JOB_SUCCESS_COUNT"

# Test: shellcheck step ran in pipeline
assert_contains "shellcheck ran in pipeline" "shellcheck" "$ACT_OUTPUT"

# Test: bats tests ran and passed
assert_contains "bats ran in pipeline" "bats" "$ACT_OUTPUT"

# Count bats test results (TAP format: "ok N ...")
BATS_OK_COUNT=$(echo "$ACT_OUTPUT" | grep -cE "^.*ok [0-9]+" || true)
if [[ "$BATS_OK_COUNT" -ge 20 ]]; then
    log "  PASS: At least 20 bats tests passed ($BATS_OK_COUNT found)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log "  FAIL: Expected at least 20 bats tests, found $BATS_OK_COUNT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: integration tests produced expected output values

# max-age 3 days: should delete 3, retain 2
assert_contains "Integration: max-age shows 'Artifacts to delete: 3'" "Artifacts to delete: 3" "$ACT_OUTPUT"
assert_contains "Integration: max-age shows 'Artifacts to retain: 2'" "Artifacts to retain: 2" "$ACT_OUTPUT"
assert_contains "Integration: max-age shows 'Space reclaimed: 8.50MB'" "Space reclaimed: 8.50MB" "$ACT_OUTPUT"
assert_contains "Integration: max-age shows DRY RUN" "DRY RUN" "$ACT_OUTPUT"

# keep-latest 1: should delete 3 (a2,a3,b2), retain 2 (a1,b1)
assert_contains "Integration: keep-latest shows DELETE artifact-a2" "DELETE: artifact-a2" "$ACT_OUTPUT"
assert_contains "Integration: keep-latest shows DELETE artifact-a3" "DELETE: artifact-a3" "$ACT_OUTPUT"
assert_contains "Integration: keep-latest shows DELETE artifact-b2" "DELETE: artifact-b2" "$ACT_OUTPUT"
assert_contains "Integration: keep-latest shows RETAIN artifact-a1" "RETAIN: artifact-a1" "$ACT_OUTPUT"
assert_contains "Integration: keep-latest shows RETAIN artifact-b1" "RETAIN: artifact-b1" "$ACT_OUTPUT"

# max-total-size 10000: should delete item-oldest (5000), retain rest
assert_contains "Integration: size-limit shows DELETE item-oldest" "DELETE: item-oldest" "$ACT_OUTPUT"
assert_contains "Integration: size-limit shows RETAIN item-newest" "RETAIN: item-newest" "$ACT_OUTPUT"
assert_contains "Integration: size-limit shows RETAIN item-old" "RETAIN: item-old" "$ACT_OUTPUT"

# combined: max-age 3 + keep-latest 1 -> delete 4, retain 1
assert_contains "Integration: combined shows 'Artifacts to delete: 4'" "Artifacts to delete: 4" "$ACT_OUTPUT"
assert_contains "Integration: combined shows 'Artifacts to retain: 1'" "Artifacts to retain: 1" "$ACT_OUTPUT"
assert_contains "Integration: combined shows RETAIN build-logs-1" "RETAIN: build-logs-1" "$ACT_OUTPUT"

# Verify the Artifact Cleanup Plan header appears
assert_contains "Plan header present" "=== Artifact Cleanup Plan ===" "$ACT_OUTPUT"

# Verify section headers appear
assert_contains "DELETE section header present" "Artifacts to DELETE" "$ACT_OUTPUT"
assert_contains "RETAIN section header present" "Artifacts to RETAIN" "$ACT_OUTPUT"
assert_contains "Summary section header present" "--- Summary ---" "$ACT_OUTPUT"

log ""

# ============================================================
# SECTION 3: Summary
# ============================================================
log "============================================"
log "SECTION 3: Test Summary"
log "============================================"
log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"
log "Total:  $((PASS_COUNT + FAIL_COUNT))"
log ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    log "RESULT: SOME TESTS FAILED"
    exit 1
else
    log "RESULT: ALL TESTS PASSED"
fi
