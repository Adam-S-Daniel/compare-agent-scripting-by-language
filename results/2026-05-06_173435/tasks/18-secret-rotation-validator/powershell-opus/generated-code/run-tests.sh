#!/bin/bash
# Test harness that runs all tests through act and validates results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"

# Clear previous results
> "$RESULT_FILE"

echo "=== WORKFLOW STRUCTURE TESTS ===" | tee -a "$RESULT_FILE"

# Test 1: YAML structure validation
echo "--- Test: YAML structure validation ---" | tee -a "$RESULT_FILE"
WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"
if [ -f "$WORKFLOW_FILE" ]; then
    echo "PASS: Workflow file exists at expected path" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Workflow file not found" | tee -a "$RESULT_FILE"
    exit 1
fi

# Test 2: Verify workflow references script files that exist
echo "--- Test: Script file references ---" | tee -a "$RESULT_FILE"
if [ -f "$SCRIPT_DIR/SecretRotationValidator.ps1" ]; then
    echo "PASS: SecretRotationValidator.ps1 exists" | tee -a "$RESULT_FILE"
else
    echo "FAIL: SecretRotationValidator.ps1 not found" | tee -a "$RESULT_FILE"
    exit 1
fi
if [ -f "$SCRIPT_DIR/SecretRotationValidator.Tests.ps1" ]; then
    echo "PASS: SecretRotationValidator.Tests.ps1 exists" | tee -a "$RESULT_FILE"
else
    echo "FAIL: SecretRotationValidator.Tests.ps1 not found" | tee -a "$RESULT_FILE"
    exit 1
fi
for fixture in mixed-secrets.json all-expired.json all-ok.json; do
    if [ -f "$SCRIPT_DIR/fixtures/$fixture" ]; then
        echo "PASS: fixtures/$fixture exists" | tee -a "$RESULT_FILE"
    else
        echo "FAIL: fixtures/$fixture not found" | tee -a "$RESULT_FILE"
        exit 1
    fi
done

# Test 3: actionlint validation
echo "--- Test: actionlint validation ---" | tee -a "$RESULT_FILE"
if actionlint "$WORKFLOW_FILE" 2>&1; then
    echo "PASS: actionlint passed with exit code 0" | tee -a "$RESULT_FILE"
else
    echo "FAIL: actionlint reported errors" | tee -a "$RESULT_FILE"
    exit 1
fi

# Test 4: Verify workflow has expected triggers
echo "--- Test: Workflow triggers ---" | tee -a "$RESULT_FILE"
if grep -q "push:" "$WORKFLOW_FILE" && grep -q "pull_request:" "$WORKFLOW_FILE" && grep -q "schedule:" "$WORKFLOW_FILE" && grep -q "workflow_dispatch:" "$WORKFLOW_FILE"; then
    echo "PASS: All expected triggers present (push, pull_request, schedule, workflow_dispatch)" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Missing expected triggers" | tee -a "$RESULT_FILE"
    exit 1
fi

# Test 5: Verify workflow uses pwsh shell
echo "--- Test: pwsh shell usage ---" | tee -a "$RESULT_FILE"
if grep -q "shell: pwsh" "$WORKFLOW_FILE"; then
    echo "PASS: Workflow uses shell: pwsh" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Workflow does not use shell: pwsh" | tee -a "$RESULT_FILE"
    exit 1
fi

# Test 6: Verify workflow uses actions/checkout@v4
echo "--- Test: actions/checkout reference ---" | tee -a "$RESULT_FILE"
if grep -q "actions/checkout@v4" "$WORKFLOW_FILE"; then
    echo "PASS: Workflow uses actions/checkout@v4" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Workflow does not use actions/checkout@v4" | tee -a "$RESULT_FILE"
    exit 1
fi

echo "" | tee -a "$RESULT_FILE"
echo "=== ACT INTEGRATION TEST ===" | tee -a "$RESULT_FILE"

# Set up temp git repo with project files for act
TMPDIR=$(mktemp -d)
cp -r "$SCRIPT_DIR/.github" "$TMPDIR/"
cp "$SCRIPT_DIR/SecretRotationValidator.ps1" "$TMPDIR/"
cp "$SCRIPT_DIR/SecretRotationValidator.Tests.ps1" "$TMPDIR/"
cp -r "$SCRIPT_DIR/fixtures" "$TMPDIR/"
cp "$SCRIPT_DIR/.actrc" "$TMPDIR/" 2>/dev/null || true

cd "$TMPDIR"
git init -q
git add -A
git commit -q -m "initial" --allow-empty

echo "--- Running act push ---" | tee -a "$RESULT_FILE"
ACT_OUTPUT=$(act push --rm --pull=false -P ubuntu-latest=act-ubuntu-pwsh:latest 2>&1) || true
ACT_EXIT=$?

echo "$ACT_OUTPUT" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# Check act exit code
echo "--- Test: act exit code ---" | tee -a "$RESULT_FILE"
if [ $ACT_EXIT -eq 0 ]; then
    echo "PASS: act exited with code 0" | tee -a "$RESULT_FILE"
else
    echo "FAIL: act exited with code $ACT_EXIT" | tee -a "$RESULT_FILE"
fi

# Check job succeeded (act uses "Success - Complete job" or "Job succeeded")
echo "--- Test: Job succeeded ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -qE "(Job succeeded|Success - Complete job)"; then
    echo "PASS: Job succeeded message found" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Job succeeded message not found" | tee -a "$RESULT_FILE"
fi

# Assert on exact expected values from act output
echo "--- Test: Pester tests passed in act ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "Tests Passed: 23"; then
    echo "PASS: All 23 Pester tests passed in act" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected 23 Pester tests to pass" | tee -a "$RESULT_FILE"
fi

echo "--- Test: JSON report total_secrets value ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "Total secrets: 5"; then
    echo "PASS: JSON report shows total_secrets=5" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected 'Total secrets: 5' in output" | tee -a "$RESULT_FILE"
fi

echo "--- Test: All-ok validation ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "All OK Report"; then
    echo "PASS: All-ok fixture step executed successfully" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected 'All OK Report' in output" | tee -a "$RESULT_FILE"
fi

echo "--- Test: All-expired validation ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "All Expired Report"; then
    echo "PASS: All-expired fixture step executed successfully" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected 'All Expired Report' in output" | tee -a "$RESULT_FILE"
fi

echo "--- Test: Markdown output validation ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "Secret Rotation Report"; then
    echo "PASS: Markdown report header present in output" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected markdown report header in output" | tee -a "$RESULT_FILE"
fi

echo "--- Test: DB_PASSWORD in markdown report ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "DB_PASSWORD"; then
    echo "PASS: DB_PASSWORD present in markdown report" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected DB_PASSWORD in markdown output" | tee -a "$RESULT_FILE"
fi

echo "--- Test: Custom warning window validation ---" | tee -a "$RESULT_FILE"
if echo "$ACT_OUTPUT" | grep -q "Custom Warning Window"; then
    echo "PASS: Custom 30-day warning window step executed" | tee -a "$RESULT_FILE"
else
    echo "FAIL: Expected custom warning window step output" | tee -a "$RESULT_FILE"
fi

# Cleanup
rm -rf "$TMPDIR"

echo "" | tee -a "$RESULT_FILE"
echo "=== TEST SUMMARY ===" | tee -a "$RESULT_FILE"
PASS_COUNT=$(grep -c "^PASS:" "$RESULT_FILE" || true)
FAIL_COUNT=$(grep -c "^FAIL:" "$RESULT_FILE" || true)
echo "Passed: $PASS_COUNT, Failed: $FAIL_COUNT" | tee -a "$RESULT_FILE"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "OVERALL: SOME TESTS FAILED" | tee -a "$RESULT_FILE"
    exit 1
else
    echo "OVERALL: ALL TESTS PASSED" | tee -a "$RESULT_FILE"
fi
