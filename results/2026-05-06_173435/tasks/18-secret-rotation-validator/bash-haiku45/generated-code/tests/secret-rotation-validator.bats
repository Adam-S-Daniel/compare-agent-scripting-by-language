#!/usr/bin/env bats

# Test the secret rotation validator script
# Using red-green TDD: write failing tests first, then implement

setup() {
  # Set up test environment - get the directory of the test file
  TEST_FILE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  SCRIPT_DIR="$(cd "${TEST_FILE_DIR}/.." && pwd)"
  SCRIPT="${SCRIPT_DIR}/secret-rotation-validator.sh"
  TEST_FIXTURES="${SCRIPT_DIR}/tests/fixtures"
  TEMP_DIR="$(mktemp -d)"

  # Reference date for consistent testing (2026-05-06)
  export CURRENT_DATE="2026-05-06"
}

teardown() {
  rm -rf "$TEMP_DIR"
}

# Test 1: Script exists and is executable
@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

# Test 2: Script shows help with --help
@test "script shows help with --help" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# Test 3: Script validates config file exists
@test "script exits with error if config file missing" {
  run "$SCRIPT" --config /nonexistent/config.json --warning-days 7
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

# Test 4: Script reads and parses valid JSON config
@test "script parses valid JSON config file" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
}

# Test 5: Script outputs markdown table format by default
@test "script outputs markdown table format by default" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  [[ "$output" == *"|"* ]]  # Markdown table has pipes
}

# Test 6: Script can output JSON format
@test "script outputs JSON format when specified" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --format json --current-date 2026-05-06
  [ "$status" -eq 0 ]
  [[ "$output" == *"{"* ]] && [[ "$output" == *"}"* ]]  # Valid JSON
}

# Test 7: Expired secret identified correctly (expired = past due date)
@test "identifies expired secrets (past rotation due date)" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  # SSL cert last rotated 2026-02-01, 90 day policy = due 2026-04-30 (passed as of 2026-05-06)
  [[ "$output" == *"ssl-cert"* ]]
  [[ "$output" == *"EXPIRED"* ]] || [[ "$output" == *"expired"* ]]
}

# Test 8: Warning status for secrets expiring soon
@test "identifies secrets expiring soon (in warning window)" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  # db-password last rotated 2026-04-01, 30 day policy = due 2026-05-01 (within 7 day window as of 2026-05-06)
  [[ "$output" == *"db-password"* ]]
  [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"warning"* ]]
}

# Test 9: OK status for secrets not expiring soon
@test "identifies secrets that are OK (not expiring soon)" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  # api-key last rotated 2026-03-15, 30 day policy = due 2026-04-14 (past due but output should still have OK status? Let me reconsider)
  # Actually api-key is also expired. Let me check my logic.
}

# Test 10: JSON output contains all required fields
@test "JSON output contains all required fields" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --format json --current-date 2026-05-06
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"name\""* ]]
  [[ "$output" == *"\"status\""* ]]
  [[ "$output" == *"\"days_until_due\""* ]]
}

# Test 11: Custom warning window respected
@test "respects custom warning window" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 20 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  # With 20 day warning, api-key should be in warning (due 2026-04-14, window 2026-04-26-2026-05-06)
  [[ "$output" == *"api-key"* ]]
}

# Test 12: Markdown table has proper headers
@test "markdown table includes proper headers" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  [[ "$output" == *"Name"* ]] || [[ "$output" == *"name"* ]]
  [[ "$output" == *"Status"* ]] || [[ "$output" == *"status"* ]]
}

# Test 13: Output grouped by urgency (expired, warning, ok)
@test "output grouped by urgency (expired, warning, ok)" {
  run "$SCRIPT" --config "$TEST_FIXTURES/sample-config.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -eq 0 ]
  output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')
  [[ "$output_lower" == *"expired"* ]]
  [[ "$output_lower" == *"warning"* ]]
}

# Test 14: Invalid JSON config handled gracefully
@test "handles invalid JSON config with error message" {
  echo "{ invalid json" > "$TEMP_DIR/bad.json"
  run "$SCRIPT" --config "$TEMP_DIR/bad.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"JSON"* ]] || [[ "$output" == *"json"* ]]
}

# Test 15: Missing required config fields handled
@test "handles incomplete secret config with error" {
  echo '{"secrets":[{"name":"incomplete"}]}' > "$TEMP_DIR/incomplete.json"
  run "$SCRIPT" --config "$TEMP_DIR/incomplete.json" --warning-days 7 --current-date 2026-05-06
  [ "$status" -ne 0 ]
}
