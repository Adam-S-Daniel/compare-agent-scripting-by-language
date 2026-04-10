#!/usr/bin/env bash
# run-tests.sh — External test harness: validates workflow structure locally,
# then runs the GitHub Actions workflow through `act` and asserts on exact
# expected output values.
#
# Output:  act-result.txt  (required artifact)
# Exit 0 if all assertions pass, non-zero otherwise.

set -euo pipefail

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="${WORK_DIR}/act-result.txt"
ACT_RAW_FILE=""   # filled in once the tmpdir is created
FAIL=0

# Helper: append a message to act-result.txt and echo to stdout.
log() { echo "$*" | tee -a "$ACT_RESULT_FILE"; }

# Helper: assert that ACT_RAW_FILE contains the given string.
# Only searches the raw act output, not the assertion messages themselves,
# to avoid false positives.
assert_contains() {
  local marker="$1"
  local description="$2"
  if grep -qF "$marker" "$ACT_RAW_FILE"; then
    log "PASS: ${description}"
  else
    log "FAIL: ${description} — expected '${marker}' not found in act output"
    FAIL=1
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight: local validations (instant, no Docker needed)
# ---------------------------------------------------------------------------

# Clear / create the result file
: > "$ACT_RESULT_FILE"
log "========================================================"
log "Environment Matrix Generator — Test Harness"
log "========================================================"
log ""

# 1. actionlint
log "--- actionlint validation ---"
WORKFLOW="${WORK_DIR}/.github/workflows/environment-matrix-generator.yml"
if actionlint "$WORKFLOW" 2>&1 | tee -a "$ACT_RESULT_FILE"; then
  log "ACTIONLINT_PASS=true"
else
  log "ACTIONLINT_PASS=false"
  FAIL=1
fi
log ""

# 2. Verify script is executable and passes shellcheck
log "--- shellcheck / bash -n validation ---"
if bash -n "${WORK_DIR}/generate-matrix.sh" && shellcheck "${WORK_DIR}/generate-matrix.sh"; then
  log "SHELLCHECK_PASS=true"
else
  log "SHELLCHECK_PASS=false"
  FAIL=1
fi
log ""

# ---------------------------------------------------------------------------
# Set up a throwaway git repo and run act
# ---------------------------------------------------------------------------

TMPDIR_ACT=$(mktemp -d)
# Ensure cleanup even on error.
# shellcheck disable=SC2064
trap 'rm -rf "$TMPDIR_ACT"' EXIT

log "--- Setting up temp git repo for act run ---"

# Copy all workspace files (including .actrc so act uses the custom container).
cp -r "${WORK_DIR}/." "${TMPDIR_ACT}/"

cd "$TMPDIR_ACT"

git init -q
git config user.email "test@test.com"
git config user.name "Test User"
git add -A
git commit -q -m "test: run environment matrix generator tests"

ACT_RAW_FILE="${TMPDIR_ACT}/act-raw.txt"

log ""
log "=== ACT RUN: environment-matrix-generator ==="
log ""

# Run act; tee raw output to ACT_RAW_FILE and also to the result file.
ACT_EXIT=0
act push --rm --pull=false 2>&1 | tee "$ACT_RAW_FILE" | tee -a "$ACT_RESULT_FILE" || ACT_EXIT=$?

log ""
log "=== ACT EXIT CODE: ${ACT_EXIT} ==="
log ""

if [ "$ACT_EXIT" -ne 0 ]; then
  log "FAIL: act exited with code ${ACT_EXIT}"
  FAIL=1
fi

# Return to original dir so relative paths in assertions are stable.
cd "$WORK_DIR"

# ---------------------------------------------------------------------------
# Parse act output and assert EXACT expected values
# ---------------------------------------------------------------------------

log "--- Assertions ---"

# Workflow job succeeded
assert_contains "Job succeeded" "Workflow job succeeded"

# Fixture 1 — basic 2-OS x 2-node matrix (4 combos)
assert_contains "FIXTURE1_COUNT=4"          "Fixture 1: combination count = 4"
assert_contains "FIXTURE1_FAILFAST=false"   "Fixture 1: fail-fast = false"
assert_contains "FIXTURE1_MAXPARALLEL=4"    "Fixture 1: max-parallel = 4"
assert_contains "FIXTURE1_VERIFIED=PASS"    "Fixture 1: all checks passed"

# Fixture 2 — excludes/includes (4 combos after rules)
assert_contains "FIXTURE2_COUNT=4"          "Fixture 2: combination count = 4"
assert_contains "FIXTURE2_FAILFAST=true"    "Fixture 2: fail-fast = true"
assert_contains "FIXTURE2_MAXPARALLEL=2"    "Fixture 2: max-parallel = 2"
assert_contains "FIXTURE2_VERIFIED=PASS"    "Fixture 2: all checks passed"

# Fixture 3 — max size exceeded (expects error)
assert_contains "FIXTURE3_ERROR=exceeds maximum"  "Fixture 3: correct error raised"
assert_contains "FIXTURE3_VERIFIED=PASS"          "Fixture 3: error handling verified"

# Fixture 4 — feature flags (2 combos)
assert_contains "FIXTURE4_COUNT=2"          "Fixture 4: combination count = 2"
assert_contains "FIXTURE4_VERIFIED=PASS"    "Fixture 4: all checks passed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
if [ "$FAIL" -eq 0 ]; then
  log "ALL TESTS PASSED"
  exit 0
else
  log "SOME TESTS FAILED — review act-result.txt for details"
  exit 1
fi
