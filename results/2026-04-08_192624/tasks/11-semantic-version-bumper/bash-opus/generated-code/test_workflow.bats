#!/usr/bin/env bats
# test_workflow.bats — TDD tests for the semantic version bumper
#
# All functional tests run through the GitHub Actions workflow via `act`.
# Structural tests validate YAML and file references.
#
# Output from every act run is appended to act-result.txt.

# ── Setup ───────────────────────────────────────────────────────────────────

setup_file() {
  export ORIG_DIR
  ORIG_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  export ACT_RESULT="${ORIG_DIR}/act-result.txt"

  # Clear the results file at the start of the suite
  : > "$ACT_RESULT"

  # Create a temporary git repo for act runs
  local tmpdir
  tmpdir=$(mktemp -d)

  # Copy project files
  cp "${ORIG_DIR}/version-bumper.sh" "$tmpdir/"
  cp -r "${ORIG_DIR}/test" "$tmpdir/"
  mkdir -p "$tmpdir/.github/workflows"
  cp "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml" \
     "$tmpdir/.github/workflows/"

  # Initialize git repo (act needs one)
  cd "$tmpdir"
  git init -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "1.0.0" > VERSION
  git add -A
  git commit -m "feat: initial commit"

  # ── Run bump-version job ──────────────────────────────────────────────
  echo "===== ACT RUN: bump-version $(date -Iseconds) =====" >> "$ACT_RESULT"

  local bump_out
  bump_out=$(act push --rm \
    -j bump-version \
    -P ubuntu-latest=catthehacker/ubuntu:act-latest \
    --detect-event 2>&1) || true

  echo "$bump_out" >> "$ACT_RESULT"
  echo "===== END bump-version =====" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  # Save to a file so individual tests can read it
  echo "$bump_out" > "${BATS_FILE_TMPDIR}/bump_output.txt"

  # ── Run test-cases job (all 5 matrix entries at once) ─────────────────
  echo "===== ACT RUN: test-cases $(date -Iseconds) =====" >> "$ACT_RESULT"

  local tc_out
  tc_out=$(act push --rm \
    -j test-cases \
    -P ubuntu-latest=catthehacker/ubuntu:act-latest \
    --detect-event 2>&1) || true

  echo "$tc_out" >> "$ACT_RESULT"
  echo "===== END test-cases =====" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  echo "$tc_out" > "${BATS_FILE_TMPDIR}/test_cases_output.txt"

  cd "$ORIG_DIR"
  rm -rf "$tmpdir"
}

setup() {
  ORIG_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  ACT_RESULT="${ORIG_DIR}/act-result.txt"
}

# Helpers to load act output
load_bump_output() {
  cat "${BATS_FILE_TMPDIR}/bump_output.txt"
}

load_test_cases_output() {
  cat "${BATS_FILE_TMPDIR}/test_cases_output.txt"
}

# ── Workflow Structure Tests ────────────────────────────────────────────────

@test "STRUCTURE: workflow file exists at expected path" {
  [ -f "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml" ]
}

@test "STRUCTURE: workflow passes actionlint" {
  run actionlint "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
  echo "$output" >> "$ACT_RESULT"
  [ "$status" -eq 0 ]
}

@test "STRUCTURE: workflow has push trigger" {
  grep -q "push:" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: workflow has pull_request trigger" {
  grep -q "pull_request:" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: workflow has workflow_dispatch trigger" {
  grep -q "workflow_dispatch:" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: workflow defines bump-version job" {
  grep -q "bump-version:" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: workflow defines test-cases job" {
  grep -q "test-cases:" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: workflow references version-bumper.sh" {
  grep -q "version-bumper.sh" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
  [ -f "${ORIG_DIR}/version-bumper.sh" ]
  [ -x "${ORIG_DIR}/version-bumper.sh" ]
}

@test "STRUCTURE: workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: workflow sets permissions" {
  grep -q "permissions:" "${ORIG_DIR}/.github/workflows/semantic-version-bumper.yml"
}

@test "STRUCTURE: script passes shellcheck" {
  run shellcheck "${ORIG_DIR}/version-bumper.sh"
  [ "$status" -eq 0 ]
}

@test "STRUCTURE: script passes bash -n syntax check" {
  run bash -n "${ORIG_DIR}/version-bumper.sh"
  [ "$status" -eq 0 ]
}

# ── Functional Tests: bump-version job via act ──────────────────────────────

@test "ACT: bump-version job succeeded" {
  local output
  output=$(load_bump_output)
  echo "$output" | grep -q "Job succeeded"
}

@test "ACT: bump-version produced version 1.1.0 (minor bump from 1.0.0)" {
  local output
  output=$(load_bump_output)
  echo "$output" | grep -q "VERSION_BUMPED=1.1.0"
}

@test "ACT: bump-version shows correct bump type (minor)" {
  local output
  output=$(load_bump_output)
  echo "$output" | grep -q "Bump type: minor"
}

@test "ACT: bump-version generated changelog" {
  local output
  output=$(load_bump_output)
  echo "$output" | grep -q "## \[1.1.0\]"
}

# ── Functional Tests: test-cases matrix via act ─────────────────────────────

@test "ACT: all 5 test-cases matrix jobs succeeded" {
  local output
  output=$(load_test_cases_output)
  local count
  count=$(echo "$output" | grep -c "Job succeeded")
  [ "$count" -eq 5 ]
}

# -- Patch bump test case --
@test "ACT: patch bump — version 1.0.0 -> 1.0.1 exactly" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep -q "TEST=patch-bump"
  echo "$output" | grep -q "ACTUAL_VERSION=1.0.1"
  echo "$output" | grep -q "PASS: Version matches (1.0.1)"
}

@test "ACT: patch bump — bump type is patch" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep "TEST=patch-bump" -A 10 | grep -q "PASS: Bump type matches (patch)"
}

# -- Minor bump test case --
@test "ACT: minor bump — version 1.1.0 -> 1.2.0 exactly" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep -q "TEST=minor-bump"
  echo "$output" | grep -q "ACTUAL_VERSION=1.2.0"
  echo "$output" | grep -q "PASS: Version matches (1.2.0)"
}

@test "ACT: minor bump — bump type is minor" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep "TEST=minor-bump" -A 10 | grep -q "PASS: Bump type matches (minor)"
}

# -- Major bump test case --
@test "ACT: major bump — version 2.3.4 -> 3.0.0 exactly" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep -q "TEST=major-bump"
  echo "$output" | grep -q "ACTUAL_VERSION=3.0.0"
  echo "$output" | grep -q "PASS: Version matches (3.0.0)"
}

@test "ACT: major bump — bump type is major" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep "TEST=major-bump" -A 10 | grep -q "PASS: Bump type matches (major)"
}

# -- Breaking-footer test case --
@test "ACT: breaking footer — version 1.0.0 -> 2.0.0 exactly" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep -q "TEST=breaking-footer"
  echo "$output" | grep -q "ACTUAL_VERSION=2.0.0"
  echo "$output" | grep -q "PASS: Version matches (2.0.0)"
}

@test "ACT: breaking footer — bump type is major" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep "TEST=breaking-footer" -A 10 | grep -q "PASS: Bump type matches (major)"
}

# -- Package.json test case --
@test "ACT: package.json — version 3.1.2 -> 3.2.0 exactly" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep -q "TEST=package-json"
  echo "$output" | grep -q "ACTUAL_VERSION=3.2.0"
  echo "$output" | grep -q "PASS: Version matches (3.2.0)"
}

@test "ACT: package.json — bump type is minor" {
  local output
  output=$(load_test_cases_output)
  echo "$output" | grep "TEST=package-json" -A 10 | grep -q "PASS: Bump type matches (minor)"
}

# ── act-result.txt artifact verification ────────────────────────────────────

@test "ARTIFACT: act-result.txt exists and is non-empty" {
  [ -f "$ACT_RESULT" ]
  [ -s "$ACT_RESULT" ]
}

@test "ARTIFACT: act-result.txt contains bump-version run" {
  grep -q "ACT RUN: bump-version" "$ACT_RESULT"
}

@test "ARTIFACT: act-result.txt contains test-cases run" {
  grep -q "ACT RUN: test-cases" "$ACT_RESULT"
}
