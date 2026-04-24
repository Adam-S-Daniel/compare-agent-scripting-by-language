#!/usr/bin/env bats
# tests/aggregate.bats - TDD tests for aggregate.sh
# Tests run in order: each block first fails (RED), then passes after implementation (GREEN).

FIXTURES_DIR="${BATS_TEST_DIRNAME}/../fixtures"
SCRIPT="${BATS_TEST_DIRNAME}/../aggregate.sh"

setup() {
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ──────────────────────────────────────────────
# RED → GREEN: JUnit XML parsing
# ──────────────────────────────────────────────

@test "parses JUnit XML and reports correct test count for single file" {
    run "$SCRIPT" "${FIXTURES_DIR}/junit-chrome.xml" -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Total Tests** | 5 |"* ]]
}

@test "parses JUnit XML: counts pass/fail/skip correctly for chrome fixture" {
    run "$SCRIPT" "${FIXTURES_DIR}/junit-chrome.xml" -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Passed** | 3 |"* ]]
    [[ "$output" == *"| **Failed** | 1 |"* ]]
    [[ "$output" == *"| **Skipped** | 1 |"* ]]
}

@test "parses JUnit XML: includes failed test name in Failed Tests section" {
    run "$SCRIPT" "${FIXTURES_DIR}/junit-chrome.xml" -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Failed Tests"* ]]
    [[ "$output" == *"test_checkout"* ]]
}

# ──────────────────────────────────────────────
# RED → GREEN: JSON parsing
# ──────────────────────────────────────────────

@test "parses JSON test results and reports correct test count" {
    run "$SCRIPT" "${FIXTURES_DIR}/results-node18.json" -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Total Tests** | 4 |"* ]]
}

@test "parses JSON: counts pass/fail/skip correctly for node18 fixture" {
    run "$SCRIPT" "${FIXTURES_DIR}/results-node18.json" -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Passed** | 3 |"* ]]
    [[ "$output" == *"| **Failed** | 1 |"* ]]
    [[ "$output" == *"| **Skipped** | 0 |"* ]]
}

# ──────────────────────────────────────────────
# RED → GREEN: Aggregation across multiple files
# ──────────────────────────────────────────────

@test "aggregates totals across all four fixture files" {
    run "$SCRIPT" \
        "${FIXTURES_DIR}/junit-chrome.xml" \
        "${FIXTURES_DIR}/junit-firefox.xml" \
        "${FIXTURES_DIR}/results-node18.json" \
        "${FIXTURES_DIR}/results-node20.json" \
        -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Total Tests** | 18 |"* ]]
    [[ "$output" == *"| **Passed** | 13 |"* ]]
    [[ "$output" == *"| **Failed** | 3 |"* ]]
    [[ "$output" == *"| **Skipped** | 2 |"* ]]
}

@test "aggregates duration across all four fixture files" {
    run "$SCRIPT" \
        "${FIXTURES_DIR}/junit-chrome.xml" \
        "${FIXTURES_DIR}/junit-firefox.xml" \
        "${FIXTURES_DIR}/results-node18.json" \
        "${FIXTURES_DIR}/results-node20.json" \
        -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    # Total duration: 1.500 + 2.000 + 0.220 + 0.206 = 3.926 → 3.93s
    [[ "$output" == *"| **Duration** | 3.93s |"* ]]
}

# ──────────────────────────────────────────────
# RED → GREEN: Flaky test detection
# ──────────────────────────────────────────────

@test "detects flaky tests across multiple runs" {
    run "$SCRIPT" \
        "${FIXTURES_DIR}/junit-chrome.xml" \
        "${FIXTURES_DIR}/junit-firefox.xml" \
        "${FIXTURES_DIR}/results-node18.json" \
        "${FIXTURES_DIR}/results-node20.json" \
        -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    # test_signup: pass in chrome, fail in firefox
    # test_checkout: fail in chrome, pass in firefox
    # unit_transform: fail in node18, pass in node20
    [[ "$output" == *"## Flaky Tests (3)"* ]]
    [[ "$output" == *"test_signup"* ]]
    [[ "$output" == *"test_checkout"* ]]
    [[ "$output" == *"unit_transform"* ]]
}

@test "reports no flaky tests when none exist" {
    # Only use node20 (all pass) and chrome (deterministic fail on test_checkout)
    run "$SCRIPT" \
        "${FIXTURES_DIR}/junit-chrome.xml" \
        "${FIXTURES_DIR}/results-node20.json" \
        -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    # No test appears in both pass and fail states across these two files
    [[ "$output" == *"No flaky tests detected"* ]]
}

# ──────────────────────────────────────────────
# RED → GREEN: Directory input
# ──────────────────────────────────────────────

@test "accepts a directory as input and processes all XML and JSON files" {
    run "$SCRIPT" "${FIXTURES_DIR}" -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Total Tests** | 18 |"* ]]
}

# ──────────────────────────────────────────────
# RED → GREEN: Error handling
# ──────────────────────────────────────────────

@test "exits with error when no input files provided" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]] || [[ "${lines[0]}" == *"ERROR"* ]]
}

@test "warns about missing files but continues with valid ones" {
    run "$SCRIPT" \
        "${FIXTURES_DIR}/nonexistent.xml" \
        "${FIXTURES_DIR}/junit-chrome.xml" \
        -o "${TEST_TMPDIR}/out.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| **Total Tests** | 5 |"* ]]
}

@test "writes markdown to specified output file" {
    run "$SCRIPT" "${FIXTURES_DIR}/junit-chrome.xml" -o "${TEST_TMPDIR}/custom.md"
    [ "$status" -eq 0 ]
    [ -f "${TEST_TMPDIR}/custom.md" ]
    grep -q "## Test Results Summary" "${TEST_TMPDIR}/custom.md"
}

# ──────────────────────────────────────────────
# RED → GREEN: Workflow structure tests
# ──────────────────────────────────────────────

@test "workflow file exists at expected path" {
    [ -f "${BATS_TEST_DIRNAME}/../.github/workflows/test-results-aggregator.yml" ]
}

@test "workflow references aggregate.sh which exists" {
    local wf="${BATS_TEST_DIRNAME}/../.github/workflows/test-results-aggregator.yml"
    grep -q "aggregate.sh" "$wf"
    [ -f "${BATS_TEST_DIRNAME}/../aggregate.sh" ]
}

@test "workflow has required triggers (push and workflow_dispatch)" {
    local wf="${BATS_TEST_DIRNAME}/../.github/workflows/test-results-aggregator.yml"
    grep -q "push:" "$wf"
    grep -q "workflow_dispatch" "$wf"
}

@test "workflow has at least one job defined" {
    local wf="${BATS_TEST_DIRNAME}/../.github/workflows/test-results-aggregator.yml"
    grep -q "jobs:" "$wf"
    grep -q "runs-on:" "$wf"
}

@test "actionlint passes on the workflow file" {
    run actionlint "${BATS_TEST_DIRNAME}/../.github/workflows/test-results-aggregator.yml"
    [ "$status" -eq 0 ]
}
