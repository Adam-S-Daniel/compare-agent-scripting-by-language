#!/usr/bin/env bats

# test_matrix_generator.bats — Tests for environment matrix generator
#
# ALL tests run through GitHub Actions via `act`. Each test:
#   1. Creates a temporary git repo with project files + fixture data
#   2. Runs `act push --rm` to execute the workflow
#   3. Captures output, appends to act-result.txt
#   4. Asserts on exact expected values in the output
#
# Usage: bats test_matrix_generator.bats

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

# Directory containing this test file (the project root)
PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT_FILE="$PROJECT_DIR/act-result.txt"
WORKFLOW_FILE="$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"

setup_file() {
  # Clear the result file at the start of the full test run
  > "$ACT_RESULT_FILE"
  # Pre-pull the Docker image to avoid transient auth race conditions
  docker pull catthehacker/ubuntu:act-latest 2>/dev/null || true
}

# Helper: set up a temp git repo with project files and a specific fixture as the default config.
# Usage: setup_act_repo <fixture_file>
# Sets TMPDIR_REPO to the temp repo path.
setup_act_repo() {
  local fixture="$1"
  TMPDIR_REPO=$(mktemp -d)

  # Copy project files
  cp "$PROJECT_DIR/generate-matrix.sh" "$TMPDIR_REPO/"
  chmod +x "$TMPDIR_REPO/generate-matrix.sh"
  mkdir -p "$TMPDIR_REPO/.github/workflows"
  cp "$WORKFLOW_FILE" "$TMPDIR_REPO/.github/workflows/"
  mkdir -p "$TMPDIR_REPO/test-fixtures"
  # Copy all fixtures for the run-all-fixtures job
  cp "$PROJECT_DIR/test-fixtures/"* "$TMPDIR_REPO/test-fixtures/"

  # If a specific fixture is provided, also place it as basic.json (the default)
  if [[ -n "$fixture" && -f "$fixture" ]]; then
    cp "$fixture" "$TMPDIR_REPO/test-fixtures/basic.json"
  fi

  # Initialize a git repo (act needs this)
  cd "$TMPDIR_REPO"
  git init -q
  git add -A
  git commit -q -m "initial" --allow-empty
}

# Helper: run act and capture output, appending to act-result.txt
# Usage: run_act [extra_args...]
# Sets ACT_OUTPUT and ACT_EXIT_CODE
run_act() {
  local label="${BATS_TEST_DESCRIPTION:-unknown}"
  ACT_EXIT_CODE=0
  ACT_OUTPUT=$(act push --rm -W .github/workflows/environment-matrix-generator.yml 2>&1) || ACT_EXIT_CODE=$?

  # Append to result file with clear delimiters
  {
    echo "========================================"
    echo "TEST: $label"
    echo "EXIT CODE: $ACT_EXIT_CODE"
    echo "========================================"
    echo "$ACT_OUTPUT"
    echo ""
  } >> "$ACT_RESULT_FILE"
}

cleanup_act_repo() {
  if [[ -n "${TMPDIR_REPO:-}" && -d "$TMPDIR_REPO" ]]; then
    rm -rf "$TMPDIR_REPO"
  fi
  cd "$PROJECT_DIR"
}

# ---------------------------------------------------------------------------
# WORKFLOW STRUCTURE TESTS
# ---------------------------------------------------------------------------

@test "workflow YAML exists and is valid" {
  [[ -f "$WORKFLOW_FILE" ]]
  # Parse the YAML — yq or python might not be available, so use actionlint
  actionlint "$WORKFLOW_FILE"
}

@test "workflow has correct trigger events" {
  # Check for push, pull_request, and workflow_dispatch triggers
  grep -q "push:" "$WORKFLOW_FILE"
  grep -q "pull_request:" "$WORKFLOW_FILE"
  grep -q "workflow_dispatch:" "$WORKFLOW_FILE"
}

@test "workflow has required jobs: generate-matrix, validate-matrix, run-all-fixtures" {
  grep -q "generate-matrix:" "$WORKFLOW_FILE"
  grep -q "validate-matrix:" "$WORKFLOW_FILE"
  grep -q "run-all-fixtures:" "$WORKFLOW_FILE"
}

@test "workflow references generate-matrix.sh script" {
  grep -q "generate-matrix.sh" "$WORKFLOW_FILE"
  # The script file must exist
  [[ -f "$PROJECT_DIR/generate-matrix.sh" ]]
}

@test "workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "$WORKFLOW_FILE"
}

@test "actionlint passes with exit code 0" {
  run actionlint "$WORKFLOW_FILE"
  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — basic 2x2 matrix
# ---------------------------------------------------------------------------

@test "act: basic 2x2 matrix generates 4 combinations" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/basic.json"
  run_act
  cleanup_act_repo

  # Assert act exited successfully
  [[ "$ACT_EXIT_CODE" -eq 0 ]]

  # Assert all jobs succeeded
  echo "$ACT_OUTPUT" | grep -q "generate-matrix.*Job succeeded" || \
    echo "$ACT_OUTPUT" | grep -q "\[Environment Matrix Generator/generate-matrix\] .*Job succeeded"

  # Assert exact entry count
  echo "$ACT_OUTPUT" | grep -q "Total combinations: 4"

  # Assert exact entries exist — ubuntu-latest + 3.9, ubuntu-latest + 3.10, etc.
  echo "$ACT_OUTPUT" | grep -q '"os": "ubuntu-latest"'
  echo "$ACT_OUTPUT" | grep -q '"os": "macos-latest"'
  echo "$ACT_OUTPUT" | grep -q '"language_version": "3.9"'
  echo "$ACT_OUTPUT" | grep -q '"language_version": "3.10"'

  # Assert matrix-level settings present
  echo "$ACT_OUTPUT" | grep -q '"fail-fast": true'
  echo "$ACT_OUTPUT" | grep -q '"max-parallel": 2'

  # Assert 4 combinations message
  echo "$ACT_OUTPUT" | grep -q "Matrix generated successfully with 4 combination"
}

@test "act: basic matrix validation passes" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/basic.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]

  # The validate-matrix job should report exactly 4 entries
  echo "$ACT_OUTPUT" | grep -q "VALIDATED: Matrix has 4 entries"
  echo "$ACT_OUTPUT" | grep -q "VALIDATED: Matrix size within limits"
  echo "$ACT_OUTPUT" | grep -q "VALIDATION_PASSED=true"
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — include rules
# ---------------------------------------------------------------------------

@test "act: include rule adds extra entry" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/with_include.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]
  # 1 base (ubuntu x 3.9) + 1 include (windows x 3.11) = 2
  echo "$ACT_OUTPUT" | grep -q "Total combinations: 2"
  echo "$ACT_OUTPUT" | grep -q "Matrix generated successfully with 2 combination"
  echo "$ACT_OUTPUT" | grep -q '"os": "windows-latest"'
  echo "$ACT_OUTPUT" | grep -q '"language_version": "3.11"'
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — exclude rules
# ---------------------------------------------------------------------------

@test "act: exclude rule removes matching entry" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/with_exclude.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]
  # 2 os x 3 versions = 6, minus 1 excluded = 5
  echo "$ACT_OUTPUT" | grep -q "Total combinations: 5"
  echo "$ACT_OUTPUT" | grep -q "Matrix generated successfully with 5 combination"
  echo "$ACT_OUTPUT" | grep -q "VALIDATED: Matrix has 5 entries"
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — three dimensions
# ---------------------------------------------------------------------------

@test "act: three dimensions produce 8 combinations" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/three_dimensions.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]
  # 2 os x 2 versions x 2 flags = 8
  echo "$ACT_OUTPUT" | grep -q "Total combinations: 8"
  echo "$ACT_OUTPUT" | grep -q "Matrix generated successfully with 8 combination"
  echo "$ACT_OUTPUT" | grep -q '"feature_flags": "flag-a"'
  echo "$ACT_OUTPUT" | grep -q '"feature_flags": "flag-b"'
  echo "$ACT_OUTPUT" | grep -q '"fail-fast": false'
  echo "$ACT_OUTPUT" | grep -q '"max-parallel": 4'
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — single entry
# ---------------------------------------------------------------------------

@test "act: single entry matrix works" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/single_entry.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]
  echo "$ACT_OUTPUT" | grep -q "Total combinations: 1"
  echo "$ACT_OUTPUT" | grep -q '"os": "ubuntu-latest"'
  echo "$ACT_OUTPUT" | grep -q '"language_version": "3.12"'
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — include + exclude combo
# ---------------------------------------------------------------------------

@test "act: include and exclude combined produce correct entries" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/include_exclude_combo.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]
  # 3 os x 2 versions = 6, minus 1 excluded = 5, plus 1 included = 6
  echo "$ACT_OUTPUT" | grep -q "Total combinations: 6"
  echo "$ACT_OUTPUT" | grep -q "Matrix generated successfully with 6 combination"
  # The included entry has feature_flags: experimental
  echo "$ACT_OUTPUT" | grep -q '"feature_flags": "experimental"'
  echo "$ACT_OUTPUT" | grep -q '"language_version": "3.11"'
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — run-all-fixtures job
# ---------------------------------------------------------------------------

@test "act: run-all-fixtures job passes all fixtures" {
  setup_act_repo "$PROJECT_DIR/test-fixtures/basic.json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -eq 0 ]]

  # Check fixture results in the run-all-fixtures job
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/basic.json"
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/with_include.json"
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/with_exclude.json"
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/three_dimensions.json"
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/single_entry.json"
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/include_exclude_combo.json"
  echo "$ACT_OUTPUT" | grep -q "PASS: test-fixtures/error_too_many.json correctly failed"
  echo "$ACT_OUTPUT" | grep -q "ALL_FIXTURES_PASSED=true"

  # All jobs should succeed
  local job_succeeded_count
  job_succeeded_count=$(echo "$ACT_OUTPUT" | grep -c "Job succeeded")
  [[ "$job_succeeded_count" -ge 3 ]]
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — error: exceeds max-combinations
# ---------------------------------------------------------------------------

@test "act: error when matrix exceeds max-combinations" {
  # Use the error_too_many fixture as the default config — this should cause
  # the generate-matrix job to fail.
  setup_act_repo "$PROJECT_DIR/test-fixtures/error_too_many.json"
  run_act
  cleanup_act_repo

  # The overall act run should fail (non-zero exit) because generate-matrix fails
  [[ "$ACT_EXIT_CODE" -ne 0 ]]
  # Should contain the specific error message
  echo "$ACT_OUTPUT" | grep -q "exceeding max-combinations limit of 10"
}

# ---------------------------------------------------------------------------
# ACT INTEGRATION TESTS — error: invalid JSON
# ---------------------------------------------------------------------------

@test "act: error on invalid JSON config" {
  # Replace basic.json with the invalid file
  setup_act_repo "$PROJECT_DIR/test-fixtures/basic.json"
  # Overwrite basic.json with invalid content
  cp "$PROJECT_DIR/test-fixtures/error_invalid_json.txt" "$TMPDIR_REPO/test-fixtures/basic.json"
  cd "$TMPDIR_REPO"
  git add -A
  git commit -q -m "use invalid json"
  run_act
  cleanup_act_repo

  [[ "$ACT_EXIT_CODE" -ne 0 ]]
  echo "$ACT_OUTPUT" | grep -q "Invalid JSON"
}

# ---------------------------------------------------------------------------
# Final check: act-result.txt exists and has content
# ---------------------------------------------------------------------------

@test "act-result.txt exists and contains test results" {
  [[ -f "$ACT_RESULT_FILE" ]]
  [[ -s "$ACT_RESULT_FILE" ]]

  # Should contain results from multiple tests
  local test_count
  test_count=$(grep -c "^TEST:" "$ACT_RESULT_FILE")
  [[ "$test_count" -ge 5 ]]
}
