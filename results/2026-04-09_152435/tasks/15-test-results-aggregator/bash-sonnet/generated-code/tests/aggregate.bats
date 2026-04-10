#!/usr/bin/env bats
# tests/aggregate.bats
# TDD test suite for the test results aggregator.
#
# Test design:
#   Red/green TDD: each @test was first written to fail, then the minimum
#   implementation was added to make it pass.
#
# Fixture data (fixtures/ directory) produces known exact totals:
#   JUnit XML: junit-run1.xml (Matrix-Ubuntu), junit-run2.xml (Matrix-Windows)
#   JSON:      json-run3.json (Matrix-Mac),    json-run4.json (Matrix-Node18)
#
#   Grand totals: 12 tests, 7 passed, 3 failed, 2 skipped, 7.00s duration
#   Flaky tests:  test-flaky, test-b, test-d

# Compute the project root relative to this test file
setup() {
    PROJ_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SCRIPT="$PROJ_DIR/aggregate.sh"
    FIXTURES="$PROJ_DIR/fixtures"
    WORKFLOW="$PROJ_DIR/.github/workflows/test-results-aggregator.yml"
}

# ── TDD Step 1: script exists ──────────────────────────────────────────────
@test "aggregate.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── TDD Step 2: script accepts a fixtures directory without error ──────────
@test "script runs successfully on fixtures directory" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
}

# ── TDD Step 3: markdown structure ────────────────────────────────────────
@test "output contains Test Results Summary header" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "# Test Results Summary"
}

@test "output contains Overview section" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "## Overview"
}

@test "output contains Results by Run section" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "## Results by Run"
}

@test "output contains Flaky Tests section" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "## Flaky Tests"
}

# ── TDD Step 4: exact aggregate totals ────────────────────────────────────
@test "aggregates total tests correctly to 12" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "| Total Tests | 12 |"
}

@test "aggregates passed tests correctly to 7" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "| Passed | 7 |"
}

@test "aggregates failed tests correctly to 3" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "| Failed | 3 |"
}

@test "aggregates skipped tests correctly to 2" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "| Skipped | 2 |"
}

@test "computes total duration correctly to 7.00s" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "| Total Duration | 7.00s |"
}

# ── TDD Step 5: per-run rows ───────────────────────────────────────────────
@test "shows Matrix-Ubuntu row in results table" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "Matrix-Ubuntu"
}

@test "shows Matrix-Windows row in results table" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "Matrix-Windows"
}

@test "shows Matrix-Mac row in results table" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "Matrix-Mac"
}

@test "shows Matrix-Node18 row in results table" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "Matrix-Node18"
}

# ── TDD Step 6: flaky test detection ──────────────────────────────────────
@test "identifies test-flaky as a flaky test" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "test-flaky"
}

@test "identifies test-b as a flaky test" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    # test-b passed in run1, failed in run2 -> flaky
    echo "$output" | grep -qF "| test-b |"
}

@test "identifies test-d as a flaky test" {
    run bash "$SCRIPT" "$FIXTURES"
    [ "$status" -eq 0 ]
    # test-d passed in run3, failed in run4 -> flaky
    echo "$output" | grep -qF "| test-d |"
}

# ── TDD Step 7: error handling ────────────────────────────────────────────
@test "exits with error for non-existent directory" {
    run bash "$SCRIPT" "/nonexistent/directory/12345"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qiF "error"
}

@test "exits with error when no arguments provided" {
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}

# ── TDD Step 8: workflow structure ────────────────────────────────────────
@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
    run grep -q "push:" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow references aggregate.sh" {
    run grep -q "aggregate.sh" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow references fixtures directory" {
    run grep -q "fixtures" "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}
