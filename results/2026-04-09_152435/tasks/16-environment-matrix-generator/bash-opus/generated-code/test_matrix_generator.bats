#!/usr/bin/env bats
# test_matrix_generator.bats — Tests for the environment matrix generator.
# All tests run through the GitHub Actions workflow via act.
# The act output is captured once in setup_file and reused across all tests.

# Path to the result file — written to the original working directory
RESULT_FILE=""
ACT_OUTPUT=""
ORIG_DIR=""

setup_file() {
  # Remember the original directory where act-result.txt should end up
  ORIG_DIR="$BATS_TEST_DIRNAME"
  RESULT_FILE="${ORIG_DIR}/act-result.txt"

  # Create a temporary git repo with all project files
  TEMP_REPO="$(mktemp -d)"
  export TEMP_REPO

  # Copy project files into the temp repo
  cp "${ORIG_DIR}/matrix-generator.sh" "${TEMP_REPO}/"
  cp -r "${ORIG_DIR}/fixtures" "${TEMP_REPO}/"
  cp -r "${ORIG_DIR}/.github" "${TEMP_REPO}/"
  # Copy .actrc if it exists
  if [[ -f "${ORIG_DIR}/.actrc" ]]; then
    cp "${ORIG_DIR}/.actrc" "${TEMP_REPO}/"
  fi

  # Initialize a git repo (act requires this)
  cd "${TEMP_REPO}" || exit 1
  git init -b main
  git add -A
  git commit -m "initial commit"

  # Run act and capture output — this is our single act invocation
  # --pull=false avoids trying to pull the local-only act-ubuntu-pwsh image from Docker Hub
  ACT_OUTPUT="$(act push --rm --pull=false 2>&1)" || true
  export ACT_OUTPUT

  # Write the output to act-result.txt in the original directory
  echo "=== ACT RUN: all tests ===" > "${RESULT_FILE}"
  echo "${ACT_OUTPUT}" >> "${RESULT_FILE}"
  echo "=== END ACT RUN ===" >> "${RESULT_FILE}"
}

teardown_file() {
  # Clean up temp repo
  if [[ -n "${TEMP_REPO:-}" && -d "${TEMP_REPO:-}" ]]; then
    rm -rf "${TEMP_REPO}"
  fi
}

# ---------- Workflow structure tests -----------------------------------------

@test "workflow YAML file exists" {
  [[ -f "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml" ]]
}

@test "workflow has correct trigger events" {
  # Check push, pull_request, and workflow_dispatch triggers
  grep -q "push:" "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
  grep -q "pull_request:" "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
  grep -q "workflow_dispatch:" "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow has generate-matrix job" {
  grep -q "generate-matrix:" "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow references matrix-generator.sh" {
  grep -q "matrix-generator.sh" "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow references checkout action" {
  grep -q "actions/checkout@v4" "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
}

@test "matrix-generator.sh exists and is executable" {
  [[ -x "${BATS_TEST_DIRNAME}/matrix-generator.sh" ]]
}

@test "all fixture files referenced in workflow exist" {
  for f in basic.json with_exclude.json with_include.json full_config.json too_large.json; do
    [[ -f "${BATS_TEST_DIRNAME}/fixtures/${f}" ]]
  done
}

@test "actionlint passes on the workflow" {
  run actionlint "${BATS_TEST_DIRNAME}/.github/workflows/environment-matrix-generator.yml"
  [[ "$status" -eq 0 ]]
}

# ---------- Act execution tests ----------------------------------------------

@test "act-result.txt exists" {
  [[ -f "${BATS_TEST_DIRNAME}/act-result.txt" ]]
}

@test "act run shows Job succeeded" {
  grep -q "Job succeeded" "${BATS_TEST_DIRNAME}/act-result.txt"
}

# ---------- Basic config test ------------------------------------------------

@test "basic config produces 4 matrix entries" {
  # Extract the basic test output block from act-result.txt
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"

  # The basic config should produce exactly 4 combinations (2 os x 2 versions)
  # Check the JSON output contains the right number of includes
  echo "$output" | grep -A 50 '=== TEST: basic ===' | grep -B 50 '=== END: basic ===' | grep -q '"include"'

  # Count the entries: look for "os" keys in the include array for this block
  local count
  count=$(echo "$output" | grep -A 50 '=== TEST: basic ===' | grep -B 50 '=== END: basic ===' | grep -c '"os"')
  [[ "$count" -eq 4 ]]
}

@test "basic config includes ubuntu-latest with 3.9" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 50 '=== TEST: basic ===' | grep -B 50 '=== END: basic ===' | grep -q '"ubuntu-latest"'
  echo "$output" | grep -A 50 '=== TEST: basic ===' | grep -B 50 '=== END: basic ===' | grep -q '"3.9"'
}

@test "basic config has fail-fast true by default" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 50 '=== TEST: basic ===' | grep -B 50 '=== END: basic ===' | grep -q '"fail-fast": true'
}

# ---------- Exclude rules test -----------------------------------------------

@test "exclude config removes windows/3.9 and macos/3.9" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  local block
  block=$(echo "$output" | grep -A 80 '=== TEST: with_exclude ===' | grep -B 80 '=== END: with_exclude ===')

  # Should have 7 entries: 3x3=9 minus 2 excludes = 7
  local count
  count=$(echo "$block" | grep -c '"os"')
  [[ "$count" -eq 7 ]]
}

@test "exclude config still includes ubuntu-latest/3.9" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  local block
  block=$(echo "$output" | grep -A 80 '=== TEST: with_exclude ===' | grep -B 80 '=== END: with_exclude ===')

  # ubuntu-latest should still appear with 3.9 (only windows and macos excluded)
  echo "$block" | grep -q '"ubuntu-latest"'
}

# ---------- Include rules test -----------------------------------------------

@test "include config adds experimental entry" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  local block
  block=$(echo "$output" | grep -A 50 '=== TEST: with_include ===' | grep -B 50 '=== END: with_include ===')

  # Should have 2 entries: 1 from cartesian + 1 include
  local count
  count=$(echo "$block" | grep -c '"os"')
  [[ "$count" -eq 2 ]]

  # The include should have the experimental field
  echo "$block" | grep -q '"experimental": true'
}

@test "include config has windows-latest/3.11" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 50 '=== TEST: with_include ===' | grep -B 50 '=== END: with_include ===' | grep -q '"windows-latest"'
  echo "$output" | grep -A 50 '=== TEST: with_include ===' | grep -B 50 '=== END: with_include ===' | grep -q '"3.11"'
}

# ---------- Full config test -------------------------------------------------

@test "full config has fail-fast false" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 100 '=== TEST: full_config ===' | grep -B 100 '=== END: full_config ===' | grep -q '"fail-fast": false'
}

@test "full config has max-parallel 4" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 100 '=== TEST: full_config ===' | grep -B 100 '=== END: full_config ===' | grep -q '"max-parallel": 4'
}

@test "full config has 8 entries (2x2x2 - 1 exclude + 1 include)" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  local block
  block=$(echo "$output" | grep -A 100 '=== TEST: full_config ===' | grep -B 100 '=== END: full_config ===')

  # 2 os x 2 versions x 2 flags = 8, minus 1 exclude = 7, plus 1 include = 8
  local count
  count=$(echo "$block" | grep -c '"os"')
  [[ "$count" -eq 8 ]]
}

@test "full config includes windows-latest/3.11/flag-c from include" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  local block
  block=$(echo "$output" | grep -A 100 '=== TEST: full_config ===' | grep -B 100 '=== END: full_config ===')
  echo "$block" | grep -q '"flag-c"'
}

# ---------- Error handling tests ---------------------------------------------

@test "too_large config triggers expected failure" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 10 '=== TEST: too_large ===' | grep -q "EXPECTED_FAILURE: matrix exceeded max_combinations"
}

@test "missing file triggers expected failure" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 10 '=== TEST: missing_file ===' | grep -q "EXPECTED_FAILURE: file not found"
}

@test "no args triggers expected failure" {
  local output
  output="$(cat "${BATS_TEST_DIRNAME}/act-result.txt")"
  echo "$output" | grep -A 10 '=== TEST: no_args ===' | grep -q "EXPECTED_FAILURE: no arguments"
}
