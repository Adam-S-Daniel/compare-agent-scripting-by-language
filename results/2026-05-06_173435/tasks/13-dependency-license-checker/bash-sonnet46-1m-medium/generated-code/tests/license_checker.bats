#!/usr/bin/env bats
# Dependency License Checker tests - bats-core framework
# TDD: tests were written before implementation to drive the design

# Paths relative to this test file
setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../license-checker.sh"
  CONFIG="$BATS_TEST_DIRNAME/../fixtures/license-config.json"
  MOCK_DB="$BATS_TEST_DIRNAME/../mock-licenses.db"
  PACKAGE_JSON="$BATS_TEST_DIRNAME/../fixtures/package.json"
  REQUIREMENTS_TXT="$BATS_TEST_DIRNAME/../fixtures/requirements.txt"
}

# --- Red phase 1: script existence ---
@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# --- Red phase 2: package.json parsing ---
@test "parse package.json: all dependency names appear in output" {
  run "$SCRIPT" "$PACKAGE_JSON" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"express"* ]]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"gpl-package"* ]]
  [[ "$output" == *"mystery-lib"* ]]
}

# --- Red phase 3: license classification (approved) ---
@test "MIT license is classified as APPROVED" {
  run "$SCRIPT" "$PACKAGE_JSON" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"APPROVED: express 4.18.0 MIT"* ]]
  [[ "$output" == *"APPROVED: lodash 4.17.21 MIT"* ]]
}

# --- Red phase 4: license classification (denied) ---
@test "GPL-3.0 license is classified as DENIED" {
  run "$SCRIPT" "$PACKAGE_JSON" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"DENIED:   gpl-package 1.0.0 GPL-3.0"* ]]
}

# --- Red phase 5: unknown license ---
@test "package not in mock DB gets UNKNOWN status" {
  run "$SCRIPT" "$PACKAGE_JSON" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"UNKNOWN:  mystery-lib 2.0.0 UNKNOWN"* ]]
}

# --- Red phase 6: summary counts ---
@test "compliance report summary shows correct counts for package.json" {
  run "$SCRIPT" "$PACKAGE_JSON" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"Summary: 2 approved, 1 denied, 1 unknown"* ]]
}

# --- Red phase 7: status FAIL when denied packages exist ---
@test "status is FAIL when denied packages exist" {
  run "$SCRIPT" "$PACKAGE_JSON" "$CONFIG" "$MOCK_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Status: FAIL"* ]]
}

# --- Red phase 8: status PASS when all approved ---
@test "status is PASS when all packages are approved" {
  # Temp fixture with only MIT-licensed packages
  local tmpfile
  tmpfile=$(mktemp /tmp/test-pkg-XXXXXX.json)
  printf '{"dependencies":{"express":"4.18.0","lodash":"4.17.21"}}\n' > "$tmpfile"
  run "$SCRIPT" "$tmpfile" "$CONFIG" "$MOCK_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status: PASS"* ]]
  rm -f "$tmpfile"
}

# --- Red phase 9: requirements.txt parsing ---
@test "parse requirements.txt: all dependency names appear in output" {
  run "$SCRIPT" "$REQUIREMENTS_TXT" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"requests"* ]]
  [[ "$output" == *"django"* ]]
  [[ "$output" == *"flask"* ]]
  [[ "$output" == *"agpl-lib"* ]]
}

# --- Red phase 10: requirements.txt Apache-2.0 approved ---
@test "requirements.txt: Apache-2.0 license is APPROVED" {
  run "$SCRIPT" "$REQUIREMENTS_TXT" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"APPROVED: requests 2.28.0 Apache-2.0"* ]]
}

# --- Red phase 11: requirements.txt AGPL denied ---
@test "requirements.txt: AGPL-3.0 license is DENIED" {
  run "$SCRIPT" "$REQUIREMENTS_TXT" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"DENIED:   agpl-lib 1.5.0 AGPL-3.0"* ]]
}

# --- Red phase 12: requirements.txt summary ---
@test "compliance report summary shows correct counts for requirements.txt" {
  run "$SCRIPT" "$REQUIREMENTS_TXT" "$CONFIG" "$MOCK_DB"
  [[ "$output" == *"Summary: 3 approved, 1 denied, 0 unknown"* ]]
}

# --- Red phase 13: error handling ---
@test "error on missing manifest file" {
  run "$SCRIPT" "/nonexistent/file.json" "$CONFIG" "$MOCK_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

@test "error on unsupported manifest format" {
  local tmpfile
  tmpfile=$(mktemp /tmp/test-manifest-XXXXXX.toml)
  printf '[dependencies]\nfoo = "1.0"\n' > "$tmpfile"
  run "$SCRIPT" "$tmpfile" "$CONFIG" "$MOCK_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"Unsupported"* ]]
  rm -f "$tmpfile"
}

# --- Red phase 14: workflow structure tests ---
@test "workflow YAML file exists" {
  local workflow="$BATS_TEST_DIRNAME/../.github/workflows/dependency-license-checker.yml"
  [ -f "$workflow" ]
}

@test "workflow has push and pull_request triggers" {
  local workflow="$BATS_TEST_DIRNAME/../.github/workflows/dependency-license-checker.yml"
  grep -q "push" "$workflow"
  grep -q "pull_request" "$workflow"
}

@test "workflow references the license-checker script" {
  local workflow="$BATS_TEST_DIRNAME/../.github/workflows/dependency-license-checker.yml"
  grep -q "license-checker.sh" "$workflow"
  [ -f "$BATS_TEST_DIRNAME/../license-checker.sh" ]
}

@test "actionlint passes on the workflow file" {
  local workflow="$BATS_TEST_DIRNAME/../.github/workflows/dependency-license-checker.yml"
  run actionlint "$workflow"
  [ "$status" -eq 0 ]
}
