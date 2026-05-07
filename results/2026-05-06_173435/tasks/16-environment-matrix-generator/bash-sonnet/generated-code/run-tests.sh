#!/usr/bin/env bash
# run-tests.sh — test harness that exercises the workflow via a single act run.
#
# Strategy:
#   1. Create an isolated temp git repo with all project files.
#   2. Run `act push --rm --pull=false` once, capturing full output.
#   3. Append output (clearly delimited) to act-result.txt.
#   4. Assert act exit code == 0.
#   5. Assert every expected exact value appears in the output.
#   6. Assert every job shows "Job succeeded".
#
# The workflow itself runs all fixtures and prints labelled output lines, so a
# single act push covers all test cases.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

: > "$ACT_RESULT"

# ── Set up isolated git repo ─────────────────────────────────────────────────

TMPDIR_REPO=$(mktemp -d)
trap 'rm -rf "$TMPDIR_REPO"' EXIT

cp -r "$SCRIPT_DIR/." "$TMPDIR_REPO/"
rm -f "$TMPDIR_REPO/act-result.txt"

git -C "$TMPDIR_REPO" init -q
git -C "$TMPDIR_REPO" config user.email "test@example.com"
git -C "$TMPDIR_REPO" config user.name "Test Runner"
git -C "$TMPDIR_REPO" add -A
git -C "$TMPDIR_REPO" commit -q -m "ci: test commit"

# ── Run act ──────────────────────────────────────────────────────────────────

echo "Running act push..."
set +e
ACT_OUTPUT=$(cd "$TMPDIR_REPO" && act push --rm --pull=false 2>&1)
ACT_EXIT=$?
set -e

# ── Save output ──────────────────────────────────────────────────────────────

{
  echo "========================================================"
  echo "act push run — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "act exit code: $ACT_EXIT"
  echo "========================================================"
  echo "$ACT_OUTPUT"
  echo ""
} >> "$ACT_RESULT"

echo "$ACT_OUTPUT"
echo ""

# ── Assertion helpers ─────────────────────────────────────────────────────────

PASS=0
FAIL=0

assert_contains() {
  local label="$1" expected="$2"
  if echo "$ACT_OUTPUT" | grep -qF "$expected"; then
    echo "  PASS: $label"
    ((PASS++)) || true
  else
    echo "  FAIL: $label — expected: $expected"
    ((FAIL++)) || true
  fi
}

assert_exit_zero() {
  if [[ "$ACT_EXIT" -eq 0 ]]; then
    echo "  PASS: act exit code is 0"
    ((PASS++)) || true
  else
    echo "  FAIL: act exit code is $ACT_EXIT (expected 0)"
    ((FAIL++)) || true
  fi
}

# ── Assertions ────────────────────────────────────────────────────────────────

echo "=== Assertions ==="

assert_exit_zero

# Every job must succeed.
assert_contains "Job succeeded" "Job succeeded"

# Test case: basic 2x2 matrix → 4 entries
assert_contains "basic fixture: MATRIX_ENTRY_COUNT=4" "MATRIX_ENTRY_COUNT=4"

# Test case: three-dimensional matrix → 12 entries
assert_contains "3D fixture: MATRIX_3D_COUNT=12" "MATRIX_3D_COUNT=12"

# Test case: settings → max-parallel=4
assert_contains "settings fixture: MATRIX_MAX_PARALLEL=4" "MATRIX_MAX_PARALLEL=4"

# Test case: settings → fail-fast=false
assert_contains "settings fixture: MATRIX_FAIL_FAST=false" "MATRIX_FAIL_FAST=false"

# Test case: oversized matrix rejected
assert_contains "oversized matrix rejected" "OVERSIZED_MATRIX_REJECTED=yes"

# All 21 bats tests completed (last bats ok line)
assert_contains "all 21 bats tests ran" "ok 21 actionlint passes on workflow file"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "========================================================"
echo "Results: $PASS passed, $FAIL failed"
echo "act-result.txt: $ACT_RESULT"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
