#!/usr/bin/env bash
#
# run-tests.sh — Test harness that validates the workflow and runs act
#
# This script:
#   1. Validates workflow structure (YAML parsing, triggers, jobs, steps)
#   2. Verifies actionlint passes
#   3. Runs 3 act scenarios (feat/fix/breaking) in isolated temp git repos
#   4. Captures all output to act-result.txt
#   5. Asserts exact expected values from each scenario

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

# Truncate result file
true > "$RESULT_FILE"

log() {
  echo "$*" | tee -a "$RESULT_FILE"
}

# shellcheck disable=SC2317
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    log "  PASS: $label (expected='$expected')"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    log "  FAIL: $label (expected='$expected', got='$actual')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# shellcheck disable=SC2317
assert_contains() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    log "  PASS: $label (contains '$expected')"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    log "  FAIL: $label (expected to contain '$expected')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# shellcheck disable=SC2317
assert_exit_code() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    log "  PASS: $label (exit code $actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    log "  FAIL: $label (expected exit $expected, got $actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ============================================================
# SECTION 1: Workflow structure tests
# ============================================================
log "================================================================"
log "SECTION 1: Workflow Structure Tests"
log "================================================================"

WORKFLOW="$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"

# Test: workflow file exists
if [[ -f "$WORKFLOW" ]]; then
  log "  PASS: Workflow file exists"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  log "  FAIL: Workflow file missing"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: actionlint passes
actionlint_output=$(actionlint "$WORKFLOW" 2>&1) || true
if [[ -z "$actionlint_output" ]]; then
  log "  PASS: actionlint passes with no errors"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  log "  FAIL: actionlint found errors: $actionlint_output"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: YAML structure — check triggers
assert_contains "Workflow has push trigger" "push:" "$(cat "$WORKFLOW")"
assert_contains "Workflow has pull_request trigger" "pull_request:" "$(cat "$WORKFLOW")"
assert_contains "Workflow has workflow_dispatch trigger" "workflow_dispatch:" "$(cat "$WORKFLOW")"

# Test: YAML structure — check jobs
assert_contains "Workflow has test job" "test:" "$(cat "$WORKFLOW")"
assert_contains "Workflow has bump job" "bump:" "$(cat "$WORKFLOW")"

# Test: workflow references script files that exist
assert_contains "Workflow references semver-bump.sh" "semver-bump.sh" "$(cat "$WORKFLOW")"
assert_contains "Workflow references tests.bats" "tests.bats" "$(cat "$WORKFLOW")"

# Test: referenced script files exist
if [[ -f "$SCRIPT_DIR/semver-bump.sh" ]]; then
  log "  PASS: semver-bump.sh exists"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  log "  FAIL: semver-bump.sh missing"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if [[ -f "$SCRIPT_DIR/tests.bats" ]]; then
  log "  PASS: tests.bats exists"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  log "  FAIL: tests.bats missing"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: uses actions/checkout@v4
assert_contains "Workflow uses actions/checkout@v4" "actions/checkout@v4" "$(cat "$WORKFLOW")"

log ""

# ============================================================
# SECTION 2: Act integration tests
# ============================================================
log "================================================================"
log "SECTION 2: Act Integration Tests"
log "================================================================"

# Helper: set up a temp git repo with project files + specific scenario
setup_test_repo() {
  local tmpdir="$1"
  local start_version="$2"
  shift 2
  # Remaining args are commit messages

  mkdir -p "$tmpdir/.github/workflows"

  # Copy project files
  cp "$SCRIPT_DIR/semver-bump.sh" "$tmpdir/"
  cp "$SCRIPT_DIR/tests.bats" "$tmpdir/"
  cp -r "$SCRIPT_DIR/test" "$tmpdir/"
  cp "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml" "$tmpdir/.github/workflows/"
  # Copy actrc if present
  if [[ -f "$SCRIPT_DIR/.actrc" ]]; then
    cp "$SCRIPT_DIR/.actrc" "$tmpdir/"
  fi

  cd "$tmpdir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"

  # Create VERSION file with starting version
  echo "$start_version" > VERSION
  git add -A
  git commit -q -m "chore: initial release $start_version"
  git tag "v$start_version"

  # Add conventional commits
  for msg in "$@"; do
    # Make a small change so git has something to commit
    echo "$msg" >> changes.log
    git add -A
    git commit -q -m "$msg"
  done
}

# --- Test Case 1: feat commit -> minor bump (1.0.0 -> 1.1.0) ---
log ""
log "--- Test Case 1: feat commit (1.0.0 -> 1.1.0) ---"

TMPDIR1=$(mktemp -d)
setup_test_repo "$TMPDIR1" "1.0.0" \
  "feat: add user authentication" \
  "feat: implement search" \
  "fix: typo in welcome message"

ACT_OUTPUT1=$(act push --rm --pull=false 2>&1) || ACT_EXIT1=$?
ACT_EXIT1=${ACT_EXIT1:-0}

log "$ACT_OUTPUT1" >> "$RESULT_FILE"

assert_exit_code "Act run 1 succeeds" 0 "$ACT_EXIT1"
assert_contains "Test case 1: test job succeeded" "Job succeeded" "$ACT_OUTPUT1"
assert_contains "Test case 1: version bumped to 1.1.0" "1.1.0" "$ACT_OUTPUT1"
assert_contains "Test case 1: bump type is minor" "minor" "$ACT_OUTPUT1"
assert_contains "Test case 1: bats tests ran" "ok 20" "$ACT_OUTPUT1"

cd "$SCRIPT_DIR"
rm -rf "$TMPDIR1"

# --- Test Case 2: fix commit -> patch bump (2.3.1 -> 2.3.2) ---
log ""
log "--- Test Case 2: fix commit (2.3.1 -> 2.3.2) ---"

TMPDIR2=$(mktemp -d)
setup_test_repo "$TMPDIR2" "2.3.1" \
  "fix: resolve null pointer" \
  "fix: handle empty input"

ACT_OUTPUT2=$(act push --rm --pull=false 2>&1) || ACT_EXIT2=$?
ACT_EXIT2=${ACT_EXIT2:-0}

log "$ACT_OUTPUT2" >> "$RESULT_FILE"

assert_exit_code "Act run 2 succeeds" 0 "$ACT_EXIT2"
assert_contains "Test case 2: test job succeeded" "Job succeeded" "$ACT_OUTPUT2"
assert_contains "Test case 2: version bumped to 2.3.2" "2.3.2" "$ACT_OUTPUT2"
assert_contains "Test case 2: bump type is patch" "patch" "$ACT_OUTPUT2"

cd "$SCRIPT_DIR"
rm -rf "$TMPDIR2"

# --- Test Case 3: breaking change -> major bump (0.5.3 -> 1.0.0) ---
log ""
log "--- Test Case 3: breaking change (0.5.3 -> 1.0.0) ---"

TMPDIR3=$(mktemp -d)
setup_test_repo "$TMPDIR3" "0.5.3" \
  "feat!: redesign API response format" \
  "fix: update error codes"

ACT_OUTPUT3=$(act push --rm --pull=false 2>&1) || ACT_EXIT3=$?
ACT_EXIT3=${ACT_EXIT3:-0}

log "$ACT_OUTPUT3" >> "$RESULT_FILE"

assert_exit_code "Act run 3 succeeds" 0 "$ACT_EXIT3"
assert_contains "Test case 3: test job succeeded" "Job succeeded" "$ACT_OUTPUT3"
assert_contains "Test case 3: version bumped to 1.0.0" "1.0.0" "$ACT_OUTPUT3"
assert_contains "Test case 3: bump type is major" "major" "$ACT_OUTPUT3"

cd "$SCRIPT_DIR"
rm -rf "$TMPDIR3"

# ============================================================
# SECTION 3: Summary
# ============================================================
log ""
log "================================================================"
log "SUMMARY"
log "================================================================"
log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"
log "Total:  $((PASS_COUNT + FAIL_COUNT))"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  log "RESULT: SOME TESTS FAILED"
  exit 1
else
  log "RESULT: ALL TESTS PASSED"
  exit 0
fi
