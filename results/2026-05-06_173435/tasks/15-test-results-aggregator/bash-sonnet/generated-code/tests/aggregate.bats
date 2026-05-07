#!/usr/bin/env bats
# Test suite for aggregate.sh - Test Results Aggregator
# Uses bats-core. Run with: bats tests/aggregate.bats

SCRIPT="$BATS_TEST_DIRNAME/../aggregate.sh"
FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

# ── Helper: run the aggregator against a fixture directory or file list ──────
run_aggregate() {
  run bash "$SCRIPT" "$@"
}

# ── RED: Test 1 - script exists and is executable ────────────────────────────
@test "aggregate.sh exists and has bash shebang" {
  [ -f "$SCRIPT" ]
  head -1 "$SCRIPT" | grep -q '#!/usr/bin/env bash'
}

# ── RED: Test 2 - parse JUnit XML single file: correct passed count ──────────
@test "parse JUnit XML: extracts passed=1 failed=1 skipped=1 from junit-run1.xml" {
  run_aggregate "$FIXTURES/junit-run1.xml"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "PASSED:1"
  echo "$output" | grep -q "FAILED:1"
  echo "$output" | grep -q "SKIPPED:1"
}

# ── RED: Test 3 - parse JUnit XML second file ────────────────────────────────
@test "parse JUnit XML: extracts passed=1 failed=1 skipped=0 from junit-run2.xml" {
  run_aggregate "$FIXTURES/junit-run2.xml"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "PASSED:1"
  echo "$output" | grep -q "FAILED:1"
}

# ── RED: Test 4 - parse JSON single file ─────────────────────────────────────
@test "parse JSON: extracts passed=2 failed=1 skipped=0 from json-run1.json" {
  run_aggregate "$FIXTURES/json-run1.json"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "PASSED:2"
  echo "$output" | grep -q "FAILED:1"
}

# ── RED: Test 5 - aggregate multiple files: correct totals ───────────────────
@test "aggregate all fixtures: totals are tests=10 passed=5 failed=3 skipped=2" {
  # junit-run1: p=1 f=1 s=1  junit-run2: p=1 f=1 s=0
  # json-run1:  p=2 f=1 s=0  json-run2:  p=1 f=0 s=1
  # Totals: tests=10, passed=5, failed=3, skipped=2
  run_aggregate "$FIXTURES"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "| 10 "
  echo "$output" | grep -q "| 5 "
  echo "$output" | grep -q "| 3 "
  echo "$output" | grep -q "| 2 "
}

# ── RED: Test 6 - flaky test detection ───────────────────────────────────────
@test "flaky detection: test_alpha identified as flaky (passed run1, failed run2)" {
  run_aggregate "$FIXTURES"
  [ "$status" -eq 0 ]
  # test_alpha passed in junit-run1 but failed in junit-run2
  echo "$output" | grep -qi "flaky"
  echo "$output" | grep -q "test_alpha"
}

# ── RED: Test 7 - markdown structure ─────────────────────────────────────────
@test "output is valid markdown with expected section headers" {
  run_aggregate "$FIXTURES"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "# Test Results Summary"
  echo "$output" | grep -q "## Totals"
  echo "$output" | grep -q "## Flaky Tests"
  echo "$output" | grep -q "## Failed Tests"
}

# ── RED: Test 8 - duration appears in output ──────────────────────────────────
@test "output includes duration in seconds" {
  run_aggregate "$FIXTURES"
  [ "$status" -eq 0 ]
  # Total duration: 0.35+0.45+0.70+0.25 = 1.75s
  echo "$output" | grep -q "1\.75"
}

# ── RED: Test 9 - error handling: missing argument ───────────────────────────
@test "exits with error when no arguments given" {
  run_aggregate
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "usage\|error"
}

# ── RED: Test 10 - error handling: nonexistent path ──────────────────────────
@test "exits with error for nonexistent path" {
  run_aggregate "/nonexistent/path"
  [ "$status" -ne 0 ]
}

# ── WORKFLOW STRUCTURE TESTS ──────────────────────────────────────────────────

@test "workflow file exists at .github/workflows/test-results-aggregator.yml" {
  local wf="$BATS_TEST_DIRNAME/../.github/workflows/test-results-aggregator.yml"
  [ -f "$wf" ]
}

@test "workflow has push trigger" {
  local wf="$BATS_TEST_DIRNAME/../.github/workflows/test-results-aggregator.yml"
  grep -q "push:" "$wf"
}

@test "workflow references aggregate.sh" {
  local wf="$BATS_TEST_DIRNAME/../.github/workflows/test-results-aggregator.yml"
  grep -q "aggregate.sh" "$wf"
}

@test "aggregate.sh exists (workflow path check)" {
  [ -f "$BATS_TEST_DIRNAME/../aggregate.sh" ]
}

@test "actionlint passes on workflow file" {
  local wf="$BATS_TEST_DIRNAME/../.github/workflows/test-results-aggregator.yml"
  run actionlint "$wf"
  [ "$status" -eq 0 ]
}

# ── ACT RUN TEST ──────────────────────────────────────────────────────────────
# Runs the workflow via act, captures output to act-result.txt,
# and asserts exact expected values from the aggregation.

@test "act: workflow runs successfully and outputs correct aggregation totals" {
  local run_script="$BATS_TEST_DIRNAME/../run_act_tests.sh"
  [ -f "$run_script" ]

  # run_act_tests.sh sets up temp repos, runs act push, appends to act-result.txt,
  # and exits 0 only when all assertions pass.
  run bash "$run_script"
  [ "$status" -eq 0 ]

  # Verify act-result.txt was created with content
  local result_file="$BATS_TEST_DIRNAME/../act-result.txt"
  [ -f "$result_file" ]
  [ -s "$result_file" ]

  # Assert exact expected values appear in captured act output
  grep -q "TOTAL:10"                    "$result_file"
  grep -q "PASSED:5"                    "$result_file"
  grep -q "FAILED:3"                    "$result_file"
  grep -q "SKIPPED:2"                   "$result_file"
  grep -q "FLAKY:TestSuite1::test_alpha" "$result_file"
  grep -q "Job succeeded"               "$result_file"
}
