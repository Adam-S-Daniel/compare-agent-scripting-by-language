#!/usr/bin/env bash
# Test harness: runs the GitHub Actions workflow through act and validates output.
# All tests execute through the CI pipeline, not directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

# Clear previous results
> "$RESULT_FILE"

assert_contains() {
    local label="$1"
    local pattern="$2"
    local text="$3"
    if echo "$text" | grep -qF "$pattern"; then
        echo "PASS: $label"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $label — expected to find: $pattern"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_contains_regex() {
    local label="$1"
    local pattern="$2"
    local text="$3"
    if echo "$text" | grep -qE "$pattern"; then
        echo "PASS: $label"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $label — expected regex: $pattern"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_not_contains() {
    local label="$1"
    local pattern="$2"
    local text="$3"
    if echo "$text" | grep -qF "$pattern"; then
        echo "FAIL: $label — should NOT contain: $pattern"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "PASS: $label"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
}

echo "============================="
echo "WORKFLOW STRUCTURE TESTS"
echo "============================="

# Test: actionlint passes
actionlint "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml"
LINT_EXIT=$?
if [ "$LINT_EXIT" -eq 0 ]; then
    echo "PASS: actionlint passes with exit code 0"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL: actionlint failed with exit code $LINT_EXIT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: Workflow YAML structure checks
WORKFLOW_CONTENT=$(cat "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml")

assert_contains "Workflow has push trigger" "push:" "$WORKFLOW_CONTENT"
assert_contains "Workflow has pull_request trigger" "pull_request:" "$WORKFLOW_CONTENT"
assert_contains "Workflow has workflow_dispatch trigger" "workflow_dispatch:" "$WORKFLOW_CONTENT"
assert_contains "Workflow uses actions/checkout@v4" "actions/checkout@v4" "$WORKFLOW_CONTENT"
assert_contains "Workflow uses pwsh shell" "shell: pwsh" "$WORKFLOW_CONTENT"
assert_contains "Workflow references New-BuildMatrix.ps1" "New-BuildMatrix.ps1" "$WORKFLOW_CONTENT"
assert_contains "Workflow references New-BuildMatrix.Tests.ps1" "New-BuildMatrix.Tests.ps1" "$WORKFLOW_CONTENT"
assert_contains "Workflow references basic.json fixture" "fixtures/basic.json" "$WORKFLOW_CONTENT"
assert_contains "Workflow references full-featured.json fixture" "fixtures/full-featured.json" "$WORKFLOW_CONTENT"
assert_contains "Workflow references oversized.json fixture" "fixtures/oversized.json" "$WORKFLOW_CONTENT"

# Verify referenced script files exist
if [ -f "$SCRIPT_DIR/New-BuildMatrix.ps1" ]; then
    echo "PASS: New-BuildMatrix.ps1 exists"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL: New-BuildMatrix.ps1 not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if [ -f "$SCRIPT_DIR/New-BuildMatrix.Tests.ps1" ]; then
    echo "PASS: New-BuildMatrix.Tests.ps1 exists"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL: New-BuildMatrix.Tests.ps1 not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

for fixture in basic.json full-featured.json oversized.json; do
    if [ -f "$SCRIPT_DIR/fixtures/$fixture" ]; then
        echo "PASS: fixtures/$fixture exists"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: fixtures/$fixture not found"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "============================="
echo "ACT EXECUTION TEST"
echo "============================="

# Set up a temporary git repo with project files
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cp -r "$SCRIPT_DIR/.github" "$TMPDIR/"
cp "$SCRIPT_DIR/New-BuildMatrix.ps1" "$TMPDIR/"
cp "$SCRIPT_DIR/New-BuildMatrix.Tests.ps1" "$TMPDIR/"
cp -r "$SCRIPT_DIR/fixtures" "$TMPDIR/"

# Copy .actrc if present
if [ -f "$SCRIPT_DIR/.actrc" ]; then
    cp "$SCRIPT_DIR/.actrc" "$TMPDIR/"
fi

cd "$TMPDIR"
git init -q
git add -A
git commit -q -m "initial"

echo "--- Running act push (test case 1: full pipeline) ---"
echo "=== ACT RUN: Full Pipeline ===" >> "$RESULT_FILE"

ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || true
ACT_EXIT=$?
echo "$ACT_OUTPUT" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# Check act exit code
if [ "$ACT_EXIT" -eq 0 ]; then
    echo "PASS: act exited with code 0"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "FAIL: act exited with code $ACT_EXIT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Check that the job succeeded
assert_contains "Job succeeded" "Job succeeded" "$ACT_OUTPUT"

# === Pester Test Assertions ===
# Verify Pester ran and all tests passed
assert_contains "Pester tests discovered" "Tests Passed:" "$ACT_OUTPUT"
assert_not_contains "Pester tests have no failures" "Tests Failed: 1" "$ACT_OUTPUT"
assert_not_contains "Pester tests have no failures (multi)" "Tests Failed: 2" "$ACT_OUTPUT"
# ANSI escape codes appear between fields, so use a looser regex
assert_contains_regex "All Pester tests passed" "Tests Passed: [0-9]+" "$ACT_OUTPUT"
assert_contains_regex "Zero Pester failures" "Failed: 0" "$ACT_OUTPUT"

# === Basic Matrix Output Assertions ===
# The basic config has os: [ubuntu-latest, windows-latest], node: [18, 20], fail-fast: true
assert_contains "Basic matrix contains ubuntu-latest" "ubuntu-latest" "$ACT_OUTPUT"
assert_contains "Basic matrix contains windows-latest" "windows-latest" "$ACT_OUTPUT"
assert_contains "Basic matrix contains node 18" '"18"' "$ACT_OUTPUT"
assert_contains "Basic matrix contains node 20" '"20"' "$ACT_OUTPUT"
assert_contains "Basic matrix has fail-fast true" '"fail-fast": true' "$ACT_OUTPUT"

# === Full-Featured Matrix Output Assertions ===
# Dimensions: os [ubuntu-latest, windows-latest, macos-latest], python [3.10, 3.11, 3.12]
# Include: os=ubuntu-latest, python=3.13, experimental=true
# Exclude: os=macos-latest, python=3.10
# fail-fast: false, max-parallel: 4
assert_contains "Full matrix contains macos-latest" "macos-latest" "$ACT_OUTPUT"
assert_contains "Full matrix contains python 3.12" '"3.12"' "$ACT_OUTPUT"
assert_contains "Full matrix has include section" '"include"' "$ACT_OUTPUT"
assert_contains "Full matrix has exclude section" '"exclude"' "$ACT_OUTPUT"
assert_contains "Full matrix includes python 3.13" '"3.13"' "$ACT_OUTPUT"
assert_contains "Full matrix experimental flag" '"experimental": true' "$ACT_OUTPUT"
assert_contains "Full matrix has fail-fast false" '"fail-fast": false' "$ACT_OUTPUT"
assert_contains "Full matrix has max-parallel 4" '"max-parallel": 4' "$ACT_OUTPUT"

# === Oversized Matrix Rejection Assertions ===
assert_contains "Oversized matrix rejected with error" "EXPECTED_ERROR:" "$ACT_OUTPUT"
assert_contains "Oversized error mentions exceeds maximum" "exceeds maximum" "$ACT_OUTPUT"
assert_contains "Oversized matrix correctly rejected msg" "Oversized matrix correctly rejected" "$ACT_OUTPUT"

# === Summary Step Assertions ===
assert_contains "Summary shows all checks passed" "=== ALL CHECKS PASSED ===" "$ACT_OUTPUT"

echo ""
echo "============================="
echo "RESULTS SUMMARY"
echo "============================="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

# Append summary to result file
echo "" >> "$RESULT_FILE"
echo "============================" >> "$RESULT_FILE"
echo "HARNESS SUMMARY: Passed=$PASS_COUNT Failed=$FAIL_COUNT" >> "$RESULT_FILE"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "Some tests FAILED."
    exit 1
fi

echo "All tests PASSED."
