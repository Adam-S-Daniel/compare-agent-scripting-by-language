#!/usr/bin/env bats

# Tests for check-licenses.sh
# Each test sets up its own fixtures in BATS_TEST_TMPDIR for isolation.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../check-licenses.sh"
    FIXTURES="$BATS_TEST_DIRNAME/fixtures"
}

# --- Smoke / CLI tests -------------------------------------------------------

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "exits non-zero with no args and prints usage" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "errors when manifest file is missing" {
    run "$SCRIPT" /no/such/manifest.json "$FIXTURES/config.env"
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
}

@test "errors when config file is missing" {
    run "$SCRIPT" "$FIXTURES/package.json" /no/such/config
    [ "$status" -ne 0 ]
    [[ "$output" == *"config"* ]]
}

# --- Manifest parsing --------------------------------------------------------

@test "parses package.json: lists each dependency name@version" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/package.json" "$FIXTURES/config.env"
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
    [[ "$output" == *"left-pad@1.3.0"* ]]
    [[ "$output" == *"lodash@4.17.21"* ]]
    [[ "$output" == *"evil-pkg@0.0.1"* ]]
    [[ "$output" == *"mystery-pkg@9.9.9"* ]]
}

@test "parses requirements.txt: lists each dependency name@version" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/requirements.txt" "$FIXTURES/config.env"
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
    [[ "$output" == *"requests@2.31.0"* ]]
    [[ "$output" == *"flask@3.0.0"* ]]
}

# --- License classification --------------------------------------------------

@test "marks MIT/Apache as APPROVED" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/package.json" "$FIXTURES/config.env"
    [[ "$output" == *"left-pad@1.3.0"*"MIT"*"APPROVED"* ]]
    [[ "$output" == *"lodash@4.17.21"*"Apache-2.0"*"APPROVED"* ]]
}

@test "marks GPL as DENIED" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/package.json" "$FIXTURES/config.env"
    [[ "$output" == *"evil-pkg@0.0.1"*"GPL-3.0"*"DENIED"* ]]
}

@test "marks not-in-DB as UNKNOWN" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/package.json" "$FIXTURES/config.env"
    [[ "$output" == *"mystery-pkg@9.9.9"*"UNKNOWN"* ]]
}

@test "exit code reflects compliance: nonzero when any DENIED" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/package.json" "$FIXTURES/config.env"
    [ "$status" -ne 0 ]
}

@test "exit code 0 when everything is approved" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/clean.json" "$FIXTURES/config.env"
    [ "$status" -eq 0 ]
}

@test "report has summary line with counts" {
    LICENSE_DB="$FIXTURES/licenses.db" \
        run "$SCRIPT" "$FIXTURES/package.json" "$FIXTURES/config.env"
    [[ "$output" == *"Summary"* ]]
    [[ "$output" == *"approved=2"* ]]
    [[ "$output" == *"denied=1"* ]]
    [[ "$output" == *"unknown=1"* ]]
}
