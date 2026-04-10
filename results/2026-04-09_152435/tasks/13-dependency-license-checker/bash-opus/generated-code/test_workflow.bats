#!/usr/bin/env bats
# test_workflow.bats - Integration tests that validate the workflow through act
# and structural tests for the workflow YAML itself.

WORKSPACE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
RESULT_FILE="$WORKSPACE_DIR/act-result.txt"
WORKFLOW_FILE="$WORKSPACE_DIR/.github/workflows/dependency-license-checker.yml"

# =============================================
# WORKFLOW STRUCTURE TESTS
# =============================================

@test "workflow YAML file exists" {
    [[ -f "$WORKFLOW_FILE" ]]
}

@test "workflow has correct trigger events" {
    grep -q "push:" "$WORKFLOW_FILE"
    grep -q "pull_request:" "$WORKFLOW_FILE"
    grep -q "workflow_dispatch:" "$WORKFLOW_FILE"
}

@test "workflow has check-licenses job" {
    grep -q "check-licenses:" "$WORKFLOW_FILE"
}

@test "workflow uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" "$WORKFLOW_FILE"
}

@test "workflow references check-licenses.sh script" {
    grep -q "check-licenses.sh" "$WORKFLOW_FILE"
}

@test "check-licenses.sh script file exists" {
    [[ -f "$WORKSPACE_DIR/check-licenses.sh" ]]
}

@test "check-licenses.sh is executable" {
    [[ -x "$WORKSPACE_DIR/check-licenses.sh" ]]
}

@test "test_check_licenses.bats file exists" {
    [[ -f "$WORKSPACE_DIR/test_check_licenses.bats" ]]
}

@test "workflow runs bats tests" {
    grep -q "bats test_check_licenses.bats" "$WORKFLOW_FILE"
}

@test "workflow has permissions defined" {
    grep -q "permissions:" "$WORKFLOW_FILE"
}

@test "workflow runs shellcheck validation" {
    grep -q "shellcheck" "$WORKFLOW_FILE"
}

@test "workflow runs bash -n validation" {
    grep -q "bash -n" "$WORKFLOW_FILE"
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW_FILE"
    [[ "$status" -eq 0 ]]
}

@test "fixtures directory exists with test data" {
    [[ -d "$WORKSPACE_DIR/fixtures" ]]
    [[ -f "$WORKSPACE_DIR/fixtures/package.json" ]]
    [[ -f "$WORKSPACE_DIR/fixtures/requirements.txt" ]]
    [[ -f "$WORKSPACE_DIR/fixtures/license-config.json" ]]
    [[ -f "$WORKSPACE_DIR/fixtures/all-approved-package.json" ]]
}

# =============================================
# ACT INTEGRATION TESTS
# =============================================
# These tests run the full workflow through act and validate output.

setup_file() {
    # Clear previous results
    > "$RESULT_FILE"

    # Create a temp directory with a git repo for act
    export TEMP_REPO
    TEMP_REPO="$(mktemp -d)"

    # Copy all project files to the temp repo
    cp -r "$WORKSPACE_DIR/check-licenses.sh" "$TEMP_REPO/"
    cp -r "$WORKSPACE_DIR/test_check_licenses.bats" "$TEMP_REPO/"
    cp -r "$WORKSPACE_DIR/fixtures" "$TEMP_REPO/"
    cp -r "$WORKSPACE_DIR/.github" "$TEMP_REPO/"
    cp "$WORKSPACE_DIR/.actrc" "$TEMP_REPO/" 2>/dev/null || true

    # Initialize git repo (required by actions/checkout)
    cd "$TEMP_REPO"
    git init -b main
    git add -A
    git -c user.name="test" -c user.email="test@test.com" commit -m "initial"

    # Run act once - capture output for all subsequent tests
    echo "========== ACT RUN START ==========" >> "$RESULT_FILE"
    echo "Date: $(date)" >> "$RESULT_FILE"
    echo "Repo: $TEMP_REPO" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    # Run act push and capture output (--pull=false to use local image)
    # Use a temp file to capture the exit code through the pipe
    local exit_file="$TEMP_REPO/.act_exit"
    (act push --rm --pull=false 2>&1; echo "$?" > "$exit_file") | tee -a "$RESULT_FILE"
    local act_exit
    act_exit="$(cat "$exit_file" 2>/dev/null || echo "1")"
    echo "" >> "$RESULT_FILE"
    echo "ACT_EXIT_CODE=$act_exit" >> "$RESULT_FILE"
    echo "========== ACT RUN END ==========" >> "$RESULT_FILE"

    # Store exit code for tests
    export ACT_EXIT_CODE="$act_exit"

    cd "$WORKSPACE_DIR"
}

teardown_file() {
    # Clean up temp repo
    if [[ -n "${TEMP_REPO:-}" && -d "${TEMP_REPO:-}" ]]; then
        rm -rf "$TEMP_REPO"
    fi
}

@test "act-result.txt file exists and is non-empty" {
    [[ -f "$RESULT_FILE" ]]
    [[ -s "$RESULT_FILE" ]]
}

@test "act push exits with code 0" {
    [[ "$ACT_EXIT_CODE" -eq 0 ]]
}

@test "act output shows Job succeeded" {
    grep -qi "Job succeeded" "$RESULT_FILE" || grep -qi "success" "$RESULT_FILE"
}

# --- Validate shellcheck step ran ---

@test "act output shows shellcheck validation passed" {
    grep -q "Syntax validation passed" "$RESULT_FILE"
}

# --- Validate package.json check output ---

@test "act output shows package.json check with express APPROVED" {
    grep -q "express" "$RESULT_FILE"
    grep -q "APPROVED" "$RESULT_FILE"
}

@test "act output shows leftpad DENIED in package.json check" {
    grep -q "leftpad" "$RESULT_FILE"
    grep -q "WTFPL" "$RESULT_FILE"
    grep -q "DENIED" "$RESULT_FILE"
}

@test "act output shows evilpkg DENIED in package.json check" {
    grep -q "evilpkg" "$RESULT_FILE"
    grep -q "GPL-3.0" "$RESULT_FILE"
}

@test "act output shows Denied: 2 for package.json" {
    grep -q "Denied: 2" "$RESULT_FILE"
}

@test "act output shows Approved: 2 for package.json" {
    grep -q "Approved: 2" "$RESULT_FILE"
}

@test "act output shows FAIL result for package.json" {
    grep -q "RESULT: FAIL - 2 denied" "$RESULT_FILE"
}

# --- Validate requirements.txt check output ---

@test "act output shows requests APPROVED in requirements.txt check" {
    grep -q "requests" "$RESULT_FILE"
    grep -q "Apache-2.0" "$RESULT_FILE"
}

@test "act output shows pylint DENIED in requirements.txt check" {
    grep -q "pylint" "$RESULT_FILE"
    grep -q "GPL-2.0" "$RESULT_FILE"
}

@test "act output shows unknown-pkg UNKNOWN in requirements.txt check" {
    grep -q "unknown-pkg" "$RESULT_FILE"
    grep -q "UNKNOWN" "$RESULT_FILE"
}

@test "act output shows Denied: 1 for requirements.txt" {
    grep -q "Denied: 1" "$RESULT_FILE"
}

# --- Validate all-approved check output ---

@test "act output shows PASS result for all-approved" {
    grep -q "RESULT: PASS - All dependencies have approved licenses" "$RESULT_FILE"
}

@test "act output shows Approved: 3 for all-approved" {
    grep -q "Approved: 3" "$RESULT_FILE"
}

# --- Validate bats tests ran and passed ---

@test "act output shows all 19 bats tests passed" {
    # bats TAP output starts with "1..19" and shows "ok" for each test
    grep -q "1\.\.19" "$RESULT_FILE"
    # Verify no test failures (no "not ok" lines)
    ! grep -q "not ok" "$RESULT_FILE"
}

@test "act output shows Total dependencies: 4 for package.json" {
    grep -q "Total dependencies: 4" "$RESULT_FILE"
}

@test "act output shows Total dependencies: 5 for requirements.txt" {
    grep -q "Total dependencies: 5" "$RESULT_FILE"
}
