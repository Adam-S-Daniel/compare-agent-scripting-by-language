#!/usr/bin/env bats
# Tests for the test results aggregator script.
# Uses red/green TDD: each test was written before the corresponding implementation.
#
# Test categories:
#   1-2:   Script existence and error handling
#   3-8:   Parsing and aggregation correctness
#   9-11:  Flaky test detection and markdown output
#   12-14: Workflow structure and actionlint validation
#   15:    Full act end-to-end run (slow, ~60s)

# --- Setup / Teardown ---

setup() {
    TEST_TMPDIR=$(mktemp -d)
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    AGGREGATE="$PROJECT_ROOT/aggregate.sh"
    FIXTURES="$PROJECT_ROOT/fixtures"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- Test 1: Script exists and is executable (RED first) ---

@test "aggregate.sh exists and is executable" {
    [ -f "$AGGREGATE" ]
    [ -x "$AGGREGATE" ]
}

# --- Test 2: Usage error with no arguments ---

@test "prints usage and exits non-zero with no arguments" {
    run "$AGGREGATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

# --- Test 3: Parses JUnit XML - passed count ---

@test "parses JUnit XML run1 - 3 passed 0 failed" {
    run "$AGGREGATE" "$FIXTURES/junit-run1.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Passed | 3"* ]]
    [[ "$output" == *"Failed | 0"* ]]
}

# --- Test 4: Parses JUnit XML with failures ---

@test "parses JUnit XML run2 - 1 passed 2 failed" {
    run "$AGGREGATE" "$FIXTURES/junit-run2.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Passed | 1"* ]]
    [[ "$output" == *"Failed | 2"* ]]
}

# --- Test 5: Parses JSON results ---

@test "parses JSON run1 - 2 passed 1 skipped" {
    run "$AGGREGATE" "$FIXTURES/results-run1.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Passed | 2"* ]]
    [[ "$output" == *"Skipped | 1"* ]]
}

# --- Test 6: Aggregates totals across all four fixture files ---
# Expected: passed=8, failed=2, skipped=2, total=12

@test "aggregates totals across all fixture files" {
    run "$AGGREGATE" \
        "$FIXTURES/junit-run1.xml" \
        "$FIXTURES/junit-run2.xml" \
        "$FIXTURES/results-run1.json" \
        "$FIXTURES/results-run2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"passed=8"* ]]
    [[ "$output" == *"failed=2"* ]]
    [[ "$output" == *"skipped=2"* ]]
}

# --- Test 7: Duration totals correctly (1.80+2.10+3.50+3.70=11.10s) ---

@test "computes total duration correctly across all files" {
    run "$AGGREGATE" \
        "$FIXTURES/junit-run1.xml" \
        "$FIXTURES/junit-run2.xml" \
        "$FIXTURES/results-run1.json" \
        "$FIXTURES/results-run2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"duration=11.10s"* ]]
}

# --- Test 8: Single file - no flaky tests ---

@test "reports no flaky tests when only one run provided" {
    run "$AGGREGATE" "$FIXTURES/junit-run1.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"flaky=none"* ]]
}

# --- Test 9: Detects flaky tests across runs ---
# test_beta: pass in run1, fail in run2 → flaky
# test_flaky: pass in run1, fail in run2 → flaky

@test "detects flaky tests - test_beta and test_flaky" {
    run "$AGGREGATE" \
        "$FIXTURES/junit-run1.xml" \
        "$FIXTURES/junit-run2.xml" \
        "$FIXTURES/results-run1.json" \
        "$FIXTURES/results-run2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"flaky=test_beta,test_flaky"* ]]
    [[ "$output" == *"\`test_beta\`"* ]]
    [[ "$output" == *"\`test_flaky\`"* ]]
}

# --- Test 10: Generates markdown structure ---

@test "generates markdown with expected headers and table" {
    run "$AGGREGATE" "$FIXTURES/junit-run1.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Test Results Summary"* ]]
    [[ "$output" == *"| Total Tests |"* ]]
    [[ "$output" == *"| Metric | Value |"* ]]
}

# --- Test 11: Error handling - missing file ---

@test "exits non-zero with error message for missing file" {
    run "$AGGREGATE" "/no/such/file.xml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

# --- Test 12: Error handling - unsupported format ---

@test "exits non-zero for unsupported file extension" {
    echo "data" > "$TEST_TMPDIR/results.csv"
    run "$AGGREGATE" "$TEST_TMPDIR/results.csv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

# --- Test 13: Workflow structure checks ---

@test "workflow file exists with push and pull_request triggers" {
    local wf="$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ -f "$wf" ]
    run grep -q "push:" "$wf"
    [ "$status" -eq 0 ]
    run grep -q "pull_request:" "$wf"
    [ "$status" -eq 0 ]
}

@test "workflow references aggregate.sh and fixtures exist" {
    local wf="$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    run grep -q "aggregate.sh" "$wf"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/aggregate.sh" ]
    [ -d "$PROJECT_ROOT/fixtures" ]
}

# --- Test 14: actionlint validation ---

@test "actionlint passes on the workflow file" {
    local wf="$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    run actionlint "$wf"
    [ "$status" -eq 0 ]
}

# --- Test 15: Full end-to-end act run (slow ~60s) ---
# Sets up a temp git repo, copies project files, runs act push,
# appends output to act-result.txt, and asserts on exact expected values.

@test "workflow runs successfully via act with expected aggregation output" {
    local act_dir="$TEST_TMPDIR/act_workspace"
    mkdir -p "$act_dir"

    # Copy all project files into the temp git repo
    cp -r "$PROJECT_ROOT/." "$act_dir/"

    # Initialize a git repo (act requires one)
    git -C "$act_dir" init -b main
    git -C "$act_dir" config user.email "ci@test.local"
    git -C "$act_dir" config user.name "CI Test"
    git -C "$act_dir" add -A
    git -C "$act_dir" commit -m "ci: test run"

    # Run act with --pull=false to use the local image (act-ubuntu-pwsh:latest)
    run bash -c "cd '$act_dir' && act push --rm --pull=false -W .github/workflows/test-results-aggregator.yml 2>&1"

    # Save output to act-result.txt in project root (required artifact)
    {
        echo "=== Test Case: Full Workflow Run ==="
        echo "Exit code: $status"
        echo "$output"
        echo "=== End Test Case ==="
    } >> "$PROJECT_ROOT/act-result.txt"

    # Assert act succeeded
    [ "$status" -eq 0 ]

    # Assert job completed successfully
    [[ "$output" == *"Job succeeded"* ]]

    # Assert exact expected aggregation values
    [[ "$output" == *"passed=8"* ]]
    [[ "$output" == *"failed=2"* ]]
    [[ "$output" == *"skipped=2"* ]]
    [[ "$output" == *"duration=11.10s"* ]]
    [[ "$output" == *"flaky=test_beta,test_flaky"* ]]
}
