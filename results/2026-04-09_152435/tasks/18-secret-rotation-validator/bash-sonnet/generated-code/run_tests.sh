#!/usr/bin/env bash
# run_tests.sh
#
# Outer test harness: sets up a temporary git repo with the project files,
# runs the GitHub Actions workflow via `act push --rm`, captures full output
# to act-result.txt, and asserts on exact known-good values.
#
# Usage:  ./run_tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="$SCRIPT_DIR/act-result.txt"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[run_tests] $*"; }
fail() { echo "[run_tests] FAIL: $*" >&2; exit 1; }

assert_contains() {
    local haystack="$1" needle="$2" desc="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        log "  ASSERT OK  : $desc"
    else
        fail "$desc — expected to find: '$needle'"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" desc="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        log "  ASSERT OK  : $desc"
    else
        fail "$desc — did NOT expect to find: '$needle'"
    fi
}

# ---------------------------------------------------------------------------
# Initialise result file
# ---------------------------------------------------------------------------
true > "$ACT_RESULT_FILE"
log "Initialised $ACT_RESULT_FILE"

# Global that tracks the current temp dir for the EXIT trap
CURRENT_TMPDIR=""

_global_cleanup() {
    if [[ -n "$CURRENT_TMPDIR" && -d "$CURRENT_TMPDIR" ]]; then
        rm -rf "$CURRENT_TMPDIR"
        CURRENT_TMPDIR=""
    fi
}
trap _global_cleanup EXIT

# ---------------------------------------------------------------------------
# run_act_case <label>
#   Creates a temp git repo, copies all project files, runs act push --rm,
#   appends full output to act-result.txt, returns the output in ACT_OUTPUT.
# ---------------------------------------------------------------------------
run_act_case() {
    local label="$1"

    local tmpdir
    tmpdir=$(mktemp -d)
    CURRENT_TMPDIR="$tmpdir"

    log "=== TEST CASE: $label ==="
    log "  Temp repo: $tmpdir"

    # --- Set up the git repo ---
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "ci@test.local"
    git -C "$tmpdir" config user.name  "CI Test"

    # Copy all project files (excluding the git history and act-result.txt itself)
    rsync -a --exclude='.git' --exclude='act-result.txt' \
        "$SCRIPT_DIR/" "$tmpdir/"

    # Copy the .actrc so act picks up the right Docker image
    cp "$SCRIPT_DIR/.actrc" "$tmpdir/.actrc"

    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "ci: test case - $label"

    # --- Run act (output to temp file to avoid subshell ACT_EXIT loss) ---
    local delimiter act_out_file
    delimiter="====== ACT OUTPUT: $label ======"
    act_out_file="$tmpdir/act_out.txt"

    echo "$delimiter" > "$act_out_file"
    set +e
    (cd "$tmpdir" && act push --rm --pull=false 2>&1) >> "$act_out_file"
    ACT_EXIT=$?
    set -e
    echo "====== ACT EXIT CODE: $ACT_EXIT ======" >> "$act_out_file"

    # Persist to the shared result file
    cat "$act_out_file" >> "$ACT_RESULT_FILE"
    cat "$act_out_file"

    # Capture output for assertions
    ACT_OUTPUT=$(cat "$act_out_file")

    CURRENT_TMPDIR=""
    rm -rf "$tmpdir"

    return "$ACT_EXIT"
}

# ===========================================================================
# TEST CASE 1: Main secrets fixture
#   Expected: DB_MASTER_PASSWORD expired (29 days), API_KEY warning (9 days),
#             JWT_SECRET ok.  All 23 bats tests pass.
# ===========================================================================
log ""
log "Running test case 1: main secrets fixture"

act_exit=0
run_act_case "main-secrets-fixture" || act_exit=$?

if [[ $act_exit -ne 0 ]]; then
    fail "act exited with code $act_exit for main-secrets-fixture"
fi
log "  act exit code: 0 — OK"

# Assert job succeeded
assert_contains "$ACT_OUTPUT" "Job succeeded" "job succeeded message"

# Assert bats ran (plan line) and all 23 tests passed (last test ok)
assert_contains "$ACT_OUTPUT" "1..23" "bats ran 23 tests"
assert_contains "$ACT_OUTPUT" "ok 23 actionlint passes on workflow file" "test 23 (last) passed"
# Verify no failures reported
assert_not_contains "$ACT_OUTPUT" "not ok" "no failing bats tests"

# Assert markdown report contains expired section with correct count
assert_contains "$ACT_OUTPUT" "## Expired (1)" "expired section header"

# Assert expired secret appears in report
assert_contains "$ACT_OUTPUT" "DB_MASTER_PASSWORD" "expired secret name present"

# Assert exact days_overdue value (30 days in UTC)
assert_contains "$ACT_OUTPUT" "| DB_MASTER_PASSWORD | 2025-12-11 | 90 | 30 |" "expired row with 30 days overdue"

# Assert warning section
assert_contains "$ACT_OUTPUT" "## Warning (1)" "warning section header"
assert_contains "$ACT_OUTPUT" "API_KEY" "warning secret name present"
assert_contains "$ACT_OUTPUT" "| API_KEY | 2026-01-18 | 90 | 8 |" "warning row with 8 days until expiry"

# Assert ok section
assert_contains "$ACT_OUTPUT" "## OK (1)" "ok section header"
assert_contains "$ACT_OUTPUT" "JWT_SECRET" "ok secret name present"
assert_contains "$ACT_OUTPUT" "| JWT_SECRET | 2026-03-11 | 90 | 60 |" "ok row with 60 days until expiry"

# Assert JSON report includes summary with correct counts
assert_contains "$ACT_OUTPUT" '"expired": 1' "JSON summary expired count"
assert_contains "$ACT_OUTPUT" '"warning": 1' "JSON summary warning count"
assert_contains "$ACT_OUTPUT" '"ok": 1'      "JSON summary ok count"
assert_contains "$ACT_OUTPUT" '"report_date": "2026-04-10"' "JSON report_date field"

# Assert all-ok fixture validation step passed
assert_contains "$ACT_OUTPUT" "All-ok fixture validated." "all-ok fixture validation step"

log ""
log "==================================================="
log "ALL ASSERTIONS PASSED"
log "act-result.txt written to: $ACT_RESULT_FILE"
log "==================================================="
