#!/usr/bin/env bash
# Test harness: runs all tests through GitHub Actions via act.
# Creates temp git repos with fixtures, runs act, captures output,
# and asserts on exact expected values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
OVERALL_PASS=true

# Clear result file
> "$RESULT_FILE"

# ================================================================
# WORKFLOW STRUCTURE TESTS
# ================================================================
echo "========================================" | tee -a "$RESULT_FILE"
echo "WORKFLOW STRUCTURE TESTS" | tee -a "$RESULT_FILE"
echo "========================================" | tee -a "$RESULT_FILE"

# Test 1: actionlint passes
echo "--- Test: actionlint validation ---" | tee -a "$RESULT_FILE"
if actionlint "$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml" >> "$RESULT_FILE" 2>&1; then
    echo "PASS: actionlint validation succeeded" | tee -a "$RESULT_FILE"
else
    echo "FAIL: actionlint validation failed" | tee -a "$RESULT_FILE"
    OVERALL_PASS=false
fi

# Test 2: YAML structure checks
echo "--- Test: YAML structure ---" | tee -a "$RESULT_FILE"
python3 - "$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml" >> "$RESULT_FILE" 2>&1 <<'PYEOF'
import sys, yaml

with open(sys.argv[1]) as f:
    wf = yaml.safe_load(f)

errors = []

# Check triggers
triggers = wf.get("on", wf.get(True, {}))
if "push" not in triggers:
    errors.append("Missing 'push' trigger")
if "workflow_dispatch" not in triggers:
    errors.append("Missing 'workflow_dispatch' trigger")

# Check jobs exist
jobs = wf.get("jobs", {})
if "test" not in jobs:
    errors.append("Missing 'test' job")
if "check-all-approved" not in jobs:
    errors.append("Missing 'check-all-approved' job")
if "check-with-denied" not in jobs:
    errors.append("Missing 'check-with-denied' job")
if "check-requirements-mixed" not in jobs:
    errors.append("Missing 'check-requirements-mixed' job")

# Check checkout step exists in test job
test_steps = jobs.get("test", {}).get("steps", [])
checkout_found = any("actions/checkout@v4" in str(s.get("uses", "")) for s in test_steps)
if not checkout_found:
    errors.append("Test job missing actions/checkout@v4")

# Check script file references
all_steps = []
for job in jobs.values():
    all_steps.extend(job.get("steps", []))
step_text = str(all_steps)
if "license_checker.py" not in step_text:
    errors.append("Workflow does not reference license_checker.py")
if "test_license_checker.py" not in step_text:
    errors.append("Workflow does not reference test_license_checker.py")

if errors:
    for e in errors:
        print(f"FAIL: {e}")
    sys.exit(1)
else:
    print("PASS: YAML structure is correct")
PYEOF
if [ $? -ne 0 ]; then
    OVERALL_PASS=false
fi

# Test 3: Referenced script files exist
echo "--- Test: Script files exist ---" | tee -a "$RESULT_FILE"
missing=0
for f in license_checker.py test_license_checker.py license_config.json; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "FAIL: Missing file: $f" | tee -a "$RESULT_FILE"
        missing=1
    fi
done
if [ $missing -eq 0 ]; then
    echo "PASS: All referenced script files exist" | tee -a "$RESULT_FILE"
else
    OVERALL_PASS=false
fi

# ================================================================
# ACT INTEGRATION TEST
# ================================================================
echo "" | tee -a "$RESULT_FILE"
echo "========================================" | tee -a "$RESULT_FILE"
echo "ACT INTEGRATION TEST" | tee -a "$RESULT_FILE"
echo "========================================" | tee -a "$RESULT_FILE"

# Set up a temp git repo with all project files
TMPDIR=$(mktemp -d)
echo "Setting up temp repo in $TMPDIR" | tee -a "$RESULT_FILE"

# Copy project files
cp "$SCRIPT_DIR/license_checker.py" "$TMPDIR/"
cp "$SCRIPT_DIR/test_license_checker.py" "$TMPDIR/"
cp "$SCRIPT_DIR/license_config.json" "$TMPDIR/"
cp -r "$SCRIPT_DIR/fixtures" "$TMPDIR/"
mkdir -p "$TMPDIR/.github/workflows"
cp "$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml" "$TMPDIR/.github/workflows/"
cp "$SCRIPT_DIR/.actrc" "$TMPDIR/"

# Init git repo (act requires a git context)
cd "$TMPDIR"
git init -b main
git config user.email "test@test.com"
git config user.name "Test"
git add -A
git commit -m "initial"

echo "--- Running act push ---" | tee -a "$RESULT_FILE"
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || true
ACT_EXIT=$?

echo "$ACT_OUTPUT" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# ================================================================
# ASSERTIONS ON ACT OUTPUT
# ================================================================
echo "========================================" | tee -a "$RESULT_FILE"
echo "ACT OUTPUT ASSERTIONS" | tee -a "$RESULT_FILE"
echo "========================================" | tee -a "$RESULT_FILE"

assert_contains() {
    local label="$1"
    local pattern="$2"
    if echo "$ACT_OUTPUT" | grep -qF "$pattern"; then
        echo "PASS: $label" | tee -a "$RESULT_FILE"
    else
        echo "FAIL: $label (expected to find: '$pattern')" | tee -a "$RESULT_FILE"
        OVERALL_PASS=false
    fi
}

assert_regex() {
    local label="$1"
    local pattern="$2"
    if echo "$ACT_OUTPUT" | grep -qE "$pattern"; then
        echo "PASS: $label" | tee -a "$RESULT_FILE"
    else
        echo "FAIL: $label (expected regex: '$pattern')" | tee -a "$RESULT_FILE"
        OVERALL_PASS=false
    fi
}

# Assert all jobs succeeded
assert_contains "test job succeeded" "Job succeeded"

# Assert pytest ran and all 28 tests passed
assert_contains "pytest ran all tests" "28 passed"

# Assert all-approved check produced correct output
assert_contains "all-approved shows express APPROVED" "[APPROVED] express"
assert_contains "all-approved shows lodash APPROVED" "[APPROVED] lodash"
assert_contains "all-approved shows jest APPROVED" "[APPROVED] jest"
assert_contains "all-approved shows Approved: 3" "Approved: 3"
assert_contains "all-approved shows PASS" "Result: PASS"

# Assert denied check produced correct output
assert_contains "denied check found gpl-lib DENIED" "[DENIED] gpl-lib"
assert_contains "denied check found express APPROVED" "[APPROVED] express"
assert_contains "denied check shows Denied: 1" "Denied: 1"
assert_contains "denied check expected failure" "EXPECTED_FAILURE: checker correctly exited non-zero for denied licenses"

# Assert requirements_mixed check produced correct output
assert_contains "requirements mixed shows requests APPROVED" "[APPROVED] requests"
assert_contains "requirements mixed shows flask APPROVED" "[APPROVED] flask"
assert_contains "requirements mixed shows numpy APPROVED" "[APPROVED] numpy"
assert_contains "requirements mixed shows gpl-lib DENIED" "[DENIED] gpl-lib"
assert_contains "requirements mixed shows unknown-pkg UNKNOWN" "[UNKNOWN] unknown-pkg"
assert_contains "requirements mixed EXPECTED_FAILURE" "EXPECTED_FAILURE: checker correctly exited non-zero for denied licenses"

# Assert summary counts for requirements_mixed
assert_contains "requirements mixed Approved: 3" "Approved: 3"
assert_contains "requirements mixed Denied: 1" "Denied: 1"
assert_contains "requirements mixed Unknown: 1" "Unknown: 1"

# Cleanup
rm -rf "$TMPDIR"

echo "" | tee -a "$RESULT_FILE"
echo "========================================" | tee -a "$RESULT_FILE"
if [ "$OVERALL_PASS" = true ]; then
    echo "ALL TESTS PASSED" | tee -a "$RESULT_FILE"
else
    echo "SOME TESTS FAILED" | tee -a "$RESULT_FILE"
fi
echo "========================================" | tee -a "$RESULT_FILE"
echo "Results saved to: $RESULT_FILE"
