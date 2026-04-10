#!/usr/bin/env bash
# Test harness: runs the workflow through act and validates output.
# Creates a temp git repo for each run, executes act, captures output,
# and asserts on exact expected values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

# Clear previous results
> "$ACT_RESULT"

log() { echo "=== $1 ===" | tee -a "$ACT_RESULT"; }
fail() { echo "FAIL: $1" | tee -a "$ACT_RESULT"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
pass() { echo "PASS: $1" | tee -a "$ACT_RESULT"; PASS_COUNT=$((PASS_COUNT + 1)); }

# -------------------------------------------------------
# Part 1: Workflow structure tests (no act needed)
# -------------------------------------------------------
log "WORKFLOW STRUCTURE TESTS"

WORKFLOW="$SCRIPT_DIR/.github/workflows/pr-label-assigner.yml"

# Test: workflow file exists
if [[ -f "$WORKFLOW" ]]; then
  pass "Workflow file exists"
else
  fail "Workflow file does not exist"
fi

# Test: actionlint passes
if actionlint "$WORKFLOW" 2>&1; then
  pass "actionlint passes with no errors"
else
  fail "actionlint reported errors"
fi

# Test: YAML structure - has expected triggers
if grep -q "push:" "$WORKFLOW" && grep -q "pull_request:" "$WORKFLOW" && grep -q "workflow_dispatch:" "$WORKFLOW"; then
  pass "Workflow has push, pull_request, and workflow_dispatch triggers"
else
  fail "Workflow missing expected triggers"
fi

# Test: has jobs section
if grep -q "jobs:" "$WORKFLOW"; then
  pass "Workflow has jobs section"
else
  fail "Workflow missing jobs section"
fi

# Test: references script files that exist
if grep -q "label-assigner.ts" "$WORKFLOW" && [[ -f "$SCRIPT_DIR/label-assigner.ts" ]]; then
  pass "Workflow references label-assigner.ts and file exists"
else
  fail "Workflow does not reference label-assigner.ts or file missing"
fi

if grep -q "label-config.json" "$WORKFLOW" && [[ -f "$SCRIPT_DIR/label-config.json" ]]; then
  pass "Workflow references label-config.json and file exists"
else
  fail "Workflow does not reference label-config.json or file missing"
fi

# Test: has checkout step
if grep -q "actions/checkout@v4" "$WORKFLOW"; then
  pass "Workflow uses actions/checkout@v4"
else
  fail "Workflow missing actions/checkout@v4"
fi

# Test: has bun setup step
if grep -q "oven-sh/setup-bun" "$WORKFLOW"; then
  pass "Workflow uses oven-sh/setup-bun"
else
  fail "Workflow missing oven-sh/setup-bun"
fi

# Test: has bun test step
if grep -q "bun test" "$WORKFLOW"; then
  pass "Workflow runs bun test"
else
  fail "Workflow missing bun test step"
fi

echo "" >> "$ACT_RESULT"

# -------------------------------------------------------
# Part 2: Run workflow through act
# -------------------------------------------------------
log "ACT INTEGRATION TESTS"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Set up a temp git repo with all project files
cp "$SCRIPT_DIR/label-assigner.ts" "$TMPDIR/"
cp "$SCRIPT_DIR/label-assigner.test.ts" "$TMPDIR/"
cp "$SCRIPT_DIR/label-config.json" "$TMPDIR/"
cp "$SCRIPT_DIR/package.json" "$TMPDIR/"
cp "$SCRIPT_DIR/tsconfig.json" "$TMPDIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/bun.lock" "$TMPDIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/.github" "$TMPDIR/.github"
cp "$SCRIPT_DIR/.actrc" "$TMPDIR/" 2>/dev/null || true

cd "$TMPDIR"
git init -q
git add -A
git commit -q -m "initial"

echo "" | tee -a "$ACT_RESULT"
log "Running act push..."

# Run act and capture output
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || ACT_EXIT=$?
ACT_EXIT=${ACT_EXIT:-0}

echo "$ACT_OUTPUT" >> "$ACT_RESULT"
echo "" >> "$ACT_RESULT"

# -------------------------------------------------------
# Part 3: Assertions on act output
# -------------------------------------------------------
log "ACT OUTPUT ASSERTIONS"

# Assert act exited 0
if [[ "$ACT_EXIT" -eq 0 ]]; then
  pass "act exited with code 0"
else
  fail "act exited with code $ACT_EXIT"
fi

# Assert job succeeded
if echo "$ACT_OUTPUT" | grep -q "Job succeeded"; then
  pass "Job succeeded message found"
else
  fail "Job succeeded message not found"
fi

# Assert unit tests ran (bun test output)
if echo "$ACT_OUTPUT" | grep -q "21 pass"; then
  pass "All 21 unit tests passed in act"
else
  fail "Expected '21 pass' in unit test output"
fi

# --- Test Case 1: docs/readme.md, src/api/users.ts, src/utils/format.ts ---
# Expected labels: documentation, api, core
if echo "$ACT_OUTPUT" | grep -q "docs/readme.md -> \[documentation\]"; then
  pass "Test case 1: docs/readme.md correctly labeled documentation"
else
  fail "Test case 1: docs/readme.md label mismatch"
fi

if echo "$ACT_OUTPUT" | grep -q "src/api/users.ts -> \[api, core\]"; then
  pass "Test case 1: src/api/users.ts correctly labeled api, core"
else
  fail "Test case 1: src/api/users.ts label mismatch"
fi

if echo "$ACT_OUTPUT" | grep -q "src/utils/format.ts -> \[core\]"; then
  pass "Test case 1: src/utils/format.ts correctly labeled core"
else
  fail "Test case 1: src/utils/format.ts label mismatch"
fi

# Test case 1 final labels
if echo "$ACT_OUTPUT" | grep -q "FINAL_LABELS: documentation,api,core"; then
  pass "Test case 1: FINAL_LABELS exactly documentation,api,core"
else
  fail "Test case 1: FINAL_LABELS mismatch"
fi

# --- Test Case 2: src/api/users.test.ts, package.json, README.md ---
# Expected: api+tests+core on test file, dependencies on package.json, documentation on README.md
if echo "$ACT_OUTPUT" | grep -q "src/api/users.test.ts -> \[api, tests, core\]"; then
  pass "Test case 2: src/api/users.test.ts correctly labeled api, tests, core"
else
  fail "Test case 2: src/api/users.test.ts label mismatch"
fi

if echo "$ACT_OUTPUT" | grep -q "package.json -> \[dependencies\]"; then
  pass "Test case 2: package.json correctly labeled dependencies"
else
  fail "Test case 2: package.json label mismatch"
fi

if echo "$ACT_OUTPUT" | grep -q "README.md -> \[documentation\]"; then
  pass "Test case 2: README.md correctly labeled documentation"
else
  fail "Test case 2: README.md label mismatch"
fi

# Test case 2 final labels: api(2), tests(3), core(4), documentation(6 from *.md), dependencies(7)
if echo "$ACT_OUTPUT" | grep -q "FINAL_LABELS: api,tests,core,documentation,dependencies"; then
  pass "Test case 2: FINAL_LABELS exactly api,tests,core,documentation,dependencies"
else
  fail "Test case 2: FINAL_LABELS mismatch"
fi

# --- Test Case 3: .github/workflows/ci.yml, src/index.ts ---
# Expected: ci on .github file, core on src file
if echo "$ACT_OUTPUT" | grep -q ".github/workflows/ci.yml -> \[ci\]"; then
  pass "Test case 3: .github/workflows/ci.yml correctly labeled ci"
else
  fail "Test case 3: .github/workflows/ci.yml label mismatch"
fi

if echo "$ACT_OUTPUT" | grep -q "src/index.ts -> \[core\]"; then
  pass "Test case 3: src/index.ts correctly labeled core"
else
  fail "Test case 3: src/index.ts label mismatch"
fi

# Test case 3 final labels: core(4), ci(5)
if echo "$ACT_OUTPUT" | grep -q "FINAL_LABELS: core,ci"; then
  pass "Test case 3: FINAL_LABELS exactly core,ci"
else
  fail "Test case 3: FINAL_LABELS mismatch"
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo "" >> "$ACT_RESULT"
log "TEST SUMMARY"
echo "Passed: $PASS_COUNT" | tee -a "$ACT_RESULT"
echo "Failed: $FAIL_COUNT" | tee -a "$ACT_RESULT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "SOME TESTS FAILED" | tee -a "$ACT_RESULT"
  exit 1
else
  echo "ALL TESTS PASSED" | tee -a "$ACT_RESULT"
  exit 0
fi
