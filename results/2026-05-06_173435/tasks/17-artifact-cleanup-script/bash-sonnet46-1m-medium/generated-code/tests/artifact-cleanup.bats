#!/usr/bin/env bats
# Artifact Cleanup Script - Test Suite
#
# TDD Progression:
#   RED   phase 1: structure tests fail (script/workflow don't exist)
#   GREEN phase 1: create artifact-cleanup.sh skeleton + workflow
#   RED   phase 2: functional act tests fail (logic not implemented)
#   GREEN phase 2: implement retention policy logic in artifact-cleanup.sh
#   REFACTOR: clean up temp file handling and output formatting

# Reference date for reproducible retention policy calculations
REFERENCE_DATE="2024-03-01"

# ============================================================
# STRUCTURE TESTS — run locally, no Docker/act required
# ============================================================

@test "artifact-cleanup.sh exists" {
    # RED: fails until we create the script
    [ -f "${BATS_TEST_DIRNAME}/../artifact-cleanup.sh" ]
}

@test "artifact-cleanup.sh is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../artifact-cleanup.sh" ]
}

@test "workflow file exists" {
    [ -f "${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml" ]
}

@test "workflow references artifact-cleanup.sh" {
    grep -q "artifact-cleanup.sh" \
        "${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
}

@test "fixture files exist" {
    local fixtures="${BATS_TEST_DIRNAME}/../fixtures"
    [ -d "$fixtures" ]
    [ -f "$fixtures/artifacts-age-test.json" ]
    [ -f "$fixtures/policy-age-test.json" ]
    [ -f "$fixtures/artifacts-keep-n-test.json" ]
    [ -f "$fixtures/policy-keep-n-test.json" ]
    [ -f "$fixtures/artifacts-size-test.json" ]
    [ -f "$fixtures/policy-size-test.json" ]
    [ -f "$fixtures/artifacts-combined-test.json" ]
    [ -f "$fixtures/policy-combined-test.json" ]
}

@test "shellcheck passes on artifact-cleanup.sh" {
    run shellcheck "${BATS_TEST_DIRNAME}/../artifact-cleanup.sh"
    [ "$status" -eq 0 ]
}

@test "bash syntax check passes" {
    run bash -n "${BATS_TEST_DIRNAME}/../artifact-cleanup.sh"
    [ "$status" -eq 0 ]
}

@test "actionlint passes on workflow file" {
    run actionlint "${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
    [ "$status" -eq 0 ]
}

@test "workflow has required trigger events: push, pull_request, workflow_dispatch" {
    local workflow="${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
    grep -q "push:" "$workflow"
    grep -q "pull_request:" "$workflow"
    grep -q "workflow_dispatch:" "$workflow"
}

@test "workflow uses actions/checkout" {
    grep -q "actions/checkout" \
        "${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
}

@test "workflow has test job with steps" {
    local workflow="${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
    grep -q "jobs:" "$workflow"
    grep -q "steps:" "$workflow"
}

# ============================================================
# ACT-BASED FUNCTIONAL TESTS — run via Docker through act
# All functional tests use a single act invocation to stay
# within the 3-run limit and keep CI fast.
# ============================================================

# Path for accumulated act output (required artifact)
ACT_RESULT_FILE="${BATS_TEST_DIRNAME}/../act-result.txt"

# Helper: copy project files into a fresh temp git repo for act
_setup_act_repo() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local src="${BATS_TEST_DIRNAME}/.."

    # Copy all project files needed for the workflow
    cp -r "$src/.github"             "$tmpdir/"
    cp    "$src/artifact-cleanup.sh" "$tmpdir/"
    cp -r "$src/fixtures"            "$tmpdir/"
    [ -f "$src/.actrc" ] && cp "$src/.actrc" "$tmpdir/"

    # Initialise git (act requires a git repo)
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "test@example.com"
    git -C "$tmpdir" config user.name  "Test Runner"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "chore: test setup"

    echo "$tmpdir"
}

@test "act: all retention scenarios run and produce correct output" {
    # RED: fails until artifact-cleanup.sh implements retention logic
    # GREEN: implement max_age, keep_latest_n, max_total_size policies

    local tmpdir
    tmpdir=$(_setup_act_repo)

    # Initialise (or append to) the required act-result.txt artifact
    {
        echo "============================================================"
        echo "=== ACT RUN: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
        echo "============================================================"
    } >> "$ACT_RESULT_FILE"

    # Run act from inside the temp repo
    local act_output act_status
    act_output=$(cd "$tmpdir" && act push --rm 2>&1)
    act_status=$?

    # Persist full output for inspection / debugging
    {
        echo "$act_output"
        echo "=== ACT EXIT CODE: $act_status ==="
    } >> "$ACT_RESULT_FILE"

    # Cleanup temp repo
    rm -rf "$tmpdir"

    # ---- assertions ----

    # act itself must succeed
    [ "$act_status" -eq 0 ]

    # The workflow job must report success
    [[ "$act_output" == *"Job succeeded"* ]]

    # Scenario: age-policy-test
    # Policy: max_age_days=30, REFERENCE_DATE=2024-03-01
    # Fixtures: 2 artifacts older than 30 days → delete 2, retain 3
    # Space reclaimed: 1048576 + 2097152 = 3145728 bytes
    [[ "$act_output" == *"TEST SCENARIO: age-policy-test"* ]]
    [[ "$act_output" == *"Space reclaimed: 3145728 bytes (3.00 MB)"* ]]

    # Scenario: keep-n-test
    # Policy: keep_latest_n=2 for 5 artifacts from same run → delete 3
    # Space reclaimed: 1048576 + 2097152 + 3145728 = 6291456 bytes
    [[ "$act_output" == *"TEST SCENARIO: keep-n-test"* ]]
    [[ "$act_output" == *"Space reclaimed: 6291456 bytes (6.00 MB)"* ]]

    # Scenario: size-test
    # Policy: max_total_size=10MB for 4×5MB artifacts → delete 2 oldest
    # Space reclaimed: 5242880 + 5242880 = 10485760 bytes
    [[ "$act_output" == *"TEST SCENARIO: size-test"* ]]
    [[ "$act_output" == *"Space reclaimed: 10485760 bytes (10.00 MB)"* ]]

    # Scenario: combined-test
    # Applies all three policies; expects 3 deletes, 2 retains
    # Space reclaimed: 1048576 + 2097152 + 2097152 = 5242880 bytes
    [[ "$act_output" == *"TEST SCENARIO: combined-test"* ]]
    [[ "$act_output" == *"Space reclaimed: 5242880 bytes (5.00 MB)"* ]]

    # Scenario: dry-run-test
    # Same fixtures as age-policy-test but with --dry-run; must show DRY-RUN
    [[ "$act_output" == *"TEST SCENARIO: dry-run-test"* ]]
    [[ "$act_output" == *"Mode: DRY-RUN"* ]]
}
