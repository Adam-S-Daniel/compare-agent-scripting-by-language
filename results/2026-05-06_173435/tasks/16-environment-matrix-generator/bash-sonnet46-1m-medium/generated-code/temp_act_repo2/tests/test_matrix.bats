#!/usr/bin/env bats
# Red/green TDD tests for generate_matrix.sh
# Each test was written failing first, then the minimal code was added to pass it.

SCRIPT="$BATS_TEST_DIRNAME/../generate_matrix.sh"

# --- Test 1: Script exists and is executable ---
@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# --- Test 2: Missing config file produces error ---
@test "missing config file produces error message" {
  run "$SCRIPT" /nonexistent/path.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

# --- Test 3: Basic matrix generation (os + version) ---
@test "generates cartesian product of os and version" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/basic_matrix.json"
  [ "$status" -eq 0 ]
  # Should contain both OS values
  [[ "$output" == *"ubuntu-latest"* ]]
  [[ "$output" == *"windows-latest"* ]]
  # Should contain both version values
  [[ "$output" == *"3.9"* ]]
  [[ "$output" == *"3.11"* ]]
}

# --- Test 4: Output is valid JSON ---
@test "output is valid JSON" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/basic_matrix.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

# --- Test 5: Matrix include entries are passed through ---
@test "include entries appear in output" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/include_matrix.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"experimental"* ]]
}

# --- Test 6: Exclude entries are present in output ---
@test "exclude entries appear in output" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/exclude_matrix.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exclude"* ]]
}

# --- Test 7: max-parallel is included in output ---
@test "max-parallel is included in output" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/parallel_matrix.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max-parallel"* ]]
  [[ "$output" == *"4"* ]]
}

# --- Test 8: fail-fast is included in output ---
@test "fail-fast is included in output" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/failfast_matrix.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fail-fast"* ]]
}

# --- Test 9: Matrix size validation - exceeding max_size produces error ---
@test "exceeding max_size produces error" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/oversized_matrix.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceed"* ]] || [[ "$output" == *"too large"* ]] || [[ "$output" == *"max"* ]]
}

# --- Test 10: Correct combination count for basic 2x2 matrix ---
@test "2x2 matrix produces exactly 4 include combinations" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/two_by_two.json"
  [ "$status" -eq 0 ]
  # Count "os" occurrences in include array - should be 4 combinations
  count=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data['include']))
")
  [ "$count" -eq 4 ]
}

# --- Test 11: fail-fast false is preserved ---
@test "fail-fast false is preserved in output" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/failfast_matrix.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('fail-fast', 'MISSING'))
")
  [ "$result" = "False" ]
}

# --- Test 12: max-parallel value is correct ---
@test "max-parallel value matches config" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/parallel_matrix.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('max-parallel', 'MISSING'))
")
  [ "$result" = "4" ]
}

# --- Test 13: Matrix with feature flags produces combinations ---
@test "feature flags are included in matrix combinations" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/feature_flags.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cache_enabled"* ]]
  [[ "$output" == *"debug_mode"* ]]
}

# --- Test 14: Empty dimensions produce valid empty matrix ---
@test "single OS single version produces 1 combination" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/single_combo.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data['include']))
")
  [ "$count" -eq 1 ]
}

# --- Test 15: Workflow structure test - YAML file exists ---
@test "workflow YAML file exists" {
  [ -f "$BATS_TEST_DIRNAME/../.github/workflows/environment-matrix-generator.yml" ]
}

# --- Test 16: Workflow references script correctly ---
@test "workflow references generate_matrix.sh" {
  grep -q "generate_matrix.sh" "$BATS_TEST_DIRNAME/../.github/workflows/environment-matrix-generator.yml"
}

# --- Test 17: Workflow has expected triggers ---
@test "workflow has push trigger" {
  grep -q "push:" "$BATS_TEST_DIRNAME/../.github/workflows/environment-matrix-generator.yml"
}

# --- Test 18: actionlint passes ---
@test "actionlint passes on workflow file" {
  run actionlint "$BATS_TEST_DIRNAME/../.github/workflows/environment-matrix-generator.yml"
  [ "$status" -eq 0 ]
}

# --- Test 19: Explicit include extras are merged into matrix ---
@test "extra include fields are preserved in output" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/include_matrix.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Check that extra key from include is present somewhere
found = any('extra_pkg' in str(item) for item in data['include'])
print('yes' if found else 'no')
")
  [ "$result" = "yes" ]
}

# --- Test 20: Exclude removes correct combination ---
@test "excluded combination is removed from matrix" {
  run "$SCRIPT" "$BATS_TEST_DIRNAME/../fixtures/exclude_matrix.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Check that excluded combo (windows-latest + 3.9) is NOT in include
excluded = any(
    item.get('os') == 'windows-latest' and str(item.get('version')) == '3.9'
    for item in data['include']
)
print('excluded' if not excluded else 'present')
")
  [ "$result" = "excluded" ]
}
