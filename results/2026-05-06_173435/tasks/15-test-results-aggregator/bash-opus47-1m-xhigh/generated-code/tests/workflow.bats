#!/usr/bin/env bats
# Workflow validation tests. Two layers:
#   1. Static: actionlint passes; YAML structure has the expected
#      triggers/jobs/steps; referenced files exist.
#   2. Dynamic: act-result.txt (produced by tests/run-act-cases.sh) contains
#      the expected per-case outputs and "Job succeeded" markers.

setup_file() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORKFLOW="$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    RESULT_FILE="$PROJECT_ROOT/act-result.txt"
    export PROJECT_ROOT WORKFLOW RESULT_FILE
}

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORKFLOW="$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    RESULT_FILE="$PROJECT_ROOT/act-result.txt"
}

# --- static validation ----------------------------------------------------

@test "actionlint passes on the workflow file" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, workflow_dispatch and schedule triggers" {
    run grep -E '^(on:|  push:|  pull_request:|  workflow_dispatch:|  schedule:)' \
        "$WORKFLOW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"on:"* ]]
    [[ "$output" == *"push:"* ]]
    [[ "$output" == *"pull_request:"* ]]
    [[ "$output" == *"workflow_dispatch:"* ]]
    [[ "$output" == *"schedule:"* ]]
}

@test "workflow declares a least-privilege contents:read permission" {
    run grep -E '^\s+contents:\s+read' "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow uses pinned actions/checkout@v4" {
    run grep 'uses: actions/checkout@v4' "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow references the aggregate.sh script which exists on disk" {
    run grep './aggregate.sh' "$WORKFLOW"
    [ "$status" -eq 0 ]
    [ -x "$PROJECT_ROOT/aggregate.sh" ]
}

@test "workflow declares an aggregate job" {
    run grep -E '^  aggregate:' "$WORKFLOW"
    [ "$status" -eq 0 ]
}

# --- dynamic: act execution -----------------------------------------------

@test "act-result.txt exists (run-act-cases.sh has been executed)" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    [ -s "$RESULT_FILE" ]
}

@test "act exit code was 0 for the all-pass case" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    run grep -E '^=== ACT EXIT: all-pass = 0 ===' "$RESULT_FILE"
    [ "$status" -eq 0 ]
}

@test "act exit code was 0 for the single-fail case" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    run grep -E '^=== ACT EXIT: single-fail = 0 ===' "$RESULT_FILE"
    [ "$status" -eq 0 ]
}

@test "act exit code was 0 for the matrix-flaky case" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    run grep -E '^=== ACT EXIT: matrix-flaky = 0 ===' "$RESULT_FILE"
    [ "$status" -eq 0 ]
}

@test "every act case ends with 'Job succeeded'" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    # Three test cases ran -> at least three "Job succeeded" lines.
    run grep -c 'Job succeeded' "$RESULT_FILE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 3 ]
}

# --- dynamic: per-case exact-value assertions -----------------------------
#
# The bash helper section() prints just the lines belonging to a named
# case, between its "ACT CASE: <name>" header and the next case header.
# Every assertion below is anchored to known expected values for the
# fixture set fed into that case (see tests/run-act-cases.sh).

section() {
    local name=$1
    awk -v name="$name" '
        /^=== ACT CASE: / { current = ($4 == name); next }
        /^=== ACT EXIT:/  { current = 0 }
        current { print }
    ' "$RESULT_FILE"
}

@test "all-pass case emits 'Status: PASSED' with 4 tests, 0 flaky" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    sec=$(section "all-pass")
    [[ "$sec" == *"**Status:** PASSED"* ]]
    [[ "$sec" == *"# Test Results Summary :white_check_mark:"* ]]
    [[ "$sec" == *"| Total tests | 4 |"* ]]
    [[ "$sec" == *"| Passed | 4 |"* ]]
    [[ "$sec" == *"| Failed | 0 |"* ]]
    [[ "$sec" == *"| Flaky | 0 |"* ]]
    [[ "$sec" == *"_No flaky tests detected._"* ]]
}

@test "single-fail case reports 1 passed, 2 failed, 1 skipped, 0 flaky" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    sec=$(section "single-fail")
    [[ "$sec" == *"**Status:** FAILED"* ]]
    [[ "$sec" == *"# Test Results Summary :x:"* ]]
    [[ "$sec" == *"| Total tests | 4 |"* ]]
    [[ "$sec" == *"| Passed | 1 |"* ]]
    [[ "$sec" == *"| Failed | 2 |"* ]]
    [[ "$sec" == *"| Skipped | 1 |"* ]]
    [[ "$sec" == *"| Flaky | 0 |"* ]]
}

@test "matrix-flaky case reports 7 passed, 4 failed, 1 skipped, 2 flaky" {
    [ -f "$RESULT_FILE" ] || skip "run tests/run-act-cases.sh first"
    sec=$(section "matrix-flaky")
    [[ "$sec" == *"**Status:** FAILED"* ]]
    [[ "$sec" == *"| Total tests | 12 |"* ]]
    [[ "$sec" == *"| Passed | 7 |"* ]]
    [[ "$sec" == *"| Failed | 4 |"* ]]
    [[ "$sec" == *"| Skipped | 1 |"* ]]
    [[ "$sec" == *"| Flaky | 2 |"* ]]
    [[ "$sec" == *"| Files aggregated | 4 |"* ]]
    [[ "$sec" == *"| Duration (s) | 9.200 |"* ]]
    # Known flaky tests appear in the Flaky section
    [[ "$sec" == *'auth.LoginTests::flaky_login'* ]]
    [[ "$sec" == *'data.SyncTests::flaky_sync'* ]]
}
