#!/usr/bin/env bats
# Dependency License Checker - Test Suite (bats-core)
#
# TDD approach: tests were written before implementation to define behavior.
# Each test section corresponds to a TDD iteration:
#   RED   -> test written, script doesn't exist yet
#   GREEN -> minimum implementation added to pass
#   REFACTOR -> clean up without breaking tests

# Paths resolved relative to this test file
PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
SCRIPT="${PROJECT_ROOT}/license_checker.sh"
FIXTURES="${PROJECT_ROOT}/fixtures"
WORKFLOW="${PROJECT_ROOT}/.github/workflows/dependency-license-checker.yml"
ACT_RESULT_FILE="${PROJECT_ROOT}/act-result.txt"

setup() {
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "${TEST_TMP}"
}

# ==============================================================================
# TDD ITERATION 1: Script existence and static analysis
# (These tests fail until license_checker.sh is created)
# ==============================================================================

@test "script exists at expected path" {
    [ -f "${SCRIPT}" ]
}

@test "script is executable" {
    [ -x "${SCRIPT}" ]
}

@test "script has bash shebang" {
    run head -1 "${SCRIPT}"
    [ "$status" -eq 0 ]
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "script passes bash syntax validation" {
    run bash -n "${SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "script passes shellcheck" {
    run shellcheck "${SCRIPT}"
    [ "$status" -eq 0 ]
}

# ==============================================================================
# TDD ITERATION 2: CLI argument validation
# (These tests fail until argument parsing is implemented)
# ==============================================================================

@test "script exits non-zero with no arguments" {
    run bash "${SCRIPT}"
    [ "$status" -ne 0 ]
}

@test "script shows error when --manifest is missing" {
    run bash "${SCRIPT}" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--manifest is required"* ]]
}

@test "script shows error when --config is missing" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --license-db "${FIXTURES}/license_db.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--config is required"* ]]
}

@test "script shows error when --license-db is missing" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--license-db is required"* ]]
}

@test "script shows error when manifest file does not exist" {
    run bash "${SCRIPT}" \
        --manifest "/nonexistent/path/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ==============================================================================
# TDD ITERATION 3: Dependency extraction from package.json
# (These tests fail until package.json parsing is implemented)
# ==============================================================================

@test "extracts production dependencies from package.json" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"lodash@"* ]]
    [[ "$output" == *"express@"* ]]
    [[ "$output" == *"gpl-package@"* ]]
}

@test "extracts devDependencies from package.json" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"jest@"* ]]
}

@test "strips version prefix characters from package.json" {
    # The fixture uses "4.17.21" (no prefix) — version should appear as-is
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"lodash@4.17.21"* ]]
}

# ==============================================================================
# TDD ITERATION 4: License lookup and status classification
# (These tests fail until license lookup and allow/deny checking is implemented)
# ==============================================================================

@test "MIT license is classified as APPROVED" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[LICENSE-CHECK] lodash@4.17.21: MIT -> APPROVED"* ]]
}

@test "GPL-3.0 license is classified as DENIED" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[LICENSE-CHECK] gpl-package@1.0.0: GPL-3.0 -> DENIED"* ]]
}

@test "package absent from license DB is classified as UNKNOWN" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[LICENSE-CHECK] unknown-mystery-lib@2.0.0: UNKNOWN -> UNKNOWN"* ]]
}

# ==============================================================================
# TDD ITERATION 5: Summary and exit codes
# (These tests fail until summary generation is implemented)
# ==============================================================================

@test "report contains a SUMMARY line" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[SUMMARY]"* ]]
}

@test "package.json summary shows correct counts: approved=3 denied=1 unknown=1" {
    # lodash->APPROVED, express->APPROVED, jest->APPROVED, gpl-package->DENIED, unknown-mystery-lib->UNKNOWN
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[SUMMARY] approved=3 denied=1 unknown=1"* ]]
}

@test "script exits 1 when denied licenses are found" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/package.json" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[RESULT] FAILED"* ]]
}

# ==============================================================================
# TDD ITERATION 6: requirements.txt support
# ==============================================================================

@test "extracts dependencies from requirements.txt with == versioning" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/requirements.txt" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[LICENSE-CHECK] requests@2.31.0: Apache-2.0 -> APPROVED"* ]]
    [[ "$output" == *"[LICENSE-CHECK] flask@2.3.0: BSD-3-Clause -> APPROVED"* ]]
    [[ "$output" == *"[LICENSE-CHECK] numpy@1.24.0: BSD-3-Clause -> APPROVED"* ]]
}

@test "requirements.txt with all-approved shows correct summary" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/requirements.txt" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [[ "$output" == *"[SUMMARY] approved=3 denied=0 unknown=0"* ]]
}

@test "script exits 0 when no denied licenses" {
    run bash "${SCRIPT}" \
        --manifest "${FIXTURES}/requirements.txt" \
        --config "${FIXTURES}/license_config.json" \
        --license-db "${FIXTURES}/license_db.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[RESULT] PASSED"* ]]
}

# ==============================================================================
# TDD ITERATION 7: Workflow structure tests
# (These tests fail until the workflow file is created)
# ==============================================================================

@test "workflow file exists" {
    [ -f "${WORKFLOW}" ]
}

@test "workflow has push trigger" {
    grep -q "push:" "${WORKFLOW}"
}

@test "workflow has pull_request trigger" {
    grep -q "pull_request:" "${WORKFLOW}"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch:" "${WORKFLOW}"
}

@test "workflow references license_checker.sh" {
    grep -q "license_checker.sh" "${WORKFLOW}"
}

@test "script file referenced by workflow actually exists" {
    [ -f "${PROJECT_ROOT}/license_checker.sh" ]
}

@test "fixtures referenced by workflow exist" {
    [ -f "${FIXTURES}/package.json" ]
    [ -f "${FIXTURES}/license_config.json" ]
    [ -f "${FIXTURES}/license_db.json" ]
}

@test "actionlint passes on workflow file" {
    run actionlint "${WORKFLOW}"
    [ "$status" -eq 0 ]
}

# ==============================================================================
# TDD ITERATION 8: Act integration test
# Runs the full GitHub Actions workflow in Docker and asserts exact output values.
# This is the end-to-end test that validates the CI pipeline works.
# ==============================================================================

@test "act runs workflow successfully and produces expected license report" {
    # Build an isolated git repo with all project files
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Copy entire project into the temp repo
    cp -r "${PROJECT_ROOT}/." "${tmpdir}/"

    # Initialize git (act requires a git repo for push events)
    cd "${tmpdir}"
    git init -q
    git config user.email "ci@test.local"
    git config user.name "CI Test"
    git add -A
    git commit -q -m "ci: license checker test run"

    # Run the workflow via act; capture full output for assertion and artifact
    run bash -c "cd '${tmpdir}' && act push --rm --platform ubuntu-latest=act-ubuntu-pwsh:latest 2>&1"
    local act_exit="${status}"
    local act_output="${output}"

    # ---- Save to required act-result.txt artifact ----
    {
        printf '=== TEST CASE: package.json and requirements.txt fixture ===\n'
        printf 'Exit code: %s\n' "${act_exit}"
        printf '%s\n' "${act_output}"
        printf '=== END TEST CASE ===\n\n'
    } >> "${ACT_RESULT_FILE}"

    # ---- Assertions ----
    # Workflow must complete successfully
    [ "${act_exit}" -eq 0 ]
    [[ "${act_output}" == *"Job succeeded"* ]]

    # Exact expected values for package.json fixture
    [[ "${act_output}" == *"[LICENSE-CHECK] lodash@4.17.21: MIT -> APPROVED"* ]]
    [[ "${act_output}" == *"[LICENSE-CHECK] express@4.18.2: MIT -> APPROVED"* ]]
    [[ "${act_output}" == *"[LICENSE-CHECK] jest@29.0.0: MIT -> APPROVED"* ]]
    [[ "${act_output}" == *"[LICENSE-CHECK] gpl-package@1.0.0: GPL-3.0 -> DENIED"* ]]
    [[ "${act_output}" == *"[LICENSE-CHECK] unknown-mystery-lib@2.0.0: UNKNOWN -> UNKNOWN"* ]]
    [[ "${act_output}" == *"[SUMMARY] approved=3 denied=1 unknown=1"* ]]

    # Exact expected values for requirements.txt fixture
    [[ "${act_output}" == *"[LICENSE-CHECK] requests@2.31.0: Apache-2.0 -> APPROVED"* ]]
    [[ "${act_output}" == *"[LICENSE-CHECK] flask@2.3.0: BSD-3-Clause -> APPROVED"* ]]
    [[ "${act_output}" == *"[SUMMARY] approved=3 denied=0 unknown=0"* ]]

    cd "${PROJECT_ROOT}"
    rm -rf "${tmpdir}"
}
