#!/usr/bin/env bats
# tests/license_checker.bats
#
# Unit tests for license_checker.sh using red/green TDD methodology.
# These tests run both locally and inside the GitHub Actions workflow via act.
#
# TDD order:
#   1. Script existence + executability
#   2. Help/usage
#   3. Error handling (missing files)
#   4. Manifest parsing (package.json, requirements.txt)
#   5. License lookup (approved, denied, unknown)
#   6. Report generation + exit codes
#   7. Summary counts

setup() {
    # Paths relative to this test file
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
    SCRIPT="${BATS_TEST_DIRNAME}/../license_checker.sh"
    # Ensure script is executable
    chmod +x "$SCRIPT"
}

# ---------------------------------------------------------------------------
# Feature 1: Script existence and executability
# ---------------------------------------------------------------------------

@test "license_checker.sh exists" {
    [ -f "$SCRIPT" ]
}

@test "license_checker.sh is executable" {
    [ -x "$SCRIPT" ]
}

# ---------------------------------------------------------------------------
# Feature 2: Help / usage output
# ---------------------------------------------------------------------------

@test "shows usage with --help flag" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# ---------------------------------------------------------------------------
# Feature 3: Error handling — missing/invalid files
# ---------------------------------------------------------------------------

@test "exits 1 with error when --manifest file not found" {
    run "$SCRIPT" \
        --manifest /nonexistent/manifest.json \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "exits 1 with error when --config file not found" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   /nonexistent/config.json \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "exits 1 with error when --mock-db file not found" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  /nonexistent/db.json
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "exits 1 when required options are missing" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing required option"* ]]
}

# ---------------------------------------------------------------------------
# Feature 4: Manifest parsing
# ---------------------------------------------------------------------------

@test "parses package.json and includes react dependency" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"react"* ]]
}

@test "parses package.json and includes lodash dependency" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lodash"* ]]
}

@test "parses requirements.txt and includes requests dependency" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    # Mixed manifest has denied license so exit 2
    [[ "$output" == *"requests"* ]]
}

@test "parses requirements.txt and includes flask dependency" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [[ "$output" == *"flask"* ]]
}

@test "exits 1 for unsupported manifest format" {
    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    run "$SCRIPT" \
        --manifest "$tmpfile" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported"* ]]
    rm -f "$tmpfile"
}

# ---------------------------------------------------------------------------
# Feature 5: License status — APPROVED
# ---------------------------------------------------------------------------

@test "MIT license is reported as APPROVED" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"APPROVED"* ]]
}

@test "Apache-2.0 license is reported as APPROVED" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_approved.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"APPROVED"* ]]
}

# ---------------------------------------------------------------------------
# Feature 6: License status — DENIED
# ---------------------------------------------------------------------------

@test "GPL-3.0 license is reported as DENIED" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DENIED"* ]]
}

@test "exits with code 2 when any license is denied" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 2 ]
}

@test "exits with code 2 when package.json has denied dependency" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package_denied.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DENIED"* ]]
}

# ---------------------------------------------------------------------------
# Feature 7: License status — UNKNOWN
# ---------------------------------------------------------------------------

@test "package not in mock database is reported as UNKNOWN" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [[ "$output" == *"UNKNOWN"* ]]
}

# ---------------------------------------------------------------------------
# Feature 8: Report content and exit codes
# ---------------------------------------------------------------------------

@test "report shows Status PASS for all-approved manifest" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Status: PASS"* ]]
}

@test "report shows Status FAIL for manifest with denied licenses" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Status: FAIL"* ]]
}

@test "report header is present" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEPENDENCY LICENSE COMPLIANCE REPORT"* ]]
}

@test "report shows total count in summary" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total:"* ]]
}

@test "report shows approved count in summary" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Approved:"* ]]
}

@test "report shows denied count in summary for mixed manifest" {
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [[ "$output" == *"Denied:"* ]]
}

@test "package.json report shows 5 dependencies approved" {
    # package.json has 3 deps + 2 devDeps, all MIT
    run "$SCRIPT" \
        --manifest "${FIXTURES}/package.json" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total: 5"* ]]
    [[ "$output" == *"Approved: 5"* ]]
    [[ "$output" == *"Denied: 0"* ]]
}

@test "mixed requirements report shows 1 denied and 1 unknown" {
    # requirements_mixed.txt: 3 approved, 1 denied (GPL), 1 unknown
    run "$SCRIPT" \
        --manifest "${FIXTURES}/requirements_mixed.txt" \
        --config   "${FIXTURES}/license_config.json" \
        --mock-db  "${FIXTURES}/mock_licenses.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Total: 5"* ]]
    [[ "$output" == *"Denied: 1"* ]]
    [[ "$output" == *"Unknown: 1"* ]]
}
