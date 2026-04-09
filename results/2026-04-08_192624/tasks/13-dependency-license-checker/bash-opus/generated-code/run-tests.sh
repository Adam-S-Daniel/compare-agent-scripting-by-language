#!/usr/bin/env bash
# run-tests.sh — Test harness that validates the workflow structure and
# runs all test cases through act, capturing output to act-result.txt.
#
# This script:
# 1. Validates workflow YAML structure (triggers, jobs, steps, file refs)
# 2. Runs actionlint
# 3. Sets up a temp git repo for each test case, runs act, captures output
# 4. Asserts exact expected values in the act output
# 5. Appends all output to act-result.txt

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="${SCRIPT_DIR}/act-result.txt"
WORKFLOW="${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
PASS=0
FAIL=0

# Clear result file
: > "$RESULT_FILE"

log() {
  echo "$*" | tee -a "$RESULT_FILE"
}

log_divider() {
  log ""
  log "================================================================"
  log "  $1"
  log "================================================================"
  log ""
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    log "  PASS: $label"
    PASS=$(( PASS + 1 ))
  else
    log "  FAIL: $label — expected to find: '$needle'"
    FAIL=$(( FAIL + 1 ))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    log "  FAIL: $label — expected NOT to find: '$needle'"
    FAIL=$(( FAIL + 1 ))
  else
    log "  PASS: $label"
    PASS=$(( PASS + 1 ))
  fi
}

assert_exit_code() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    log "  PASS: $label (exit code $actual)"
    PASS=$(( PASS + 1 ))
  else
    log "  FAIL: $label — expected exit $expected, got $actual"
    FAIL=$(( FAIL + 1 ))
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PART 1: WORKFLOW STRUCTURE TESTS
# ══════════════════════════════════════════════════════════════════════════════

log_divider "WORKFLOW STRUCTURE TESTS"

# Test: workflow file exists
if [[ -f "$WORKFLOW" ]]; then
  log "  PASS: Workflow file exists at .github/workflows/dependency-license-checker.yml"
  PASS=$(( PASS + 1 ))
else
  log "  FAIL: Workflow file not found"
  FAIL=$(( FAIL + 1 ))
fi

# Read workflow content
WF_CONTENT="$(cat "$WORKFLOW")"

# Test: triggers
assert_contains "Workflow has push trigger" "push:" "$WF_CONTENT"
assert_contains "Workflow has pull_request trigger" "pull_request:" "$WF_CONTENT"
assert_contains "Workflow has workflow_dispatch trigger" "workflow_dispatch:" "$WF_CONTENT"

# Test: jobs
assert_contains "Job check-licenses-packagejson exists" "check-licenses-packagejson:" "$WF_CONTENT"
assert_contains "Job check-licenses-requirements exists" "check-licenses-requirements:" "$WF_CONTENT"
assert_contains "Job run-bats-tests exists" "run-bats-tests:" "$WF_CONTENT"
assert_contains "Job error-handling exists" "error-handling:" "$WF_CONTENT"

# Test: uses checkout action
assert_contains "Uses actions/checkout@v4" "actions/checkout@v4" "$WF_CONTENT"

# Test: references correct script files
assert_contains "References dependency-license-checker.sh" "dependency-license-checker.sh" "$WF_CONTENT"
assert_contains "References test/fixtures/package.json" "test/fixtures/package.json" "$WF_CONTENT"
assert_contains "References test/fixtures/requirements.txt" "test/fixtures/requirements.txt" "$WF_CONTENT"
assert_contains "References test/fixtures/license-config.json" "test/fixtures/license-config.json" "$WF_CONTENT"
assert_contains "References test/fixtures/mock-licenses.json" "test/fixtures/mock-licenses.json" "$WF_CONTENT"

# Test: referenced files exist
for f in dependency-license-checker.sh test/fixtures/package.json test/fixtures/requirements.txt test/fixtures/license-config.json test/fixtures/mock-licenses.json test/dependency-license-checker.bats; do
  if [[ -f "${SCRIPT_DIR}/$f" ]]; then
    log "  PASS: Referenced file exists: $f"
    PASS=$(( PASS + 1 ))
  else
    log "  FAIL: Referenced file missing: $f"
    FAIL=$(( FAIL + 1 ))
  fi
done

# Test: permissions
assert_contains "Has permissions block" "permissions:" "$WF_CONTENT"
assert_contains "Has contents: read permission" "contents: read" "$WF_CONTENT"

# Test: actionlint
log ""
log "  Running actionlint..."
actionlint_output="$(actionlint "$WORKFLOW" 2>&1)" || true
if [[ -z "$actionlint_output" ]]; then
  log "  PASS: actionlint passes with no errors"
  PASS=$(( PASS + 1 ))
else
  log "  FAIL: actionlint found errors: $actionlint_output"
  FAIL=$(( FAIL + 1 ))
fi

# ══════════════════════════════════════════════════════════════════════════════
# PART 2: ACT TEST CASES
# ══════════════════════════════════════════════════════════════════════════════

# Helper: set up a temp git repo with all project files and run act
run_act_job() {
  local job_name="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"

  # Copy project files into temp repo
  cp -r "$SCRIPT_DIR/.github" "$tmpdir/"
  cp "$SCRIPT_DIR/dependency-license-checker.sh" "$tmpdir/"
  cp -r "$SCRIPT_DIR/test" "$tmpdir/"
  chmod +x "$tmpdir/dependency-license-checker.sh"

  # Initialise a git repo (act requires it for checkout)
  cd "$tmpdir" || exit
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -q -m "init"

  # Run act for the specific job
  local act_output
  local act_exit
  act_output="$(act push --rm -j "$job_name" --container-architecture linux/amd64 2>&1)" && act_exit=0 || act_exit=$?

  # Return to original dir and clean up
  cd "$SCRIPT_DIR" || exit
  rm -rf "$tmpdir"

  # Return output and exit code via globals
  ACT_OUTPUT="$act_output"
  ACT_EXIT="$act_exit"
}

# ── Test Case 1: package.json license check ──────────────────────────────────

log_divider "TEST CASE 1: check-licenses-packagejson (via act)"

run_act_job "check-licenses-packagejson"
log "$ACT_OUTPUT"
log ""

assert_exit_code "act exits 0 for package.json job" 0 "$ACT_EXIT"
assert_contains "Job succeeded for package.json" "Job succeeded" "$ACT_OUTPUT"
assert_contains "Syntax validation passed" "Syntax validation passed" "$ACT_OUTPUT"

# Exact expected values from package.json fixture
assert_contains "express is MIT approved" "express" "$ACT_OUTPUT"
assert_contains "lodash is MIT approved" "lodash" "$ACT_OUTPUT"
assert_contains "left-pad has WTFPL unknown" "left-pad" "$ACT_OUTPUT"
assert_contains "jest is MIT approved" "jest" "$ACT_OUTPUT"
assert_contains "Total is 4" "Total: 4" "$ACT_OUTPUT"
assert_contains "Approved count is 3" "Approved: 3" "$ACT_OUTPUT"
assert_contains "Denied count is 0" "Denied: 0" "$ACT_OUTPUT"
assert_contains "Unknown count is 1" "Unknown: 1" "$ACT_OUTPUT"

# JSON output assertions
assert_contains "JSON has total 4" '"total": 4' "$ACT_OUTPUT"
assert_contains "JSON has approved 3" '"approved": 3' "$ACT_OUTPUT"
assert_contains "JSON has denied 0" '"denied": 0' "$ACT_OUTPUT"
assert_contains "JSON has unknown 1" '"unknown": 1' "$ACT_OUTPUT"
assert_contains "JSON has express entry" '"name": "express"' "$ACT_OUTPUT"

# ── Test Case 2: requirements.txt license check ─────────────────────────────

log_divider "TEST CASE 2: check-licenses-requirements (via act)"

run_act_job "check-licenses-requirements"
log "$ACT_OUTPUT"
log ""

assert_exit_code "act exits 0 for requirements job" 0 "$ACT_EXIT"
assert_contains "Job succeeded for requirements" "Job succeeded" "$ACT_OUTPUT"

# Exact values from requirements.txt fixture
assert_contains "requests is Apache-2.0 approved" "Apache-2.0" "$ACT_OUTPUT"
assert_contains "flask is BSD-3-Clause approved" "BSD-3-Clause" "$ACT_OUTPUT"
assert_contains "cryptography is GPL-3.0 denied" "GPL-3.0" "$ACT_OUTPUT"
assert_contains "Shows denied deps message" "denied dependencies" "$ACT_OUTPUT"
assert_contains "Total is 4 for requirements" "Total: 4" "$ACT_OUTPUT"
assert_contains "Approved 3 for requirements" "Approved: 3" "$ACT_OUTPUT"
assert_contains "Denied 1 for requirements" "Denied: 1" "$ACT_OUTPUT"

# ── Test Case 3: bats test suite ─────────────────────────────────────────────

log_divider "TEST CASE 3: run-bats-tests (via act)"

run_act_job "run-bats-tests"
log "$ACT_OUTPUT"
log ""

assert_exit_code "act exits 0 for bats job" 0 "$ACT_EXIT"
assert_contains "Job succeeded for bats" "Job succeeded" "$ACT_OUTPUT"

# Verify specific bats test results
assert_contains "Bats ok 1" "ok 1" "$ACT_OUTPUT"
assert_contains "Bats reports 18 tests" "1..18" "$ACT_OUTPUT"
assert_not_contains "No bats failures" "not ok" "$ACT_OUTPUT"

# ── Test Case 4: error handling ──────────────────────────────────────────────

log_divider "TEST CASE 4: error-handling (via act)"

run_act_job "error-handling"
log "$ACT_OUTPUT"
log ""

assert_exit_code "act exits 0 for error-handling job" 0 "$ACT_EXIT"
assert_contains "Job succeeded for error-handling" "Job succeeded" "$ACT_OUTPUT"
assert_contains "Missing manifest error handled" "correctly errored on missing --manifest" "$ACT_OUTPUT"
assert_contains "Unsupported manifest error handled" "correctly errored on unsupported manifest" "$ACT_OUTPUT"

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

log_divider "TEST SUMMARY"
TOTAL=$(( PASS + FAIL ))
log "Total: $TOTAL | Passed: $PASS | Failed: $FAIL"
log ""

if [[ $FAIL -gt 0 ]]; then
  log "RESULT: SOME TESTS FAILED"
  exit 1
else
  log "RESULT: ALL TESTS PASSED"
  exit 0
fi
