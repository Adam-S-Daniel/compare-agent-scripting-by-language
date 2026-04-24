#!/usr/bin/env bash
# tests/run_act_tests.sh - Act-based integration test harness
#
# For each test case, creates a temporary git repo containing the project
# files, runs `act push --rm`, captures the full output to act-result.txt,
# and asserts on EXACT expected values from the workflow output.
#
# Requirements:
#   - act and Docker must be installed and running
#   - The .actrc in the parent workspace dir is copied into each temp repo
#
# Usage: bash tests/run_act_tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"
PASS_COUNT=0
FAIL_COUNT=0

# Clear/create the required artifact file
true > "$ACT_RESULT_FILE"

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
pass() { log "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { log "FAIL: $1 — $2" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Run one act test case.
#   $1: human-readable test case name
#   $2+: expected substrings that must appear in the act output
run_act_case() {
    local test_name="$1"; shift
    local -a expected=("$@")

    log "=== Test case: ${test_name} ==="
    echo "=== Test case: ${test_name} ===" >> "$ACT_RESULT_FILE"

    # Create isolated temp git repo
    local tmpdir
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" EXIT

    # Copy all project files (preserving structure)
    cp -r "${PROJECT_DIR}/." "${tmpdir}/"

    pushd "$tmpdir" > /dev/null

    git init -q
    git config user.email "test@test.local"
    git config user.name  "Test Runner"
    git add -A
    git commit -q -m "ci: test run for ${test_name}"

    local act_output act_exit=0
    act_output=$(act push --rm --pull=false 2>&1) || act_exit=$?

    popd > /dev/null
    rm -rf "$tmpdir"
    trap - EXIT

    # Append full output to artifact
    {
        printf '%s\n' "$act_output"
        echo "--- end of act output for: ${test_name} ---"
        echo ""
    } >> "$ACT_RESULT_FILE"

    # Assert: act must exit 0
    if [[ "$act_exit" -ne 0 ]]; then
        fail "$test_name" "act exited with code ${act_exit}"
        return 1
    fi

    # Assert: workflow job must succeed
    if ! printf '%s\n' "$act_output" | grep -q "Job succeeded"; then
        fail "$test_name" "'Job succeeded' not found in act output"
        return 1
    fi

    # Assert: all bats tests must pass (no "not ok" lines)
    if printf '%s\n' "$act_output" | grep -q "^not ok"; then
        fail "$test_name" "bats reported failing tests"
        return 1
    fi

    # Assert every expected pattern is present
    local all_ok=true
    for pattern in "${expected[@]}"; do
        if ! printf '%s\n' "$act_output" | grep -qF "$pattern"; then
            fail "$test_name" "expected pattern not found: '${pattern}'"
            all_ok=false
        fi
    done

    if $all_ok; then
        pass "$test_name"
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Test cases
# ──────────────────────────────────────────────────────────────────────

# TC1: Full matrix build — all four fixture files aggregated together.
# Expected: 18 total tests, 13 pass, 3 fail, 2 skip, 3 flaky tests identified.
run_act_case "full-matrix-aggregation" \
    "| **Total Tests** | 18 |" \
    "| **Passed** | 13 |" \
    "| **Failed** | 3 |" \
    "| **Skipped** | 2 |" \
    "| **Duration** | 3.93s |" \
    "## Flaky Tests (3)" \
    "test_signup" \
    "test_checkout" \
    "unit_transform" \
    "## Failed Tests" \
    "1..18"

# ──────────────────────────────────────────────────────────────────────
# Final report
# ──────────────────────────────────────────────────────────────────────

echo ""
log "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "act-result.txt written to: ${ACT_RESULT_FILE}"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
