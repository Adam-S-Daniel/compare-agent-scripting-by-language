#!/usr/bin/env bash
set -euo pipefail

# Test harness that runs all tests through the GitHub Actions workflow via act.
# Creates a temp git repo, runs act, captures output, and validates results.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

: > "$RESULT_FILE"

log() { echo "[HARNESS] $1" | tee -a "$RESULT_FILE"; }
fail_test() { echo "FAIL: $1" | tee -a "$RESULT_FILE"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
pass_test() { echo "PASS: $1" | tee -a "$RESULT_FILE"; PASS_COUNT=$((PASS_COUNT + 1)); }

# ===== Workflow structure tests =====

log "=========================================="
log "WORKFLOW STRUCTURE TESTS"
log "=========================================="

WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"

# Test: workflow file exists
if [[ -f "$WORKFLOW_FILE" ]]; then
  pass_test "Workflow file exists at .github/workflows/secret-rotation-validator.yml"
else
  fail_test "Workflow file not found"
fi

# Test: workflow has expected triggers
for trigger in push pull_request schedule workflow_dispatch; do
  if grep -q "$trigger" "$WORKFLOW_FILE"; then
    pass_test "Workflow contains trigger: $trigger"
  else
    fail_test "Workflow missing trigger: $trigger"
  fi
done

# Test: workflow has validate job
if grep -q "validate:" "$WORKFLOW_FILE"; then
  pass_test "Workflow contains 'validate' job"
else
  fail_test "Workflow missing 'validate' job"
fi

# Test: workflow references script file
if grep -q "secret-rotation-validator.sh" "$WORKFLOW_FILE"; then
  pass_test "Workflow references secret-rotation-validator.sh"
else
  fail_test "Workflow does not reference secret-rotation-validator.sh"
fi

# Test: script file exists
if [[ -f "$SCRIPT_DIR/secret-rotation-validator.sh" ]]; then
  pass_test "Script file secret-rotation-validator.sh exists"
else
  fail_test "Script file secret-rotation-validator.sh not found"
fi

# Test: test fixture files exist
for fixture in basic-secrets.json all-expired.json all-ok.json empty-secrets.json; do
  if [[ -f "$SCRIPT_DIR/test/fixtures/$fixture" ]]; then
    pass_test "Test fixture exists: $fixture"
  else
    fail_test "Test fixture missing: $fixture"
  fi
done

# Test: bats test file exists
if [[ -f "$SCRIPT_DIR/test/secret-rotation-validator.bats" ]]; then
  pass_test "Bats test file exists"
else
  fail_test "Bats test file not found"
fi

# Test: actionlint passes
if actionlint "$WORKFLOW_FILE" 2>&1; then
  pass_test "actionlint passes with no errors"
else
  fail_test "actionlint found errors"
fi

# Test: uses actions/checkout@v4
if grep -q "actions/checkout@v4" "$WORKFLOW_FILE"; then
  pass_test "Workflow uses actions/checkout@v4"
else
  fail_test "Workflow does not use actions/checkout@v4"
fi

# Test: workflow installs bats
if grep -q "bats" "$WORKFLOW_FILE"; then
  pass_test "Workflow installs/references bats"
else
  fail_test "Workflow does not reference bats"
fi

# ===== Act execution test =====

log ""
log "=========================================="
log "ACT EXECUTION TEST"
log "=========================================="

TMPDIR_ACT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ACT"' EXIT

log "Creating temp git repo at $TMPDIR_ACT"

cp -r "$SCRIPT_DIR/.github" "$TMPDIR_ACT/"
cp "$SCRIPT_DIR/secret-rotation-validator.sh" "$TMPDIR_ACT/"
cp -r "$SCRIPT_DIR/test" "$TMPDIR_ACT/"
cp "$SCRIPT_DIR/.actrc" "$TMPDIR_ACT/" 2>/dev/null || true

cd "$TMPDIR_ACT"
git init -q
git add -A
git commit -q -m "initial"

log "Running act push --rm ..."
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || true

{
  echo ""
  echo "========================================="
  echo "ACT RAW OUTPUT"
  echo "========================================="
  echo "$ACT_OUTPUT"
  echo ""
} >> "$RESULT_FILE"

cd "$SCRIPT_DIR"

log ""
log "=========================================="
log "ACT OUTPUT VALIDATION"
log "=========================================="

# Test: act completed
if echo "$ACT_OUTPUT" | grep -q "Job succeeded"; then
  pass_test "Act job succeeded"
else
  fail_test "Act job did not succeed"
fi

# Test: bats tests ran and all 28 passed
if echo "$ACT_OUTPUT" | grep -q "ok 28"; then
  pass_test "All 28 bats tests executed"
else
  fail_test "Not all 28 bats tests appeared in output"
fi

# Validate specific bats test results appeared
for test_desc in \
  "exits with error when no --config provided" \
  "basic secrets: classifies DB_PASSWORD as expired" \
  "basic secrets: classifies API_KEY as warning" \
  "basic secrets: classifies TLS_CERT as ok" \
  "basic secrets: summary counts are correct" \
  "all-expired: exit code is 2" \
  "all-ok: exit code is 0" \
  "empty secrets: handles empty array gracefully" \
  "json output: days_since_rotation is correct for DB_PASSWORD" \
  "markdown output: contains report header" \
  "exit code 1 when only warning secrets exist"; do
  if echo "$ACT_OUTPUT" | grep -qF "$test_desc"; then
    pass_test "Bats test output found: $test_desc"
  else
    fail_test "Bats test output missing: $test_desc"
  fi
done

# Test: markdown report appeared with correct header
if echo "$ACT_OUTPUT" | grep -qF "# Secret Rotation Report"; then
  pass_test "Markdown report header present in output"
else
  fail_test "Markdown report header missing"
fi

# Test: markdown report has correct reference date
if echo "$ACT_OUTPUT" | grep -qF "**Reference Date:** 2026-05-07"; then
  pass_test "Markdown report has reference date 2026-05-07"
else
  fail_test "Markdown report missing reference date 2026-05-07"
fi

# Test: markdown report shows correct expired count
if echo "$ACT_OUTPUT" | grep -qF "**Expired:** 1"; then
  pass_test "Markdown report shows Expired: 1"
else
  fail_test "Markdown report missing Expired: 1"
fi

# Test: markdown report shows DB_PASSWORD in table
if echo "$ACT_OUTPUT" | grep -qF "DB_PASSWORD"; then
  pass_test "Markdown report contains DB_PASSWORD"
else
  fail_test "Markdown report missing DB_PASSWORD"
fi

# Test: JSON output contains correct expired count for basic secrets
if echo "$ACT_OUTPUT" | grep -q '"expired": 1'; then
  pass_test "JSON output has expired: 1 for basic secrets"
else
  fail_test "JSON output missing expired: 1"
fi

# Test: JSON output contains correct days_since for DB_PASSWORD
if echo "$ACT_OUTPUT" | grep -q '"days_since_rotation": 112'; then
  pass_test "JSON output has days_since_rotation: 112 for DB_PASSWORD"
else
  fail_test "JSON output missing days_since_rotation: 112"
fi

# Test: JSON output has correct expiry_date for DB_PASSWORD
if echo "$ACT_OUTPUT" | grep -q '"expiry_date": "2026-04-15"'; then
  pass_test "JSON output has expiry_date: 2026-04-15 for DB_PASSWORD"
else
  fail_test "JSON output missing expiry_date: 2026-04-15"
fi

# Test: all-expired run shows 2 expired
if echo "$ACT_OUTPUT" | grep -q '"expired": 2'; then
  pass_test "All-expired fixture shows expired: 2"
else
  fail_test "All-expired fixture missing expired: 2"
fi

# Test: all-ok run shows 2 ok
if echo "$ACT_OUTPUT" | grep -q '"ok": 2'; then
  pass_test "All-ok fixture shows ok: 2"
else
  fail_test "All-ok fixture missing ok: 2"
fi

# Test: empty secrets run shows 0 total
if echo "$ACT_OUTPUT" | grep -q '"total_secrets": 0'; then
  pass_test "Empty fixture shows total_secrets: 0"
else
  fail_test "Empty fixture missing total_secrets: 0"
fi

# Test: API_KEY appears in warning section of JSON
if echo "$ACT_OUTPUT" | grep -q '"name": "API_KEY"'; then
  pass_test "API_KEY appears in JSON output"
else
  fail_test "API_KEY missing from JSON output"
fi

# Test: required_by services appear
if echo "$ACT_OUTPUT" | grep -q "api-server"; then
  pass_test "Required-by service 'api-server' appears in output"
else
  fail_test "Required-by service 'api-server' missing"
fi

# ===== Summary =====

log ""
log "=========================================="
log "TEST SUMMARY"
log "=========================================="
log "PASSED: $PASS_COUNT"
log "FAILED: $FAIL_COUNT"
log "TOTAL:  $((PASS_COUNT + FAIL_COUNT))"

if [[ $FAIL_COUNT -gt 0 ]]; then
  log "RESULT: SOME TESTS FAILED"
  exit 1
else
  log "RESULT: ALL TESTS PASSED"
  exit 0
fi
