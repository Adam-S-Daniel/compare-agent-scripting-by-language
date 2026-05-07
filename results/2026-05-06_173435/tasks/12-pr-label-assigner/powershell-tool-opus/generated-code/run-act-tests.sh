#!/usr/bin/env bash
# Test harness: validates workflow structure, runs actionlint, executes act, asserts results

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"
> "$ACT_RESULT"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "PASS: $1" | tee -a "$ACT_RESULT"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "FAIL: $1" | tee -a "$ACT_RESULT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

WF="$SCRIPT_DIR/.github/workflows/pr-label-assigner.yml"

echo "=== Workflow Structure Tests ===" | tee -a "$ACT_RESULT"

grep -q "push:" "$WF" && pass "push trigger present" || fail "push trigger missing"
grep -q "pull_request:" "$WF" && pass "pull_request trigger present" || fail "pull_request trigger missing"
grep -q "workflow_dispatch:" "$WF" && pass "workflow_dispatch trigger present" || fail "workflow_dispatch trigger missing"
grep -q "jobs:" "$WF" && pass "jobs section present" || fail "jobs section missing"
grep -q "runs-on:" "$WF" && pass "runs-on present" || fail "runs-on missing"
grep -q "actions/checkout" "$WF" && pass "checkout action referenced" || fail "checkout action missing"
grep -q "shell: pwsh" "$WF" && pass "shell: pwsh used" || fail "shell: pwsh missing"

echo "" | tee -a "$ACT_RESULT"
echo "=== File Reference Tests ===" | tee -a "$ACT_RESULT"

[[ -f "$SCRIPT_DIR/Invoke-PRLabelAssigner.ps1" ]] && pass "Script file exists" || fail "Script file missing"
[[ -f "$SCRIPT_DIR/Invoke-PRLabelAssigner.Tests.ps1" ]] && pass "Test file exists" || fail "Test file missing"
[[ -f "$SCRIPT_DIR/config.json" ]] && pass "Config file exists" || fail "Config file missing"
grep -q "Invoke-PRLabelAssigner.ps1" "$WF" && pass "Workflow references script" || fail "Workflow missing script reference"
grep -q "Invoke-PRLabelAssigner.Tests.ps1" "$WF" && pass "Workflow references tests" || fail "Workflow missing test reference"

echo "" | tee -a "$ACT_RESULT"
echo "=== Actionlint Validation ===" | tee -a "$ACT_RESULT"

LINT_OUTPUT=$(actionlint "$WF" 2>&1) || true
if [[ -z "$LINT_OUTPUT" ]]; then
    pass "actionlint clean"
else
    fail "actionlint errors: $LINT_OUTPUT"
fi

echo "" | tee -a "$ACT_RESULT"
echo "=== Act Functional Tests ===" | tee -a "$ACT_RESULT"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

mkdir -p "$TMPDIR/.github/workflows"
cp "$WF" "$TMPDIR/.github/workflows/"
cp "$SCRIPT_DIR/Invoke-PRLabelAssigner.ps1" "$TMPDIR/"
cp "$SCRIPT_DIR/Invoke-PRLabelAssigner.Tests.ps1" "$TMPDIR/"
cp "$SCRIPT_DIR/config.json" "$TMPDIR/"
cp "$SCRIPT_DIR/.actrc" "$TMPDIR/" 2>/dev/null || true

cd "$TMPDIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git add -A
git commit -q -m "Initial commit"

echo "Running act push --rm --pull=false..." | tee -a "$ACT_RESULT"
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || true
ACT_EXIT=${PIPESTATUS[0]:-$?}

echo "$ACT_OUTPUT" >> "$ACT_RESULT"

cd "$SCRIPT_DIR"

# Strip ANSI codes
CLEAN_OUTPUT=$(echo "$ACT_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r')

echo "" | tee -a "$ACT_RESULT"
echo "=== Act Exit and Job Assertions ===" | tee -a "$ACT_RESULT"

echo "$CLEAN_OUTPUT" | grep -q "Job succeeded" && pass "Job succeeded" || fail "Job did not succeed"

# Pester results
PESTER_FAILED=$(echo "$CLEAN_OUTPUT" | grep "PESTER_FAILED:" | tail -1 | sed 's/.*PESTER_FAILED: //' | tr -d ' \t')
if [[ "$PESTER_FAILED" == "0" ]]; then
    pass "All Pester tests passed (PESTER_FAILED: 0)"
else
    fail "Pester failures detected: PESTER_FAILED=$PESTER_FAILED"
fi

echo "" | tee -a "$ACT_RESULT"
echo "=== Scenario Value Assertions ===" | tee -a "$ACT_RESULT"

assert_scenario() {
    local num=$1
    local expected=$2
    local actual
    actual=$(echo "$CLEAN_OUTPUT" | grep "RESULT_${num}:" | tail -1 | sed "s/.*RESULT_${num}: //" | sed 's/[[:space:]]*$//')
    if [[ "$actual" == "$expected" ]]; then
        pass "Scenario $num: '$actual' == '$expected'"
    else
        fail "Scenario $num: got '$actual', expected '$expected'"
    fi
}

assert_scenario 1 "documentation"
assert_scenario 2 "api, documentation"
assert_scenario 3 "tests"
assert_scenario 4 "backend"
assert_scenario 5 "(none)"
assert_scenario 6 "api, tests"

echo "" | tee -a "$ACT_RESULT"
echo "=== Summary ===" | tee -a "$ACT_RESULT"
echo "Passed: $PASS_COUNT" | tee -a "$ACT_RESULT"
echo "Failed: $FAIL_COUNT" | tee -a "$ACT_RESULT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "OVERALL: FAILED" | tee -a "$ACT_RESULT"
    exit 1
else
    echo "OVERALL: PASSED" | tee -a "$ACT_RESULT"
fi
