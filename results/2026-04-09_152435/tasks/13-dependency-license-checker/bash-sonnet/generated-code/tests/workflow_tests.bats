#!/usr/bin/env bats
# tests/workflow_tests.bats
#
# Workflow structure tests and act integration tests.
#
# Test groups:
#   1. YAML structure verification (no Docker needed)
#   2. File reference verification (paths exist on disk)
#   3. actionlint validation
#   4. Full act integration (runs the workflow in Docker)

setup() {
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
    SCRIPT="${BATS_TEST_DIRNAME}/../license_checker.sh"
    WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/dependency-license-checker.yml"
    WORKDIR="${BATS_TEST_DIRNAME}/.."
    ACT_RESULT_FILE="${WORKDIR}/act-result.txt"
}

# ---------------------------------------------------------------------------
# Group 1: Workflow YAML structure
# ---------------------------------------------------------------------------

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
    grep -q "push:" "$WORKFLOW"
}

@test "workflow has pull_request trigger" {
    grep -q "pull_request:" "$WORKFLOW"
}

@test "workflow has schedule trigger" {
    grep -q "schedule:" "$WORKFLOW"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" "$WORKFLOW"
}

@test "workflow has license-check job" {
    grep -q "license-check:" "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" "$WORKFLOW"
}

@test "workflow has install dependencies step" {
    grep -q "Install dependencies" "$WORKFLOW"
}

@test "workflow has validate script syntax step" {
    grep -q "shellcheck" "$WORKFLOW"
}

@test "workflow has run unit tests step" {
    grep -q "bats tests/license_checker.bats" "$WORKFLOW"
}

@test "workflow has run license compliance check step" {
    grep -q "license_checker.sh" "$WORKFLOW"
}

# ---------------------------------------------------------------------------
# Group 2: File references — verify referenced paths exist on disk
# ---------------------------------------------------------------------------

@test "license_checker.sh exists at root" {
    [ -f "$SCRIPT" ]
}

@test "unit test file exists" {
    [ -f "${BATS_TEST_DIRNAME}/license_checker.bats" ]
}

@test "package.json fixture exists" {
    [ -f "${FIXTURES}/package.json" ]
}

@test "license_config.json fixture exists" {
    [ -f "${FIXTURES}/license_config.json" ]
}

@test "mock_licenses.json fixture exists" {
    [ -f "${FIXTURES}/mock_licenses.json" ]
}

# ---------------------------------------------------------------------------
# Group 3: actionlint validation
# ---------------------------------------------------------------------------

@test "workflow passes actionlint" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Group 4: Act integration — full workflow execution in Docker
#
# Runs act push --rm inside a fresh temporary git repo containing all project
# files, saves output to act-result.txt, and asserts on EXACT expected values.
# ---------------------------------------------------------------------------

@test "act push runs successfully and produces expected compliance output" {
    # Create a fresh temp git repo with the full project
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy all project files (excluding any previous act-result.txt and .git)
    cp -r "${WORKDIR}/." "$tmpdir/"
    rm -rf "${tmpdir}/.git" "${tmpdir}/act-result.txt"

    # Copy .actrc for Docker image configuration if present
    if [[ -f "${WORKDIR}/.actrc" ]]; then
        cp "${WORKDIR}/.actrc" "${tmpdir}/.actrc"
    fi

    # Initialise git repo (act requires a real git repo)
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "test@example.com"
    git -C "$tmpdir" config user.name "Test Runner"
    git -C "$tmpdir" add -A
    git -C "$tmpdir" commit -q -m "test: run license checker workflow"

    # Run the workflow via act and capture output
    local act_output exit_code
    exit_code=0
    # --pull=false: use locally cached Docker image (act-ubuntu-pwsh:latest is local-only)
    act_output=$(cd "$tmpdir" && act push --rm --pull=false 2>&1) || exit_code=$?

    # --- Save to act-result.txt (required artifact) ---
    {
        printf '=== ACT RUN START: %s ===\n' "$(date -Iseconds)"
        printf '%s\n' "$act_output"
        printf '=== ACT RUN END (exit code: %d) ===\n\n' "$exit_code"
    } >> "$ACT_RESULT_FILE"

    # Clean up temp repo
    rm -rf "$tmpdir"

    # --- Assertions: exit code ---
    [ "$exit_code" -eq 0 ]

    # --- Assertions: job succeeded ---
    [[ "$act_output" == *"Job succeeded"* ]]

    # --- Assertions: unit tests ran and passed ---
    # bats outputs "X tests, 0 failures" or similar success lines
    [[ "$act_output" == *"26 tests"* ]] || [[ "$act_output" == *"ok 26"* ]]

    # --- Assertions: exact compliance report values ---
    # The workflow runs the checker on tests/fixtures/package.json which has
    # 5 MIT-licensed packages — all APPROVED, Status: PASS.
    [[ "$act_output" == *"react"* ]]
    [[ "$act_output" == *"lodash"* ]]
    [[ "$act_output" == *"MIT"* ]]
    [[ "$act_output" == *"APPROVED"* ]]
    [[ "$act_output" == *"Total: 5"* ]]
    [[ "$act_output" == *"Approved: 5"* ]]
    [[ "$act_output" == *"Denied: 0"* ]]
    [[ "$act_output" == *"Status: PASS"* ]]
}
