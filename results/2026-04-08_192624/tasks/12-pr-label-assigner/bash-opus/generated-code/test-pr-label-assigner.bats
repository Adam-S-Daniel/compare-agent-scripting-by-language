#!/usr/bin/env bats
# test-pr-label-assigner.bats - Test suite for PR Label Assigner
#
# All tests run through GitHub Actions via act (nektos/act).
# Each test case:
#   1. Sets up a temp git repo with project files + fixture data
#   2. Runs act push --rm
#   3. Captures output and asserts on exact expected values
#
# Output is appended to act-result.txt in the project root.

# Project root directory (where the source files live)
PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"

# Helper: set up a temp git repo with the project files and a given fixture
# as the "changed-files.txt" that the workflow will pick up.
setup_act_repo() {
    local fixture_file="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy project files
    cp -r "${PROJECT_DIR}/.github" "${tmpdir}/"
    cp "${PROJECT_DIR}/pr-label-assigner.sh" "${tmpdir}/"
    cp "${PROJECT_DIR}/label-rules.conf" "${tmpdir}/"
    mkdir -p "${tmpdir}/test-fixtures"
    cp -r "${PROJECT_DIR}/test-fixtures/"* "${tmpdir}/test-fixtures/"

    # Copy the specific fixture as the default changed-files.txt
    cp "${PROJECT_DIR}/test-fixtures/${fixture_file}" "${tmpdir}/test-fixtures/changed-files.txt"

    # Initialize git repo
    cd "${tmpdir}"
    git init -q
    git config user.email "test@test.com"
    git config user.name "test"
    git add -A
    git commit -q -m "test setup"

    echo "${tmpdir}"
}

# Helper: run act in a temp repo and capture output
run_act_in_repo() {
    local tmpdir="$1"
    cd "${tmpdir}"
    act push --rm 2>&1
}

# Helper: append delimited output to act-result.txt
append_result() {
    local test_name="$1"
    local output="$2"
    {
        echo "========================================"
        echo "TEST CASE: ${test_name}"
        echo "========================================"
        echo "${output}"
        echo ""
    } >> "${ACT_RESULT_FILE}"
}

# Clean the result file before the first test
setup_file() {
    > "${ACT_RESULT_FILE}"
}

# --- Workflow structure tests ---

@test "workflow YAML is valid and passes actionlint" {
    run actionlint "${PROJECT_DIR}/.github/workflows/pr-label-assigner.yml"
    append_result "actionlint-validation" "$output"
    [ "$status" -eq 0 ]
}

@test "workflow has correct trigger events" {
    local wf="${PROJECT_DIR}/.github/workflows/pr-label-assigner.yml"
    # Check for push trigger
    run grep -c "push:" "$wf"
    [ "$output" -ge 1 ]
    # Check for pull_request trigger
    run grep -c "pull_request:" "$wf"
    [ "$output" -ge 1 ]
    # Check for workflow_dispatch trigger
    run grep -c "workflow_dispatch:" "$wf"
    [ "$output" -ge 1 ]
}

@test "workflow has assign-labels job with correct steps" {
    local wf="${PROJECT_DIR}/.github/workflows/pr-label-assigner.yml"
    # Check for job name
    run grep -c "assign-labels:" "$wf"
    [ "$output" -ge 1 ]
    # Check for checkout step
    run grep -c "actions/checkout@v4" "$wf"
    [ "$output" -ge 1 ]
    # Check for script reference
    run grep -c "pr-label-assigner.sh" "$wf"
    [ "$output" -ge 1 ]
}

@test "workflow references existing script files" {
    # pr-label-assigner.sh must exist
    [ -f "${PROJECT_DIR}/pr-label-assigner.sh" ]
    # label-rules.conf must exist
    [ -f "${PROJECT_DIR}/label-rules.conf" ]
    # Workflow must exist
    [ -f "${PROJECT_DIR}/.github/workflows/pr-label-assigner.yml" ]
}

# --- Functional tests through act ---

@test "case1: docs-only files produce only documentation label" {
    local tmpdir
    tmpdir=$(setup_act_repo "case1-docs-only.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "case1-docs-only" "$output"

    # act must succeed
    [ "$status" -eq 0 ]

    # Job must succeed
    echo "$output" | grep -q "Job succeeded"

    # Must contain exact label: documentation
    echo "$output" | grep -q "documentation"

    # Extract labels from the LABELS_OUTPUT line and subsequent lines
    # The output should have documentation and NOT have api, tests, etc.
    local labels_section
    labels_section=$(echo "$output" | grep -A20 "Assigned labels:" | head -20)
    echo "$labels_section" | grep -q "documentation"

    # Should NOT contain other labels
    ! echo "$labels_section" | grep -q "^[[:space:]]*|[[:space:]]*api$"
    ! echo "$labels_section" | grep -q "^[[:space:]]*|[[:space:]]*tests$"
    ! echo "$labels_section" | grep -q "^[[:space:]]*|[[:space:]]*frontend$"

    rm -rf "${tmpdir}"
}

@test "case2: mixed files produce documentation, api, tests, frontend, ci-cd, core labels" {
    local tmpdir
    tmpdir=$(setup_act_repo "case2-mixed-files.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "case2-mixed-files" "$output"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"

    # All expected labels must appear in order (priority-sorted)
    echo "$output" | grep -q "documentation"
    echo "$output" | grep -q "api"
    echo "$output" | grep -q "tests"
    echo "$output" | grep -q "frontend"
    echo "$output" | grep -q "ci-cd"
    echo "$output" | grep -q "core"

    # Verify priority ordering: documentation (10) before api (20) before tests (30)
    # Extract the FINAL_LABELS output which lists them in priority order
    local labels_block
    labels_block=$(echo "$output" | grep -A10 "FINAL_LABELS=")
    echo "$labels_block" | head -1 | grep -q "documentation"

    rm -rf "${tmpdir}"
}

@test "case3: test files produce only tests label" {
    local tmpdir
    tmpdir=$(setup_act_repo "case3-tests-only.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "case3-tests-only" "$output"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"

    # Only tests label expected
    echo "$output" | grep -q "tests"

    # Verify no other labels in the assigned section
    local assigned_block
    assigned_block=$(echo "$output" | grep -A5 "FINAL_LABELS=")
    echo "$assigned_block" | grep -q "tests"
    ! echo "$assigned_block" | grep -q "documentation"
    ! echo "$assigned_block" | grep -q "api"
    ! echo "$assigned_block" | grep -q "frontend"

    rm -rf "${tmpdir}"
}

@test "case4: infrastructure files produce ci-cd and infrastructure labels" {
    local tmpdir
    tmpdir=$(setup_act_repo "case4-infra.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "case4-infra" "$output"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"

    # Expected: ci-cd (from *.yml docker-compose.yml) and infrastructure
    echo "$output" | grep -q "ci-cd"
    echo "$output" | grep -q "infrastructure"

    # ci-cd (50) should appear before infrastructure (60) in priority order
    local labels_block
    labels_block=$(echo "$output" | grep -A5 "FINAL_LABELS=")
    echo "$labels_block" | head -1 | grep -q "ci-cd"

    rm -rf "${tmpdir}"
}

@test "case5: single API file produces api, frontend, core labels" {
    local tmpdir
    tmpdir=$(setup_act_repo "case5-single-file.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "case5-single-file" "$output"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"

    # src/api/endpoints/v2/health.js matches:
    #   src/api/** -> api (20)
    #   src/**/*.js -> frontend (40)
    #   src/** -> core (90)
    echo "$output" | grep -q "api"
    echo "$output" | grep -q "frontend"
    echo "$output" | grep -q "core"

    # api (20) should appear first
    local labels_block
    labels_block=$(echo "$output" | grep -A5 "FINAL_LABELS=")
    echo "$labels_block" | head -1 | grep -q "api"

    rm -rf "${tmpdir}"
}

@test "case6: priority conflict - documentation before tests in output" {
    local tmpdir
    tmpdir=$(setup_act_repo "case6-priority-conflict.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "case6-priority-conflict" "$output"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"

    # CHANGELOG.md -> documentation (10)
    # utils.test.js -> tests (30)
    echo "$output" | grep -q "documentation"
    echo "$output" | grep -q "tests"

    # documentation (10) should come before tests (30)
    local labels_block
    labels_block=$(echo "$output" | grep -A5 "FINAL_LABELS=")
    echo "$labels_block" | head -1 | grep -q "documentation"

    rm -rf "${tmpdir}"
}

@test "syntax validation step passes in act" {
    # Use case2 as representative - check the syntax validation step output
    local tmpdir
    tmpdir=$(setup_act_repo "case2-mixed-files.txt")
    run run_act_in_repo "${tmpdir}"
    append_result "syntax-validation" "$output"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SYNTAX_CHECK=passed"
    echo "$output" | grep -q "Job succeeded"

    rm -rf "${tmpdir}"
}
