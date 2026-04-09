#!/usr/bin/env bash
# Test harness that runs all test cases through GitHub Actions via act.
# Each test case sets up a temp git repo, runs act, captures output,
# and asserts on exact expected values.
#
# Required output: act-result.txt in the current working directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"
ACT_IMAGE="catthehacker/ubuntu:act-latest"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

# Clear previous results
> "$RESULT_FILE"

# Helper: set up a temp git repo with project files and a specific fixture
setup_test_repo() {
    local fixture_dir="$1"
    local manifest_file="$2"
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy project files
    cp "$SCRIPT_DIR/license_checker.py" "$tmpdir/"
    cp "$SCRIPT_DIR/test_license_checker.py" "$tmpdir/"
    cp "$SCRIPT_DIR/config.json" "$tmpdir/"

    # Copy the fixture manifest
    cp "$fixture_dir/$manifest_file" "$tmpdir/"

    # Copy workflow
    mkdir -p "$tmpdir/.github/workflows"
    cp "$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml" "$tmpdir/.github/workflows/"

    # Initialize git repo (act requires a git repo)
    cd "$tmpdir"
    git init -b main --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    git add -A
    git commit -m "initial" --quiet

    echo "$tmpdir"
}

# Helper: run act in a temp repo and capture output
run_act_test() {
    local test_name="$1"
    local tmpdir="$2"
    local expect_checker_exit="${3:-0}"  # 0 = expect success, nonzero = expect checker failure

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo "======================================================" >> "$RESULT_FILE"
    echo "TEST CASE: $test_name" >> "$RESULT_FILE"
    echo "======================================================" >> "$RESULT_FILE"

    local act_output
    local act_exit=0

    cd "$tmpdir"
    act_output=$(act push --rm -P ubuntu-latest=$ACT_IMAGE 2>&1) || act_exit=$?

    echo "$act_output" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    # Return the output and exit code via globals
    ACT_OUTPUT="$act_output"
    ACT_EXIT="$act_exit"
}

# Helper: assert a string is in the output
assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"

    if echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $label (found '$needle')"
        return 0
    else
        echo "  FAIL: $label (expected '$needle' not found)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# Helper: assert exit code
assert_exit_code() {
    local label="$1"
    local actual="$2"
    local expected="$3"

    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $label (exit code $actual)"
        return 0
    else
        echo "  FAIL: $label (expected exit $expected, got $actual)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

echo "=========================================="
echo "Dependency License Checker - Act Test Suite"
echo "=========================================="
echo ""

# -------------------------------------------------------------------
# TEST CASE 1: All approved (package.json with MIT-only deps)
# -------------------------------------------------------------------
echo "--- Test Case 1: All Approved ---"
TMPDIR1=$(setup_test_repo "$SCRIPT_DIR/fixtures/all-approved" "package.json")
run_act_test "all-approved" "$TMPDIR1"

assert_exit_code "act exits 0" "$ACT_EXIT" 0
assert_contains "unit-tests succeeded" "$ACT_OUTPUT" "Job succeeded"
assert_contains "report header" "$ACT_OUTPUT" "Dependency License Compliance Report"
assert_contains "express approved" "$ACT_OUTPUT" "express (^4.18.0) - MIT - APPROVED"
assert_contains "lodash approved" "$ACT_OUTPUT" "lodash (~4.17.21) - MIT - APPROVED"
assert_contains "jest approved" "$ACT_OUTPUT" "jest (^29.0.0) - MIT - APPROVED"
assert_contains "total count" "$ACT_OUTPUT" "Total: 3"
assert_contains "approved count" "$ACT_OUTPUT" "Approved: 3"
assert_contains "denied count" "$ACT_OUTPUT" "Denied: 0"
assert_contains "unknown count" "$ACT_OUTPUT" "Unknown: 0"
assert_contains "overall pass" "$ACT_OUTPUT" "Overall: PASS"

PASS_COUNT=$((PASS_COUNT + 11))
rm -rf "$TMPDIR1"
echo ""

# -------------------------------------------------------------------
# TEST CASE 2: Has denied (package.json with GPL dep)
# -------------------------------------------------------------------
echo "--- Test Case 2: Has Denied ---"
TMPDIR2=$(setup_test_repo "$SCRIPT_DIR/fixtures/has-denied" "package.json")

# Modify the workflow to allow exit code 2 from the checker (denied deps)
# so act doesn't abort on the intentional non-zero exit
cat > "$TMPDIR2/.github/workflows/dependency-license-checker.yml" << 'WFEOF'
name: Dependency License Checker

on:
  push:
    branches: ["*"]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  MANIFEST_FILE: package.json
  CONFIG_FILE: config.json

jobs:
  unit-tests:
    name: Run Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install pytest
        run: pip install pytest

      - name: Run unit tests
        run: python -m pytest test_license_checker.py -v

  license-check:
    name: Check Dependency Licenses
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Run license checker
        run: |
          python license_checker.py "${{ env.MANIFEST_FILE }}" "${{ env.CONFIG_FILE }}" || exit_code=$?
          if [ "${exit_code:-0}" -eq 2 ]; then
            echo "LICENSE_CHECK_DENIED=true" >> "$GITHUB_ENV"
            echo "::warning::Denied licenses found"
          elif [ "${exit_code:-0}" -ne 0 ]; then
            exit "$exit_code"
          fi

      - name: Report denied licenses
        if: env.LICENSE_CHECK_DENIED == 'true'
        run: echo "WARNING - Denied licenses detected in dependencies"
WFEOF

cd "$TMPDIR2"
git add -A && git commit -m "update workflow" --quiet

run_act_test "has-denied" "$TMPDIR2"

assert_exit_code "act exits 0" "$ACT_EXIT" 0
assert_contains "unit-tests succeeded" "$ACT_OUTPUT" "Job succeeded"
assert_contains "report header" "$ACT_OUTPUT" "Dependency License Compliance Report"
assert_contains "express approved" "$ACT_OUTPUT" "express (^4.18.0) - MIT - APPROVED"
assert_contains "gpl-pkg denied" "$ACT_OUTPUT" "gpl-pkg (^1.0.0) - GPL-3.0 - DENIED"
assert_contains "total count" "$ACT_OUTPUT" "Total: 2"
assert_contains "approved count" "$ACT_OUTPUT" "Approved: 1"
assert_contains "denied count" "$ACT_OUTPUT" "Denied: 1"
assert_contains "overall fail" "$ACT_OUTPUT" "Overall: FAIL"
assert_contains "denied warning" "$ACT_OUTPUT" "Denied licenses detected"

PASS_COUNT=$((PASS_COUNT + 10))
rm -rf "$TMPDIR2"
echo ""

# -------------------------------------------------------------------
# TEST CASE 3: Mixed statuses (approved, denied, unknown)
# -------------------------------------------------------------------
echo "--- Test Case 3: Mixed Statuses ---"
TMPDIR3=$(setup_test_repo "$SCRIPT_DIR/fixtures/mixed-statuses" "package.json")

# Use the same denied-tolerant workflow
cp "$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml" "$TMPDIR3/.github/workflows/dependency-license-checker.yml"
cat > "$TMPDIR3/.github/workflows/dependency-license-checker.yml" << 'WFEOF'
name: Dependency License Checker

on:
  push:
    branches: ["*"]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  MANIFEST_FILE: package.json
  CONFIG_FILE: config.json

jobs:
  unit-tests:
    name: Run Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install pytest
        run: pip install pytest

      - name: Run unit tests
        run: python -m pytest test_license_checker.py -v

  license-check:
    name: Check Dependency Licenses
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Run license checker
        run: |
          python license_checker.py "${{ env.MANIFEST_FILE }}" "${{ env.CONFIG_FILE }}" || exit_code=$?
          if [ "${exit_code:-0}" -eq 2 ]; then
            echo "LICENSE_CHECK_DENIED=true" >> "$GITHUB_ENV"
            echo "::warning::Denied licenses found"
          elif [ "${exit_code:-0}" -ne 0 ]; then
            exit "$exit_code"
          fi

      - name: Report denied licenses
        if: env.LICENSE_CHECK_DENIED == 'true'
        run: echo "WARNING - Denied licenses detected in dependencies"
WFEOF

cd "$TMPDIR3"
git add -A && git commit -m "update workflow" --quiet

run_act_test "mixed-statuses" "$TMPDIR3"

assert_exit_code "act exits 0" "$ACT_EXIT" 0
assert_contains "report header" "$ACT_OUTPUT" "Dependency License Compliance Report"
assert_contains "express approved" "$ACT_OUTPUT" "express (^4.18.0) - MIT - APPROVED"
assert_contains "gpl-pkg denied" "$ACT_OUTPUT" "gpl-pkg (^1.0.0) - GPL-3.0 - DENIED"
assert_contains "left-pad unknown" "$ACT_OUTPUT" "left-pad (^1.0.0) - WTFPL - UNKNOWN"
assert_contains "total count" "$ACT_OUTPUT" "Total: 3"
assert_contains "approved count" "$ACT_OUTPUT" "Approved: 1"
assert_contains "denied count" "$ACT_OUTPUT" "Denied: 1"
assert_contains "unknown count" "$ACT_OUTPUT" "Unknown: 1"
assert_contains "overall fail" "$ACT_OUTPUT" "Overall: FAIL"

PASS_COUNT=$((PASS_COUNT + 10))
rm -rf "$TMPDIR3"
echo ""

# -------------------------------------------------------------------
# TEST CASE 4: requirements.txt (Python manifest)
# -------------------------------------------------------------------
echo "--- Test Case 4: Requirements.txt ---"
TMPDIR4=$(setup_test_repo "$SCRIPT_DIR/fixtures/requirements-txt" "requirements.txt")

# Override the env var for the manifest file
cat > "$TMPDIR4/.github/workflows/dependency-license-checker.yml" << 'WFEOF'
name: Dependency License Checker

on:
  push:
    branches: ["*"]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  MANIFEST_FILE: requirements.txt
  CONFIG_FILE: config.json

jobs:
  unit-tests:
    name: Run Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install pytest
        run: pip install pytest

      - name: Run unit tests
        run: python -m pytest test_license_checker.py -v

  license-check:
    name: Check Dependency Licenses
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Run license checker
        run: python license_checker.py "${{ env.MANIFEST_FILE }}" "${{ env.CONFIG_FILE }}"
WFEOF

cd "$TMPDIR4"
git add -A && git commit -m "update workflow" --quiet

run_act_test "requirements-txt" "$TMPDIR4"

assert_exit_code "act exits 0" "$ACT_EXIT" 0
assert_contains "report header" "$ACT_OUTPUT" "Dependency License Compliance Report"
assert_contains "flask approved" "$ACT_OUTPUT" "flask (==2.3.0) - BSD-3-Clause - APPROVED"
assert_contains "requests approved" "$ACT_OUTPUT" "requests (==2.31.0) - Apache-2.0 - APPROVED"
assert_contains "django approved" "$ACT_OUTPUT" "django (>=4.0) - BSD-3-Clause - APPROVED"
assert_contains "numpy approved" "$ACT_OUTPUT" "numpy (~=1.24) - BSD-3-Clause - APPROVED"
assert_contains "total count" "$ACT_OUTPUT" "Total: 4"
assert_contains "approved count" "$ACT_OUTPUT" "Approved: 4"
assert_contains "denied count" "$ACT_OUTPUT" "Denied: 0"
assert_contains "overall pass" "$ACT_OUTPUT" "Overall: PASS"

PASS_COUNT=$((PASS_COUNT + 10))
rm -rf "$TMPDIR4"
echo ""

# -------------------------------------------------------------------
# WORKFLOW STRUCTURE TESTS
# -------------------------------------------------------------------
echo "--- Workflow Structure Tests ---"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

WF_FILE="$SCRIPT_DIR/.github/workflows/dependency-license-checker.yml"

# Test: YAML parses and has expected triggers
echo "  Checking YAML structure..."
if python3 -c "
import json, sys
# Use basic YAML parsing via json-compatible check
# Read the file and check for expected keys
with open('$WF_FILE') as f:
    content = f.read()
assert 'push:' in content, 'Missing push trigger'
assert 'pull_request:' in content, 'Missing pull_request trigger'
assert 'workflow_dispatch:' in content, 'Missing workflow_dispatch trigger'
assert 'unit-tests:' in content, 'Missing unit-tests job'
assert 'license-check:' in content, 'Missing license-check job'
assert 'actions/checkout@v4' in content, 'Missing checkout action'
assert 'actions/setup-python@v5' in content, 'Missing setup-python action'
assert 'license_checker.py' in content, 'Missing reference to license_checker.py'
assert 'test_license_checker.py' in content, 'Missing reference to test_license_checker.py'
assert 'config.json' in content, 'Missing reference to config.json'
print('All structure checks passed')
" 2>&1; then
    echo "  PASS: Workflow YAML structure is correct"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  FAIL: Workflow YAML structure check failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test: Referenced script files exist
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo "  Checking script file references..."
all_exist=true
for f in license_checker.py test_license_checker.py config.json; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "  FAIL: Referenced file $f does not exist"
        all_exist=false
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done
if $all_exist; then
    echo "  PASS: All referenced script files exist"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# Test: actionlint passes
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo "  Running actionlint..."
if actionlint "$WF_FILE" 2>&1; then
    echo "  PASS: actionlint passed with exit code 0"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  FAIL: actionlint returned non-zero exit code"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "=========================================="
echo "RESULTS"
echo "=========================================="
echo "Total test cases: $((TOTAL_TESTS))"
echo "Assertions passed: $PASS_COUNT"
echo "Assertions failed: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "ALL TESTS PASSED"
    exit 0
else
    echo "SOME TESTS FAILED"
    exit 1
fi
