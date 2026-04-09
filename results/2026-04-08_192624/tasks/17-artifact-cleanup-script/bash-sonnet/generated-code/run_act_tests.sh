#!/usr/bin/env bash
# run_act_tests.sh - Test harness that runs the GitHub Actions workflow via act
#
# For each test case, this harness:
#   1. Creates a temporary git repo with the project files and that case's fixture
#   2. Runs `act push --rm` against the workflow
#   3. Captures output to act-result.txt (appended, clearly delimited)
#   4. Asserts exact expected values appear in the output
#   5. Asserts every job shows "Job succeeded"
#
# Additionally verifies:
#   - Workflow YAML structure (triggers, jobs, steps)
#   - File references in the workflow are valid
#   - actionlint passes

set -euo pipefail

# -----------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="${SCRIPT_DIR}/act-result.txt"
PLATFORM="ubuntu-latest=catthehacker/ubuntu:act-latest"
WORKFLOW_FILE=".github/workflows/artifact-cleanup-script.yml"

# Clear results file
: > "$ACT_RESULT"

PASS_COUNT=0
FAIL_COUNT=0

# Global variables set by run_act_for_test_case (avoids subshell capture issues)
CASE_LOG=""
CASE_TMPDIR=""

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------
log()  { echo "[INFO]  $*"; }
pass() { echo "[PASS]  $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo "[FAIL]  $*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

# assert_contains LABEL EXPECTED FILE_PATH
# Checks that FILE_PATH contains the EXPECTED string; records pass/fail.
assert_contains() {
    local label="$1" expected="$2" file="$3"
    if grep -qF "$expected" "$file"; then
        pass "$label: found '$expected'"
    else
        fail "$label: expected '$expected' not found in output"
    fi
}

# run_act_for_test_case LABEL TC_ID
# Creates an isolated temp git repo with all project files (all fixtures
# are included so bats tests work), runs act with TC_ID env var (which
# selects the specific integration test case in the workflow), and appends
# output to act-result.txt.
# Results written to globals: CASE_LOG (log file path), CASE_TMPDIR.
run_act_for_test_case() {
    local label="$1"
    local tc_id="$2"
    local tmpdir
    tmpdir=$(mktemp -d)
    CASE_TMPDIR="$tmpdir"

    log "Setting up temp repo for $label in $tmpdir"

    # --- Copy project files into temp repo ---
    cp "$SCRIPT_DIR/artifact_cleanup.sh" "$tmpdir/"
    mkdir -p "$tmpdir/tests/fixtures"
    cp "$SCRIPT_DIR/tests/artifact_cleanup.bats" "$tmpdir/tests/"
    # Copy all fixture files so bats tests can find them
    cp "$SCRIPT_DIR/tests/fixtures/"*.csv "$tmpdir/tests/fixtures/"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$SCRIPT_DIR/$WORKFLOW_FILE" "$tmpdir/$WORKFLOW_FILE"

    # --- Initialise git repo (actions/checkout@v4 needs a git history) ---
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "test@example.com"
    git -C "$tmpdir" config user.name "Test"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -qm "test: $label"

    local case_log="$tmpdir/act_output.txt"
    CASE_LOG="$case_log"

    log "Running act for $label (TC_ID=$tc_id)..."
    set +e
    act push \
        --rm \
        --platform "$PLATFORM" \
        --env "TC_ID=$tc_id" \
        --env "REFDATE=9999999999" \
        --no-cache-server \
        --directory "$tmpdir" \
        2>&1 | tee "$case_log"
    local act_exit="${PIPESTATUS[0]}"
    set -e

    # --- Append to global act-result.txt with clear delimiter ---
    {
        echo ""
        echo "################################################################"
        echo "# TEST CASE: $label (TC_ID=$tc_id)"
        echo "# act exit code: $act_exit"
        echo "################################################################"
        cat "$case_log"
        echo "################################################################"
        echo "# END: $label"
        echo "################################################################"
    } >> "$ACT_RESULT"

    # --- Assert act exit code ---
    if [[ "$act_exit" -eq 0 ]]; then
        pass "$label: act exited 0"
    else
        fail "$label: act exited $act_exit (non-zero)"
    fi
}

# -----------------------------------------------------------------------
# SECTION 0: Workflow structure and static checks
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " SECTION 0: Workflow Structure & Static Validation"
echo "======================================================="

{
    echo ""
    echo "################################################################"
    echo "# SECTION 0: Workflow Structure & Static Validation"
    echo "################################################################"
} >> "$ACT_RESULT"

# Check that workflow file exists
if [[ -f "$SCRIPT_DIR/$WORKFLOW_FILE" ]]; then
    pass "Workflow file exists at $WORKFLOW_FILE"
    echo "STRUCTURE: workflow file exists at $WORKFLOW_FILE" >> "$ACT_RESULT"
else
    fail "Workflow file missing: $WORKFLOW_FILE"
fi

# Verify workflow references correct script path
if grep -qF "artifact_cleanup.sh" "$SCRIPT_DIR/$WORKFLOW_FILE"; then
    pass "Workflow references artifact_cleanup.sh"
    echo "STRUCTURE: workflow references artifact_cleanup.sh" >> "$ACT_RESULT"
else
    fail "Workflow does not reference artifact_cleanup.sh"
fi

# Verify script file exists
if [[ -f "$SCRIPT_DIR/artifact_cleanup.sh" ]]; then
    pass "Script file artifact_cleanup.sh exists"
else
    fail "Script file artifact_cleanup.sh missing"
fi

# Verify fixture files referenced in workflow exist
for fixture in test_max_age test_keep_latest test_max_size test_combined test_dry_run; do
    fixture_path="$SCRIPT_DIR/tests/fixtures/${fixture}.csv"
    if [[ -f "$fixture_path" ]]; then
        pass "Fixture exists: tests/fixtures/${fixture}.csv"
    else
        fail "Fixture missing: tests/fixtures/${fixture}.csv"
    fi
done

# Verify actionlint passes
log "Running actionlint..."
actionlint_output=$(actionlint "$SCRIPT_DIR/$WORKFLOW_FILE" 2>&1) && actionlint_exit=0 || actionlint_exit=$?
echo "ACTIONLINT EXIT: $actionlint_exit" >> "$ACT_RESULT"
echo "$actionlint_output" >> "$ACT_RESULT"
if [[ "$actionlint_exit" -eq 0 ]]; then
    pass "actionlint: workflow passes"
else
    fail "actionlint: workflow has errors: $actionlint_output"
fi

# Verify workflow has expected trigger events
for trigger in push pull_request workflow_dispatch schedule; do
    if grep -qF "$trigger" "$SCRIPT_DIR/$WORKFLOW_FILE"; then
        pass "Workflow has trigger: $trigger"
    else
        fail "Workflow missing trigger: $trigger"
    fi
done

# Verify expected job names exist in workflow
for job in lint unit-tests integration; do
    if grep -qF "$job" "$SCRIPT_DIR/$WORKFLOW_FILE"; then
        pass "Workflow has job: $job"
    else
        fail "Workflow missing job: $job"
    fi
done

# Static analysis on the main script
if shellcheck "$SCRIPT_DIR/artifact_cleanup.sh" 2>/dev/null; then
    pass "shellcheck: artifact_cleanup.sh passes"
    echo "SHELLCHECK: passed" >> "$ACT_RESULT"
else
    fail "shellcheck: artifact_cleanup.sh has warnings"
fi

if bash -n "$SCRIPT_DIR/artifact_cleanup.sh" 2>/dev/null; then
    pass "bash -n: artifact_cleanup.sh syntax valid"
else
    fail "bash -n: artifact_cleanup.sh syntax error"
fi

# -----------------------------------------------------------------------
# SECTION 1: Test Case 1 — max-age policy
# Expected: DELETE old-artifact, RETAIN new-artifact; space_reclaimed=1048576
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " SECTION 1: TC1 — max-age policy"
echo "======================================================="

run_act_for_test_case \
    "TC1: max-age policy" \
    "tc1"

assert_contains "TC1" "DELETE old-artifact max_age 1048576" "$CASE_LOG"
assert_contains "TC1" "RETAIN new-artifact"                  "$CASE_LOG"
assert_contains "TC1" "space_reclaimed=1048576"              "$CASE_LOG"
assert_contains "TC1" "total=2"                              "$CASE_LOG"
assert_contains "TC1" "retained=1"                           "$CASE_LOG"
assert_contains "TC1" "deleted=1"                            "$CASE_LOG"
assert_contains "TC1" "Job succeeded"                        "$CASE_LOG"
rm -rf "$CASE_TMPDIR"

# -----------------------------------------------------------------------
# SECTION 2: Test Case 2 — keep-latest-N policy
# Expected: DELETE artifact-v1 (oldest), RETAIN artifact-v2 artifact-v3
# space_reclaimed=524288
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " SECTION 2: TC2 — keep-latest-N policy"
echo "======================================================="

run_act_for_test_case \
    "TC2: keep-latest-N policy" \
    "tc2"

assert_contains "TC2" "DELETE artifact-v1 keep_latest 524288" "$CASE_LOG"
assert_contains "TC2" "RETAIN artifact-v2"                     "$CASE_LOG"
assert_contains "TC2" "RETAIN artifact-v3"                     "$CASE_LOG"
assert_contains "TC2" "space_reclaimed=524288"                 "$CASE_LOG"
assert_contains "TC2" "total=3"                                "$CASE_LOG"
assert_contains "TC2" "retained=2"                             "$CASE_LOG"
assert_contains "TC2" "deleted=1"                              "$CASE_LOG"
assert_contains "TC2" "Job succeeded"                          "$CASE_LOG"
rm -rf "$CASE_TMPDIR"

# -----------------------------------------------------------------------
# SECTION 3: Test Case 3 — max-total-size policy
# Expected: DELETE artifact-a (oldest 3 MB), RETAIN artifact-b artifact-c
# space_reclaimed=3145728
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " SECTION 3: TC3 — max-total-size policy"
echo "======================================================="

run_act_for_test_case \
    "TC3: max-total-size policy" \
    "tc3"

assert_contains "TC3" "DELETE artifact-a max_total_size 3145728" "$CASE_LOG"
assert_contains "TC3" "RETAIN artifact-b"                         "$CASE_LOG"
assert_contains "TC3" "RETAIN artifact-c"                         "$CASE_LOG"
assert_contains "TC3" "space_reclaimed=3145728"                   "$CASE_LOG"
assert_contains "TC3" "total=3"                                   "$CASE_LOG"
assert_contains "TC3" "retained=2"                                "$CASE_LOG"
assert_contains "TC3" "deleted=1"                                 "$CASE_LOG"
assert_contains "TC3" "Job succeeded"                             "$CASE_LOG"
rm -rf "$CASE_TMPDIR"

# -----------------------------------------------------------------------
# SECTION 4: Test Case 4 — combined policies (max-age + keep-latest)
# Expected: DELETE old-v1 old-v2 (max_age) + new-v1 (keep_latest)
# space_reclaimed=3145728 (3 × 1048576)
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " SECTION 4: TC4 — combined policies"
echo "======================================================="

run_act_for_test_case \
    "TC4: combined policies" \
    "tc4"

assert_contains "TC4" "DELETE old-v1 max_age 1048576"        "$CASE_LOG"
assert_contains "TC4" "DELETE old-v2 max_age 1048576"        "$CASE_LOG"
assert_contains "TC4" "DELETE new-v1 keep_latest 1048576"    "$CASE_LOG"
assert_contains "TC4" "RETAIN new-v2"                         "$CASE_LOG"
assert_contains "TC4" "RETAIN new-v3"                         "$CASE_LOG"
assert_contains "TC4" "space_reclaimed=3145728"               "$CASE_LOG"
assert_contains "TC4" "total=5"                               "$CASE_LOG"
assert_contains "TC4" "retained=2"                            "$CASE_LOG"
assert_contains "TC4" "deleted=3"                             "$CASE_LOG"
assert_contains "TC4" "Job succeeded"                         "$CASE_LOG"
rm -rf "$CASE_TMPDIR"

# -----------------------------------------------------------------------
# SECTION 5: Test Case 5 — dry-run mode
# Expected: DRY-RUN MODE header, same plan as TC1
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " SECTION 5: TC5 — dry-run mode"
echo "======================================================="

run_act_for_test_case \
    "TC5: dry-run mode" \
    "tc5"

assert_contains "TC5" "DRY-RUN MODE"                          "$CASE_LOG"
assert_contains "TC5" "DELETE old-artifact max_age 1048576"   "$CASE_LOG"
assert_contains "TC5" "RETAIN new-artifact"                    "$CASE_LOG"
assert_contains "TC5" "space_reclaimed=1048576"                "$CASE_LOG"
assert_contains "TC5" "Job succeeded"                          "$CASE_LOG"
rm -rf "$CASE_TMPDIR"

# -----------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------
echo ""
echo "======================================================="
echo " RESULTS"
echo "======================================================="
echo "  Passed: $PASS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo ""
echo "  act-result.txt written to: $ACT_RESULT"

{
    echo ""
    echo "################################################################"
    echo "# HARNESS SUMMARY"
    echo "# Passed: $PASS_COUNT"
    echo "# Failed: $FAIL_COUNT"
    echo "################################################################"
} >> "$ACT_RESULT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "HARNESS FAILED: $FAIL_COUNT assertion(s) failed" >&2
    exit 1
fi

echo "All assertions passed."
exit 0
