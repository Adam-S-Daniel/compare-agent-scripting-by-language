#!/usr/bin/env bash
# run_act_tests.sh - Test harness that runs all test cases through GitHub Actions via act
#
# This script:
# 1. Sets up a temp git repo with all project files
# 2. Runs `act push --rm` once (the workflow covers all test cases)
# 3. Asserts act exits with code 0
# 4. Parses act output and asserts EXACT expected labels per test case step
# 5. Saves all act output to act-result.txt
#
# Usage: ./run_act_tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

# ============================================================
# YAML structure and file validation (no Docker required)
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=()

# Log to both stdout and result file
log() { printf '%s\n' "$*" | tee -a "$ACT_RESULT"; }

assert_pass() {
    local name="$1"
    log "PASS: $name"
    PASS_COUNT=$((PASS_COUNT + 1))
}

assert_fail() {
    local name="$1"
    local reason="$2"
    log "FAIL: $name - $reason"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_TESTS+=("$name: $reason")
}

# ============================================================
# Initialise result file
# ============================================================
true > "$ACT_RESULT"
log "PR Label Assigner - Test Harness Results"
log "Date: $(date)"
log ""

# ============================================================
# SECTION 1: YAML / workflow structure tests
# ============================================================
log "================================================================"
log "SECTION 1: YAML Structure Tests"
log "================================================================"

YAML="$SCRIPT_DIR/.github/workflows/pr-label-assigner.yml"

# Test: actionlint passes
lint_out=$(actionlint "$YAML" 2>&1) && lint_code=0 || lint_code=$?
if [[ $lint_code -eq 0 ]]; then
    assert_pass "actionlint validation"
else
    assert_fail "actionlint validation" "exit code $lint_code: $lint_out"
fi

# Test: push trigger
if grep -q "push:" "$YAML"; then
    assert_pass "workflow has push trigger"
else
    assert_fail "workflow has push trigger" "push: not found"
fi

# Test: pull_request trigger
if grep -q "pull_request:" "$YAML"; then
    assert_pass "workflow has pull_request trigger"
else
    assert_fail "workflow has pull_request trigger" "pull_request: not found"
fi

# Test: workflow_dispatch trigger
if grep -q "workflow_dispatch:" "$YAML"; then
    assert_pass "workflow has workflow_dispatch trigger"
else
    assert_fail "workflow has workflow_dispatch trigger" "workflow_dispatch: not found"
fi

# Test: script referenced in workflow
if grep -q "pr_label_assigner.sh" "$YAML"; then
    assert_pass "workflow references pr_label_assigner.sh"
else
    assert_fail "workflow references pr_label_assigner.sh" "not found in YAML"
fi

# Test: uses checkout@v4
if grep -q "actions/checkout@v4" "$YAML"; then
    assert_pass "workflow uses actions/checkout@v4"
else
    assert_fail "workflow uses actions/checkout@v4" "not found"
fi

# Test: script is executable
if [[ -x "$SCRIPT_DIR/pr_label_assigner.sh" ]]; then
    assert_pass "pr_label_assigner.sh is executable"
else
    assert_fail "pr_label_assigner.sh is executable" "not executable or missing"
fi

# Test: all fixture files exist
for fixture in \
    "fixtures/rules.conf" \
    "fixtures/changed_files_docs.txt" \
    "fixtures/changed_files_api.txt" \
    "fixtures/changed_files_mixed.txt"
do
    if [[ -f "$SCRIPT_DIR/$fixture" ]]; then
        assert_pass "fixture exists: $fixture"
    else
        assert_fail "fixture exists: $fixture" "file not found"
    fi
done

# ============================================================
# SECTION 2: act-based integration tests
# Run once; the workflow covers all three fixture scenarios.
# ============================================================
log ""
log "================================================================"
log "SECTION 2: ACT Integration Tests"
log "================================================================"

# Set up a temp git repo so act can determine the push context
TMPDIR_REPO="$(mktemp -d)"
# shellcheck disable=SC2317
cleanup() { rm -rf "$TMPDIR_REPO"; }
trap cleanup EXIT

log "Setting up temp git repo in $TMPDIR_REPO"

# Copy all project files (including .github/) into temp repo
cp -r "$SCRIPT_DIR/." "$TMPDIR_REPO/"
rm -rf "$TMPDIR_REPO/.git"

cd "$TMPDIR_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "CI Tester"
git add .
git commit -q -m "chore: test run"

log "Running: act push --rm --no-cache-server"
log "--- ACT OUTPUT START ---"

# Run act, capture output; don't fail immediately on non-zero
act_output=""
act_exit=0
if act_output=$(act push --rm --no-cache-server 2>&1); then
    act_exit=0
else
    act_exit=$?
fi

log "$act_output"
log "--- ACT OUTPUT END ---"
log "act exit code: $act_exit"

cd "$SCRIPT_DIR"

# ============================================================
# Assert: act exited with 0
# ============================================================
if [[ $act_exit -eq 0 ]]; then
    assert_pass "act push exit code 0"
else
    assert_fail "act push exit code 0" "got exit code $act_exit"
fi

# ============================================================
# Assert: Job succeeded
# ============================================================
if echo "$act_output" | grep -q "Job succeeded"; then
    assert_pass "Job succeeded"
else
    assert_fail "Job succeeded" "'Job succeeded' not found in act output"
fi

# ============================================================
# Helper: extract labels output from a named step in act output.
# act prints step output as:
#   [Job/Step Name]   | <output line>
# We capture lines after the step header until the next header.
# ============================================================
extract_step_labels() {
    local step_name="$1"
    # Filter lines that look like "  | label" output for this step
    # Act output: "[...] ⭐ Run Main <step name>" then "[...]   | <label>"
    echo "$act_output" \
        | awk -v step="$step_name" '
            /⭐ Run Main / {
                # Check if this header matches our step
                found = index($0, step) > 0
            }
            /  \| / && found {
                # Extract what comes after "  | "
                match($0, /  \| (.*)/, a)
                if (a[1] != "" && a[1] !~ /^===/) print a[1]
            }
            /✅|❌/ && found { found = 0 }
        '
}

# ============================================================
# Test Case 1: docs-only PR -> documentation
# ============================================================
log ""
log "--- Test Case: docs-only PR ---"
docs_labels=$(extract_step_labels "Demo - docs-only PR")
log "Captured labels: $docs_labels"

# Assert EXACT expected label
if echo "$docs_labels" | grep -qx "documentation"; then
    assert_pass "docs-only PR: label 'documentation' (exact)"
else
    assert_fail "docs-only PR: label 'documentation' (exact)" \
        "not found in: $docs_labels"
fi

# Assert no unexpected labels
if echo "$docs_labels" | grep -qvx "documentation"; then
    assert_fail "docs-only PR: no unexpected labels" \
        "unexpected labels: $(echo "$docs_labels" | grep -vx "documentation")"
else
    assert_pass "docs-only PR: no unexpected labels"
fi

# ============================================================
# Test Case 2: API-only PR -> api, backend
# ============================================================
log ""
log "--- Test Case: API-only PR ---"
api_labels=$(extract_step_labels "Demo - API PR")
log "Captured labels: $api_labels"

for expected_label in "api" "backend"; do
    if echo "$api_labels" | grep -qx "$expected_label"; then
        assert_pass "API-only PR: label '$expected_label' (exact)"
    else
        assert_fail "API-only PR: label '$expected_label' (exact)" \
            "not found in: $api_labels"
    fi
done

# Assert 'documentation' and 'tests' are NOT present
for unexpected in "documentation" "tests"; do
    if echo "$api_labels" | grep -qx "$unexpected"; then
        assert_fail "API-only PR: label '$unexpected' absent" \
            "label '$unexpected' unexpectedly found"
    else
        assert_pass "API-only PR: label '$unexpected' absent"
    fi
done

# ============================================================
# Test Case 3: mixed PR -> api, tests, documentation, backend
# ============================================================
log ""
log "--- Test Case: mixed PR ---"
mixed_labels=$(extract_step_labels "Demo - mixed PR")
log "Captured labels: $mixed_labels"

for expected_label in "api" "tests" "documentation" "backend"; do
    if echo "$mixed_labels" | grep -qx "$expected_label"; then
        assert_pass "mixed PR: label '$expected_label' (exact)"
    else
        assert_fail "mixed PR: label '$expected_label' (exact)" \
            "not found in: $mixed_labels"
    fi
done

# Assert priority ordering: api (30) before tests (25) before documentation (10) before backend (5)
api_line=$(echo "$mixed_labels" | grep -n "^api$" | cut -d: -f1)
tests_line=$(echo "$mixed_labels" | grep -n "^tests$" | cut -d: -f1)
doc_line=$(echo "$mixed_labels" | grep -n "^documentation$" | cut -d: -f1)
backend_line=$(echo "$mixed_labels" | grep -n "^backend$" | cut -d: -f1)

log "Priority order check: api=$api_line tests=$tests_line doc=$doc_line backend=$backend_line"

if [[ -n "$api_line" && -n "$tests_line" && "$api_line" -lt "$tests_line" ]]; then
    assert_pass "mixed PR: priority order api before tests"
else
    assert_fail "mixed PR: priority order api before tests" \
        "api_line=$api_line tests_line=$tests_line"
fi

if [[ -n "$tests_line" && -n "$doc_line" && "$tests_line" -lt "$doc_line" ]]; then
    assert_pass "mixed PR: priority order tests before documentation"
else
    assert_fail "mixed PR: priority order tests before documentation" \
        "tests_line=$tests_line doc_line=$doc_line"
fi

if [[ -n "$doc_line" && -n "$backend_line" && "$doc_line" -lt "$backend_line" ]]; then
    assert_pass "mixed PR: priority order documentation before backend"
else
    assert_fail "mixed PR: priority order documentation before backend" \
        "doc_line=$doc_line backend_line=$backend_line"
fi

# ============================================================
# SUMMARY
# ============================================================
log ""
log "================================================================"
log "TEST SUMMARY"
log "================================================================"
log "PASSED: $PASS_COUNT"
log "FAILED: $FAIL_COUNT"
log ""

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    log "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do
        log "  - $t"
    done
    log ""
fi

if [[ $FAIL_COUNT -eq 0 ]]; then
    log "ALL TESTS PASSED"
    exit 0
else
    log "SOME TESTS FAILED"
    exit 1
fi
