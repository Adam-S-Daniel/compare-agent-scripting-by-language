#!/usr/bin/env bash
# run_act_tests.sh - Test harness that runs the semantic version bumper workflow
# through GitHub Actions locally using act (nektos/act).
#
# This script:
#   1. Creates a temp git repo containing all project files
#   2. Runs `act push --rm` to execute the workflow in Docker
#   3. Saves full output to act-result.txt (required artifact)
#   4. Asserts that act exited with code 0
#   5. Parses output and asserts on EXACT expected values for each demo step
#   6. Asserts every job shows "Job succeeded"
#
# Usage: bash run_act_tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

# Delimiter used between test case sections in act-result.txt
DELIMITER="======================================================================"

# Color helpers (only when terminal supports it)
RED='' GREEN='' RESET=''
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; RESET='\033[0m'
fi

pass() { echo -e "${GREEN}PASS${RESET}: $*"; }
fail() { echo -e "${RED}FAIL${RESET}: $*"; exit 1; }

# ---------------------------------------------------------------------------
# setup_act_repo <tmpdir>
# Copy all project files into tmpdir and initialise a git repo.
# ---------------------------------------------------------------------------
setup_act_repo() {
    local tmpdir="$1"

    # Copy project files
    cp -r "$SCRIPT_DIR/." "$tmpdir/"

    # Remove any nested .git (we're about to create a fresh one)
    rm -rf "$tmpdir/.git"

    # Initialise git repo (act requires a real git repo for push events)
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "test@example.com"
    git -C "$tmpdir" config user.name "Test"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "ci: initial commit for act test"
}

# ---------------------------------------------------------------------------
# run_act <tmpdir> <label>
# Run act push in tmpdir, capture output, append to act-result.txt.
# Returns the act exit code.
# ---------------------------------------------------------------------------
run_act() {
    local tmpdir="$1"
    local label="$2"
    local output
    local exit_code=0

    {
        echo ""
        echo "$DELIMITER"
        echo "TEST CASE: $label"
        echo "$DELIMITER"
    } >> "$ACT_RESULT"

    # Run act; capture both stdout and stderr; preserve exit code
    output=$(cd "$tmpdir" && act push --rm 2>&1) || exit_code=$?

    echo "$output" >> "$ACT_RESULT"
    echo "" >> "$ACT_RESULT"

    return $exit_code
}

# ---------------------------------------------------------------------------
# assert_contains <string> <pattern> <description>
# Checks that string contains pattern; fails with description on mismatch.
# ---------------------------------------------------------------------------
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local desc="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        pass "$desc"
    else
        fail "$desc — expected to find: '$needle'"
    fi
}

# ---------------------------------------------------------------------------
# assert_job_succeeded <output>
# Checks that the act output contains "Job succeeded".
# ---------------------------------------------------------------------------
assert_job_succeeded() {
    local output="$1"
    if echo "$output" | grep -qiE "(Job succeeded|succeeded)"; then
        pass "Job succeeded"
    else
        fail "Job did not succeed — check act-result.txt for details"
    fi
}

# ===========================================================================
# MAIN TEST EXECUTION
# ===========================================================================

echo "Semantic Version Bumper — Act Test Harness"
echo "==========================================="

# Initialise act-result.txt (overwrite any previous run)
{
    echo "Semantic Version Bumper — Act Test Results"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
} > "$ACT_RESULT"

# ---------------------------------------------------------------------------
# TEST CASE 1: Full workflow run (all unit tests + demo bumps)
# This single act run exercises all test scenarios because the bats suite
# covers all bump types and the workflow demo steps show exact versions.
# ---------------------------------------------------------------------------
echo ""
echo "Running: act push (full workflow)"
echo "---------------------------------"

TMPDIR_1="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_1"' EXIT

setup_act_repo "$TMPDIR_1"

ACT_OUTPUT=""
ACT_EXIT=0
ACT_OUTPUT=$(cd "$TMPDIR_1" && act push --rm 2>&1) || ACT_EXIT=$?

# Append to act-result.txt
{
    echo "$DELIMITER"
    echo "TEST CASE: Full workflow — all unit tests and version bump demos"
    echo "$DELIMITER"
    echo "$ACT_OUTPUT"
    echo ""
} >> "$ACT_RESULT"

# --- Assert act exited successfully ---
if [[ "$ACT_EXIT" -eq 0 ]]; then
    pass "act exited with code 0"
else
    # Print last 50 lines of output to help diagnose
    echo "act output (last 50 lines):"
    echo "$ACT_OUTPUT" | tail -50
    fail "act exited with code $ACT_EXIT — see act-result.txt for full output"
fi

# --- Assert job succeeded ---
assert_job_succeeded "$ACT_OUTPUT"

# --- Assert all 29 bats tests passed ---
assert_contains "$ACT_OUTPUT" "1..29" "bats ran 29 tests"

# Check for any failed tests in bats TAP output
if echo "$ACT_OUTPUT" | grep -qE "^not ok "; then
    fail_line=$(echo "$ACT_OUTPUT" | grep -E "^not ok " | head -1)
    fail "bats test failed: $fail_line"
else
    pass "all bats tests passed (no 'not ok' lines)"
fi

# --- Assert EXACT expected version values from demo steps ---
# Patch bump: 1.0.0 + fix commits -> 1.0.1
assert_contains "$ACT_OUTPUT" "DEMO_PATCH: 1.0.1" "patch bump demo: 1.0.0 -> 1.0.1"

# Minor bump: 1.1.0 + feat commits -> 1.2.0
assert_contains "$ACT_OUTPUT" "DEMO_MINOR: 1.2.0" "minor bump demo: 1.1.0 -> 1.2.0"

# Major bump: 1.2.3 + breaking commits -> 2.0.0
assert_contains "$ACT_OUTPUT" "DEMO_MAJOR: 2.0.0" "major bump demo: 1.2.3 -> 2.0.0"

# package.json minor bump: 2.0.1 + feat -> 2.1.0
assert_contains "$ACT_OUTPUT" "DEMO_PKG_MINOR: 2.1.0" "package.json minor bump demo: 2.0.1 -> 2.1.0"

# Changelog was generated
assert_contains "$ACT_OUTPUT" "CHANGELOG_SAMPLE_START" "changelog sample was displayed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==========================================="
echo "All assertions passed."
echo "act-result.txt written to: $ACT_RESULT"
echo "==========================================="
