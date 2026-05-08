#!/usr/bin/env bats
# tests/aggregator.bats
# TDD test suite for test-results-aggregator.sh
#
# Written in red/green TDD phases:
#   Phase 1 (first failing test): error handling - drives usage() and validation
#   Phase 2: JUnit XML parsing - drives parse_junit() function
#   Phase 3: JSON parsing - drives parse_json() function
#   Phase 4: multi-file aggregation - drives accumulation logic
#   Phase 5: flaky test detection - drives detect_flaky()
#   Phase 6: markdown structure - drives output format
#   Phase 7: workflow structure - drives .github/workflows/ file
#   Phase 8: actionlint - ensures workflow passes static analysis

SCRIPT="${BATS_TEST_DIRNAME}/../test-results-aggregator.sh"
FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/test-results-aggregator.yml"

# ---------------------------------------------------------------------------
# Phase 1: Error handling (written first - drove usage() and file validation)
# ---------------------------------------------------------------------------

@test "fails with no arguments" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "fails when file does not exist" {
    run bash "$SCRIPT" /nonexistent/path/file.xml
    [ "$status" -eq 1 ]
    [[ "$output" == *"File not found"* ]]
}

@test "fails on unknown file format" {
    local tmpfile
    tmpfile=$(mktemp /tmp/test-XXXXXX.txt)
    echo "not a test result" > "$tmpfile"
    run bash "$SCRIPT" "$tmpfile"
    rm -f "$tmpfile"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown format"* ]]
}

# ---------------------------------------------------------------------------
# Phase 2: JUnit XML parsing
# ---------------------------------------------------------------------------

@test "parses JUnit XML: correct passed count" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Passed | 2 |"* ]]
}

@test "parses JUnit XML: correct failed count" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Failed | 1 |"* ]]
}

@test "parses JUnit XML: correct skipped count" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Skipped | 1 |"* ]]
}

@test "parses JUnit XML: total test count" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Total Tests | 4 |"* ]]
}

# ---------------------------------------------------------------------------
# Phase 3: JSON parsing
# ---------------------------------------------------------------------------

@test "parses JSON: correct passed count" {
    run bash "$SCRIPT" "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Passed | 2 |"* ]]
}

@test "parses JSON: correct failed count" {
    run bash "$SCRIPT" "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Failed | 1 |"* ]]
}

@test "parses JSON: no skipped tests" {
    run bash "$SCRIPT" "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Skipped | 0 |"* ]]
}

# ---------------------------------------------------------------------------
# Phase 4: Multi-file aggregation across matrix runs
# ---------------------------------------------------------------------------

@test "aggregates: files processed count" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml" \
        "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Files Processed | 3 |"* ]]
}

@test "aggregates: total test instances" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml" \
        "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Total Tests | 11 |"* ]]
}

@test "aggregates: total passed count" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml" \
        "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Passed | 6 |"* ]]
}

@test "aggregates: total failed count" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml" \
        "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Failed | 3 |"* ]]
}

@test "aggregates: total skipped count" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml" \
        "${FIXTURES}/json-matrix-macos.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Skipped | 2 |"* ]]
}

# ---------------------------------------------------------------------------
# Phase 5: Flaky test detection
# ---------------------------------------------------------------------------

@test "detects flaky TestB (passed ubuntu, failed windows)" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test.core.TestB"* ]]
}

@test "detects flaky TestC (failed ubuntu, passed windows)" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test.core.TestC"* ]]
}

@test "reports no flaky tests when single file" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No flaky tests detected"* ]]
}

@test "TestA and TestD are not marked flaky" {
    run bash "$SCRIPT" \
        "${FIXTURES}/junit-matrix-ubuntu.xml" \
        "${FIXTURES}/junit-matrix-windows.xml"
    [ "$status" -eq 0 ]
    # TestA passed in both, TestD skipped in both - neither is flaky
    [[ "$output" != *"TestA | Passed in some"* ]]
    [[ "$output" != *"TestD | Passed in some"* ]]
}

# ---------------------------------------------------------------------------
# Phase 6: Markdown output structure
# ---------------------------------------------------------------------------

@test "output has required top-level header" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary"* ]]
}

@test "output has Overview section" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Overview"* ]]
}

@test "output has Flaky Tests section" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Flaky Tests"* ]]
}

@test "output has Files Analyzed section" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Files Analyzed"* ]]
}

@test "status shows FAILED when there are failures" {
    run bash "$SCRIPT" "${FIXTURES}/junit-matrix-ubuntu.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Status: FAILED"* ]]
}

@test "status shows PASSED when no failures" {
    local tmpfile
    tmpfile=$(mktemp /tmp/test-XXXXXX.json)
    cat > "$tmpfile" <<'FIXTURE'
{
  "suite": "all-passing",
  "duration": 0.5,
  "tests": [
    {"name": "test.ok.Alpha", "status": "passed", "duration": 0.3},
    {"name": "test.ok.Beta",  "status": "passed", "duration": 0.2}
  ]
}
FIXTURE
    run bash "$SCRIPT" "$tmpfile"
    rm -f "$tmpfile"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Status: PASSED"* ]]
}

# ---------------------------------------------------------------------------
# Phase 7: Workflow file structure
# ---------------------------------------------------------------------------

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
    grep -q "push:" "$WORKFLOW"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" "$WORKFLOW"
}

@test "workflow references the aggregator script" {
    grep -q "test-results-aggregator.sh" "$WORKFLOW"
}

@test "workflow has bats install or run step" {
    grep -q "bats" "$WORKFLOW"
}

@test "workflow has a checkout step" {
    grep -q "actions/checkout" "$WORKFLOW"
}

# ---------------------------------------------------------------------------
# Phase 8: actionlint validation
# ---------------------------------------------------------------------------

@test "workflow passes actionlint" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}
