#!/bin/bash
# run-tests.sh - Test harness for PR Label Assigner
# Runs workflow structure tests, then executes the workflow via act,
# and validates expected output.

set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT="$WORKDIR/act-result.txt"
FAILURES=0

# Clear result file
> "$ACT_RESULT"

log() {
    echo "$1" | tee -a "$ACT_RESULT"
}

fail() {
    log "FAIL: $1"
    FAILURES=$((FAILURES + 1))
}

pass() {
    log "PASS: $1"
}

# ==============================================================================
# WORKFLOW STRUCTURE TESTS
# ==============================================================================
log "========================================"
log "=== Workflow Structure Tests ==="
log "========================================"

# Test: actionlint validation
log "--- actionlint validation ---"
ACTIONLINT_OUTPUT=$(actionlint "$WORKDIR/.github/workflows/pr-label-assigner.yml" 2>&1) || true
ACTIONLINT_EXIT=$?
if [ $ACTIONLINT_EXIT -eq 0 ]; then
    pass "actionlint validation passed (exit code 0)"
else
    fail "actionlint validation failed: $ACTIONLINT_OUTPUT"
fi

# Test: Workflow file exists
if [ -f "$WORKDIR/.github/workflows/pr-label-assigner.yml" ]; then
    pass "Workflow YAML file exists"
else
    fail "Workflow YAML file not found"
fi

# Test: YAML has expected triggers
WORKFLOW_CONTENT=$(cat "$WORKDIR/.github/workflows/pr-label-assigner.yml")
if echo "$WORKFLOW_CONTENT" | grep -q "push"; then
    pass "Workflow has push trigger"
else
    fail "Workflow missing push trigger"
fi

if echo "$WORKFLOW_CONTENT" | grep -q "pull_request"; then
    pass "Workflow has pull_request trigger"
else
    fail "Workflow missing pull_request trigger"
fi

# Test: YAML has jobs section
if echo "$WORKFLOW_CONTENT" | grep -q "jobs:"; then
    pass "Workflow has jobs section"
else
    fail "Workflow missing jobs section"
fi

# Test: Uses actions/checkout@v4
if echo "$WORKFLOW_CONTENT" | grep -q "actions/checkout@v4"; then
    pass "Workflow uses actions/checkout@v4"
else
    fail "Workflow missing actions/checkout@v4"
fi

# Test: Uses shell: pwsh
if echo "$WORKFLOW_CONTENT" | grep -q "shell: pwsh"; then
    pass "Workflow uses shell: pwsh"
else
    fail "Workflow missing shell: pwsh"
fi

# Test: References script files that exist
if echo "$WORKFLOW_CONTENT" | grep -q "PrLabelAssigner.ps1" && [ -f "$WORKDIR/PrLabelAssigner.ps1" ]; then
    pass "Workflow references PrLabelAssigner.ps1 (exists)"
else
    fail "Workflow does not reference PrLabelAssigner.ps1 or file missing"
fi

if echo "$WORKFLOW_CONTENT" | grep -q "Invoke-PrLabelAssigner.ps1" && [ -f "$WORKDIR/Invoke-PrLabelAssigner.ps1" ]; then
    pass "Workflow references Invoke-PrLabelAssigner.ps1 (exists)"
else
    fail "Workflow does not reference Invoke-PrLabelAssigner.ps1 or file missing"
fi

if echo "$WORKFLOW_CONTENT" | grep -q "Invoke-PrLabelAssigner.Tests.ps1" && [ -f "$WORKDIR/Invoke-PrLabelAssigner.Tests.ps1" ]; then
    pass "Workflow references Invoke-PrLabelAssigner.Tests.ps1 (exists)"
else
    fail "Workflow does not reference Invoke-PrLabelAssigner.Tests.ps1 or file missing"
fi

# ==============================================================================
# ACT EXECUTION TEST
# ==============================================================================
log ""
log "========================================"
log "=== Act Execution Test ==="
log "========================================"

# Set up temp git repo with project files
TMPDIR=$(mktemp -d)
log "Setting up temp repo in $TMPDIR"

# Copy project files (exclude .git, act-result.txt, and run-tests.sh itself)
cp -r "$WORKDIR/.github" "$TMPDIR/"
cp -r "$WORKDIR/fixtures" "$TMPDIR/"
cp "$WORKDIR/PrLabelAssigner.ps1" "$TMPDIR/"
cp "$WORKDIR/Invoke-PrLabelAssigner.ps1" "$TMPDIR/"
cp "$WORKDIR/Invoke-PrLabelAssigner.Tests.ps1" "$TMPDIR/"
# Copy .actrc if present
if [ -f "$WORKDIR/.actrc" ]; then
    cp "$WORKDIR/.actrc" "$TMPDIR/"
fi

cd "$TMPDIR"
git init -q
git add -A
git commit -q -m "test commit"

log "Running act push --rm --pull=false..."
set +e
ACT_OUTPUT=$(act push --rm --pull=false 2>&1)
ACT_EXIT=$?
set -e

log "--- act output start ---"
log "$ACT_OUTPUT"
log "--- act output end ---"
log "act exit code: $ACT_EXIT"

cd "$WORKDIR"
rm -rf "$TMPDIR"

# Assert act succeeded
if [ "$ACT_EXIT" -eq 0 ]; then
    pass "act push exited with code 0"
else
    fail "act push exited with code $ACT_EXIT"
fi

# Assert job succeeded
if echo "$ACT_OUTPUT" | grep -q "Job succeeded"; then
    pass "Job succeeded message found"
else
    fail "Job succeeded message not found in act output"
fi

# ==============================================================================
# OUTPUT VALUE ASSERTIONS
# ==============================================================================
log ""
log "========================================"
log "=== Output Value Assertions ==="
log "========================================"

# Test: Basic matching should output "Labels: documentation"
if echo "$ACT_OUTPUT" | grep -q 'LABEL_RESULT\[basic\]: Labels: documentation'; then
    pass "Basic matching: Labels: documentation"
else
    fail "Basic matching: expected 'LABEL_RESULT[basic]: Labels: documentation'"
fi

# Test: Multiple labels should output "Labels: core, documentation, tests"
if echo "$ACT_OUTPUT" | grep -q 'LABEL_RESULT\[multi\]: Labels: core, documentation, tests'; then
    pass "Multiple labels: Labels: core, documentation, tests"
else
    fail "Multiple labels: expected 'LABEL_RESULT[multi]: Labels: core, documentation, tests'"
fi

# Test: Priority should output "Labels: api, core"
if echo "$ACT_OUTPUT" | grep -q 'LABEL_RESULT\[priority\]: Labels: api, core'; then
    pass "Priority: Labels: api, core"
else
    fail "Priority: expected 'LABEL_RESULT[priority]: Labels: api, core'"
fi

# Test: No matches should output "No labels matched"
if echo "$ACT_OUTPUT" | grep -q 'LABEL_RESULT\[nomatch\]: No labels matched'; then
    pass "No matches: No labels matched"
else
    fail "No matches: expected 'LABEL_RESULT[nomatch]: No labels matched'"
fi

# Test: Wildcard should output "Labels: javascript, tests"
if echo "$ACT_OUTPUT" | grep -q 'LABEL_RESULT\[wildcard\]: Labels: javascript, tests'; then
    pass "Wildcard: Labels: javascript, tests"
else
    fail "Wildcard: expected 'LABEL_RESULT[wildcard]: Labels: javascript, tests'"
fi

# Test: Pester tests passed
if echo "$ACT_OUTPUT" | grep -q 'PESTER_FAILED=0'; then
    pass "Pester tests: all passed (PESTER_FAILED=0)"
else
    fail "Pester tests: some tests failed"
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
log ""
log "========================================"
log "=== Summary ==="
log "========================================"
if [ $FAILURES -eq 0 ]; then
    log "All tests passed!"
else
    log "$FAILURES test(s) FAILED"
fi

exit $FAILURES
