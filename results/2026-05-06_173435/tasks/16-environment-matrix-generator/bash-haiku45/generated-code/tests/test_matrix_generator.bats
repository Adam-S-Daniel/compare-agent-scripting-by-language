#!/usr/bin/env bats

# Test fixtures directory
FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"
SCRIPT="${BATS_TEST_DIRNAME}/../generate-matrix.sh"

setup() {
  # Create fixtures directory if it doesn't exist
  mkdir -p "$FIXTURES_DIR"

  # Create temporary files for test outputs
  export TEST_OUTPUT=$(mktemp)
}

teardown() {
  # Clean up temporary files
  rm -f "$TEST_OUTPUT" "${FIXTURES_DIR}"/*.json 2>/dev/null || true
}

# Test 1: Script exists and is executable
@test "script exists and is readable" {
  [ -f "$SCRIPT" ]
}

# Test 2: Simple matrix with single OS
@test "generates matrix with single OS" {
  local config='{"os": ["ubuntu-latest"], "node-version": ["18"]}'
  local result
  result=$("$SCRIPT" "$config")

  # Should contain os array
  echo "$result" | grep -q '"os"'
  # Should contain node-version
  echo "$result" | grep -q '"node-version"'
  # Should contain ubuntu-latest
  echo "$result" | grep -q 'ubuntu-latest'
}

# Test 3: Multiple OS versions
@test "generates matrix with multiple OS" {
  local config='{"os": ["ubuntu-latest", "macos-latest"], "node-version": ["18"]}'
  local result
  result=$("$SCRIPT" "$config")

  echo "$result" | grep -q 'ubuntu-latest'
  echo "$result" | grep -q 'macos-latest'
}

# Test 4: Matrix with include rules
@test "supports include rules" {
  local config='{
    "os": ["ubuntu-latest"],
    "node-version": ["18"],
    "include": [{"os": "windows-latest", "node-version": "20"}]
  }'
  local result
  result=$("$SCRIPT" "$config")

  # Should have windows-latest from include rule
  echo "$result" | grep -q 'windows-latest'
  echo "$result" | grep -q '"20"'
}

# Test 5: Matrix with exclude rules
@test "supports exclude rules" {
  local config='{
    "os": ["ubuntu-latest", "windows-latest"],
    "node-version": ["18", "20"],
    "exclude": [{"os": "windows-latest", "node-version": "18"}]
  }'
  local result
  result=$("$SCRIPT" "$config")

  # Result should be valid JSON
  echo "$result" | jq . > /dev/null
}

# Test 6: Max parallel configuration
@test "includes max-parallel setting" {
  local config='{
    "os": ["ubuntu-latest"],
    "node-version": ["18"],
    "max-parallel": 5
  }'
  local result
  result=$("$SCRIPT" "$config")

  # max-parallel should be in output
  echo "$result" | grep -q '"max-parallel"'
  echo "$result" | grep -q '5'
}

# Test 7: Fail-fast configuration
@test "includes fail-fast setting" {
  local config='{
    "os": ["ubuntu-latest"],
    "node-version": ["18"],
    "fail-fast": false
  }'
  local result
  result=$("$SCRIPT" "$config")

  # fail-fast should be in output and be false
  echo "$result" | jq '.["fail-fast"]' | grep -q 'false'
}

# Test 8: Matrix size validation
@test "validates matrix size does not exceed maximum" {
  local config='{
    "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
    "node-version": ["16", "18", "20"],
    "python-version": ["3.8", "3.9", "3.10"],
    "exclude": []
  }'
  local result
  result=$("$SCRIPT" "$config")

  # Should not fail, max size check should pass
  [ -n "$result" ]
  echo "$result" | jq . > /dev/null
}

# Test 9: Matrix size exceeded error
@test "rejects matrix that exceeds size limit" {
  # Create a config that would exceed 256 combinations
  local config='{
    "os": ["os1", "os2", "os3", "os4", "os5", "os6", "os7", "os8", "os9", "os10"],
    "version": ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8", "v9", "v10"],
    "feature": ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10"],
    "other": ["a", "b", "c", "d"]
  }'

  # Should fail with error code
  ! "$SCRIPT" "$config" > /dev/null 2>&1
}

# Test 10: Output is valid JSON
@test "output is valid JSON" {
  local config='{"os": ["ubuntu-latest"], "node-version": ["18"]}'
  local result
  result=$("$SCRIPT" "$config")

  # Should be parseable as JSON
  echo "$result" | jq . > /dev/null
}

# Test 11: Complex nested configuration
@test "handles complex configuration with multiple factors" {
  local config='{
    "os": ["ubuntu-latest", "macos-latest"],
    "node-version": ["16", "18", "20"],
    "feature": ["api", "cli"],
    "max-parallel": 8,
    "fail-fast": true
  }'
  local result
  result=$("$SCRIPT" "$config")

  # All keys should be present
  echo "$result" | jq '.matrix' > /dev/null
  echo "$result" | jq '.["max-parallel"]' > /dev/null
  echo "$result" | jq '.["fail-fast"]' > /dev/null
}

# Test 12: Include overwrites base matrix combinations
@test "include rules add new combinations" {
  local config='{
    "os": ["ubuntu-latest"],
    "node-version": ["18"],
    "include": [
      {"os": "windows-latest", "node-version": "20", "extra": "value"}
    ]
  }'
  local result
  result=$("$SCRIPT" "$config")

  # Check that extra field is in include
  echo "$result" | jq '.matrix.include[0].extra' | grep -q 'value'
}

# Test 13: Empty configuration
@test "handles empty matrix configuration" {
  local config='{
    "os": [],
    "max-parallel": 1
  }'

  # Should handle gracefully or error appropriately
  local result
  result=$("$SCRIPT" "$config") || true
  # Empty arrays should still produce JSON
  [ -z "$result" ] || echo "$result" | jq . > /dev/null
}

# Test 14: Large matrix within limits
@test "generates large matrix within 256 combination limit" {
  local config='{
    "os": ["ubuntu-latest", "macos-latest"],
    "node-version": ["16", "18"],
    "python": ["3.8", "3.9"],
    "feature": ["api", "cli", "web"],
    "max-parallel": 12
  }'
  local result
  result=$("$SCRIPT" "$config")

  # Should produce valid JSON without errors
  echo "$result" | jq . > /dev/null

  # Should have the limit in the output
  echo "$result" | jq '.["max-parallel"]' | grep -q '12'
}
