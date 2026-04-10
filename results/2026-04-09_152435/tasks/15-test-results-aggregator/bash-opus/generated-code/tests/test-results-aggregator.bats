#!/usr/bin/env bats
# tests/test-results-aggregator.bats
#
# Test suite for the test results aggregator.
# Structure tests validate YAML/script correctness locally.
# Functional tests run all scenarios through act (GitHub Actions).

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    cd "$PROJECT_DIR"
}

# ─── Workflow Structure Tests ───────────────────────────────────────────────

@test "structure: workflow file exists" {
    [[ -f .github/workflows/test-results-aggregator.yml ]]
}

@test "structure: workflow has push trigger" {
    grep -q "push:" .github/workflows/test-results-aggregator.yml
}

@test "structure: workflow has pull_request trigger" {
    grep -q "pull_request:" .github/workflows/test-results-aggregator.yml
}

@test "structure: workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" .github/workflows/test-results-aggregator.yml
}

@test "structure: workflow has aggregate job" {
    grep -q "aggregate:" .github/workflows/test-results-aggregator.yml
}

@test "structure: workflow uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" .github/workflows/test-results-aggregator.yml
}

@test "structure: workflow references aggregate-test-results.sh" {
    grep -q "aggregate-test-results.sh" .github/workflows/test-results-aggregator.yml
}

@test "structure: script file exists and is executable" {
    [[ -f aggregate-test-results.sh ]]
    [[ -x aggregate-test-results.sh ]]
}

@test "structure: fixture directories exist with files" {
    [[ -d fixtures/junit-only ]]
    [[ -d fixtures/json-only ]]
    [[ -d fixtures/mixed ]]
    # Each scenario has at least 2 files for flaky detection
    [[ $(ls fixtures/junit-only/ | wc -l) -ge 2 ]]
    [[ $(ls fixtures/json-only/ | wc -l) -ge 2 ]]
    [[ $(ls fixtures/mixed/ | wc -l) -ge 2 ]]
}

@test "structure: actionlint passes" {
    run actionlint .github/workflows/test-results-aggregator.yml
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "structure: shellcheck passes on script" {
    run shellcheck aggregate-test-results.sh
    echo "$output"
    [[ "$status" -eq 0 ]]
}

@test "structure: bash -n syntax check passes" {
    run bash -n aggregate-test-results.sh
    echo "$output"
    [[ "$status" -eq 0 ]]
}

# ─── Functional Tests via act ───────────────────────────────────────────────

@test "act: all scenarios produce correct aggregated results" {
    # Create isolated temp git repo with project files
    local tmpdir
    tmpdir=$(mktemp -d)

    cp aggregate-test-results.sh "$tmpdir/"
    cp -r fixtures "$tmpdir/"
    cp -r .github "$tmpdir/"
    cp .actrc "$tmpdir/"

    cd "$tmpdir"
    chmod +x aggregate-test-results.sh
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git add -A
    git commit -q -m "initial"

    # Run act — capture stdout+stderr (--pull=false for local-only images)
    local act_output act_exit=0
    act_output=$(act push --rm --pull=false 2>&1) || act_exit=$?

    cd "$PROJECT_DIR"

    # Save output to act-result.txt (required artifact, appended with delimiters)
    {
        echo "========================================"
        echo "=== ACT RUN: all-scenarios $(date -Iseconds) ==="
        echo "========================================"
        echo "$act_output"
        echo "=== END ACT RUN ==="
    } >> "$PROJECT_DIR/act-result.txt"

    rm -rf "$tmpdir"

    # ── Assert act exited successfully ──
    echo "Act exit code: $act_exit"
    [[ "$act_exit" -eq 0 ]]

    # ── Assert job succeeded ──
    [[ "$act_output" == *"Job succeeded"* ]]

    # ── junit-only scenario (5+5 tests across 2 XML files) ──
    local junit_output
    junit_output=$(echo "$act_output" | sed -n '/SCENARIO: junit-only/,/END SCENARIO: junit-only/p')

    [[ "$junit_output" == *"Total Tests | 10"* ]]
    [[ "$junit_output" == *"Passed | 7"* ]]
    [[ "$junit_output" == *"Failed | 2"* ]]
    [[ "$junit_output" == *"Skipped | 1"* ]]
    [[ "$junit_output" == *"Duration | 4.80s"* ]]
    [[ "$junit_output" == *"Pass Rate | 70.0%"* ]]
    # Flaky tests: test_divide and test_subtract flip between runs
    [[ "$junit_output" == *"Flaky Tests"* ]]
    [[ "$junit_output" == *"MathTests.test_divide"* ]]
    [[ "$junit_output" == *"MathTests.test_subtract"* ]]
    # Failed tests appear in listing
    [[ "$junit_output" == *"Failed Tests"* ]]

    # ── json-only scenario (4+4 tests across 2 JSON files) ──
    local json_output
    json_output=$(echo "$act_output" | sed -n '/SCENARIO: json-only/,/END SCENARIO: json-only/p')

    [[ "$json_output" == *"Total Tests | 8"* ]]
    [[ "$json_output" == *"Passed | 6"* ]]
    [[ "$json_output" == *"Failed | 1"* ]]
    [[ "$json_output" == *"Skipped | 1"* ]]
    [[ "$json_output" == *"Duration | 3.30s"* ]]
    [[ "$json_output" == *"Pass Rate | 75.0%"* ]]
    [[ "$json_output" == *"Flaky Tests"* ]]
    [[ "$json_output" == *"AuthTests.test_logout"* ]]

    # ── mixed scenario (3 XML + 3 JSON tests, cross-format flaky detection) ──
    local mixed_output
    mixed_output=$(echo "$act_output" | sed -n '/SCENARIO: mixed/,/END SCENARIO: mixed/p')

    [[ "$mixed_output" == *"Total Tests | 6"* ]]
    [[ "$mixed_output" == *"Passed | 4"* ]]
    [[ "$mixed_output" == *"Failed | 2"* ]]
    [[ "$mixed_output" == *"Skipped | 0"* ]]
    [[ "$mixed_output" == *"Duration | 2.60s"* ]]
    [[ "$mixed_output" == *"Pass Rate | 66.7%"* ]]
    [[ "$mixed_output" == *"Flaky Tests"* ]]
    [[ "$mixed_output" == *"ApiTests.test_api_get"* ]]
    [[ "$mixed_output" == *"ApiTests.test_api_post"* ]]
}

@test "act-result.txt was created and is non-empty" {
    [[ -f "$PROJECT_DIR/act-result.txt" ]]
    [[ -s "$PROJECT_DIR/act-result.txt" ]]
}
