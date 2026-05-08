#!/usr/bin/env bats
# Workflow structure tests + act integration tests.
# Verifies the .github/workflows/semantic-version-bumper.yml file is correct
# and that the workflow executes successfully end-to-end via act.

WORKFLOW=".github/workflows/semantic-version-bumper.yml"
SCRIPT="bump-version.sh"
FIXTURES_DIR="fixtures"
ACT_RESULT_FILE="$BATS_TEST_DIRNAME/act-result.txt"

# ---------------------------------------------------------------------------
# Workflow structure tests (YAML parsing)
# ---------------------------------------------------------------------------

@test "workflow file exists" {
    [ -f "$BATS_TEST_DIRNAME/$WORKFLOW" ]
}

@test "script file exists and is executable" {
    [ -f "$BATS_TEST_DIRNAME/$SCRIPT" ]
    [ -x "$BATS_TEST_DIRNAME/$SCRIPT" ]
}

@test "all fixture files exist" {
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/commits-fix.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/commits-feat.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/commits-breaking.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/commits-mixed.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/commits-none.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/version-1.0.0.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/version-1.2.3.txt" ]
    [ -f "$BATS_TEST_DIRNAME/$FIXTURES_DIR/package-1.0.0.json" ]
}

@test "workflow has push trigger" {
    grep -q "push:" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow has pull_request trigger" {
    grep -q "pull_request:" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow has a jobs section" {
    grep -q "^jobs:" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow references bump-version.sh script" {
    grep -q "bump-version.sh" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow references bats test file" {
    grep -q "test-version-bumper.bats" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow emits PATCH_RESULT marker" {
    grep -q "PATCH_RESULT" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow emits MINOR_RESULT marker" {
    grep -q "MINOR_RESULT" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "workflow emits MAJOR_RESULT marker" {
    grep -q "MAJOR_RESULT" "$BATS_TEST_DIRNAME/$WORKFLOW"
}

@test "actionlint passes on the workflow file" {
    run actionlint "$BATS_TEST_DIRNAME/$WORKFLOW"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Act integration test — runs the full workflow in Docker and asserts output
# ---------------------------------------------------------------------------

@test "act: workflow runs successfully with correct version outputs" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy entire project into a fresh temp dir so act has an isolated repo
    cp -r "$BATS_TEST_DIRNAME/." "$tmpdir/"

    # Initialise a git repo (act push requires commits)
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "ci@test.local"
    git -C "$tmpdir" config user.name "CI Test"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "chore: initial test commit"

    # Run act and capture all output; record exit status separately
    local act_output act_exit
    act_exit=0
    act_output=$(cd "$tmpdir" && act push --rm --pull=false 2>&1) || act_exit=$?

    # Append this run's output to act-result.txt (required artifact)
    {
        echo "================================================================"
        echo "=== ACT RUN: semantic-version-bumper ==="
        echo "=== Exit code: ${act_exit} ==="
        echo "================================================================"
        echo "$act_output"
        echo "================================================================"
    } >> "$ACT_RESULT_FILE"

    # Assert the workflow completed without error
    [ "$act_exit" -eq 0 ]

    # Assert exact expected version values appear in workflow output
    echo "$act_output" | grep -q "PATCH_RESULT: 1.0.1"
    echo "$act_output" | grep -q "MINOR_RESULT: 1.1.0"
    echo "$act_output" | grep -q "MAJOR_RESULT: 2.0.0"
    echo "$act_output" | grep -q "MIXED_RESULT: 1.1.0"
    echo "$act_output" | grep -q "PKG_RESULT: 1.1.0"
    echo "$act_output" | grep -q "NONE_RESULT: 1.0.0"

    # Assert every job succeeded
    echo "$act_output" | grep -q "Job succeeded"

    rm -rf "$tmpdir"
}
