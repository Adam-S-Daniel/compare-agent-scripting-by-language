#!/usr/bin/env bash
set -euo pipefail

# Test harness: runs all tests through GitHub Actions via act, then validates output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
FAILURES=0

true > "$RESULT_FILE"

log() { echo "=== $1 ==="; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $1"; }

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label — expected to find '$needle'"
  fi
}

# --- Workflow structure tests ---
log "Workflow Structure Tests"

WORKFLOW="$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"

if [[ -f "$WORKFLOW" ]]; then
  pass "workflow file exists"
else
  fail "workflow file missing"
fi

workflow_content=$(cat "$WORKFLOW")

assert_contains "has push trigger" "$workflow_content" "push:"
assert_contains "has pull_request trigger" "$workflow_content" "pull_request:"
assert_contains "has workflow_dispatch trigger" "$workflow_content" "workflow_dispatch"
assert_contains "has test job" "$workflow_content" "test:"
assert_contains "has bump job" "$workflow_content" "bump:"
assert_contains "references checkout action" "$workflow_content" "actions/checkout@v4"
assert_contains "references semver-bump.sh" "$workflow_content" "semver-bump.sh"
assert_contains "references bats test file" "$workflow_content" "test/semver-bump.bats"

if [[ -f "$SCRIPT_DIR/semver-bump.sh" ]]; then
  pass "semver-bump.sh exists"
else
  fail "semver-bump.sh missing"
fi

if [[ -f "$SCRIPT_DIR/test/semver-bump.bats" ]]; then
  pass "test/semver-bump.bats exists"
else
  fail "test/semver-bump.bats missing"
fi

log "Actionlint Validation"
if actionlint "$WORKFLOW" 2>&1; then
  pass "actionlint passes"
else
  fail "actionlint found errors"
fi

# --- Act execution ---
log "Running act push"

# We need a git repo for act to work with
cd "$SCRIPT_DIR"

ACT_OUTPUT=""
ACT_EXIT=0
ACT_OUTPUT=$(act push --rm 2>&1) || ACT_EXIT=$?

{
  echo "========== ACT RUN: push =========="
  echo "$ACT_OUTPUT"
  echo "EXIT CODE: $ACT_EXIT"
  echo "====================================="
} >> "$RESULT_FILE"

log "Act Exit Code Check"
if [[ $ACT_EXIT -eq 0 ]]; then
  pass "act exited with code 0"
else
  fail "act exited with code $ACT_EXIT"
  echo "--- Act output (last 50 lines) ---"
  echo "$ACT_OUTPUT" | tail -50
fi

# --- Verify bats test results in output ---
log "Bats Test Results"

assert_contains "bats: parse version from VERSION file" "$ACT_OUTPUT" "ok 1 parse version from VERSION file"
assert_contains "bats: parse version from package.json" "$ACT_OUTPUT" "ok 2 parse version from package.json"
assert_contains "bats: fix commits produce patch bump" "$ACT_OUTPUT" "ok 3 fix commits produce patch bump"
assert_contains "bats: feat commits produce minor bump" "$ACT_OUTPUT" "ok 4 feat commits produce minor bump"
assert_contains "bats: breaking change (bang) produces major bump" "$ACT_OUTPUT" "ok 5 breaking change (bang) produces major bump"
assert_contains "bats: BREAKING CHANGE footer produces major bump" "$ACT_OUTPUT" "ok 6 BREAKING CHANGE footer produces major bump"
assert_contains "bats: mixed commits use highest bump" "$ACT_OUTPUT" "ok 7 mixed commits use highest bump"
assert_contains "bats: no conventional commits defaults to patch" "$ACT_OUTPUT" "ok 8 no conventional commits defaults to patch"
assert_contains "bats: VERSION file is updated in place" "$ACT_OUTPUT" "ok 9 VERSION file is updated in place"
assert_contains "bats: package.json version field is updated" "$ACT_OUTPUT" "ok 10 package.json version field is updated"
assert_contains "bats: changelog file is created" "$ACT_OUTPUT" "ok 11 changelog file is created with entries"
assert_contains "bats: changelog groups entries by type" "$ACT_OUTPUT" "ok 12 changelog groups entries by type"

# --- Verify shellcheck and syntax validation ran ---
log "Lint Validation in CI"
assert_contains "shellcheck step succeeded" "$ACT_OUTPUT" "Success - Main Validate script with shellcheck"
assert_contains "syntax check step succeeded" "$ACT_OUTPUT" "Success - Main Validate script syntax"
assert_contains "bats: missing version file produces error" "$ACT_OUTPUT" "ok 13 missing version file produces error"
assert_contains "bats: missing commit log produces error" "$ACT_OUTPUT" "ok 14 missing commit log produces error"
assert_contains "bats: invalid version string produces error" "$ACT_OUTPUT" "ok 15 invalid version string produces error"
assert_contains "bats: empty commit log defaults to patch bump" "$ACT_OUTPUT" "ok 16 empty commit log defaults to patch bump"
assert_contains "bats: TAP plan shows 16 tests" "$ACT_OUTPUT" "1..16"

# --- Verify demo bump outputs ---
log "Demo Bump Output Validation"

# Fix commits: 1.0.0 -> 1.0.1
assert_contains "fix bump: version 1.0.1" "$ACT_OUTPUT" "1.0.1"

# Feat commits: 2.3.1 -> 2.4.0
assert_contains "feat bump: version 2.4.0" "$ACT_OUTPUT" "2.4.0"

# Breaking change: 1.5.2 -> 2.0.0
assert_contains "breaking bump: version 2.0.0" "$ACT_OUTPUT" "2.0.0"

# --- Verify job success ---
log "Job Success Checks"

# act reports success with "Job succeeded" or via exit code 0
# Count how many jobs succeeded
test_job_success=$(echo "$ACT_OUTPUT" | grep -c "Job succeeded" || true)
if [[ $test_job_success -ge 2 ]]; then
  pass "both jobs succeeded ($test_job_success 'Job succeeded' messages)"
else
  # act may not always print "Job succeeded" — fall back to exit code
  if [[ $ACT_EXIT -eq 0 ]]; then
    pass "act exited 0 (all jobs succeeded)"
  else
    fail "expected at least 2 'Job succeeded' messages, found $test_job_success"
  fi
fi

# --- Summary ---
echo ""
log "SUMMARY"
if [[ $FAILURES -eq 0 ]]; then
  echo "All assertions passed!"
else
  echo "$FAILURES assertion(s) failed"
fi

echo ""
echo "Results written to: $RESULT_FILE"
exit "$FAILURES"
