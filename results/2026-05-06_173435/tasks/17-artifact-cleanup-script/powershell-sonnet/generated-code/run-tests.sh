#!/usr/bin/env bash
# run-tests.sh — test harness for artifact-cleanup-script
#
# Execution model:
#   Each "test case" below runs `act push --rm` from this workspace directory
#   (which contains .actrc pointing at act-ubuntu-pwsh:latest).  All fixture
#   data lives inside ArtifactCleanup.Tests.ps1 as in-memory PSCustomObjects,
#   so a single act run exercises every scenario.  The harness:
#     1. Validates the workflow with actionlint (no container needed, instant).
#     2. Runs `act push --rm` and streams + appends output to act-result.txt.
#     3. Asserts act exited 0 for every test case.
#     4. Asserts EXACT expected values emitted by the Pester AfterAll markers.
#     5. Asserts every job shows "Job succeeded".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="$SCRIPT_DIR/act-result.txt"
WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/artifact-cleanup-script.yml"
FAILURES=0

# ── helpers ────────────────────────────────────────────────────────────────
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
    local pattern="$1"
    local description="$2"
    if grep -qF "$pattern" "$ACT_RESULT_FILE"; then
        pass "$description"
    else
        fail "$description  [expected: $pattern]"
    fi
}

assert_exit_zero() {
    local code="$1"
    local description="$2"
    if [ "$code" -eq 0 ]; then
        pass "$description"
    else
        fail "$description  [exit code: $code]"
    fi
}

# ── initialise results file ─────────────────────────────────────────────────
> "$ACT_RESULT_FILE"
echo "Test harness started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$ACT_RESULT_FILE"
echo "" >> "$ACT_RESULT_FILE"

# ── 0. Workflow structure: actionlint ───────────────────────────────────────
echo "=== Step 0: actionlint validation ==="
actionlint "$WORKFLOW_FILE" 2>&1 | tee -a "$ACT_RESULT_FILE"
assert_exit_zero $? "actionlint passes on artifact-cleanup-script.yml"
echo "" >> "$ACT_RESULT_FILE"

# ── function: run one act test case ─────────────────────────────────────────
run_test_case() {
    local test_name="$1"

    echo ""
    echo "=== TEST CASE: $test_name ===" | tee -a "$ACT_RESULT_FILE"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ACT_RESULT_FILE"
    echo "" >> "$ACT_RESULT_FILE"

    # Strip ANSI escape codes so grep -F can match literal strings
    local act_exit=0
    act push --rm 2>&1 \
        | sed 's/\x1b\[[0-9;]*[mGKHF]//g' \
        | tee -a "$ACT_RESULT_FILE" \
        || act_exit=$?

    echo "" >> "$ACT_RESULT_FILE"
    echo "=== END TEST CASE: $test_name (exit=$act_exit) ===" | tee -a "$ACT_RESULT_FILE"
    echo "" >> "$ACT_RESULT_FILE"

    assert_exit_zero "$act_exit" "act push exits 0 for test case: $test_name"
}

# ── 1. Run all test cases (all fixtures are in ArtifactCleanup.Tests.ps1) ───
cd "$SCRIPT_DIR"

# Commit project files so actions/checkout@v4 can find them
git add ArtifactCleanup.ps1 ArtifactCleanup.Tests.ps1 \
        .github/workflows/artifact-cleanup-script.yml \
        run-tests.sh 2>/dev/null || true
git commit -m "Add artifact cleanup implementation for CI" \
           --allow-empty-message \
           --no-edit 2>/dev/null || \
    git commit -m "ci: add artifact cleanup implementation" 2>/dev/null || true

run_test_case "all-artifact-cleanup-tests"

# ── 2. Exact-value assertions ────────────────────────────────────────────────
echo ""
echo "=== Step 2: exact-value assertions ==="

# Max-age policy: 2 artifacts deleted (100MB + 200MB = 300MB reclaimed), 3 retained
assert_contains \
    "TESTRESULT|max-age-policy|deleted=2|retained=3|space_mb=300" \
    "max-age policy: 2 deleted, 3 retained, 300 MB reclaimed"

# Max-total-size policy: delete 2 oldest (50MB + 100MB = 150MB) to get under 400MB limit
assert_contains \
    "TESTRESULT|max-size-policy|deleted=2|retained=3|space_mb=150" \
    "max-size policy: 2 deleted, 3 retained, 150 MB reclaimed"

# Keep-latest-N=2 per workflow: delete 1 from each of 2 runs (100MB + 80MB = 180MB)
assert_contains \
    "TESTRESULT|keep-latest-n|deleted=2|retained=4|space_mb=180" \
    "keep-latest-N policy: 2 deleted, 4 retained, 180 MB reclaimed"

# Combined MaxAgeDays=30 + KeepLatestN=1: 3 deleted (100+150+80=330MB), 2 retained
assert_contains \
    "TESTRESULT|combined-policies|deleted=3|retained=2|space_mb=330" \
    "combined policies: 3 deleted, 2 retained, 330 MB reclaimed"

# Dry-run: same deletions as max-age, IsDryRun=True
assert_contains \
    "TESTRESULT|dry-run|deleted=2|retained=3|space_mb=300|is_dry_run=True" \
    "dry-run mode: 2 deleted, 3 retained, 300 MB reclaimed, IsDryRun=True"

# Pester summary: zero failures
assert_contains \
    "Failed=0" \
    "Pester reports zero test failures"

# GitHub Actions job must succeed
assert_contains \
    "Job succeeded" \
    "GitHub Actions job succeeded"

# ── final report ────────────────────────────────────────────────────────────
echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "=== All assertions passed! ==="
    echo "Results saved to: $ACT_RESULT_FILE"
    exit 0
else
    echo "=== $FAILURES assertion(s) FAILED ==="
    echo "Review $ACT_RESULT_FILE for details"
    exit 1
fi
