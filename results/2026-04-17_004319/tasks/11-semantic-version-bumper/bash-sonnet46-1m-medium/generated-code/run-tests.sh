#!/usr/bin/env bash
# Test harness: sets up a git repo, runs the GHA workflow via act,
# then verifies exact expected version values in the output.
# Saves all act output to act-result.txt (required artifact).

set -euo pipefail

WORKDIR=$(pwd)
ACT_RESULT_FILE="${WORKDIR}/act-result.txt"

# Initialize the result file
true > "$ACT_RESULT_FILE"

TMPDIR_BASE=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

PASS=0
FAIL=0
FAIL_NAMES=()

# Assert that act-result.txt contains marker=value exactly
check_output() {
    local test_name="$1"
    local marker="$2"
    local expected="$3"

    if grep -qF "${marker}=${expected}" "$ACT_RESULT_FILE"; then
        echo "  PASS: ${test_name} (${marker}=${expected})"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${test_name} — expected '${marker}=${expected}'"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("${test_name}")
    fi
}

# ---------------------------------------------------------------------------
# Set up a temporary git repo with all project files
# ---------------------------------------------------------------------------
TESTREPO="${TMPDIR_BASE}/repo"
mkdir -p "${TESTREPO}"

echo ">>> Copying project files into temp repo: ${TESTREPO}"
cp bump-version.sh "${TESTREPO}/"
cp -r tests       "${TESTREPO}/"
cp -r fixtures    "${TESTREPO}/"
mkdir -p "${TESTREPO}/.github/workflows"
cp .github/workflows/semantic-version-bumper.yml "${TESTREPO}/.github/workflows/"
cp .actrc "${TESTREPO}/"

cd "${TESTREPO}"

git init -q
git config user.email "test@example.com"
git config user.name "Test Runner"
git add -A
git commit -q -m "chore: test setup for version bumper"

# ---------------------------------------------------------------------------
# Run the workflow via act (single invocation — all scenarios inside workflow)
# ---------------------------------------------------------------------------
echo ""
echo "================================================================"
echo ">>> Running: act push --rm"
echo "================================================================"
echo ""

{
    echo "=== TEST RUN: act push ==="
    echo "=== Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo ""
} >> "$ACT_RESULT_FILE"

# Capture output and tee to result file; preserve act exit code
set +e
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT_FILE"
ACT_EXIT="${PIPESTATUS[0]}"
set -e

{
    echo ""
    echo "=== Act exit code: ${ACT_EXIT} ==="
} | tee -a "$ACT_RESULT_FILE"

cd "${WORKDIR}"

echo ""
echo "================================================================"
echo ">>> Asserting results"
echo "================================================================"

# Assert act itself succeeded
if [[ "$ACT_EXIT" -ne 0 ]]; then
    echo "  FAIL: act exited with code ${ACT_EXIT} (workflow failed)"
    echo ""
    echo "Results: 0 passed, 1 failed"
    exit 1
fi

# Assert the job reported success
if grep -q "Job succeeded" "$ACT_RESULT_FILE"; then
    echo "  PASS: Job succeeded"
    PASS=$((PASS + 1))
else
    echo "  FAIL: 'Job succeeded' not found in act output"
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("Job succeeded")
fi

# Verify exact version outputs from the workflow's scenario step
check_output "fix commits produce 1.0.1"        "SCENARIO_FIX_RESULT"      "1.0.1"
check_output "feat commits produce 1.1.0"        "SCENARIO_FEAT_RESULT"     "1.1.0"
check_output "breaking change produces 2.0.0"    "SCENARIO_BREAKING_RESULT" "2.0.0"
check_output "mixed feat+fix produces 2.4.0"     "SCENARIO_MIXED_RESULT"    "2.4.0"
check_output "package.json fix produces 2.3.5"   "SCENARIO_PKG_RESULT"      "2.3.5"

echo ""
echo "================================================================"
if [[ "$FAIL" -gt 0 ]]; then
    echo "Results: ${PASS} passed, ${FAIL} failed"
    echo "Failed:"
    for name in "${FAIL_NAMES[@]}"; do
        echo "  - ${name}"
    done
    echo "================================================================"
    echo "See act-result.txt for full workflow output."
    exit 1
fi

echo "Results: ${PASS} passed, 0 failed — ALL TESTS PASSED"
echo "================================================================"
echo "act-result.txt saved at: ${ACT_RESULT_FILE}"
