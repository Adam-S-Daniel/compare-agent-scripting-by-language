#!/usr/bin/env bats
# Dependency License Checker Tests
# Uses red/green TDD: each test was written before the implementation

# Load bats support libraries if available
setup() {
    # Set script directory for finding fixtures
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    CHECKER="${SCRIPT_DIR}/license-checker.sh"
    FIXTURES="${SCRIPT_DIR}/fixtures"
}

# ============================================================
# TEST 1: Script exists and is executable
# RED: Will fail until we create license-checker.sh
# ============================================================
@test "license-checker.sh exists and is executable" {
    [ -f "${CHECKER}" ]
    [ -x "${CHECKER}" ]
}

# ============================================================
# TEST 2: Parse package.json dependencies
# RED: Will fail until parse logic is implemented
# ============================================================
@test "parses package.json and extracts dependencies" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --list-deps
    [ "$status" -eq 0 ]
    [[ "$output" == *"express"* ]]
    [[ "$output" == *"lodash"* ]]
    [[ "$output" == *"axios"* ]]
}

# ============================================================
# TEST 3: Parse requirements.txt dependencies
# RED: Will fail until requirements.txt parsing is implemented
# ============================================================
@test "parses requirements.txt and extracts dependencies" {
    run "${CHECKER}" --manifest "${FIXTURES}/requirements.txt" --licenses "${FIXTURES}/license-config.json" --list-deps
    [ "$status" -eq 0 ]
    [[ "$output" == *"requests"* ]]
    [[ "$output" == *"flask"* ]]
    [[ "$output" == *"numpy"* ]]
}

# ============================================================
# TEST 4: Approved license shows as approved
# RED: Will fail until license checking is implemented
# Note: report exits 1 when denied packages exist; we only check output content
# ============================================================
@test "dependency with approved license shows status approved" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --report
    # exit code can be 0 or 1 depending on other deps; check output content
    [[ "$output" == *"express"*"APPROVED"* ]] || [[ "$output" == *"APPROVED"*"express"* ]]
}

# ============================================================
# TEST 5: Denied license shows as denied
# RED: Will fail until deny-list checking is implemented
# Note: report exits 1 when denied packages exist; we check content and exit code
# ============================================================
@test "dependency with denied license shows status denied" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --report
    # gpl-package uses GPL-3.0 which is in the deny-list — exit code should be 1
    [ "$status" -eq 1 ]
    [[ "$output" == *"gpl-package"*"DENIED"* ]] || [[ "$output" == *"DENIED"*"gpl-package"* ]]
}

# ============================================================
# TEST 6: Unknown license shows as unknown
# RED: Will fail until unknown detection is implemented
# ============================================================
@test "dependency with unknown license shows status unknown" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --report
    # mystery-dep has a license not in allow or deny lists
    [[ "$output" == *"mystery-dep"*"UNKNOWN"* ]] || [[ "$output" == *"UNKNOWN"*"mystery-dep"* ]]
}

# ============================================================
# TEST 7: Exit code 1 when denied licenses found
# RED: Will fail until exit code logic is implemented
# ============================================================
@test "exits with code 1 when denied licenses are found" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --report
    [ "$status" -eq 1 ]
}

# ============================================================
# TEST 8: Exit code 0 when all licenses approved
# RED: Will fail until clean manifest checking works
# ============================================================
@test "exits with code 0 when all licenses are approved" {
    run "${CHECKER}" --manifest "${FIXTURES}/package-clean.json" --licenses "${FIXTURES}/license-config.json" --report
    [ "$status" -eq 0 ]
}

# ============================================================
# TEST 9: Summary counts in report
# RED: Will fail until summary reporting is implemented
# ============================================================
@test "report includes summary counts of approved/denied/unknown" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --report
    # Should show summary counts regardless of exit code
    [[ "$output" == *"Approved:"* ]]
    [[ "$output" == *"Denied:"* ]]
    [[ "$output" == *"Unknown:"* ]]
}

# ============================================================
# TEST 10: Error on missing manifest file
# RED: Will fail until error handling is implemented
# ============================================================
@test "exits with error when manifest file does not exist" {
    run "${CHECKER}" --manifest "/nonexistent/package.json" --licenses "${FIXTURES}/license-config.json" --report
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

# ============================================================
# TEST 11: Error on missing license config file
# RED: Will fail until error handling is implemented
# ============================================================
@test "exits with error when license config file does not exist" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "/nonexistent/config.json" --report
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

# ============================================================
# TEST 12: Version numbers extracted correctly
# RED: Will fail until version extraction is implemented
# ============================================================
@test "extracts version numbers from dependencies" {
    run "${CHECKER}" --manifest "${FIXTURES}/package.json" --licenses "${FIXTURES}/license-config.json" --list-deps
    [ "$status" -eq 0 ]
    [[ "$output" == *"4.18"* ]] || [[ "$output" == *"express"*"4"* ]]
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================
@test "GitHub Actions workflow file exists" {
    [ -f "${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml" ]
}

@test "workflow file passes actionlint validation" {
    run actionlint "${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow references existing script files" {
    local workflow="${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
    # Verify license-checker.sh is referenced in the workflow
    grep -q "license-checker.sh" "${workflow}"
    # Verify the script actually exists
    [ -f "${SCRIPT_DIR}/license-checker.sh" ]
}

@test "workflow has required triggers" {
    local workflow="${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
    grep -q "push\|pull_request\|workflow_dispatch" "${workflow}"
}

@test "workflow has at least one job" {
    local workflow="${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
    grep -q "jobs:" "${workflow}"
}
