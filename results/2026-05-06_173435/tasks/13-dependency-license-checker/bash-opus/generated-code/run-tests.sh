#!/usr/bin/env bash
# Test harness: runs all tests through GitHub Actions via act,
# validates output, and produces act-result.txt.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

: > "$RESULT_FILE"

log() { echo "[TEST-HARNESS] $*" | tee -a "$RESULT_FILE"; }
pass() { log "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { log "FAIL: $1 -- $2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# ---------- Workflow structure tests (no act needed) ----------

log "=========================================="
log "WORKFLOW STRUCTURE TESTS"
log "=========================================="

WORKFLOW="$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml"

# Test: workflow YAML exists
if [[ -f "$WORKFLOW" ]]; then
  pass "Workflow file exists"
else
  fail "Workflow file exists" "Not found at $WORKFLOW"
fi

# Test: actionlint passes
if actionlint "$WORKFLOW" 2>&1; then
  pass "actionlint passes with no errors"
else
  fail "actionlint passes" "actionlint reported errors"
fi

# Test: workflow has expected triggers
if grep -q "push:" "$WORKFLOW" && grep -q "pull_request:" "$WORKFLOW" && grep -q "workflow_dispatch:" "$WORKFLOW"; then
  pass "Workflow has push, pull_request, and workflow_dispatch triggers"
else
  fail "Workflow triggers" "Missing expected trigger events"
fi

# Test: workflow has license-check job
if grep -q "license-check:" "$WORKFLOW"; then
  pass "Workflow defines license-check job"
else
  fail "Workflow job" "Missing license-check job"
fi

# Test: workflow references checkout action
if grep -q "actions/checkout@v4" "$WORKFLOW"; then
  pass "Workflow uses actions/checkout@v4"
else
  fail "Checkout action" "Missing actions/checkout@v4"
fi

# Test: workflow references the main script
if grep -q "dependency-license-checker.sh" "$WORKFLOW"; then
  pass "Workflow references dependency-license-checker.sh"
else
  fail "Script reference" "Workflow doesn't reference the main script"
fi

# Test: workflow references bats test file
if grep -q "dependency-license-checker.bats" "$WORKFLOW"; then
  pass "Workflow references bats test file"
else
  fail "Bats reference" "Workflow doesn't reference bats tests"
fi

# Test: all referenced script files exist
for f in dependency-license-checker.sh license-db.sh test/dependency-license-checker.bats; do
  if [[ -f "$SCRIPT_DIR/$f" ]]; then
    pass "Referenced file exists: $f"
  else
    fail "Referenced file exists" "$f not found"
  fi
done

log ""
log "=========================================="
log "ACT INTEGRATION TEST"
log "=========================================="

# Set up a temp git repo with all project files for act
TMPDIR_ACT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ACT"' EXIT

cp -r "$SCRIPT_DIR"/.github "$TMPDIR_ACT/"
cp -r "$SCRIPT_DIR"/test "$TMPDIR_ACT/"
cp "$SCRIPT_DIR"/dependency-license-checker.sh "$TMPDIR_ACT/"
cp "$SCRIPT_DIR"/license-db.sh "$TMPDIR_ACT/"
cp "$SCRIPT_DIR"/.actrc "$TMPDIR_ACT/" 2>/dev/null || true

cd "$TMPDIR_ACT"
git init -q
git add -A
git commit -q -m "test commit"

log "Running act push --rm --pull=false in $TMPDIR_ACT ..."
ACT_OUTPUT=""
ACT_EXIT=0
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || ACT_EXIT=$?

echo "" >> "$RESULT_FILE"
echo "=========================================" >> "$RESULT_FILE"
echo "ACT RAW OUTPUT" >> "$RESULT_FILE"
echo "=========================================" >> "$RESULT_FILE"
echo "$ACT_OUTPUT" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"
echo "=========================================" >> "$RESULT_FILE"
echo "END ACT RAW OUTPUT" >> "$RESULT_FILE"
echo "=========================================" >> "$RESULT_FILE"

log "Act exit code: $ACT_EXIT"

# Test: act exited successfully
if [[ "$ACT_EXIT" -eq 0 ]]; then
  pass "act push exited with code 0"
else
  fail "act push exit code" "Expected 0, got $ACT_EXIT"
fi

# Test: job succeeded
if echo "$ACT_OUTPUT" | grep -qi "Job succeeded"; then
  pass "Job reports success"
else
  fail "Job succeeded" "No 'Job succeeded' message in act output"
fi

# Test: bats tests ran and all 21 passed (TAP format: "ok N ...")
if echo "$ACT_OUTPUT" | grep -q "ok 21 "; then
  if echo "$ACT_OUTPUT" | grep -q "not ok"; then
    fail "Bats test results" "Found failing tests ('not ok') in output"
  else
    pass "All 21 bats tests passed"
  fi
else
  fail "Bats test results" "Did not find all 21 tests passing in output"
fi

# Test: package.json check produced expected output
if echo "$ACT_OUTPUT" | grep -q "=== Dependency License Compliance Report ==="; then
  pass "Compliance report header present in output"
else
  fail "Compliance report" "Report header not found"
fi

# Test: express was detected with MIT/approved
if echo "$ACT_OUTPUT" | grep -q "express.*MIT"; then
  pass "express dependency detected with MIT license"
else
  fail "express detection" "express/MIT not found in output"
fi

# Test: mysql-connector was detected with GPL-2.0
if echo "$ACT_OUTPUT" | grep -q "mysql-connector.*GPL-2.0"; then
  pass "mysql-connector detected with GPL-2.0 license"
else
  fail "mysql-connector detection" "mysql-connector/GPL-2.0 not found"
fi

# Test: package.json summary shows Total: 4, Approved: 3, Denied: 1
if echo "$ACT_OUTPUT" | grep -q "Total: 4"; then
  pass "package.json total count is 4"
else
  fail "package.json total" "Expected Total: 4"
fi

if echo "$ACT_OUTPUT" | grep -q "Approved: 3"; then
  pass "package.json approved count is 3"
else
  fail "package.json approved" "Expected Approved: 3"
fi

if echo "$ACT_OUTPUT" | grep -q "Denied: 1"; then
  pass "package.json denied count is 1"
else
  fail "package.json denied" "Expected Denied: 1"
fi

# Test: FAIL result for package.json (has denied deps)
if echo "$ACT_OUTPUT" | grep -q "RESULT: FAIL - Denied licenses found"; then
  pass "FAIL result reported for manifest with denied deps"
else
  fail "FAIL result" "Expected FAIL result"
fi

# Test: requirements.txt deps detected
if echo "$ACT_OUTPUT" | grep -q "flask.*BSD-3-Clause"; then
  pass "flask detected with BSD-3-Clause license"
else
  fail "flask detection" "flask/BSD-3-Clause not found"
fi

if echo "$ACT_OUTPUT" | grep -q "requests.*Apache-2.0"; then
  pass "requests detected with Apache-2.0 license"
else
  fail "requests detection" "requests/Apache-2.0 not found"
fi

if echo "$ACT_OUTPUT" | grep -q "gpl-package.*GPL-3.0"; then
  pass "gpl-package detected with GPL-3.0 license"
else
  fail "gpl-package detection" "gpl-package/GPL-3.0 not found"
fi

# Test: clean package shows PASS
if echo "$ACT_OUTPUT" | grep -q "RESULT: PASS - All dependencies approved"; then
  pass "PASS result reported for clean manifest"
else
  fail "PASS result" "Expected PASS result for clean package"
fi

# Test: shellcheck/bash -n validation step ran
if echo "$ACT_OUTPUT" | grep -qi "Validate scripts"; then
  pass "Script validation step executed"
else
  fail "Script validation" "Validation step not found in output"
fi

cd "$SCRIPT_DIR"

log ""
log "=========================================="
log "FINAL RESULTS"
log "=========================================="
log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"
log "Total:  $((PASS_COUNT + FAIL_COUNT))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  log "OVERALL: SOME TESTS FAILED"
  exit 1
else
  log "OVERALL: ALL TESTS PASSED"
  exit 0
fi
