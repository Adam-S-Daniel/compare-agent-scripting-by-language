#!/usr/bin/env bash
# run-act-tests.sh — Act-based integration test harness
#
# Runs the GitHub Actions workflow through act (nektos/act) and asserts on
# exact expected values in the output.
#
# Requirements:
#   - act and Docker must be available
#   - .actrc in the project root configures the Docker image
#
# Output: appends all act output to act-result.txt (required artifact)
# Exit:   0 if all assertions pass, 1 on any failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

# Initialise (or truncate) the result file
: > "$ACT_RESULT"

# ── Helpers ────────────────────────────────────────────────────────────────

log() { echo "$*" | tee -a "$ACT_RESULT"; }

assert_contains() {
    local expected="$1"
    if grep -qF "$expected" "$ACT_RESULT"; then
        log "PASS: found expected value: $expected"
    else
        log "FAIL: expected value not found: $expected"
        echo "ERROR: assertion failed — expected '$expected' in act output" >&2
        exit 1
    fi
}

assert_no_bats_failures() {
    if grep -qE "^not ok " "$ACT_RESULT"; then
        log "FAIL: one or more bats tests failed"
        grep -E "^not ok " "$ACT_RESULT" | tee -a "$ACT_RESULT" >&2
        exit 1
    fi
    log "PASS: no bats test failures found"
}

# ── Set up a temporary git repository ────────────────────────────────────

TMPDIR="$(mktemp -d)"
# shellcheck disable=SC2064
trap 'rm -rf "$TMPDIR"' EXIT

log "=== Test Case 1: Full aggregation with all fixtures ==="
log "Setting up temp git repo in $TMPDIR"

# Copy project files into the temp repo
cp -r "$SCRIPT_DIR/." "$TMPDIR/"
# Remove any previous act-result.txt so it doesn't confuse assertions
rm -f "$TMPDIR/act-result.txt"

cd "$TMPDIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test Runner"
git add -A
git commit -q -m "ci: add test results aggregator for act run"

# ── Run act ───────────────────────────────────────────────────────────────

log ""
log "Running: act push --rm --pull=false"
log "--- act output start ---"

ACT_EXIT=0
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT" || ACT_EXIT=$?

log "--- act output end ---"
log ""

# Restore working directory
cd "$SCRIPT_DIR"

# ── Assert act exit code ──────────────────────────────────────────────────

if [ "$ACT_EXIT" -ne 0 ]; then
    log "FAIL: act exited with code $ACT_EXIT"
    echo "ERROR: act push failed with exit code $ACT_EXIT" >&2
    exit 1
fi
log "PASS: act exited with code 0"

# ── Assert all bats tests passed ──────────────────────────────────────────

assert_no_bats_failures

# ── Assert exact aggregated values ────────────────────────────────────────
# These match the known totals from the four fixture files:
#   junit-run1.xml  (Matrix-Ubuntu):  4 tests, 2 pass, 1 fail, 1 skip, 2.00s
#   junit-run2.xml  (Matrix-Windows): 4 tests, 2 pass, 1 fail, 1 skip, 2.50s
#   json-run3.json  (Matrix-Mac):     2 tests, 2 pass, 0 fail, 0 skip, 1.00s
#   json-run4.json  (Matrix-Node18):  2 tests, 1 pass, 1 fail, 0 skip, 1.50s
#   Grand totals:                    12 tests, 7 pass, 3 fail, 2 skip, 7.00s

assert_contains "| Total Tests | 12 |"
assert_contains "| Passed | 7 |"
assert_contains "| Failed | 3 |"
assert_contains "| Skipped | 2 |"
assert_contains "| Total Duration | 7.00s |"

# Assert flaky tests are identified
assert_contains "test-flaky"
assert_contains "| test-b |"
assert_contains "| test-d |"

# Assert all jobs succeeded
assert_contains "Job succeeded"

# ── Summary ───────────────────────────────────────────────────────────────

log ""
log "=== All assertions passed ==="
log "act-result.txt written to: $ACT_RESULT"
echo "SUCCESS: all tests passed via act"
