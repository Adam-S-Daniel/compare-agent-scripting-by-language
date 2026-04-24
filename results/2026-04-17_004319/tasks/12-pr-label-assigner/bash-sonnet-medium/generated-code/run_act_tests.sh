#!/usr/bin/env bash
# Test harness: runs the GitHub Actions workflow via act and validates output.
# Writes all act output to act-result.txt in the current working directory.

set -uo pipefail

RESULT_FILE="$(pwd)/act-result.txt"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILURES=0

log() { echo "[harness] $*"; }
fail() { echo "[FAIL] $*" >&2; FAILURES=$((FAILURES + 1)); }

# Clear result file
true > "$RESULT_FILE"

delimiter() {
  local label="$1"
  printf '\n%s\n%s\n%s\n' \
    "================================================================" \
    "TEST CASE: $label" \
    "================================================================" \
    >> "$RESULT_FILE"
}

run_act() {
  local label="$1"
  delimiter "$label"
  log "Running act for: $label"

  # Run act; capture exit code; tee output to result file
  set +e
  act push --rm 2>&1 | tee -a "$RESULT_FILE"
  local exit_code="${PIPESTATUS[0]}"
  set -e

  log "act exit code: $exit_code"
  echo "ACT_EXIT_CODE=$exit_code" >> "$RESULT_FILE"
  echo "$exit_code"
}

# ── Run act (single run covers all jobs) ─────────────────────────────────────
cd "$SCRIPT_DIR"

log "Starting act run — this runs all workflow jobs"
exit_code=$(run_act "Full workflow: test-structure + run-tests + integration-test")

# ── Assertions ────────────────────────────────────────────────────────────────
log "Asserting act exit code = 0"
if [ "$exit_code" -ne 0 ]; then
  fail "act exited with code $exit_code (expected 0)"
else
  log "PASS: act exit code = 0"
fi

log "Asserting 'Job succeeded' appears in output"
job_succeeded_count=$(grep -c "Job succeeded" "$RESULT_FILE" 2>/dev/null || echo 0)
if [ "$job_succeeded_count" -lt 1 ]; then
  fail "Expected at least 1 'Job succeeded' marker, found $job_succeeded_count"
else
  log "PASS: Found $job_succeeded_count 'Job succeeded' markers"
fi

log "Asserting integration test labels are correct"
if grep -q "documentation" "$RESULT_FILE" && grep -q "api" "$RESULT_FILE" && grep -q "tests" "$RESULT_FILE"; then
  log "PASS: Expected labels found in act output"
else
  fail "Expected labels (documentation, api, tests) not all found in act output"
fi

log "Asserting priority ordering test passed"
if grep -q "Priority ordering test passed" "$RESULT_FILE"; then
  log "PASS: Priority ordering confirmed"
else
  fail "Priority ordering test output not found"
fi

log "Asserting no-match scenario passed"
if grep -q "No-match scenario passed" "$RESULT_FILE"; then
  log "PASS: No-match scenario confirmed"
else
  fail "No-match scenario output not found"
fi

log "Asserting bats tests passed"
if grep -q "17 tests, 0 failures" "$RESULT_FILE" || grep -q "ok 17" "$RESULT_FILE"; then
  log "PASS: All bats tests passed"
else
  fail "Could not confirm all 17 bats tests passed in act output"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "" >> "$RESULT_FILE"
echo "HARNESS SUMMARY: FAILURES=$FAILURES" >> "$RESULT_FILE"

log "Results written to: $RESULT_FILE"

if [ "$FAILURES" -eq 0 ]; then
  log "ALL ASSERTIONS PASSED"
  exit 0
else
  log "FAILURES: $FAILURES assertion(s) failed"
  exit 1
fi
