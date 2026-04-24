#!/usr/bin/env bats
# Tests for aggregate.sh - test results aggregator.
# Follows red/green TDD: each test exercises one piece of behavior.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../aggregate.sh"
    FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
    TMPDIR_BATS="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR_BATS"
}

# --- Existence / shape ----------------------------------------------------

@test "aggregate.sh exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "aggregate.sh prints usage with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "aggregate.sh errors with missing input dir" {
    run "$SCRIPT" /no/such/dir
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* || "$output" == *"No such"* ]]
}

# --- JUnit XML parsing ----------------------------------------------------

@test "parses a single JUnit XML file: counts passed/failed/skipped" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total: 4"* ]]
    [[ "$output" == *"Passed: 2"* ]]
    [[ "$output" == *"Failed: 1"* ]]
    [[ "$output" == *"Skipped: 1"* ]]
}

@test "JUnit duration is summed across testcases" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    # run1 totals: 0.10 + 0.20 + 0.30 + 0.40 = 1.00s
    [[ "$output" == *"Duration: 1.00s"* ]]
}

# --- JSON parsing ---------------------------------------------------------

@test "parses a single JSON file with passed/failed/skipped" {
    cp "$FIXTURES/json-run1.json" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total: 3"* ]]
    [[ "$output" == *"Passed: 2"* ]]
    [[ "$output" == *"Failed: 1"* ]]
    [[ "$output" == *"Skipped: 0"* ]]
}

# --- Aggregation across multiple files ------------------------------------

@test "aggregates totals across XML + JSON files" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    cp "$FIXTURES/json-run1.json" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total: 7"* ]]
    [[ "$output" == *"Passed: 4"* ]]
    [[ "$output" == *"Failed: 2"* ]]
    [[ "$output" == *"Skipped: 1"* ]]
}

# --- Flaky test detection -------------------------------------------------

@test "detects flaky tests across runs (passed in some, failed in others)" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    cp "$FIXTURES/junit-run2.xml" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    # run1: testB fails, run2: testB passes -> flaky
    [[ "$output" == *"Flaky"* ]]
    [[ "$output" == *"suiteA.testB"* ]]
}

@test "non-flaky tests are not listed under flaky section" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    cp "$FIXTURES/junit-run2.xml" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    # testA passes in both runs, should not appear in flaky list
    # crude check: confirm testA isn't in a flaky bullet
    ! grep -E '^- .*testA$' <<< "$output"
}

# --- Markdown output ------------------------------------------------------

@test "produces a markdown summary header" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary"* ]]
}

@test "writes summary to GITHUB_STEP_SUMMARY when set" {
    cp "$FIXTURES/junit-run1.xml" "$TMPDIR_BATS/"
    summary_file="$TMPDIR_BATS/summary.md"
    GITHUB_STEP_SUMMARY="$summary_file" run "$SCRIPT" "$TMPDIR_BATS"
    [ "$status" -eq 0 ]
    [ -f "$summary_file" ]
    grep -q "Test Results Summary" "$summary_file"
}

# --- Lint -----------------------------------------------------------------

@test "aggregate.sh passes shellcheck" {
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "aggregate.sh passes bash -n" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}
