#!/usr/bin/env bash
# run-tests.sh — outer test harness for pr-label-assigner
#
# Sets up a temporary git repo with all project files, runs the GitHub Actions
# workflow via `act push --rm`, captures the full output to act-result.txt,
# and asserts exact expected values.
#
# All bats test cases execute inside the workflow — this script is the single
# act invocation that covers every test case.

set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$WORKSPACE/act-result.txt"

# ---------------------------------------------------------------------------
# actionlint pre-check (instant — validate before spending 30-90s on act)
# ---------------------------------------------------------------------------
echo "=== actionlint pre-check ===" | tee "$RESULT_FILE"
actionlint "$WORKSPACE/.github/workflows/pr-label-assigner.yml" 2>&1 | tee -a "$RESULT_FILE"
echo "actionlint PASSED" | tee -a "$RESULT_FILE"

# ---------------------------------------------------------------------------
# Set up a temp git repo with the project files
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
# Ensure cleanup even on error
trap 'rm -rf "$TMPDIR"' EXIT

echo "" | tee -a "$RESULT_FILE"
echo "=== Setting up temp git repo at $TMPDIR ===" | tee -a "$RESULT_FILE"

# Copy all project files (excluding git history and the result file itself)
rsync -a --exclude='.git' --exclude='act-result.txt' "$WORKSPACE/" "$TMPDIR/"

# Copy .actrc so act uses the correct container image
cp "$WORKSPACE/.actrc" "$TMPDIR/.actrc"

# Initialize git repo (act requires a git repository)
cd "$TMPDIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test Runner"
git add -A
git commit -q -m "test: add project files for act run"

# ---------------------------------------------------------------------------
# Run act — one invocation covers all test cases (bats tests run inside it)
# ---------------------------------------------------------------------------
echo "" | tee -a "$RESULT_FILE"
echo "==================================================================" | tee -a "$RESULT_FILE"
echo "=== act push --rm (all test cases run inside the workflow) ===" | tee -a "$RESULT_FILE"
echo "==================================================================" | tee -a "$RESULT_FILE"

set +e
act push --rm --pull=false 2>&1 | tee -a "$RESULT_FILE"
ACT_EXIT="${PIPESTATUS[0]}"
set -e

echo "" | tee -a "$RESULT_FILE"
echo "=== act exit code: $ACT_EXIT ===" | tee -a "$RESULT_FILE"

# ---------------------------------------------------------------------------
# Assertions on captured output
# ---------------------------------------------------------------------------
FAIL=0

# assert_contains must NOT use pipes (piping creates a subshell, preventing
# FAIL=1 from propagating to the parent shell).
assert_contains() {
    local desc="$1"
    local pattern="$2"
    local msg
    if grep -qE "$pattern" "$RESULT_FILE"; then
        msg="ASSERT OK  : $desc"
    else
        msg="ASSERT FAIL: $desc (pattern not found: $pattern)"
        FAIL=1
    fi
    echo "$msg" | tee -a "$RESULT_FILE"
}

echo "" | tee -a "$RESULT_FILE"
echo "=== Assertions ===" | tee -a "$RESULT_FILE"

# act must exit 0
if [ "$ACT_EXIT" -eq 0 ]; then
    echo "ASSERT OK  : act exited with code 0" | tee -a "$RESULT_FILE"
else
    echo "ASSERT FAIL: act exited with code $ACT_EXIT (expected 0)" | tee -a "$RESULT_FILE"
    FAIL=1
fi

# Every job must show Job succeeded
assert_contains "every job shows Job succeeded" "Job succeeded"

# All 25 bats tests passed — act prefixes each output line so match without ^ anchor
assert_contains "bats: all 25 tests passed" "ok 25 workflow passes actionlint"

# Integration test step must pass
assert_contains "integration test passed" "INTEGRATION_TEST_PASSED"

# Exact label output assertions from the integration test step
assert_contains "exact labels output: documentation,api,tests" "ACTUAL_LABELS: documentation,api,tests"
assert_contains "priority test passed" "PRIORITY_TEST_PASSED"
assert_contains "priority labels: api,tests" "PRIORITY_LABELS: api,tests"

# Specific bats test names must show ok (exact value checks)
assert_contains "bats test: assigns documentation label" "ok.*assigns documentation label"
assert_contains "bats test: assigns api label" "ok.*assigns api label"
assert_contains "bats test: assigns tests label" "ok.*assigns tests label"
assert_contains "bats test: priority ordering" "ok.*priority config - api before tests"
assert_contains "bats test: deduplication" "ok.*deduplicates labels"
assert_contains "bats test: workflow actionlint" "ok.*workflow passes actionlint"

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------
echo "" | tee -a "$RESULT_FILE"
if [ "$FAIL" -eq 0 ]; then
    echo "ALL ASSERTIONS PASSED" | tee -a "$RESULT_FILE"
    exit 0
else
    echo "ONE OR MORE ASSERTIONS FAILED — see act-result.txt for details" | tee -a "$RESULT_FILE"
    exit 1
fi
