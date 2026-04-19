#!/usr/bin/env bats
# Tests for the GitHub Actions matrix generator

setup() {
    export SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
    export TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# Test 1: Script exists and is executable
@test "matrix-generator script exists" {
    [ -f "$SCRIPT_DIR/matrix-generator.sh" ]
}

@test "matrix-generator script is executable" {
    [ -x "$SCRIPT_DIR/matrix-generator.sh" ]
}

# Test 2: Basic matrix generation with single OS and language
@test "generates matrix with single OS and single language" {
    local config='{"os": ["ubuntu-latest"], "language": ["node"], "version": ["18"]}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    echo "$result" | jq . > /dev/null  # Validate JSON
    [ "$(echo "$result" | jq '.include | length')" -gt 0 ]
}

# Test 3: Cartesian product of OS and versions
@test "generates cartesian product of os and versions" {
    local config='{"os": ["ubuntu-latest", "macos-latest"], "version": ["1", "2"]}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    # Should have 2 OS * 2 versions = 4 combinations
    local include_count
    include_count=$(echo "$result" | jq '.include | length')
    [ "$include_count" = "4" ]
}

# Test 4: Include rules
@test "supports include rules" {
    local config='{"os": ["ubuntu"], "version": ["1"], "include": [{"os": "windows", "version": "2"}]}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    echo "$result" | jq '.include[] | select(.os == "windows")' | grep -q "windows"
}

# Test 5: Exclude rules
@test "supports exclude rules" {
    local config='{"os": ["ubuntu", "macos"], "version": ["1", "2"], "exclude": [{"os": "macos", "version": "1"}]}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    # macos with version 1 should be excluded
    ! echo "$result" | jq '.include[] | select(.os == "macos" and .version == "1")' | grep -q .
}

# Test 6: Fail-fast configuration
@test "includes fail-fast configuration" {
    local config='{"os": ["ubuntu"], "version": ["1"], "fail-fast": true}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    [ "$(echo "$result" | jq '.["fail-fast"]')" = "true" ]
}

# Test 7: Max-parallel configuration
@test "includes max-parallel configuration" {
    local config='{"os": ["ubuntu"], "version": ["1"], "max-parallel": 5}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    [ "$(echo "$result" | jq '.["max-parallel"]')" = "5" ]
}

# Test 8: Matrix size validation
@test "rejects matrix exceeding max size" {
    local config='{"os": ["u1", "u2", "u3", "u4", "u5"], "version": ["1", "2", "3", "4", "5"], "language": ["a", "b", "c", "d"], "max-matrix-size": 10}'

    run "$SCRIPT_DIR/matrix-generator.sh" "$config" 2>&1
    [ $status -ne 0 ]
    [[ "$output" == *"exceeds maximum"* ]] || [[ "$output" == *"too large"* ]]
}

# Test 9: Handles missing OS field gracefully
@test "returns error for missing required fields" {
    local config='{"version": ["1"], "include": []}'

    run "$SCRIPT_DIR/matrix-generator.sh" "$config" 2>&1
    [ $status -ne 0 ]
}

# Test 10: Complex matrix with all features
@test "complex matrix with os, language, version, include, exclude, and limits" {
    local config='{
        "os": ["ubuntu-latest", "macos-latest"],
        "language": ["node", "python"],
        "version": ["16", "18", "20"],
        "include": [{"os": "windows-latest", "language": "node", "version": "18"}],
        "exclude": [{"language": "python", "version": "16"}],
        "fail-fast": false,
        "max-parallel": 10
    }'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    # Should be valid JSON
    echo "$result" | jq . > /dev/null

    # Should have fail-fast and max-parallel
    [ "$(echo "$result" | jq '.["fail-fast"]')" = "false" ]
    [ "$(echo "$result" | jq '.["max-parallel"]')" = "10" ]

    # Should have include array
    [ "$(echo "$result" | jq '.include | type')" = '"array"' ]
}

# Test 11: Empty base arrays (all via include)
@test "handles empty base arrays with include rules" {
    local config='{"os": [], "version": [], "include": [{"os": "ubuntu", "version": "1"}]}'
    local result
    result=$("$SCRIPT_DIR/matrix-generator.sh" "$config")

    echo "$result" | jq . > /dev/null
    [ "$(echo "$result" | jq '.include | length')" -ge 1 ]
}
