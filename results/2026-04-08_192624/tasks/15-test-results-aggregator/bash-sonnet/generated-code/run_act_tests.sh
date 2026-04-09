#!/usr/bin/env bash
# run_act_tests.sh — Run all tests through GitHub Actions via act (nektos/act).
# Requirements:
#   1. Set up a temp git repo with project files.
#   2. Run `act push --rm` and capture output.
#   3. Save output to act-result.txt (appending each test case, clearly delimited).
#   4. Assert act exited with code 0.
#   5. Parse act output and assert on EXACT expected values.
#   6. Assert every job shows "Job succeeded".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

# Clear previous results
: > "$ACT_RESULT"

# ---------------------------------------------------------------------------
# Helper: append a delimiter to act-result.txt
# ---------------------------------------------------------------------------
delimit() {
  local label="$1"
  printf '\n%s\n%s\n%s\n' \
    "========================================" \
    "TEST CASE: $label" \
    "========================================" >> "$ACT_RESULT"
}

# ---------------------------------------------------------------------------
# Helper: set up a temp git repo with all project files and run act
# ---------------------------------------------------------------------------
run_act_test() {
  local label="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" EXIT

  echo "[act] Setting up temp repo for: $label"
  cp -r "$SCRIPT_DIR/." "$tmpdir/"

  cd "$tmpdir"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git add -A
  git commit -q -m "test: $label"

  delimit "$label"

  local act_exit=0
  # Run act — capture output to both terminal and file
  act push --rm 2>&1 | tee -a "$ACT_RESULT" || act_exit=$?

  cd "$SCRIPT_DIR"
  rm -rf "$tmpdir"
  # Reset trap
  trap - EXIT

  return $act_exit
}

# ---------------------------------------------------------------------------
# Helper: assert a string appears in act-result.txt (last run section)
# ---------------------------------------------------------------------------
assert_contains() {
  local expected="$1"
  if ! grep -qF "$expected" "$ACT_RESULT"; then
    echo "ASSERTION FAILED: expected '$expected' in act-result.txt" >&2
    exit 1
  fi
  echo "  PASS: found '$expected'"
}

# ---------------------------------------------------------------------------
# Run the single workflow (all test cases are inside it)
# ---------------------------------------------------------------------------
echo "=== Running test-results-aggregator workflow via act ==="
run_act_test "test-results-aggregator full pipeline"

echo ""
echo "=== Asserting expected values in act output ==="

# Assert exact values from workflow "Verify expected values" step
assert_contains "PASS: junit-pass passed=3"
assert_contains "PASS: junit-fail failed=2"
assert_contains "PASS: junit-skip skipped=1"
assert_contains "PASS: json passed=4"
assert_contains "PASS: aggregation passed=5 failed=2"
assert_contains "PASS: flaky detection TestFlaky"
assert_contains "All assertions passed."

# Assert bats test output (all 12 tests pass)
assert_contains "ok 12 handles unknown file format gracefully"

# Assert job succeeded
assert_contains "Job succeeded"

echo ""
echo "=== All act assertions passed. act-result.txt written. ==="
