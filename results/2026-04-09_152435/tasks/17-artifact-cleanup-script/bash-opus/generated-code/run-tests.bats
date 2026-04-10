#!/usr/bin/env bats
# Test harness that runs all tests through GitHub Actions via act.
# Each test sets up a temp git repo, runs act push --rm, captures output,
# and asserts on exact expected values.

PROJ_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT="$PROJ_DIR/act-result.txt"

setup_file() {
    # Clear act-result.txt at the start
    : > "$ACT_RESULT"
}

# Helper: set up a temp git repo with project files and run act
# Arguments: $1 = test label
# Globals: PROJ_DIR, ACT_RESULT
# Sets: ACT_OUTPUT, ACT_EXIT
run_act_test() {
    local label="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy project files into the temp repo
    cp "$PROJ_DIR/artifact-cleanup.sh" "$tmpdir/"
    cp -r "$PROJ_DIR/fixtures" "$tmpdir/"
    cp -r "$PROJ_DIR/tests" "$tmpdir/"
    mkdir -p "$tmpdir/.github/workflows"
    cp "$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml" "$tmpdir/.github/workflows/"

    # Copy .actrc for custom container
    if [[ -f "$PROJ_DIR/.actrc" ]]; then
        cp "$PROJ_DIR/.actrc" "$tmpdir/"
    fi

    # Initialize git repo (act requires it)
    (cd "$tmpdir" && git init -b main && git add -A && git commit -m "test: $label") >/dev/null 2>&1

    # Run act
    local act_output act_exit
    act_output=$(cd "$tmpdir" && act push --rm --pull=false 2>&1) || true
    act_exit=${PIPESTATUS[0]:-$?}

    # Append to act-result.txt
    {
        echo "========== TEST: $label =========="
        echo "$act_output"
        echo "========== EXIT CODE: $act_exit =========="
        echo ""
    } >> "$ACT_RESULT"

    # Clean up
    rm -rf "$tmpdir"

    # Export for assertions
    ACT_OUTPUT="$act_output"
    ACT_EXIT="$act_exit"
}

# ── Workflow structure tests ─────────────────────────────────────────────────

@test "workflow YAML has correct triggers" {
    local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
    [[ -f "$wf" ]]
    # Check triggers exist
    grep -q "push:" "$wf"
    grep -q "pull_request:" "$wf"
    grep -q "workflow_dispatch:" "$wf"
}

@test "workflow YAML has expected jobs and steps" {
    local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
    grep -q "jobs:" "$wf"
    grep -q "test:" "$wf"
    grep -q "actions/checkout@v4" "$wf"
    grep -q "bats" "$wf"
    grep -q "shellcheck" "$wf"
}

@test "workflow references script files that exist" {
    local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
    # Workflow references artifact-cleanup.sh
    grep -q "artifact-cleanup.sh" "$wf"
    # The referenced file must exist
    [[ -f "$PROJ_DIR/artifact-cleanup.sh" ]]
    # Tests directory must exist
    [[ -d "$PROJ_DIR/tests" ]]
}

@test "actionlint passes on workflow" {
    run actionlint "$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "shellcheck passes on artifact-cleanup.sh" {
    run shellcheck "$PROJ_DIR/artifact-cleanup.sh"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "bash -n passes on artifact-cleanup.sh" {
    run bash -n "$PROJ_DIR/artifact-cleanup.sh"
    echo "$output"
    [ "$status" -eq 0 ]
}

# ── Act integration test ────────────────────────────────────────────────────

@test "act: full test suite passes through GitHub Actions" {
    run_act_test "full-test-suite"

    # Assert act succeeded
    echo "$ACT_OUTPUT"
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]

    # Assert shellcheck step passed
    [[ "$ACT_OUTPUT" == *"shellcheck passed"* ]]
    [[ "$ACT_OUTPUT" == *"bash -n passed"* ]]

    # Assert bats test results appear — check for TAP output lines
    # TAP: "ok" lines indicate passing tests
    [[ "$ACT_OUTPUT" == *"ok 1"* ]]

    # Verify specific test names from the bats output
    [[ "$ACT_OUTPUT" == *"exits with error when no --input given"* ]]
    [[ "$ACT_OUTPUT" == *"max-age-days: deletes artifacts older than threshold"* ]]
    [[ "$ACT_OUTPUT" == *"keep-latest-n: keeps only N newest per workflow"* ]]
    [[ "$ACT_OUTPUT" == *"max-total-size: deletes oldest first to fit budget"* ]]
    [[ "$ACT_OUTPUT" == *"combined policies: max-age and keep-latest-n together"* ]]
    [[ "$ACT_OUTPUT" == *"dry-run mode is shown by default"* ]]
    [[ "$ACT_OUTPUT" == *"output contains expected section headers"* ]]
    [[ "$ACT_OUTPUT" == *"basic fixture: max-age-days 30 produces correct summary"* ]]

    # All 15 tests should pass (ok 1 through ok 15)
    [[ "$ACT_OUTPUT" == *"ok 1"* ]]
    [[ "$ACT_OUTPUT" == *"ok 5"* ]]
    [[ "$ACT_OUTPUT" == *"ok 10"* ]]
    [[ "$ACT_OUTPUT" == *"ok 15"* ]]

    # No test failures
    if echo "$ACT_OUTPUT" | grep -q "^not ok"; then
        echo "FAIL: Some bats tests failed"
        return 1
    fi
}

@test "act-result.txt was created and contains output" {
    [[ -f "$ACT_RESULT" ]]
    [[ -s "$ACT_RESULT" ]]
    grep -q "TEST: full-test-suite" "$ACT_RESULT"
    grep -q "Job succeeded" "$ACT_RESULT"
}
