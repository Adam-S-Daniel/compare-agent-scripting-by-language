#!/usr/bin/env bats
# test_check_licenses.bats - Unit tests for check-licenses.sh
# These tests are run inside the GitHub Actions workflow via bats.

setup() {
    # Source the script to access individual functions
    source ./check-licenses.sh

    # Set up test fixtures directory
    FIXTURES_DIR="./fixtures"
}

# --- Tests for manifest parsing ---

@test "parse_package_json extracts dependencies with versions" {
    local output
    output="$(parse_package_json "$FIXTURES_DIR/package.json")"
    [[ "$output" == *"express ^4.18.0"* ]]
    [[ "$output" == *"lodash ^4.17.21"* ]]
    [[ "$output" == *"leftpad ^1.0.0"* ]]
    [[ "$output" == *"evilpkg ^1.0.0"* ]]
}

@test "parse_package_json returns 4 dependencies from test fixture" {
    local count
    count="$(parse_package_json "$FIXTURES_DIR/package.json" | wc -l)"
    [[ "$count" -eq 4 ]]
}

@test "parse_requirements_txt extracts dependencies with versions" {
    local output
    output="$(parse_requirements_txt "$FIXTURES_DIR/requirements.txt")"
    [[ "$output" == *"requests 2.31.0"* ]]
    [[ "$output" == *"flask 2.0.0"* ]]
    [[ "$output" == *"numpy 1.24.0"* ]]
    [[ "$output" == *"pylint 2.17.0"* ]]
}

@test "parse_requirements_txt skips comments and empty lines" {
    local count
    count="$(parse_requirements_txt "$FIXTURES_DIR/requirements.txt" | wc -l)"
    # 5 actual deps (requests, flask, numpy, pylint, unknown-pkg)
    [[ "$count" -eq 5 ]]
}

# --- Tests for license lookup ---

@test "builtin_license_lookup returns MIT for express" {
    local result
    result="$(builtin_license_lookup "express")"
    [[ "$result" == "MIT" ]]
}

@test "builtin_license_lookup returns GPL-3.0 for evilpkg" {
    local result
    result="$(builtin_license_lookup "evilpkg")"
    [[ "$result" == "GPL-3.0" ]]
}

@test "builtin_license_lookup returns UNKNOWN for unrecognized packages" {
    local result
    result="$(builtin_license_lookup "totally-fake-package")"
    [[ "$result" == "UNKNOWN" ]]
}

# --- Tests for license classification ---

@test "classify_license returns approved for MIT" {
    local result
    result="$(classify_license "MIT" "$FIXTURES_DIR/license-config.json")"
    [[ "$result" == "approved" ]]
}

@test "classify_license returns denied for GPL-3.0" {
    local result
    result="$(classify_license "GPL-3.0" "$FIXTURES_DIR/license-config.json")"
    [[ "$result" == "denied" ]]
}

@test "classify_license returns unknown for UNKNOWN license" {
    local result
    result="$(classify_license "UNKNOWN" "$FIXTURES_DIR/license-config.json")"
    [[ "$result" == "unknown" ]]
}

@test "classify_license returns unknown for unlisted license" {
    local result
    result="$(classify_license "Artistic-2.0" "$FIXTURES_DIR/license-config.json")"
    [[ "$result" == "unknown" ]]
}

# --- Tests for full report generation ---

@test "report for package.json shows FAIL with denied licenses" {
    local output
    output="$(generate_report "$FIXTURES_DIR/package.json" "$FIXTURES_DIR/license-config.json" 2>&1 || true)"
    [[ "$output" == *"RESULT: FAIL"* ]]
    [[ "$output" == *"Denied: 2"* ]]
    [[ "$output" == *"Approved: 2"* ]]
}

@test "report for all-approved shows PASS" {
    local output
    output="$(generate_report "$FIXTURES_DIR/all-approved-package.json" "$FIXTURES_DIR/license-config.json" 2>&1)"
    [[ "$output" == *"RESULT: PASS"* ]]
    [[ "$output" == *"Approved: 3"* ]]
    [[ "$output" == *"Denied: 0"* ]]
}

@test "report for requirements.txt shows FAIL with denied and unknown" {
    local output
    output="$(generate_report "$FIXTURES_DIR/requirements.txt" "$FIXTURES_DIR/license-config.json" 2>&1 || true)"
    [[ "$output" == *"RESULT: FAIL"* ]]
    [[ "$output" == *"Denied: 1"* ]]
    [[ "$output" == *"Unknown: 1"* ]]
    [[ "$output" == *"Approved: 3"* ]]
}

# --- Tests for error handling ---

@test "main returns error for missing manifest file" {
    run main "/nonexistent/file.json" "$FIXTURES_DIR/license-config.json"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"ERROR: Manifest file not found"* ]]
}

@test "main returns error for missing config file" {
    run main "$FIXTURES_DIR/package.json" "/nonexistent/config.json"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"ERROR: Config file not found"* ]]
}

@test "main returns error when called with no arguments" {
    run main
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Usage:"* ]]
}

@test "report shows correct package names in output" {
    local output
    output="$(generate_report "$FIXTURES_DIR/package.json" "$FIXTURES_DIR/license-config.json" 2>&1 || true)"
    [[ "$output" == *"express"* ]]
    [[ "$output" == *"lodash"* ]]
    [[ "$output" == *"leftpad"* ]]
    [[ "$output" == *"evilpkg"* ]]
}

@test "report shows total dependency count" {
    local output
    output="$(generate_report "$FIXTURES_DIR/package.json" "$FIXTURES_DIR/license-config.json" 2>&1 || true)"
    [[ "$output" == *"Total dependencies: 4"* ]]
}
