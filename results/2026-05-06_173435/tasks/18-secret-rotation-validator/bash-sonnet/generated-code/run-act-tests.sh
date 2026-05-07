#!/usr/bin/env bash
# run-act-tests.sh
# Test harness: copies project files into a temp git repo and runs the full
# workflow via `act push --rm`.  All output is captured in act-result.txt.
# Asserts on exact expected values produced by the workflow steps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="$SCRIPT_DIR/act-result.txt"

# ── Helpers ───────────────────────────────────────────────────────────────────

log()  { echo "[harness] $*"; }
pass() { echo "[PASS] $*" | tee -a "$ACT_RESULT_FILE"; }
fail() { echo "[FAIL] $*" | tee -a "$ACT_RESULT_FILE"; exit 1; }

assert_contains() {
    local label="$1"
    local pattern="$2"
    if grep -q "$pattern" "$ACT_RESULT_FILE"; then
        pass "$label"
    else
        fail "$label — pattern not found: '$pattern'"
    fi
}

# ── Setup ─────────────────────────────────────────────────────────────────────

true > "$ACT_RESULT_FILE"   # create / truncate

TMPDIR_REPO=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_REPO"; }
trap cleanup EXIT

log "Copying project files to temp git repo: $TMPDIR_REPO"
cp -r "$SCRIPT_DIR/." "$TMPDIR_REPO/"
cd "$TMPDIR_REPO"

git init -q
git config user.email "test@example.com"
git config user.name "Test Harness"
git add -A
git commit -q -m "test: secret rotation validator"

# ── Act run ───────────────────────────────────────────────────────────────────

{
    echo "========================================================"
    echo "ACT RUN: Full Test Suite — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "========================================================"
} | tee -a "$ACT_RESULT_FILE"

log "Starting act push --rm …"
act_exit=0
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT_FILE" || act_exit=$?

{
    echo "========================================================"
    echo "ACT EXIT CODE: $act_exit"
    echo "========================================================"
} | tee -a "$ACT_RESULT_FILE"

cd "$SCRIPT_DIR"

# ── Assertions ────────────────────────────────────────────────────────────────

log "Asserting act exit code 0 …"
[[ "$act_exit" -eq 0 ]] || fail "act exited with non-zero code: $act_exit"
pass "act exited with code 0"

# Job-level success
assert_contains "Job succeeded" "Job succeeded"

# ── bats output assertions ────────────────────────────────────────────────────
# The workflow step runs bats with --tap so each test is visible in the log.

assert_contains "bats: script exists and is executable"        "script exists and is executable"
assert_contains "bats: EXPIRED_SECRET classified as expired"   "EXPIRED_SECRET is classified as expired"
assert_contains "bats: WARNING_SECRET classified as warning"   "WARNING_SECRET is classified as warning"
assert_contains "bats: OK_SECRET classified as ok"             "OK_SECRET is classified as ok"
assert_contains "bats: JSON output is valid JSON"              "JSON output is valid JSON"
assert_contains "bats: actionlint passes"                      "actionlint passes on workflow file"
assert_contains "bats: shellcheck passes"                      "shellcheck passes on the main script"

# ── Exact value assertions from direct workflow steps ─────────────────────────

# EXPIRED secret exact values (asserted in workflow step output)
assert_contains "expired name=EXPIRED_SECRET"    "EXPIRED_SECRET"
assert_contains "expired expires=2024-01-31"     "2024-01-31"
assert_contains "expired days_remaining=-44"     "\-44"
assert_contains "expired urgency verified"       "PASS: Expired secret exact values verified"

# WARNING secret exact values
assert_contains "warning name=WARNING_SECRET"    "WARNING_SECRET"
assert_contains "warning expires=2024-03-17"     "2024-03-17"
assert_contains "warning days_remaining=2"       "days_remaining: 2"
assert_contains "warning urgency verified"       "PASS: Warning secret exact values verified"

# OK secret exact values
assert_contains "ok name=OK_SECRET"              "OK_SECRET"
assert_contains "ok expires=2024-05-30"          "2024-05-30"
assert_contains "ok days_remaining=76"           "days_remaining: 76"
assert_contains "ok urgency verified"            "PASS: OK secret exact values verified"

# Summary counts: 1 expired, 1 warning, 1 ok
assert_contains "summary counts verified" "PASS: Summary counts verified"

# Markdown output contains all three sections and summary
assert_contains "markdown EXPIRED section" "## EXPIRED"
assert_contains "markdown WARNING section" "## WARNING"
assert_contains "markdown OK section"      "## OK"
assert_contains "markdown summary"         "expired, 1 warning, 1 ok"

# Custom warning window: with --warning-days 1, WARNING_SECRET (2 days) becomes OK
assert_contains "custom warning window output" "CUSTOM WARNING WINDOW"

log ""
log "============================================"
log "All assertions passed! act-result.txt saved."
log "============================================"
