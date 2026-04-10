#!/usr/bin/env bats
# Tests for generate-matrix.sh using red/green TDD
# Tests are written BEFORE the implementation to ensure they fail first.
#
# Approach: Each test exercises a discrete piece of functionality.
# We cover: existence, error handling, cartesian product, feature flags,
# excludes, includes, max-size validation, output format, and workflow structure.

# Resolve paths relative to this test file so tests work from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT="${PROJECT_DIR}/generate-matrix.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

# Helper: run the script capturing both stdout and stderr.
# Bats `run` captures stdout only; this merges stderr so we can assert on errors.
run_with_stderr() {
  "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Group 1: Script existence and basic error handling
# ---------------------------------------------------------------------------

# RED → GREEN 1: Create generate-matrix.sh (just shebang initially)
@test "generate-matrix.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# RED → GREEN 2: Print usage to stderr when no arguments given
@test "exits non-zero with Usage message when no arguments given" {
  run run_with_stderr "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

# RED → GREEN 3: Error when config file does not exist
@test "exits non-zero with 'not found' error when config file missing" {
  run run_with_stderr "$SCRIPT" /nonexistent/config.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# RED → GREEN 4: Error on invalid JSON
@test "exits non-zero with 'Invalid JSON' error for malformed config" {
  local bad_json
  bad_json=$(mktemp)
  echo "this is not json" > "$bad_json"
  run run_with_stderr "$SCRIPT" "$bad_json"
  rm -f "$bad_json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid JSON"* ]]
}

# RED → GREEN 5: Error when OS list is empty
@test "exits non-zero when OS list is empty" {
  local cfg
  cfg=$(mktemp)
  echo '{"os":[],"language_versions":{},"feature_flags":{}}' > "$cfg"
  run run_with_stderr "$SCRIPT" "$cfg"
  rm -f "$cfg"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Group 2: Cartesian product — basic cases
# ---------------------------------------------------------------------------

# RED → GREEN 6: 2 OS × 2 node versions = 4 combinations
@test "generates 4 combinations for 2 OS x 2 node versions (config1)" {
  run "$SCRIPT" "${FIXTURES}/config1.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.strategy.matrix.include | length')
  [ "$count" -eq 4 ]
}

# RED → GREEN 7: Specific combination ubuntu+node18 must be present
@test "output includes ubuntu-latest with node 18 (config1)" {
  run "$SCRIPT" "${FIXTURES}/config1.json"
  [ "$status" -eq 0 ]
  local found
  found=$(echo "$output" | jq '[.strategy.matrix.include[] | select(.os == "ubuntu-latest" and .node == "18")] | length')
  [ "$found" -ge 1 ]
}

# ---------------------------------------------------------------------------
# Group 3: Feature flags included in combinations
# ---------------------------------------------------------------------------

# RED → GREEN 8: 1 OS × 1 python × 2 debug flags = 2 combinations
@test "generates 2 combinations for OS x python x debug flags (config4)" {
  run "$SCRIPT" "${FIXTURES}/config4.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.strategy.matrix.include | length')
  [ "$count" -eq 2 ]
}

# RED → GREEN 9: Both debug:true and debug:false must appear
@test "output includes both debug=true and debug=false combinations (config4)" {
  run "$SCRIPT" "${FIXTURES}/config4.json"
  [ "$status" -eq 0 ]
  local true_count false_count
  true_count=$(echo "$output" | jq '[.strategy.matrix.include[] | select(.debug == true)] | length')
  false_count=$(echo "$output" | jq '[.strategy.matrix.include[] | select(.debug == false)] | length')
  [ "$true_count" -eq 1 ]
  [ "$false_count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Group 4: Exclude rules remove matching combinations
# ---------------------------------------------------------------------------

# RED → GREEN 10: config2 excludes windows+python3.10, leaving 3 base combos,
# then one include adds 1 more → total 4
@test "generates 4 combinations after exclude and include rules (config2)" {
  run "$SCRIPT" "${FIXTURES}/config2.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.strategy.matrix.include | length')
  [ "$count" -eq 4 ]
}

# RED → GREEN 11: Excluded combination must NOT be in output
@test "excluded combination windows+python3.10 is absent (config2)" {
  run "$SCRIPT" "${FIXTURES}/config2.json"
  [ "$status" -eq 0 ]
  local found
  found=$(echo "$output" | jq '[.strategy.matrix.include[] | select(.os == "windows-latest" and .python == "3.10")] | length')
  [ "$found" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Group 5: Include rules add extra combinations
# ---------------------------------------------------------------------------

# RED → GREEN 12: Included combination macos+python3.11+extra=bonus must appear
@test "included combination macos-latest+python3.11+extra=bonus is present (config2)" {
  run "$SCRIPT" "${FIXTURES}/config2.json"
  [ "$status" -eq 0 ]
  local found
  found=$(echo "$output" | jq '[.strategy.matrix.include[] | select(.os == "macos-latest" and .python == "3.11" and .extra == "bonus")] | length')
  [ "$found" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Group 6: Max size validation
# ---------------------------------------------------------------------------

# RED → GREEN 13: config3 produces 18 combos (3x3x2) but max_size=5 → error
@test "exits non-zero with 'exceeds maximum' error when matrix too large (config3)" {
  run run_with_stderr "$SCRIPT" "${FIXTURES}/config3.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceeds maximum"* ]]
}

# ---------------------------------------------------------------------------
# Group 7: Output format — max-parallel, fail-fast, valid JSON
# ---------------------------------------------------------------------------

# RED → GREEN 14: max-parallel from config is present in output
@test "output strategy.max-parallel equals 4 (config1)" {
  run "$SCRIPT" "${FIXTURES}/config1.json"
  [ "$status" -eq 0 ]
  local mp
  mp=$(echo "$output" | jq '.strategy["max-parallel"]')
  [ "$mp" -eq 4 ]
}

# RED → GREEN 15: fail-fast from config is present in output
@test "output strategy.fail-fast equals false (config1)" {
  run "$SCRIPT" "${FIXTURES}/config1.json"
  [ "$status" -eq 0 ]
  local ff
  ff=$(echo "$output" | jq '.strategy["fail-fast"]')
  [ "$ff" = "false" ]
}

# RED → GREEN 16: fail-fast=true from config2
@test "output strategy.fail-fast equals true (config2)" {
  run "$SCRIPT" "${FIXTURES}/config2.json"
  [ "$status" -eq 0 ]
  local ff
  ff=$(echo "$output" | jq '.strategy["fail-fast"]')
  [ "$ff" = "true" ]
}

# RED → GREEN 17: Output is valid JSON
@test "output is valid JSON (config1)" {
  run "$SCRIPT" "${FIXTURES}/config1.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  [ "$?" -eq 0 ]
}

# RED → GREEN 18: Output has expected top-level structure
@test "output has strategy.matrix.include array (config1)" {
  run "$SCRIPT" "${FIXTURES}/config1.json"
  [ "$status" -eq 0 ]
  local type
  type=$(echo "$output" | jq -r '.strategy.matrix.include | type')
  [ "$type" = "array" ]
}

# ---------------------------------------------------------------------------
# Group 8: Workflow structure tests
# ---------------------------------------------------------------------------

# RED → GREEN 19: Workflow file must exist
@test "workflow file exists at .github/workflows/environment-matrix-generator.yml" {
  [ -f "${PROJECT_DIR}/.github/workflows/environment-matrix-generator.yml" ]
}

# RED → GREEN 20: Workflow has a push trigger
@test "workflow file contains push trigger" {
  grep -q "push" "${PROJECT_DIR}/.github/workflows/environment-matrix-generator.yml"
}

# RED → GREEN 21: Workflow references generate-matrix.sh
@test "workflow file references generate-matrix.sh" {
  grep -q "generate-matrix.sh" "${PROJECT_DIR}/.github/workflows/environment-matrix-generator.yml"
}

# RED → GREEN 22: actionlint passes on workflow file
@test "actionlint passes on workflow file" {
  if ! command -v actionlint &>/dev/null; then
    skip "actionlint not installed in this environment"
  fi
  run actionlint "${PROJECT_DIR}/.github/workflows/environment-matrix-generator.yml"
  [ "$status" -eq 0 ]
}
