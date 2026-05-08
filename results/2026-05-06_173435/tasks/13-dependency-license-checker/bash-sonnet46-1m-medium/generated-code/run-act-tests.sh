#!/usr/bin/env bash
# Act-based test harness for the Dependency License Checker workflow.
# Sets up a temporary git repo, runs the GitHub Actions workflow via act,
# saves output to act-result.txt, and asserts on exact expected values.

set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT="$WORK_DIR/act-result.txt"

# Assertion helper: grep act-result.txt for an exact string
assert_contains() {
  local pattern="$1"
  local description="$2"
  if grep -qF "$pattern" "$ACT_RESULT"; then
    echo "PASS: $description"
  else
    echo "FAIL: $description"
    echo "      Expected to find: $pattern"
    exit 1
  fi
}

# --- Setup ---
echo "=== DEPENDENCY LICENSE CHECKER - ACT TEST HARNESS ===" | tee "$ACT_RESULT"
echo "Date: $(date -u)" | tee -a "$ACT_RESULT"
echo "" | tee -a "$ACT_RESULT"

TMPDIR_ACT=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR_ACT'" EXIT

# Copy all project files into the temp repo (including .actrc)
echo "Copying project files to $TMPDIR_ACT..." | tee -a "$ACT_RESULT"
cp -r "$WORK_DIR/." "$TMPDIR_ACT/"

cd "$TMPDIR_ACT"
git init -q
git config user.email "test@example.com"
git config user.name "Test Runner"
git add -A
git commit -q -m "test: dependency license checker"

# --- Test Case 1: Full workflow run ---
echo "" | tee -a "$ACT_RESULT"
echo "=== TEST CASE 1: act push (full workflow) ===" | tee -a "$ACT_RESULT"
echo "Running: act push --rm" | tee -a "$ACT_RESULT"
echo "" | tee -a "$ACT_RESULT"

# Capture both stdout and exit code; tee to act-result.txt
set +e
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT"
ACT_EXIT="${PIPESTATUS[0]}"
set -e

echo "" | tee -a "$ACT_RESULT"
echo "=== ACT EXIT CODE: $ACT_EXIT ===" | tee -a "$ACT_RESULT"

# --- Assertions ---
if [ "$ACT_EXIT" -ne 0 ]; then
  echo "FAIL: act exited with code $ACT_EXIT (expected 0)" | tee -a "$ACT_RESULT"
  exit 1
fi
echo "PASS: act exit code 0" | tee -a "$ACT_RESULT"

# Workflow completion
assert_contains "Job succeeded" "workflow job succeeded"

# Exact expected values from the compliance check on package.json
assert_contains "APPROVED: express 4.18.0 MIT"          "express approved with MIT"
assert_contains "APPROVED: lodash 4.17.21 MIT"           "lodash approved with MIT"
assert_contains "DENIED:   gpl-package 1.0.0 GPL-3.0"   "gpl-package denied with GPL-3.0"
assert_contains "UNKNOWN:  mystery-lib 2.0.0 UNKNOWN"    "mystery-lib unknown"
assert_contains "Summary: 2 approved, 1 denied, 1 unknown" "package.json summary counts"
assert_contains "Status: FAIL"                           "package.json status is FAIL"
assert_contains "All assertions passed for package.json" "workflow package.json assertions passed"

# Exact expected values from the compliance check on requirements.txt
assert_contains "APPROVED: requests 2.28.0 Apache-2.0"  "requests approved with Apache-2.0"
assert_contains "APPROVED: django 4.2.0 BSD-3-Clause"   "django approved with BSD-3-Clause"
assert_contains "APPROVED: flask 2.3.0 BSD-3-Clause"    "flask approved with BSD-3-Clause"
assert_contains "DENIED:   agpl-lib 1.5.0 AGPL-3.0"    "agpl-lib denied with AGPL-3.0"
assert_contains "Summary: 3 approved, 1 denied, 0 unknown" "requirements.txt summary counts"
assert_contains "All assertions passed for requirements.txt" "workflow requirements.txt assertions passed"

echo "" | tee -a "$ACT_RESULT"
echo "=== ALL ASSERTIONS PASSED ===" | tee -a "$ACT_RESULT"
cd "$WORK_DIR"
