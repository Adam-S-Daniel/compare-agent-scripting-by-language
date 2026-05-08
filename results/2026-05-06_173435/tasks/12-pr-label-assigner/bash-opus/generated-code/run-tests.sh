#!/usr/bin/env bash
# Test harness: runs all tests through GitHub Actions via act
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="${SCRIPT_DIR}/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

true > "$RESULT_FILE"

log() { echo "[TEST] $*"; }
pass() { PASS_COUNT=$((PASS_COUNT + 1)); log "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); log "FAIL: $1 - $2"; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    pass "$label"
  else
    fail "$label" "expected to find '$needle'"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    fail "$label" "should not contain '$needle'"
  else
    pass "$label"
  fi
}

# ============================================================
# SECTION 1: Workflow Structure Tests (no act required)
# ============================================================
log "=== Workflow Structure Tests ==="

WORKFLOW_FILE="${SCRIPT_DIR}/.github/workflows/pr-label-assigner.yml"

# Test: workflow file exists
if [[ -f "$WORKFLOW_FILE" ]]; then
  pass "Workflow file exists"
else
  fail "Workflow file exists" "not found at $WORKFLOW_FILE"
fi

# Test: actionlint passes
actionlint_output=$(actionlint "$WORKFLOW_FILE" 2>&1) || true
if [[ -z "$actionlint_output" ]]; then
  pass "actionlint validation"
else
  fail "actionlint validation" "$actionlint_output"
fi

# Test: workflow has correct triggers
workflow_content=$(cat "$WORKFLOW_FILE")
assert_contains "$workflow_content" "push:" "Workflow has push trigger"
assert_contains "$workflow_content" "pull_request:" "Workflow has pull_request trigger"
assert_contains "$workflow_content" "workflow_dispatch:" "Workflow has workflow_dispatch trigger"

# Test: workflow references script files that exist
assert_contains "$workflow_content" "pr-label-assigner.sh" "Workflow references main script"
if [[ -f "${SCRIPT_DIR}/pr-label-assigner.sh" ]]; then
  pass "Main script file exists"
else
  fail "Main script file exists" "not found"
fi
if [[ -f "${SCRIPT_DIR}/label-rules.conf" ]]; then
  pass "Label rules config exists"
else
  fail "Label rules config exists" "not found"
fi

# Test: workflow has checkout step
assert_contains "$workflow_content" "actions/checkout@v4" "Workflow uses actions/checkout@v4"

# Test: workflow has jobs
assert_contains "$workflow_content" "jobs:" "Workflow has jobs section"
assert_contains "$workflow_content" "label-assigner:" "Workflow has label-assigner job"

# Test: workflow has permissions
assert_contains "$workflow_content" "permissions:" "Workflow has permissions section"

# Test: shellcheck and bash -n pass on main script
shellcheck_output=$(shellcheck "${SCRIPT_DIR}/pr-label-assigner.sh" 2>&1) || true
if [[ -z "$shellcheck_output" ]]; then
  pass "shellcheck passes on main script"
else
  fail "shellcheck passes on main script" "$shellcheck_output"
fi
if bash -n "${SCRIPT_DIR}/pr-label-assigner.sh" 2>&1; then
  pass "bash -n syntax check passes"
else
  fail "bash -n syntax check passes" "syntax error"
fi

{
  echo ""
  echo "=== WORKFLOW STRUCTURE TEST RESULTS ==="
  echo "Passed: $PASS_COUNT, Failed: $FAIL_COUNT"
  echo ""
} >> "$RESULT_FILE"

# ============================================================
# SECTION 2: Run all test cases through act
# ============================================================
log "=== Running act push ==="

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Set up a temp git repo with all project files
cp -r "${SCRIPT_DIR}/.github" "$TMPDIR/"
cp "${SCRIPT_DIR}/pr-label-assigner.sh" "$TMPDIR/"
cp "${SCRIPT_DIR}/label-rules.conf" "$TMPDIR/"
cp -r "${SCRIPT_DIR}/test-fixtures" "$TMPDIR/"
cp "${SCRIPT_DIR}/.actrc" "$TMPDIR/"

cd "$TMPDIR"
git init -b main --quiet
git add -A
git commit -m "test commit" --quiet

log "Running act push (this may take a minute)..."
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || ACT_EXIT=$?
ACT_EXIT=${ACT_EXIT:-0}

{
  echo "=== ACT RUN OUTPUT ==="
  echo "$ACT_OUTPUT"
  echo "=== END ACT RUN OUTPUT ==="
  echo ""
} >> "$RESULT_FILE"

cd "$SCRIPT_DIR"

# ============================================================
# SECTION 3: Validate act results
# ============================================================
log "=== Validating act results ==="

# Test: act exited successfully
if [[ "$ACT_EXIT" -eq 0 ]]; then
  pass "act push exited with code 0"
else
  fail "act push exited with code 0" "exit code was $ACT_EXIT"
fi

# Test: job succeeded
assert_contains "$ACT_OUTPUT" "Job succeeded" "Job shows succeeded"

# Test Case 1: docs-only → documentation, needs-review
assert_contains "$ACT_OUTPUT" "TEST CASE 1: docs-only" "Case 1 ran"
# docs/README.md and docs/guide/setup.md → documentation (docs/**) + needs-review (**)
# docs/*.md also matches documentation via **/*.md
assert_contains "$ACT_OUTPUT" "- documentation" "Case 1: has documentation label"
assert_contains "$ACT_OUTPUT" "- needs-review" "Case 1: has needs-review label"

# Test Case 2: mixed → documentation, api, tests, core, needs-review
assert_contains "$ACT_OUTPUT" "TEST CASE 2: mixed" "Case 2 ran"
assert_contains "$ACT_OUTPUT" "- api" "Case 2: has api label"
assert_contains "$ACT_OUTPUT" "- tests" "Case 2: has tests label"
assert_contains "$ACT_OUTPUT" "- core" "Case 2: has core label"

# Test Case 3: infra → ci, config, infrastructure, needs-review
assert_contains "$ACT_OUTPUT" "TEST CASE 3: infra" "Case 3 ran"
assert_contains "$ACT_OUTPUT" "- ci" "Case 3: has ci label"
assert_contains "$ACT_OUTPUT" "- config" "Case 3: has config label"
assert_contains "$ACT_OUTPUT" "- infrastructure" "Case 3: has infrastructure label"

# Test Case 4: priority conflict → api, tests, core, needs-review (ordered by priority)
assert_contains "$ACT_OUTPUT" "TEST CASE 4: priority" "Case 4 ran"
# src/api/users.test.ts matches: api(20), tests(30), core(40), needs-review(100)
assert_contains "$ACT_OUTPUT" "- api" "Case 4: has api label (priority 20)"
assert_contains "$ACT_OUTPUT" "- tests" "Case 4: has tests label (priority 30)"
assert_contains "$ACT_OUTPUT" "- core" "Case 4: has core label (priority 40)"

# Test Case 5: custom rules → critical-api, backend
assert_contains "$ACT_OUTPUT" "TEST CASE 5: custom-rules" "Case 5 ran"
assert_contains "$ACT_OUTPUT" "- critical-api" "Case 5: has critical-api label"
assert_contains "$ACT_OUTPUT" "- backend" "Case 5: has backend label"

# Test Case 6: error handling
assert_contains "$ACT_OUTPUT" "TEST CASE 6: error-missing-config" "Case 6 ran"
assert_contains "$ACT_OUTPUT" "Correctly failed with missing config" "Case 6: error handled correctly"

# Test Case 7: stdin input
assert_contains "$ACT_OUTPUT" "TEST CASE 7: stdin-input" "Case 7 ran"
assert_contains "$ACT_OUTPUT" "- tests" "Case 7: has tests label from stdin"
assert_contains "$ACT_OUTPUT" "- core" "Case 7: has core label from stdin"

# Test: syntax check passed
assert_contains "$ACT_OUTPUT" "SYNTAX_CHECK=pass" "Syntax validation passed in CI"

# Test: all test case sections completed
assert_contains "$ACT_OUTPUT" "All test cases completed successfully" "Summary step reached"

# ============================================================
# SECTION 4: Final summary
# ============================================================
{
  echo ""
  echo "=== FINAL TEST SUMMARY ==="
  echo "Total: $((PASS_COUNT + FAIL_COUNT)), Passed: $PASS_COUNT, Failed: $FAIL_COUNT"
} >> "$RESULT_FILE"

log ""
log "============================================"
log "Total: $((PASS_COUNT + FAIL_COUNT)), Passed: $PASS_COUNT, Failed: $FAIL_COUNT"
log "Results written to: $RESULT_FILE"
log "============================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
