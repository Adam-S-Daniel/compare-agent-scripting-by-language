#!/usr/bin/env bats
# test-results-aggregator.bats
#
# TDD tests for the test-results-aggregator pipeline.
# All tests run through act (nektos/act) to validate the full GitHub Actions workflow.
# Also includes structural tests for the workflow YAML itself.
#
# Approach:
#   - A setup_file hook runs act ONCE and caches the output
#   - Each test asserts on specific parts of the cached act output
#   - All act output is saved to act-result.txt as required

# Project root (where our script and fixtures live)
PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"

# File to cache the act output across tests (shared state, fixed path)
ACT_CACHE_FILE="/tmp/bats-act-cache-aggregator"

# --- Setup / Teardown for the whole file ---

setup_file() {
  # Clear act-result.txt at the start
  : > "${ACT_RESULT_FILE}"

  # Set up a temp git repo with all project files
  local repo
  repo=$(mktemp -d)
  cp "${PROJECT_DIR}/aggregate-test-results.sh" "${repo}/"
  cp -r "${PROJECT_DIR}/fixtures" "${repo}/"
  mkdir -p "${repo}/.github/workflows"
  cp "${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml" \
    "${repo}/.github/workflows/"

  # Initialize git repo (act requires it)
  cd "${repo}"
  git init -q
  git config user.email "test@test.com"
  git config user.name "test"
  git add -A
  git commit -q -m "test commit"

  # Run act once and cache the full output
  local act_output
  act_output=$(act push --rm 2>&1) || true

  # Save to cache file for all tests to read
  echo "$act_output" > "${ACT_CACHE_FILE}"

  # Write to act-result.txt (required artifact)
  {
    echo "=== ACT FULL OUTPUT ==="
    echo "$act_output"
    echo "=== END ACT FULL OUTPUT ==="
    echo ""
  } >> "${ACT_RESULT_FILE}"

  # Clean up temp repo
  rm -rf "${repo}"
}

teardown_file() {
  rm -f "${ACT_CACHE_FILE}"
}

# Helper: get the cached act output
get_act_output() {
  cat "${ACT_CACHE_FILE}"
}

# ============================================================
# Workflow Structure Tests (YAML validation, no act needed)
# ============================================================

# TDD Red: verify the workflow file exists
@test "workflow YAML file exists" {
  [ -f "${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml" ]
}

# TDD Red: verify workflow has expected triggers
@test "workflow has push, pull_request, and workflow_dispatch triggers" {
  local wf="${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  grep -q "push:" "$wf"
  grep -q "pull_request:" "$wf"
  grep -q "workflow_dispatch:" "$wf"
}

# TDD Red: verify workflow has the expected job and runner
@test "workflow has aggregate-tests job with ubuntu-latest" {
  local wf="${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  grep -q "aggregate-tests:" "$wf"
  grep -q "ubuntu-latest" "$wf"
}

# TDD Red: verify workflow references checkout action
@test "workflow uses actions/checkout@v4" {
  local wf="${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  grep -q "actions/checkout@v4" "$wf"
}

# TDD Red: verify workflow references the main script file and it exists
@test "workflow references aggregate-test-results.sh and file exists" {
  local wf="${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  grep -q "aggregate-test-results.sh" "$wf"
  [ -f "${PROJECT_DIR}/aggregate-test-results.sh" ]
}

# TDD Red: verify workflow references all fixture files and they exist
@test "workflow references fixture files and they exist" {
  local wf="${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  grep -q "fixtures/junit-run1.xml" "$wf"
  grep -q "fixtures/junit-run2.xml" "$wf"
  grep -q "fixtures/results-run1.json" "$wf"
  grep -q "fixtures/results-run2.json" "$wf"
  [ -f "${PROJECT_DIR}/fixtures/junit-run1.xml" ]
  [ -f "${PROJECT_DIR}/fixtures/junit-run2.xml" ]
  [ -f "${PROJECT_DIR}/fixtures/results-run1.json" ]
  [ -f "${PROJECT_DIR}/fixtures/results-run2.json" ]
}

# TDD Red: actionlint must pass with exit code 0
@test "actionlint passes with no errors" {
  run actionlint "${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  [ "$status" -eq 0 ]
}

# TDD Red: workflow has permissions set
@test "workflow has permissions defined" {
  local wf="${PROJECT_DIR}/.github/workflows/test-results-aggregator.yml"
  grep -q "permissions:" "$wf"
  grep -q "contents: read" "$wf"
}

# ============================================================
# Act Integration Tests (assertions on cached act output)
# ============================================================

# TDD Red: act must show "Job succeeded"
@test "act: job succeeds" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "Job succeeded"
}

# TDD Red: verify exact total test count = 18
@test "act: total tests = 18" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "| Total Tests | 18 |"
}

# TDD Red: verify exact passed count = 10
@test "act: passed = 10" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "| Passed | 10 |"
}

# TDD Red: verify exact failed count = 4
@test "act: failed = 4" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "| Failed | 4 |"
}

# TDD Red: verify exact skipped count = 4
@test "act: skipped = 4" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "| Skipped | 4 |"
}

# TDD Red: verify exact duration = 10.70s
@test "act: duration = 10.70s" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "| Duration | 10.70s |"
}

# TDD Red: verify totals verification step echoes exact values
@test "act: TOTALS_VERIFIED with exact values" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "TOTALS_VERIFIED: passed=10 failed=4 skipped=4 total=18 duration=10.70s"
}

# TDD Red: verify all 4 flaky tests detected
@test "act: all 4 flaky tests detected" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "FLAKY_VERIFIED:.*api.CacheTest.test_flaky_cache"
  echo "$output" | grep -q "FLAKY_VERIFIED:.*api.UsersTest.test_create_user"
  echo "$output" | grep -q "FLAKY_VERIFIED:.*auth.LogoutTest.test_logout"
  echo "$output" | grep -q "FLAKY_VERIFIED:.*net.NetworkTest.test_flaky_network"
}

# TDD Red: error handling - no files
@test "act: error handling verified for no-files case" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "ERROR_HANDLING_VERIFIED: no-files"
}

# TDD Red: error handling - missing file
@test "act: error handling verified for missing-file case" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "ERROR_HANDLING_VERIFIED: missing-file"
}

# TDD Red: error handling - unsupported format
@test "act: error handling verified for unsupported-format case" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "ERROR_HANDLING_VERIFIED: unsupported-format"
}

# TDD Red: XML-only aggregation produces correct totals
@test "act: XML-only aggregation exact values" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "XML_ONLY_VERIFIED: total=10 passed=6 failed=2 skipped=2"
}

# TDD Red: JSON-only aggregation produces correct totals
@test "act: JSON-only aggregation exact values" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "JSON_ONLY_VERIFIED: total=8 passed=4 failed=2 skipped=2"
}

# TDD Red: summary contains the test results header
@test "act: summary shows Test Results Summary" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "Test Results Summary"
}

# TDD Red: all verification steps show success
@test "act: all workflow steps succeed" {
  local output
  output=$(get_act_output)
  echo "$output" | grep -q "Success - Main Verify summary content"
  echo "$output" | grep -q "Success - Main Verify exact totals"
  echo "$output" | grep -q "Success - Main Verify flaky test detection"
  echo "$output" | grep -q "Success - Main Test error handling - no files"
  echo "$output" | grep -q "Success - Main Test error handling - missing file"
  echo "$output" | grep -q "Success - Main Test error handling - unsupported format"
  echo "$output" | grep -q "Success - Main Test XML-only aggregation"
  echo "$output" | grep -q "Success - Main Test JSON-only aggregation"
}

# TDD Red: act-result.txt exists as required artifact
@test "act-result.txt exists and is non-empty" {
  [ -f "${ACT_RESULT_FILE}" ]
  [ -s "${ACT_RESULT_FILE}" ]
}
