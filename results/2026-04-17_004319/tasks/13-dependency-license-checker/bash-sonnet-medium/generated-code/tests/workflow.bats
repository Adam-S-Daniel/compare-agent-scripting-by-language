#!/usr/bin/env bats
# tests/workflow.bats
# Workflow structure tests + act integration test.
#
# Structure tests run instantly (parse YAML, check paths, run actionlint).
# The act integration test spins up the full Docker pipeline and asserts on
# exact output values in act-result.txt.

WORKFLOW_FILE="${BATS_TEST_DIRNAME}/../.github/workflows/dependency-license-checker.yml"
PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."

# ── Structure: workflow file exists ──────────────────────────────────────────
@test "workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

# ── Structure: workflow has push and pull_request triggers ───────────────────
@test "workflow has push and pull_request triggers" {
    run grep -E "^\s+(push|pull_request):" "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"push"* ]]
    [[ "$output" == *"pull_request"* ]]
}

# ── Structure: workflow has schedule trigger ──────────────────────────────────
@test "workflow has schedule trigger" {
    run grep -E "schedule:" "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ── Structure: workflow has check-licenses job ────────────────────────────────
@test "workflow defines check-licenses job" {
    run grep -E "check-licenses:" "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ── Structure: workflow uses actions/checkout@v4 ──────────────────────────────
@test "workflow uses actions/checkout@v4" {
    run grep "actions/checkout@v4" "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ── Structure: workflow references license-checker.sh ────────────────────────
@test "workflow references license-checker.sh" {
    run grep "license-checker.sh" "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ── Structure: workflow references fixture files that exist ──────────────────
@test "fixture files referenced in workflow exist" {
    [ -f "${PROJECT_ROOT}/fixtures/package.json" ]
    [ -f "${PROJECT_ROOT}/fixtures/approved-only.json" ]
    [ -f "${PROJECT_ROOT}/fixtures/requirements.txt" ]
    [ -f "${PROJECT_ROOT}/fixtures/license-config.json" ]
    [ -f "${PROJECT_ROOT}/fixtures/mock-licenses.json" ]
}

# ── Structure: actionlint passes ─────────────────────────────────────────────
@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ── Act integration: run full workflow in Docker ──────────────────────────────
# This test sets up a temp git repo, copies the project, runs act push,
# saves all output to act-result.txt, and asserts on exact expected values.
@test "act push runs workflow successfully and produces expected output" {
    # Skip if act or docker is not available
    command -v act  || skip "act not installed"
    command -v docker || skip "docker not installed"

    local tmpdir act_output act_rc
    tmpdir=$(mktemp -d)

    # Copy project files into the temp repo
    cp -r "${PROJECT_ROOT}/." "$tmpdir/"

    # Initialise a git repo (act requires one for push events)
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "ci@test.local"
    git -C "$tmpdir" config user.name  "CI Test"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "test"

    # Run act; capture output; always clean up
    act_output=$(cd "$tmpdir" && act push --rm --pull=false 2>&1) && act_rc=$? || act_rc=$?

    rm -rf "$tmpdir"

    # Persist output to act-result.txt in the project root (required artifact)
    {
        echo "========== TEST CASE: act push =========="
        echo "$act_output"
        echo ""
    } >> "${PROJECT_ROOT}/act-result.txt"

    # ── Assert exit code ──────────────────────────────────────────────────────
    if [[ "$act_rc" -ne 0 ]]; then
        echo "act exited with $act_rc" >&2
        echo "--- act output ---" >&2
        echo "$act_output" >&2
        return 1
    fi

    # ── Assert job succeeded ──────────────────────────────────────────────────
    [[ "$act_output" == *"Job succeeded"* ]]

    # ── Assert exact summary values from the approved-only run ───────────────
    # The "approved-only.json (strict)" step outputs this exact summary line.
    [[ "$act_output" == *"Summary: 3 approved, 0 denied, 0 unknown"* ]]

    # ── Assert summary for package.json run ──────────────────────────────────
    [[ "$act_output" == *"Summary: 3 approved, 1 denied, 1 unknown"* ]]

    # ── Assert specific packages appear in correct sections ───────────────────
    [[ "$act_output" == *"express"*"MIT"* ]]
    [[ "$act_output" == *"node-gpl-lib"*"GPL-2.0"* ]]
    [[ "$act_output" == *"mystery-pkg"* ]]

    # ── Assert summary for requirements.txt run ───────────────────────────────
    [[ "$act_output" == *"Summary: 2 approved, 1 denied, 1 unknown"* ]]
}
