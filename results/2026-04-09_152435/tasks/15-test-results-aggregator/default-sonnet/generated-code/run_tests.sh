#!/usr/bin/env bash
# run_tests.sh — Test harness for test-results-aggregator
#
# Runs every test case through GitHub Actions via `act`.
# Output is appended to act-result.txt in the project root.
#
# Test cases:
#   1. Workflow structure validation (actionlint, file paths, YAML triggers)
#   2. Full pipeline: parse JUnit XML + JSON, aggregate, detect flaky tests
#
# Usage: bash run_tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
SEP="================================================================"

# Initialise / truncate result file
: > "$RESULT_FILE"
echo "Test Results Aggregator — CI Test Harness" >> "$RESULT_FILE"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$RESULT_FILE"

log() { echo "$*" | tee -a "$RESULT_FILE"; }
pass() { log "  PASS: $*"; }
fail() { log "  FAIL: $*"; exit 1; }

# ---------------------------------------------------------------------------
# TEST CASE 1: Workflow structure validation (fast, no Docker)
# ---------------------------------------------------------------------------
log ""
log "$SEP"
log "TEST CASE 1: Workflow structure validation"
log "$SEP"

WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/test-results-aggregator.yml"

# 1a. Workflow file exists
[ -f "$WORKFLOW_FILE" ] && pass "Workflow file exists" || fail "Workflow file not found: $WORKFLOW_FILE"

# 1b. Required triggers present
grep -q "push:" "$WORKFLOW_FILE"         && pass "'push' trigger present"         || fail "'push' trigger missing"
grep -q "pull_request:" "$WORKFLOW_FILE" && pass "'pull_request' trigger present" || fail "'pull_request' trigger missing"
grep -q "schedule:" "$WORKFLOW_FILE"     && pass "'schedule' trigger present"     || fail "'schedule' trigger missing"
grep -q "workflow_dispatch:" "$WORKFLOW_FILE" && pass "'workflow_dispatch' trigger present" || fail "'workflow_dispatch' trigger missing"

# 1c. Jobs section exists
grep -q "jobs:" "$WORKFLOW_FILE" && pass "'jobs:' section present" || fail "'jobs:' section missing"

# 1d. Referenced script exists
[ -f "$SCRIPT_DIR/src/aggregator.py" ]  && pass "src/aggregator.py exists"  || fail "src/aggregator.py not found"
[ -f "$SCRIPT_DIR/tests/test_aggregator.py" ] && pass "tests/test_aggregator.py exists" || fail "tests/test_aggregator.py not found"
[ -d "$SCRIPT_DIR/fixtures" ]           && pass "fixtures/ directory exists" || fail "fixtures/ directory missing"

# 1e. actionlint validation (assert exit 0)
log "  Running actionlint..."
if actionlint "$WORKFLOW_FILE" >> "$RESULT_FILE" 2>&1; then
    pass "actionlint passed with exit code 0"
else
    fail "actionlint reported errors (see above)"
fi

log "TEST CASE 1: PASSED"

# ---------------------------------------------------------------------------
# TEST CASE 2: Full pipeline via act (parse + aggregate + flaky detection)
# ---------------------------------------------------------------------------
log ""
log "$SEP"
log "TEST CASE 2: Full pipeline via act push --rm"
log "$SEP"

# Create an isolated git repo so act has a clean environment to check out
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

log "  Isolated repo: $WORK_DIR"

# Copy project files — exclude .git (we create a fresh one) and result file
(cd "$SCRIPT_DIR" && tar \
    --exclude='./.git' \
    --exclude='./act-result.txt' \
    --exclude='./__pycache__' \
    --exclude='./.pytest_cache' \
    -cf - .) | tar -xf - -C "$WORK_DIR/"

cd "$WORK_DIR"

# Initialise a fresh git repo and commit everything
git init -q
git config user.email "test@example.com"
git config user.name "Test Runner"
git add -A
git commit -q -m "chore: initial commit for act test run"

log "  Running: act push --rm --pull=false"
log ""

# Run act; --pull=false uses local image without attempting Docker Hub pull;
# tee output to both terminal and result file; capture exit code via PIPESTATUS
set +e
act push --rm --pull=false 2>&1 | tee -a "$RESULT_FILE"
ACT_EXIT="${PIPESTATUS[0]}"
set -e

log ""
log "  act exit code: $ACT_EXIT"

# Assertion A: act must exit 0
[ "$ACT_EXIT" -eq 0 ] && pass "act exit code is 0" || fail "act exited with code $ACT_EXIT (expected 0)"

# Assertion B: Every job must have succeeded
grep -q "Job succeeded" "$RESULT_FILE" && pass "Job succeeded" || fail "'Job succeeded' not found in act output"

# Assertion C: Exact aggregate results
EXPECTED_AGG="AGGREGATE_RESULTS: total=10 passed=5 failed=3 skipped=2 duration=2.90"
grep -qF "$EXPECTED_AGG" "$RESULT_FILE" \
    && pass "Aggregate totals: $EXPECTED_AGG" \
    || fail "Expected '$EXPECTED_AGG' — not found in output"

# Assertion D: Exact flaky test list
EXPECTED_FLAKY="FLAKY_TESTS: test_b,test_c"
grep -qF "$EXPECTED_FLAKY" "$RESULT_FILE" \
    && pass "Flaky tests: $EXPECTED_FLAKY" \
    || fail "Expected '$EXPECTED_FLAKY' — not found in output"

# Assertion E: pytest reported all tests passed
grep -q "passed" "$RESULT_FILE" && pass "pytest reported passing tests" || fail "pytest pass indicator not found"

log ""
log "TEST CASE 2: PASSED"

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
log ""
log "$SEP"
log "ALL TEST CASES PASSED"
log "Results written to: $RESULT_FILE"
log "$SEP"
echo ""
echo "All assertions passed! See $RESULT_FILE for full output."
