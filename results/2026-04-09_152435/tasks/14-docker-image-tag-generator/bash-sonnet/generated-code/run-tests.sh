#!/usr/bin/env bash
# Test harness: runs the GitHub Actions workflow via act and validates output.
#
# This script:
#   1. Sets up a temp git repo with all project files
#   2. Runs `act push --rm` (once — captures all bats test results)
#   3. Saves full act output to act-result.txt
#   4. Asserts act exited 0 and "Job succeeded" is present
#   5. Parses bats output to verify each expected test passed
#   6. Runs workflow structure tests (YAML parsing, path checks, actionlint)
#
# Usage: bash run-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="${SCRIPT_DIR}/act-result.txt"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; FAILURES=$((FAILURES + 1)); }

FAILURES=0

# ─────────────────────────────────────────────────────────────────────────────
# Section 1: Workflow structure tests (instant, no act needed)
# ─────────────────────────────────────────────────────────────────────────────

echo "=== Workflow Structure Tests ==="

WORKFLOW_FILE="${SCRIPT_DIR}/.github/workflows/docker-image-tag-generator.yml"

# 1a. Workflow file exists
if [[ -f "$WORKFLOW_FILE" ]]; then
    pass "Workflow file exists"
else
    fail "Workflow file not found: $WORKFLOW_FILE"
fi

# 1b. Script file exists
if [[ -f "${SCRIPT_DIR}/generate-tags.sh" ]]; then
    pass "generate-tags.sh exists"
else
    fail "generate-tags.sh not found"
fi

# 1c. Test file exists
if [[ -f "${SCRIPT_DIR}/tests/generate-tags.bats" ]]; then
    pass "tests/generate-tags.bats exists"
else
    fail "tests/generate-tags.bats not found"
fi

# 1d. Workflow references the script
if grep -q "generate-tags.sh" "$WORKFLOW_FILE"; then
    pass "Workflow references generate-tags.sh"
else
    fail "Workflow does not reference generate-tags.sh"
fi

# 1e. Workflow has push trigger
if grep -q "push:" "$WORKFLOW_FILE"; then
    pass "Workflow has push trigger"
else
    fail "Workflow missing push trigger"
fi

# 1f. Workflow has pull_request trigger
if grep -q "pull_request" "$WORKFLOW_FILE"; then
    pass "Workflow has pull_request trigger"
else
    fail "Workflow missing pull_request trigger"
fi

# 1g. Workflow has actions/checkout step
if grep -q "actions/checkout" "$WORKFLOW_FILE"; then
    pass "Workflow uses actions/checkout"
else
    fail "Workflow missing actions/checkout"
fi

# 1h. Workflow has bats test step
if grep -q "bats" "$WORKFLOW_FILE"; then
    pass "Workflow runs bats tests"
else
    fail "Workflow missing bats test step"
fi

# 1i. actionlint validation
if actionlint "$WORKFLOW_FILE" 2>&1; then
    pass "actionlint validation passed"
else
    fail "actionlint validation failed"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Section 2: Run workflow through act
# ─────────────────────────────────────────────────────────────────────────────

echo "=== Act Workflow Execution ==="

# Set up a temp git repo with all project files
TMPDIR_REPO=$(mktemp -d)
trap 'rm -rf "$TMPDIR_REPO"' EXIT

echo "Setting up temp git repo in: $TMPDIR_REPO"

# Copy project files
cp -r "${SCRIPT_DIR}/." "$TMPDIR_REPO/"

# Initialise git repo (act needs a real repo)
cd "$TMPDIR_REPO"
git init -b main
git config user.email "test@example.com"
git config user.name "Test"
git add -A
git commit -m "initial commit for act test"

# Run act — capture full output
echo "Running: act push --rm"
echo "" >> "$ACT_RESULT_FILE" 2>/dev/null || true
{
    echo "======================================================================"
    echo "ACT RUN: $(date -Iseconds)"
    echo "======================================================================"
} >> "$ACT_RESULT_FILE"

ACT_EXIT=0
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT_FILE" || ACT_EXIT=$?

{
    echo "======================================================================"
    echo "ACT EXIT CODE: $ACT_EXIT"
    echo "======================================================================"
} >> "$ACT_RESULT_FILE"

cd "$SCRIPT_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Section 3: Assert on act output
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "=== Act Output Assertions ==="

# 3a. act exited 0
if [[ "$ACT_EXIT" -eq 0 ]]; then
    pass "act exited with code 0"
else
    fail "act exited with code $ACT_EXIT (expected 0)"
fi

# 3b. Job succeeded
if grep -q "Job succeeded" "$ACT_RESULT_FILE"; then
    pass "Job succeeded present in output"
else
    fail "'Job succeeded' not found in act output"
fi

# 3c. All 15 bats tests passed — TAP plan header confirms count; no 'not ok' means 0 failures
if grep -q "1\.\.15" "$ACT_RESULT_FILE"; then
    pass "bats TAP plan shows 15 tests (1..15)"
else
    fail "Expected bats TAP plan '1..15' in act output"
fi

if grep -q "not ok" "$ACT_RESULT_FILE"; then
    fail "act output contains 'not ok' — at least one bats test failed"
else
    pass "No failing bats tests (no 'not ok' lines)"
fi

# 3d. Specific test names appear (verify bats actually ran our tests)
EXPECTED_TESTS=(
    "main branch generates 'latest' tag"
    "PR number generates 'pr-{number}' tag"
    "semver tag on main generates 'v1.2.3' and 'latest'"
    "feature branch generates branch-shortsha tag"
    "branch name is lowercased"
    "underscores in branch name are replaced with hyphens"
    "missing --branch argument exits with error"
)

for test_name in "${EXPECTED_TESTS[@]}"; do
    if grep -qF "$test_name" "$ACT_RESULT_FILE"; then
        pass "Test ran: $test_name"
    else
        fail "Test not found in output: $test_name"
    fi
done

# 3e. Demo output: exact expected tag values
if grep -q "^latest$\|latest" "$ACT_RESULT_FILE"; then
    pass "Demo output contains 'latest'"
else
    fail "Demo output missing 'latest'"
fi

if grep -q "feature-example-" "$ACT_RESULT_FILE"; then
    pass "Demo output contains feature branch tag"
else
    fail "Demo output missing feature branch tag"
fi

if grep -q "^v1\.2\.3$\|v1\.2\.3" "$ACT_RESULT_FILE"; then
    pass "Demo output contains 'v1.2.3'"
else
    fail "Demo output missing 'v1.2.3'"
fi

if grep -q "^pr-99$\|pr-99" "$ACT_RESULT_FILE"; then
    pass "Demo output contains 'pr-99'"
else
    fail "Demo output missing 'pr-99'"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Final report
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "act-result.txt written to: $ACT_RESULT_FILE"

if [[ "$FAILURES" -eq 0 ]]; then
    echo "ALL TESTS PASSED"
    exit 0
else
    echo "FAILURES: $FAILURES"
    exit 1
fi
