#!/usr/bin/env bats
# TDD tests for dependency-license-checker.sh
# Each test was written before the corresponding feature implementation.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CHECKER="$SCRIPT_DIR/dependency-license-checker.sh"
  FIXTURES="$SCRIPT_DIR/test/fixtures"
  CONFIG="$FIXTURES/license-config.json"
  CONFIG_STRICT="$FIXTURES/license-config-strict.json"
}

# --- Error handling tests (TDD round 1) ---

@test "fails with error when no arguments provided" {
  run bash "$CHECKER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Manifest file is required"* ]]
}

@test "fails with error when manifest is missing" {
  run bash "$CHECKER" -m /nonexistent/package.json -c "$CONFIG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Manifest file not found"* ]]
}

@test "fails with error when config is missing" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c /nonexistent/config.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"Config file not found"* ]]
}

@test "fails with error for unsupported manifest format" {
  local unsupported
  unsupported="$(mktemp -d)/Gemfile"
  touch "$unsupported"
  run bash "$CHECKER" -m "$unsupported" -c "$CONFIG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported manifest format"* ]]
  rm -f "$unsupported"
}

# --- package.json parsing tests (TDD round 2) ---

@test "parses package.json and lists all dependencies" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c "$CONFIG"
  [[ "$output" == *"express"* ]]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"axios"* ]]
  [[ "$output" == *"mysql-connector"* ]]
}

@test "reports correct license for each npm dependency" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c "$CONFIG"
  [[ "$output" == *"express"*"MIT"* ]]
  [[ "$output" == *"lodash"*"MIT"* ]]
  [[ "$output" == *"axios"*"MIT"* ]]
  [[ "$output" == *"mysql-connector"*"GPL-2.0"* ]]
}

# --- requirements.txt parsing tests (TDD round 3) ---

@test "parses requirements.txt and lists all dependencies" {
  run bash "$CHECKER" -m "$FIXTURES/requirements.txt" -c "$CONFIG"
  [[ "$output" == *"flask"* ]]
  [[ "$output" == *"requests"* ]]
  [[ "$output" == *"numpy"* ]]
  [[ "$output" == *"gpl-package"* ]]
}

@test "reports correct license for each Python dependency" {
  run bash "$CHECKER" -m "$FIXTURES/requirements.txt" -c "$CONFIG"
  [[ "$output" == *"flask"*"BSD-3-Clause"* ]]
  [[ "$output" == *"requests"*"Apache-2.0"* ]]
  [[ "$output" == *"numpy"*"BSD-3-Clause"* ]]
  [[ "$output" == *"gpl-package"*"GPL-3.0"* ]]
}

# --- License status classification tests (TDD round 4) ---

@test "marks MIT as approved" {
  run bash "$CHECKER" -m "$FIXTURES/package-clean.json" -c "$CONFIG"
  [[ "$output" == *"express"*"MIT"*"approved"* ]]
}

@test "marks GPL-2.0 as denied" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c "$CONFIG"
  [[ "$output" == *"mysql-connector"*"GPL-2.0"*"denied"* ]]
}

@test "marks unrecognized license as unknown" {
  run bash "$CHECKER" -m "$FIXTURES/package-unknown.json" -c "$CONFIG"
  # left-pad has WTFPL which is not in allow or deny list
  [[ "$output" == *"left-pad"*"WTFPL"*"unknown"* ]]
}

# --- Compliance report format tests (TDD round 5) ---

@test "report includes header" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c "$CONFIG"
  [[ "$output" == *"=== Dependency License Compliance Report ==="* ]]
}

@test "report includes summary with correct counts for package.json" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c "$CONFIG"
  [[ "$output" == *"Total: 4"* ]]
  [[ "$output" == *"Approved: 3"* ]]
  [[ "$output" == *"Denied: 1"* ]]
  [[ "$output" == *"Unknown: 0"* ]]
}

@test "report includes summary with correct counts for requirements.txt" {
  run bash "$CHECKER" -m "$FIXTURES/requirements.txt" -c "$CONFIG"
  [[ "$output" == *"Total: 4"* ]]
  [[ "$output" == *"Approved: 3"* ]]
  [[ "$output" == *"Denied: 1"* ]]
  [[ "$output" == *"Unknown: 0"* ]]
}

# --- Exit code tests (TDD round 6) ---

@test "exits 2 when denied dependencies found (package.json)" {
  run bash "$CHECKER" -m "$FIXTURES/package.json" -c "$CONFIG"
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT: FAIL - Denied licenses found"* ]]
}

@test "exits 0 when all dependencies approved" {
  run bash "$CHECKER" -m "$FIXTURES/package-clean.json" -c "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT: PASS - All dependencies approved"* ]]
}

@test "exits 0 with warning when unknown licenses found" {
  run bash "$CHECKER" -m "$FIXTURES/package-unknown.json" -c "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT: WARNING - Unknown licenses found"* ]]
}

@test "exits 2 when denied dependencies found (requirements.txt)" {
  run bash "$CHECKER" -m "$FIXTURES/requirements.txt" -c "$CONFIG"
  [ "$status" -eq 2 ]
  [[ "$output" == *"RESULT: FAIL - Denied licenses found"* ]]
}

# --- Empty manifest test (TDD round 7) ---

@test "handles empty dependencies gracefully" {
  run bash "$CHECKER" -m "$FIXTURES/package-empty.json" -c "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No dependencies found"* ]]
}

# --- Strict config test (TDD round 8) ---

@test "strict config denies BSD-3-Clause and Apache-2.0" {
  run bash "$CHECKER" -m "$FIXTURES/requirements.txt" -c "$CONFIG_STRICT"
  [[ "$output" == *"flask"*"BSD-3-Clause"*"denied"* ]]
  [[ "$output" == *"requests"*"Apache-2.0"*"denied"* ]]
  [[ "$output" == *"Denied: 4"* ]]
  [ "$status" -eq 2 ]
}

@test "strict config approves only MIT" {
  run bash "$CHECKER" -m "$FIXTURES/package-clean.json" -c "$CONFIG_STRICT"
  [[ "$output" == *"express"*"MIT"*"approved"* ]]
  [[ "$output" == *"Approved: 3"* ]]
}
