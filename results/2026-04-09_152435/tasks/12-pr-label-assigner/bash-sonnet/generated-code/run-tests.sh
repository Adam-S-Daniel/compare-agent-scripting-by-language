#!/usr/bin/env bash
# run-tests.sh
#
# Act-based test harness for the PR Label Assigner GitHub Actions workflow.
#
# Workflow:
#   1. Copy project files into a temp git repo
#   2. Run `act push --rm` once — all test cases execute inside the workflow
#   3. Capture full act output to act-result.txt
#   4. Assert exit code 0 (every job succeeded)
#   5. Assert on exact expected values in the output
#
# Usage: bash run-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="${SCRIPT_DIR}/act-result.txt"
FAILURES=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "=== $* ===" | tee -a "$ACT_RESULT_FILE"; }
pass() { echo "PASS: $*" | tee -a "$ACT_RESULT_FILE"; }
fail() { echo "FAIL: $*" | tee -a "$ACT_RESULT_FILE"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
    local description="$1"
    local expected="$2"
    if grep -q "$expected" "$ACT_RESULT_FILE"; then
        pass "$description"
    else
        fail "$description -- expected to find: '$expected'"
    fi
}

assert_not_contains() {
    local description="$1"
    local unexpected="$2"
    if grep -q "$unexpected" "$ACT_RESULT_FILE"; then
        fail "$description -- should NOT contain: '$unexpected'"
    else
        pass "$description"
    fi
}

# ---------------------------------------------------------------------------
# Setup: initialise act-result.txt and create temp git repo
# ---------------------------------------------------------------------------
: > "$ACT_RESULT_FILE"   # truncate / create

log "PR Label Assigner - Act Test Harness"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$ACT_RESULT_FILE"

TEMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$TEMP_DIR'" EXIT

log "Setting up temp git repo at $TEMP_DIR"

# Copy all project files into the temp repo.
# Explicit list avoids accidentally including act-result.txt or run-tests.sh
# in the git commit (they are host-side artifacts, not project files).
mkdir -p "$TEMP_DIR/.github/workflows" "$TEMP_DIR/tests" "$TEMP_DIR/fixtures"

cp "$SCRIPT_DIR/pr-label-assigner.sh"                           "$TEMP_DIR/"
cp "$SCRIPT_DIR/label-rules.conf"                               "$TEMP_DIR/"
cp "$SCRIPT_DIR/fixtures/test-rules.conf"                       "$TEMP_DIR/fixtures/"
cp "$SCRIPT_DIR/tests/pr-label-assigner.bats"                   "$TEMP_DIR/tests/"
cp "$SCRIPT_DIR/.github/workflows/pr-label-assigner.yml"        "$TEMP_DIR/.github/workflows/"

# Copy .actrc so act uses the correct container image (act-ubuntu-pwsh:latest)
if [[ -f "$SCRIPT_DIR/.actrc" ]]; then
    cp "$SCRIPT_DIR/.actrc" "$TEMP_DIR/"
fi

# Initialise a git repo and make an initial commit so actions/checkout@v4
# has a real HEAD to check out.
cd "$TEMP_DIR"
git init -q
git config user.email "ci@test.local"
git config user.name  "CI Test"
git add -A
git commit -q -m "test: initial commit for act run"

# ---------------------------------------------------------------------------
# Run act push (one invocation covers all test cases via the workflow)
# ---------------------------------------------------------------------------
log "Running: act push --rm --pull=false"
echo "" | tee -a "$ACT_RESULT_FILE"

# --pull=false: use the local act-ubuntu-pwsh:latest image without pulling.
# Capture both stdout and stderr; tee appends to act-result.txt.
# We do NOT use pipefail here so we can inspect ACT_EXIT independently.
set +e
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT_FILE"
ACT_EXIT="${PIPESTATUS[0]}"
set -e

echo "" | tee -a "$ACT_RESULT_FILE"
log "act exited with code: $ACT_EXIT"

if [[ "$ACT_EXIT" -ne 0 ]]; then
    fail "act exited non-zero ($ACT_EXIT) — workflow failed"
fi

# ---------------------------------------------------------------------------
# Assert: job-level success
# ---------------------------------------------------------------------------
log "Checking job-level assertions"
assert_contains "workflow job succeeded" "Job succeeded"

# ---------------------------------------------------------------------------
# Assert: bats test suite passed inside the container
# bats uses TAP format: "1..N" plan + "ok N name" per passing test.
# Asserting on the last test line proves all 33 tests ran and passed.
# ---------------------------------------------------------------------------
log "Checking bats test results"
assert_contains "bats all 33 tests passed (last test ok)" "ok 33 actionlint passes on workflow file"
# Also verify no failing tests (no 'not ok' lines)
assert_not_contains "no failing bats tests" "not ok"

# ---------------------------------------------------------------------------
# Assert: actionlint passed
# ---------------------------------------------------------------------------
log "Checking actionlint result"
assert_contains "actionlint passed" "ACTIONLINT_RESULT: passed"

# ---------------------------------------------------------------------------
# Assert: TC1 — single docs file → "documentation"
# ---------------------------------------------------------------------------
log "Checking TC1: docs/README.md → documentation"
assert_contains "TC1 label output" "LABELS_TC1: documentation"

# ---------------------------------------------------------------------------
# Assert: TC2 — single api file → "api"
# ---------------------------------------------------------------------------
log "Checking TC2: src/api/users.ts → api"
assert_contains "TC2 label output" "LABELS_TC2: api"

# ---------------------------------------------------------------------------
# Assert: TC3 — test file → "tests"
# ---------------------------------------------------------------------------
log "Checking TC3: src/utils.test.ts → tests"
assert_contains "TC3 label output" "LABELS_TC3: tests"

# ---------------------------------------------------------------------------
# Assert: TC4 — docs + api file → "documentation api"
# ---------------------------------------------------------------------------
log "Checking TC4: docs/README.md + src/api/users.ts → documentation api"
assert_contains "TC4 label output" "LABELS_TC4: documentation api"

# ---------------------------------------------------------------------------
# Assert: TC5 — three-rule match → "documentation api tests"
# ---------------------------------------------------------------------------
log "Checking TC5: docs/README.md + src/api/utils.test.ts → documentation api tests"
assert_contains "TC5 label output" "LABELS_TC5: documentation api tests"

# ---------------------------------------------------------------------------
# Assert: TC6 — no-match → empty (echoed as "empty")
# ---------------------------------------------------------------------------
log "Checking TC6: unknown/file.xyz → empty"
assert_contains "TC6 no-match output" "LABELS_TC6: empty"

# ---------------------------------------------------------------------------
# Assert: demo step completed
# ---------------------------------------------------------------------------
log "Checking demo step"
assert_contains "demo completed" "DEMO_COMPLETE: true"

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo "" | tee -a "$ACT_RESULT_FILE"
log "Test harness complete"
echo "Failures: $FAILURES" | tee -a "$ACT_RESULT_FILE"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "RESULT: FAIL ($FAILURES assertion(s) failed)" | tee -a "$ACT_RESULT_FILE"
    exit 1
fi

echo "RESULT: PASS — all assertions succeeded" | tee -a "$ACT_RESULT_FILE"
