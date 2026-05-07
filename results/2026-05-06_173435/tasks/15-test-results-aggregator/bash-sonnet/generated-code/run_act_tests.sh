#!/usr/bin/env bash
# run_act_tests.sh - Executes GitHub Actions workflow via act for each test case.
#
# Sets up isolated temp git repos, runs act push --rm, appends output to
# act-result.txt, and asserts exact expected values.
#
# Usage: ./run_act_tests.sh
# Output: act-result.txt in current directory; exits 0 on all pass, 1 on any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="${SCRIPT_DIR}/act-result.txt"
OVERALL_EXIT=0

# Wipe previous results
: > "$ACT_RESULT"

# ── Helper: run one test case via act ────────────────────────────────────────
# $1 = test case label
# $2 = expected grep patterns (newline-separated "PATTERN:VALUE" strings)
run_test_case() {
  local label="$1"
  local expected_patterns="$2"

  echo "=== TEST CASE: $label ===" | tee -a "$ACT_RESULT"

  # Build isolated temp git repo
  local work_dir
  work_dir=$(mktemp -d)

  # Ensure cleanup on exit from this function
  # shellcheck disable=SC2064
  trap "rm -rf $work_dir" RETURN

  # Copy all project files (including fixtures and workflow)
  cp -r "$SCRIPT_DIR/." "$work_dir/"

  # Initialize git repo (act requires a valid git repo)
  git -C "$work_dir" init -q
  git -C "$work_dir" config user.email "test@test.com"
  git -C "$work_dir" config user.name "Test"
  git -C "$work_dir" add -A
  git -C "$work_dir" commit -q -m "test: $label"

  # Run act from within the temp repo directory
  local act_out act_exit=0
  act_out=$(cd "$work_dir" && act push --rm --pull=false 2>&1) || act_exit=$?

  # Append to act-result.txt
  {
    echo "act exit code: $act_exit"
    echo "$act_out"
    echo "=== END TEST CASE: $label ==="
    echo ""
  } >> "$ACT_RESULT"

  # Assert act exited 0
  if [ "$act_exit" -ne 0 ]; then
    echo "FAIL [$label]: act exited $act_exit" >&2
    OVERALL_EXIT=1
    return
  fi

  # Assert "Job succeeded" appears in output
  if ! echo "$act_out" | grep -q "Job succeeded"; then
    echo "FAIL [$label]: 'Job succeeded' not found in act output" >&2
    OVERALL_EXIT=1
    return
  fi

  # Assert each expected pattern
  local pattern
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    if ! echo "$act_out" | grep -q "$pattern"; then
      echo "FAIL [$label]: expected pattern not found: $pattern" >&2
      OVERALL_EXIT=1
    else
      echo "PASS [$label]: found '$pattern'"
    fi
  done <<< "$expected_patterns"
}

# ── Test Case 1: Full aggregation across all fixture files ────────────────────
run_test_case "full aggregation" "
TOTAL:10
PASSED:5
FAILED:3
SKIPPED:2
FLAKY:TestSuite1::test_alpha
"

# ── Test Case 2: Verify bats unit tests pass inside workflow ──────────────────
run_test_case "bats unit tests in workflow" "
ok 1 aggregate.sh exists and has bash shebang
ok 5 aggregate all fixtures
ok 6 flaky detection
"

echo ""
echo "act-result.txt written to: $ACT_RESULT"

if [ "$OVERALL_EXIT" -eq 0 ]; then
  echo "ALL ACT TESTS PASSED"
else
  echo "SOME ACT TESTS FAILED" >&2
fi

exit "$OVERALL_EXIT"
