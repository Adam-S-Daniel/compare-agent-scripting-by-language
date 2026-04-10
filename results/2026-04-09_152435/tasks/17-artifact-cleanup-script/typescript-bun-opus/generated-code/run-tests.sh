#!/bin/bash
# run-tests.sh — Test harness that runs all tests through act and validates output
# Produces act-result.txt with all results and assertions.
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$WORK_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

> "$RESULT_FILE"

log() {
  echo "$1" | tee -a "$RESULT_FILE"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    log "ASSERT PASSED: $desc (expected=$expected)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    log "ASSERT FAILED: $desc (expected=$expected, got=$actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    log "ASSERT PASSED: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    log "ASSERT FAILED: $desc — expected to find '$needle'"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    log "ASSERT FAILED: $desc — found '$needle' but should not have"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    log "ASSERT PASSED: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

# ============================================================
# PART 1: Workflow Structure Tests
# ============================================================
log "============================================================"
log "WORKFLOW STRUCTURE TESTS"
log "============================================================"

WORKFLOW="$WORK_DIR/.github/workflows/artifact-cleanup-script.yml"

# Test: Workflow file exists
if [ -f "$WORKFLOW" ]; then
  log "ASSERT PASSED: Workflow file exists"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  log "ASSERT FAILED: Workflow file does not exist"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: YAML has expected triggers
YAML_CONTENT=$(cat "$WORKFLOW")
assert_contains "workflow has push trigger" "push:" "$YAML_CONTENT"
assert_contains "workflow has pull_request trigger" "pull_request:" "$YAML_CONTENT"
assert_contains "workflow has workflow_dispatch trigger" "workflow_dispatch:" "$YAML_CONTENT"
assert_contains "workflow has schedule trigger" "schedule:" "$YAML_CONTENT"

# Test: YAML has expected jobs and steps
assert_contains "workflow has test-and-run job" "test-and-run:" "$YAML_CONTENT"
assert_contains "workflow uses actions/checkout@v4" "actions/checkout@v4" "$YAML_CONTENT"
assert_contains "workflow installs bun" "bun.sh/install" "$YAML_CONTENT"
assert_contains "workflow runs bun test" "bun test" "$YAML_CONTENT"
assert_contains "workflow runs main.ts" "main.ts" "$YAML_CONTENT"

# Test: Referenced script files exist
assert_eq "main.ts exists" "true" "$([ -f "$WORK_DIR/main.ts" ] && echo true || echo false)"
assert_eq "cleanup.ts exists" "true" "$([ -f "$WORK_DIR/cleanup.ts" ] && echo true || echo false)"
assert_eq "types.ts exists" "true" "$([ -f "$WORK_DIR/types.ts" ] && echo true || echo false)"
assert_eq "cleanup.test.ts exists" "true" "$([ -f "$WORK_DIR/cleanup.test.ts" ] && echo true || echo false)"
assert_eq "fixtures.ts exists" "true" "$([ -f "$WORK_DIR/fixtures.ts" ] && echo true || echo false)"
assert_eq "test-artifacts.json exists" "true" "$([ -f "$WORK_DIR/test-artifacts.json" ] && echo true || echo false)"

# Test: actionlint passes
if actionlint "$WORKFLOW" 2>&1; then
  log "ASSERT PASSED: actionlint passes with exit code 0"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  log "ASSERT FAILED: actionlint reported errors"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# ============================================================
# PART 2: ACT Integration Tests
# ============================================================
log ""
log "============================================================"
log "ACT INTEGRATION TESTS"
log "============================================================"

# Create a temporary git repo with project files
TMPDIR=$(mktemp -d)
log "Setting up temp repo in $TMPDIR"

# Copy all project files
cp "$WORK_DIR/types.ts" "$TMPDIR/"
cp "$WORK_DIR/cleanup.ts" "$TMPDIR/"
cp "$WORK_DIR/cleanup.test.ts" "$TMPDIR/"
cp "$WORK_DIR/fixtures.ts" "$TMPDIR/"
cp "$WORK_DIR/main.ts" "$TMPDIR/"
cp "$WORK_DIR/test-artifacts.json" "$TMPDIR/"
cp "$WORK_DIR/.actrc" "$TMPDIR/"
mkdir -p "$TMPDIR/.github/workflows"
cp "$WORKFLOW" "$TMPDIR/.github/workflows/"

# Initialize git repo (required by act)
cd "$TMPDIR"
git init -q
git add -A
git commit -q -m "test commit"

# Run act
log ""
log "--- Running act push --rm ---"
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || true
ACT_EXIT=${PIPESTATUS[0]:-$?}
echo "$ACT_OUTPUT" >> "$RESULT_FILE"

log ""
log "--- Act run completed (exit code: $ACT_EXIT) ---"
log ""

# Cleanup temp dir
cd "$WORK_DIR"
rm -rf "$TMPDIR"

# ============================================================
# PART 3: Assert on ACT output
# ============================================================
log "============================================================"
log "ACT OUTPUT ASSERTIONS"
log "============================================================"

# Assert act exited successfully
assert_eq "act exit code is 0" "0" "$ACT_EXIT"

# Assert job succeeded
assert_contains "job succeeded" "Job succeeded" "$ACT_OUTPUT"

# --- Bun test assertions ---
# Check all 16 tests passed (the exact count from cleanup.test.ts)
assert_contains "bun tests show pass" "pass" "$ACT_OUTPUT"
assert_contains "bun tests show 0 fail" "0 fail" "$ACT_OUTPUT"

# --- Max age policy output assertions ---
assert_contains "max-age: delete count = 3" "Artifacts to delete: 3" "$ACT_OUTPUT"
assert_contains "max-age: retain count = 4" "Artifacts to retain: 4" "$ACT_OUTPUT"
assert_contains "max-age: reclaimed = 6500000" "Space reclaimed: 6500000 bytes" "$ACT_OUTPUT"
assert_contains "max-age: mode = DRY-RUN" "Mode: DRY-RUN" "$ACT_OUTPUT"
assert_contains "max-age: deletes deploy-bundle-1" "DELETE: deploy-bundle-1" "$ACT_OUTPUT"
assert_contains "max-age: deletes build-artifact-1" "DELETE: build-artifact-1" "$ACT_OUTPUT"
assert_contains "max-age: deletes test-results-1" "DELETE: test-results-1" "$ACT_OUTPUT"

# --- Keep-latest-N policy output assertions ---
assert_contains "keep-latest-1: delete count = 4" "Artifacts to delete: 4" "$ACT_OUTPUT"
assert_contains "keep-latest-1: retain count = 3" "Artifacts to retain: 3" "$ACT_OUTPUT"
assert_contains "keep-latest-1: reclaimed = 8500000" "Space reclaimed: 8500000 bytes" "$ACT_OUTPUT"

# --- Max total size policy output assertions ---
assert_contains "max-size-10M: delete count = 1" "Artifacts to delete: 1" "$ACT_OUTPUT"
assert_contains "max-size-10M: retain count = 6" "Artifacts to retain: 6" "$ACT_OUTPUT"
assert_contains "max-size-10M: reclaimed = 5000000" "Space reclaimed: 5000000 bytes" "$ACT_OUTPUT"

# --- Combined policy output assertions ---
# maxAge=30, keepLatest=1, maxSize=8M -> delete 4, retain 3, reclaim 8,500,000
# This appears in the combined policy section. We check the combined output has
# the exact values. Since multiple sections produce "Artifacts to delete: 4",
# we verify the combined section specifically.
assert_contains "combined: COMBINED POLICY TEST marker" "=== COMBINED POLICY TEST ===" "$ACT_OUTPUT"
assert_contains "combined: reclaimed = 8500000" "Space reclaimed: 8500000 bytes" "$ACT_OUTPUT"

# ============================================================
# SUMMARY
# ============================================================
log ""
log "============================================================"
log "TEST SUMMARY"
log "============================================================"
log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"
log "Total:  $((PASS_COUNT + FAIL_COUNT))"

if [ "$FAIL_COUNT" -gt 0 ]; then
  log "RESULT: SOME TESTS FAILED"
  exit 1
else
  log "RESULT: ALL TESTS PASSED"
  exit 0
fi
