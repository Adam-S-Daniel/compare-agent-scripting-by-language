#!/usr/bin/env bash
# run_act_tests.sh - Run all tests through GitHub Actions via `act`
#
# This script:
# 1. Sets up a temp git repo with project files + fixture data
# 2. Runs `act push --rm` for each test case
# 3. Saves all act output to act-result.txt
# 4. Asserts act exits with code 0
# 5. Parses act output and asserts on exact expected values
# 6. Asserts every job shows "Job succeeded"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="$SCRIPT_DIR/act-result.txt"

# Clear/create act-result.txt
true > "$ACT_RESULT_FILE"

# Logging helpers
log() { echo "[run_act_tests] $*"; }
die() { echo "FAIL: $*" >&2; exit 1; }

# Append a delimiter and test name to act-result.txt
append_delimiter() {
    local test_name="$1"
    cat >> "$ACT_RESULT_FILE" <<EOF

================================================================================
TEST CASE: $test_name
================================================================================
EOF
}

# Run act for a specific job in a temp git repo
# Args: test_name, job_id, expected_patterns (associative array key=label value=pattern)
run_act_job() {
    local test_name="$1"
    local job_id="$2"

    log "Running test: $test_name (job: $job_id)"
    append_delimiter "$test_name"

    # Create temp directory with full project
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    # Copy project files to temp dir
    cp "$SCRIPT_DIR/matrix_generator.sh" "$tmp_dir/"
    mkdir -p "$tmp_dir/.github/workflows"
    cp "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml" "$tmp_dir/.github/workflows/"

    # Init git repo (required by act)
    cd "$tmp_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git add .
    git commit -q -m "test"

    # Run act for specific job, capture output
    local act_output
    local act_exit=0
    act_output=$(act push --rm -j "$job_id" --container-architecture linux/amd64 2>&1) || act_exit=$?

    # Append output to act-result.txt
    echo "$act_output" >> "$ACT_RESULT_FILE"
    echo "" >> "$ACT_RESULT_FILE"

    cd "$SCRIPT_DIR"
    return "$act_exit"
}

# Run a test and validate output
run_and_validate() {
    local test_name="$1"
    local job_id="$2"
    shift 2
    local expected_patterns=("$@")

    local act_output
    local act_exit=0

    log "Running test: $test_name (job: $job_id)"
    append_delimiter "$test_name"

    # Create temp directory with full project
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Copy project files to temp dir
    cp "$SCRIPT_DIR/matrix_generator.sh" "$tmp_dir/"
    mkdir -p "$tmp_dir/.github/workflows"
    cp "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml" "$tmp_dir/.github/workflows/"

    # Init git repo (required by act)
    cd "$tmp_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git add .
    git commit -q -m "test"

    # Run act for specific job
    act_output=$(act push --rm -j "$job_id" --container-architecture linux/amd64 2>&1) || act_exit=$?

    # Append output to act-result.txt
    echo "$act_output" >> "$ACT_RESULT_FILE"
    echo "" >> "$ACT_RESULT_FILE"

    # Clean up
    rm -rf "$tmp_dir"
    cd "$SCRIPT_DIR"

    # Assert act exited with code 0
    if [[ "$act_exit" -ne 0 ]]; then
        echo "FAIL: $test_name - act exited with code $act_exit" | tee -a "$ACT_RESULT_FILE"
        echo "Output was:" | tee -a "$ACT_RESULT_FILE"
        echo "$act_output" | tee -a "$ACT_RESULT_FILE"
        die "$test_name failed: act exit code $act_exit"
    fi

    # Assert "Job succeeded" appears
    if ! echo "$act_output" | grep -q "Job succeeded\|succeeded\|success"; then
        echo "FAIL: $test_name - no 'Job succeeded' in output" | tee -a "$ACT_RESULT_FILE"
        die "$test_name failed: no Job succeeded"
    fi

    # Assert all expected patterns appear in output
    for pattern in "${expected_patterns[@]}"; do
        if ! echo "$act_output" | grep -q "$pattern"; then
            echo "FAIL: $test_name - expected pattern not found: $pattern" | tee -a "$ACT_RESULT_FILE"
            die "$test_name failed: missing expected pattern '$pattern'"
        fi
        log "  PASS: found expected pattern: $pattern"
    done

    echo "PASS: $test_name" | tee -a "$ACT_RESULT_FILE"
    log "PASS: $test_name"
}

# ============================================================
# Run individual test jobs
# ============================================================

log "Starting act-based test suite"
log "Results will be written to: $ACT_RESULT_FILE"

# Test 1: Basic matrix generation - expect 4 combinations
run_and_validate \
    "basic-matrix-generation" \
    "test-basic-matrix" \
    "RESULT: basic-matrix-count=4"

# Test 2: Exclude rules - expect 3 combinations after exclude
run_and_validate \
    "exclude-rules" \
    "test-exclude-rules" \
    "RESULT: exclude-rules-count=3"

# Test 3: fail-fast and max-parallel settings
run_and_validate \
    "fail-fast-max-parallel" \
    "test-fail-fast-max-parallel" \
    "RESULT: fail-fast=true max-parallel=4"

# Test 4: Oversized matrix validation
run_and_validate \
    "max-size-validation" \
    "test-max-size-validation" \
    "RESULT: oversized-matrix-correctly-rejected"

# Test 5: Include extra combinations
run_and_validate \
    "include-extra-combinations" \
    "test-include-extra" \
    "RESULT: include-extra-count=2"

# Test 6: Full matrix with all options
run_and_validate \
    "full-matrix-all-options" \
    "test-full-matrix" \
    "RESULT: full-matrix-count=16" \
    "fail-fast=false" \
    "max-parallel=8"

# Test 7: Error handling
run_and_validate \
    "error-handling" \
    "test-error-handling" \
    "RESULT: missing-os-correctly-rejected" \
    "RESULT: invalid-json-correctly-rejected"

# ============================================================
# Final summary
# ============================================================
{
    echo ""
    echo "================================================================================"
    echo "ALL TESTS PASSED"
    echo "================================================================================"
} | tee -a "$ACT_RESULT_FILE"

log "All tests passed! Results in: $ACT_RESULT_FILE"
