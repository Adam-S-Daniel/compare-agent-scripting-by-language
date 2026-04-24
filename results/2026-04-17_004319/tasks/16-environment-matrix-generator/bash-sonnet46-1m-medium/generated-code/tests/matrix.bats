#!/usr/bin/env bats
# Tests for generate_matrix.sh
# TDD approach: tests written first, then implementation added to make them pass.

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/generate_matrix.sh"
FIXTURES="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures" && pwd)"

# ── Red phase: first failing test ──────────────────────────────────────────
@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── Core functionality tests ────────────────────────────────────────────────

@test "no arguments exits with error" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "missing config file exits with error" {
  run "$SCRIPT" "/nonexistent/config.json"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "invalid JSON config exits with error" {
  run "$SCRIPT" "$FIXTURES/invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "invalid JSON" ]]
}

@test "basic matrix output is valid JSON" {
  run "$SCRIPT" "$FIXTURES/basic-config.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq '.' > /dev/null
}

@test "basic matrix contains os array with 2 entries" {
  run "$SCRIPT" "$FIXTURES/basic-config.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '.matrix.os | length')
  [ "$result" -eq 2 ]
}

@test "basic matrix contains ubuntu-latest and windows-latest" {
  run "$SCRIPT" "$FIXTURES/basic-config.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.matrix.os | contains(["ubuntu-latest", "windows-latest"])' > /dev/null
}

@test "basic matrix contains node-version array" {
  run "$SCRIPT" "$FIXTURES/basic-config.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.matrix["node-version"] | contains(["18", "20"])' > /dev/null
}

@test "basic matrix has fail-fast false" {
  run "$SCRIPT" "$FIXTURES/basic-config.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '."fail-fast"')
  [ "$result" = "false" ]
}

@test "basic matrix has no max-parallel when not specified" {
  run "$SCRIPT" "$FIXTURES/basic-config.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '."max-parallel"')
  [ "$result" = "null" ]
}

# ── Include rules ──────────────────────────────────────────────────────────

@test "include rules appear in matrix output" {
  run "$SCRIPT" "$FIXTURES/with-includes.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '.matrix.include | length')
  [ "$result" -eq 1 ]
}

@test "include entry has expected node-version value" {
  run "$SCRIPT" "$FIXTURES/with-includes.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.matrix.include[0]["node-version"]')
  [ "$result" = "22" ]
}

@test "include entry has experimental flag" {
  run "$SCRIPT" "$FIXTURES/with-includes.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '.matrix.include[0].experimental')
  [ "$result" = "true" ]
}

# ── Exclude rules ──────────────────────────────────────────────────────────

@test "exclude rules appear in matrix output" {
  run "$SCRIPT" "$FIXTURES/with-excludes.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '.matrix.exclude | length')
  [ "$result" -eq 1 ]
}

@test "exclude entry has expected os value" {
  run "$SCRIPT" "$FIXTURES/with-excludes.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.matrix.exclude[0].os')
  [ "$result" = "windows-latest" ]
}

# ── max-parallel and fail-fast ─────────────────────────────────────────────

@test "max-parallel is included when specified" {
  run "$SCRIPT" "$FIXTURES/max-parallel.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '."max-parallel"')
  [ "$result" -eq 2 ]
}

@test "fail-fast true is preserved" {
  run "$SCRIPT" "$FIXTURES/max-parallel.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '."fail-fast"')
  [ "$result" = "true" ]
}

# ── Matrix size validation ─────────────────────────────────────────────────

@test "oversized matrix is rejected with error" {
  run "$SCRIPT" "$FIXTURES/oversized.json"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "exceeds maximum" ]]
}

@test "oversized error message includes size info" {
  run "$SCRIPT" "$FIXTURES/oversized.json"
  [ "$status" -eq 1 ]
  # Error should mention the actual size and limit
  [[ "$output" =~ "4" ]]
  [[ "$output" =~ "3" ]]
}

# ── Feature flags / arbitrary dimensions ──────────────────────────────────

@test "feature flag dimensions appear in matrix" {
  run "$SCRIPT" "$FIXTURES/with-flags.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq '.matrix.experimental | length')
  [ "$result" -eq 2 ]
}

@test "multiple dimensions all appear in output" {
  run "$SCRIPT" "$FIXTURES/with-flags.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.matrix.os' > /dev/null
  echo "$output" | jq -e '.matrix["node-version"]' > /dev/null
  echo "$output" | jq -e '.matrix.experimental' > /dev/null
}

# ── Workflow structure tests ────────────────────────────────────────────────

@test "workflow file exists" {
  [ -f "$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.github/workflows/environment-matrix-generator.yml" ]
}

@test "actionlint passes on workflow file" {
  WORKFLOW="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.github/workflows/environment-matrix-generator.yml"
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow has push trigger" {
  WORKFLOW="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.github/workflows/environment-matrix-generator.yml"
  run grep -q "push:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow references generate_matrix.sh" {
  WORKFLOW="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.github/workflows/environment-matrix-generator.yml"
  run grep -q "generate_matrix.sh" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "script file referenced in workflow exists" {
  SCRIPT_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/generate_matrix.sh"
  [ -f "$SCRIPT_PATH" ]
}
