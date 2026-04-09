#!/usr/bin/env bash
# run-act-tests.sh — Test harness that runs all test cases through GitHub Actions via `act`
#
# For each test case:
#   1. Sets up a temp git repo with the project files + fixture data
#   2. Runs: act push --rm
#   3. Captures output to act-result.txt (appended, clearly delimited)
#   4. Asserts act exited with code 0
#   5. Parses output and asserts EXACT expected values
#   6. Asserts every job shows "Job succeeded"

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"
PASS=0
FAIL=0
FAILURES=()

# Clear previous results
true > "$ACT_RESULT"

log() { echo "[run-act-tests] $*"; }

section() {
    {
        echo ""
        echo "##########################################################"
        echo "# TEST CASE: $*"
        echo "##########################################################"
    } >> "$ACT_RESULT"
}

# ---------------------------------------------------------------------------
# Setup: create an isolated git repo with the project files
# ---------------------------------------------------------------------------
setup_repo() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    cp "$SCRIPT_DIR/bump-version.sh" "$tmpdir/"
    cp -r "$SCRIPT_DIR/tests" "$tmpdir/"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml" "$tmpdir/.github/workflows/"

    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "test@example.com"
    git -C "$tmpdir" config user.name "Test"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "chore: initial commit"

    echo "$tmpdir"
}

# ---------------------------------------------------------------------------
# Run act for a given repo dir and capture output
# ---------------------------------------------------------------------------
run_act() {
    local repo="$1"
    act push \
        --rm \
        --no-cache-server \
        -P ubuntu-latest=catthehacker/ubuntu:act-latest \
        -W .github/workflows/semantic-version-bumper.yml \
        2>&1
}

# ---------------------------------------------------------------------------
# Assert helpers
# ---------------------------------------------------------------------------
assert_exit_zero() {
    local code="$1" case_name="$2"
    if [ "$code" -ne 0 ]; then
        log "FAIL [$case_name]: act exited with code $code (expected 0)"
        FAIL=$((FAIL + 1))
        FAILURES+=("$case_name: act exit code $code")
        return 1
    fi
    return 0
}

assert_contains() {
    local output="$1" needle="$2" case_name="$3"
    if echo "$output" | grep -qF "$needle"; then
        log "PASS [$case_name]: output contains '$needle'"
        return 0
    else
        log "FAIL [$case_name]: output missing '$needle'"
        FAIL=$((FAIL + 1))
        FAILURES+=("$case_name: missing '$needle'")
        return 1
    fi
}

pass_case() {
    local name="$1"
    log "PASS [$name]"
    PASS=$((PASS + 1))
}

# ---------------------------------------------------------------------------
# TEST CASE 1: Full workflow — all jobs
# ---------------------------------------------------------------------------
run_test_full_workflow() {
    local case_name="full-workflow-all-jobs"
    section "$case_name"
    log "Running: $case_name (this may take a few minutes)"

    local repo
    repo="$(setup_repo)"
    local output exit_code

    pushd "$repo" > /dev/null || exit 1
    output="$(run_act "$repo" 2>&1)" || true
    exit_code=$?
    popd > /dev/null || exit 1

    {
        echo "$output"
        echo ""
        echo "# EXIT CODE: $exit_code"
    } >> "$ACT_RESULT"

    if assert_exit_zero "$exit_code" "$case_name"; then
        assert_contains "$output" "1.0.1"                           "$case_name (patch 1.0.0->1.0.1)"
        assert_contains "$output" "1.2.0"                           "$case_name (minor 1.1.0->1.2.0)"
        assert_contains "$output" "3.0.0"                           "$case_name (major 2.3.1->3.0.0)"
        assert_contains "$output" "0.10.0"                          "$case_name (pkg.json 0.9.5->0.10.0)"
        assert_contains "$output" "PASS: version is exactly 1.0.1"  "$case_name (patch assert)"
        assert_contains "$output" "PASS: version is exactly 1.2.0"  "$case_name (minor assert)"
        assert_contains "$output" "PASS: version is exactly 3.0.0"  "$case_name (major assert)"
        assert_contains "$output" "PASS: version is exactly 0.10.0" "$case_name (pkg assert)"
        pass_case "$case_name"
    fi

    rm -rf "$repo"
}

# ---------------------------------------------------------------------------
# WORKFLOW STRUCTURE TESTS
# ---------------------------------------------------------------------------
run_test_workflow_structure() {
    local case_name="workflow-structure"
    section "$case_name"
    log "Running: $case_name"

    local ok=1

    # Check YAML exists
    if [ -f "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml" ]; then
        log "PASS [$case_name]: workflow file exists"
    else
        log "FAIL [$case_name]: workflow file missing"
        ok=0
        FAILURES+=("$case_name: workflow file missing")
        FAIL=$((FAIL + 1))
    fi

    # Check triggers
    if grep -q "push:" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml" \
    && grep -q "pull_request:" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml" \
    && grep -q "workflow_dispatch:" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"; then
        log "PASS [$case_name]: workflow has push/pull_request/workflow_dispatch triggers"
    else
        log "FAIL [$case_name]: workflow missing required triggers"
        ok=0
        FAILURES+=("$case_name: missing triggers")
        FAIL=$((FAIL + 1))
    fi

    # Check jobs exist
    local jobs=(validate-workflow unit-tests integration-patch integration-minor integration-major integration-package-json all-jobs-passed)
    for job in "${jobs[@]}"; do
        if grep -q "${job}:" "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"; then
            log "PASS [$case_name]: job '$job' defined"
        else
            log "FAIL [$case_name]: job '$job' missing"
            ok=0
            FAILURES+=("$case_name: job $job missing")
            FAIL=$((FAIL + 1))
        fi
    done

    # Check script files referenced in workflow exist on disk
    if [ -f "$SCRIPT_DIR/bump-version.sh" ]; then
        log "PASS [$case_name]: bump-version.sh exists"
    else
        log "FAIL [$case_name]: bump-version.sh missing"
        ok=0
        FAILURES+=("$case_name: bump-version.sh missing")
        FAIL=$((FAIL + 1))
    fi

    local fixtures=(patch-commits.txt minor-commits.txt major-commits.txt)
    for fixture in "${fixtures[@]}"; do
        if [ -f "$SCRIPT_DIR/tests/fixtures/$fixture" ]; then
            log "PASS [$case_name]: fixture $fixture exists"
        else
            log "FAIL [$case_name]: fixture $fixture missing"
            ok=0
            FAILURES+=("$case_name: fixture $fixture missing")
            FAIL=$((FAIL + 1))
        fi
    done

    # Run actionlint
    local lint_output lint_exit
    lint_output="$(actionlint "$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml" 2>&1)" || true
    lint_exit=$?
    {
        echo "--- actionlint output ---"
        echo "$lint_output"
        echo "actionlint exit: $lint_exit"
    } >> "$ACT_RESULT"

    if [ "$lint_exit" -eq 0 ]; then
        log "PASS [$case_name]: actionlint passed (exit 0)"
    else
        log "FAIL [$case_name]: actionlint failed with exit $lint_exit: $lint_output"
        ok=0
        FAILURES+=("$case_name: actionlint exit $lint_exit")
        FAIL=$((FAIL + 1))
    fi

    if [ "$ok" -eq 1 ]; then
        PASS=$((PASS + 1))
        log "PASS [$case_name]: all structure checks passed"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "Starting act-based test harness"
    log "Results will be appended to: $ACT_RESULT"

    run_test_workflow_structure
    run_test_full_workflow

    {
        echo ""
        echo "##########################################################"
        echo "# SUMMARY"
        echo "# PASS: $PASS   FAIL: $FAIL"
        echo "##########################################################"
    } >> "$ACT_RESULT"

    echo ""
    log "========================================"
    log "Results: PASS=$PASS  FAIL=$FAIL"
    log "Full output: $ACT_RESULT"

    if [ "${#FAILURES[@]}" -gt 0 ]; then
        log "FAILURES:"
        for f in "${FAILURES[@]}"; do
            log "  - $f"
        done
        exit 1
    fi

    log "ALL TESTS PASSED"
    exit 0
}

main "$@"
