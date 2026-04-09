#!/usr/bin/env bats

# Test suite for GitHub Actions workflow validation and execution
# Verifies workflow structure, actionlint compliance, and act execution

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/semantic-version-bumper.yml"

# ============================================================
# Workflow Structure Tests
# ============================================================

@test "workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "workflow has push trigger" {
    grep -q "push:" "$WORKFLOW_FILE"
}

@test "workflow has pull_request trigger" {
    grep -q "pull_request:" "$WORKFLOW_FILE"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" "$WORKFLOW_FILE"
}

@test "workflow has lint job" {
    grep -q "lint:" "$WORKFLOW_FILE"
}

@test "workflow has test job" {
    grep -q "test:" "$WORKFLOW_FILE"
}

@test "workflow has bump job" {
    grep -q "bump:" "$WORKFLOW_FILE"
}

@test "workflow uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" "$WORKFLOW_FILE"
}

@test "workflow references version_bumper.sh" {
    grep -q "version_bumper.sh" "$WORKFLOW_FILE"
}

@test "workflow references version_lib.sh" {
    grep -q "version_lib.sh" "$WORKFLOW_FILE"
}

@test "workflow sets permissions" {
    grep -q "permissions:" "$WORKFLOW_FILE"
}

@test "workflow has job dependencies (needs)" {
    grep -q "needs:" "$WORKFLOW_FILE"
}

@test "referenced script files exist" {
    [ -f "$SCRIPT_DIR/version_bumper.sh" ]
    [ -f "$SCRIPT_DIR/version_lib.sh" ]
}

@test "workflow references test fixtures correctly" {
    grep -q "test/fixtures/commits_minor.txt" "$WORKFLOW_FILE"
    [ -f "$SCRIPT_DIR/test/fixtures/commits_minor.txt" ]
}

# ============================================================
# actionlint Validation
# ============================================================

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ============================================================
# act Execution Test
# ============================================================

@test "act push runs workflow successfully and produces correct output" {
    # Create isolated temp repo
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Initialize git repo and copy project files
    cd "$tmpdir"
    git init
    git config user.email "test@test.com"
    git config user.name "test"
    cp -r "$SCRIPT_DIR"/* .
    cp -r "$SCRIPT_DIR"/.github .
    git add -A
    git commit -m "test"

    # Run act and capture output
    run act push --rm
    local act_output="$output"
    local act_exit="$status"

    # Save output to act-result.txt in the project directory
    echo "$act_output" > "$SCRIPT_DIR/act-result.txt"

    # Assert act exited successfully
    [ "$act_exit" -eq 0 ]

    # Assert each job succeeded
    [[ "$act_output" == *"Lint and Validate"*"Job succeeded"* ]]
    [[ "$act_output" == *"Run Tests"*"Job succeeded"* ]]
    [[ "$act_output" == *"Version Bump"*"Job succeeded"* ]]

    # Assert correct version output (commits_minor.txt bumps 1.0.0 -> 1.1.0)
    [[ "$act_output" == *"Version bumped to: 1.1.0"* ]]
    [[ "$act_output" == *"new_version=1.1.0"* ]]

    # Assert changelog content appears in output
    [[ "$act_output" == *"## 1.1.0"* ]]
    [[ "$act_output" == *"### Added"* ]]
    [[ "$act_output" == *"add user authentication endpoint"* ]]
    [[ "$act_output" == *"### Fixed"* ]]
    [[ "$act_output" == *"handle edge case in login flow"* ]]

    # Assert all 34 bats tests passed in CI
    [[ "$act_output" == *"ok 34"* ]]

    # Assert VERSION file was updated correctly
    [[ "$act_output" == *"=== New Version ==="* ]]

    # Cleanup
    rm -rf "$tmpdir"
}

@test "act-result.txt exists and contains expected data" {
    # This test depends on the previous test having run
    [ -f "$SCRIPT_DIR/act-result.txt" ]
    [ -s "$SCRIPT_DIR/act-result.txt" ]

    local content
    content="$(cat "$SCRIPT_DIR/act-result.txt")"

    # Verify the file has the key markers
    [[ "$content" == *"Job succeeded"* ]]
    [[ "$content" == *"1.1.0"* ]]
}
