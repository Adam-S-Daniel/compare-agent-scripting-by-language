#!/usr/bin/env bash
# run-act-tests.sh — Drive the workflow through `act push` for each fixture.
#
# Per project rules: every test case must run through the GitHub Actions
# pipeline via act. We're limited to 3 act runs total, so we have 3 cases:
#   1. basic 2x2 matrix (success path)
#   2. include/exclude + max-parallel/fail-fast passthrough (success path)
#   3. matrix size exceeds max_size (error path; EXPECT_FAILURE=1)
#
# Output: appends each run's output to act-result.txt with delimiters and
# asserts on exit code, "Job succeeded", and exact expected substrings.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_FILE="$PROJECT_ROOT/act-result.txt"
: > "$RESULT_FILE"

failed=0
total=0

run_case() {
    local name="$1" fixture="$2" expect_failure="$3"
    shift 3
    local -a expected_substrings=("$@")

    total=$((total + 1))
    {
        echo "===================================================="
        echo "TEST CASE: $name"
        echo "FIXTURE:   $fixture"
        echo "EXPECT_FAILURE: $expect_failure"
        echo "===================================================="
    } >> "$RESULT_FILE"

    local out
    local rc=0
    out="$(cd "$PROJECT_ROOT" && act push --rm --pull=false \
            --env FIXTURE="$fixture" \
            --env EXPECT_FAILURE="$expect_failure" 2>&1)" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "$out" >> "$RESULT_FILE"
        echo "ACT_EXIT=$rc (FAIL — expected 0)" >> "$RESULT_FILE"
        echo "[FAIL] $name: act exited non-zero ($rc)"
        failed=$((failed + 1))
        return
    fi
    echo "$out" >> "$RESULT_FILE"
    echo "ACT_EXIT=0" >> "$RESULT_FILE"

    # Every job must report success.
    if ! grep -q "Job succeeded" <<<"$out"; then
        echo "[FAIL] $name: missing 'Job succeeded'"
        failed=$((failed + 1))
        return
    fi

    # Each expected substring must appear verbatim.
    local missing=0
    for needle in "${expected_substrings[@]}"; do
        if ! grep -qF "$needle" <<<"$out"; then
            echo "[FAIL] $name: expected substring not found: $needle"
            missing=$((missing + 1))
        fi
    done
    if [ "$missing" -gt 0 ]; then
        failed=$((failed + 1))
        return
    fi

    echo "[PASS] $name"
}

# Case 1: basic — success path, output should contain compact JSON arrays
run_case "basic 2x2" "test/fixtures/basic.json" "0" \
    "GENERATE_STATUS=ok" \
    "ubuntu-latest" \
    "macos-latest" \
    '"node":'

# Case 2: include/exclude + parallel/fail-fast passthrough
run_case "include-exclude" "test/fixtures/with-include-exclude.json" "0" \
    "GENERATE_STATUS=ok" \
    "windows-latest" \
    '"max-parallel": 4' \
    '"fail-fast": false'

# Case 3: max_size violation — error path, must exit ok because EXPECT_FAILURE=1
run_case "exceeds max_size" "test/fixtures/too-big.json" "1" \
    "GENERATE_STATUS=err" \
    "exceeds max_size"

echo
echo "===================================================="
echo "Total: $total  Failed: $failed"
echo "===================================================="

[ "$failed" -eq 0 ]
