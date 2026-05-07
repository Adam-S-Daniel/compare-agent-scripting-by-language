#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../matrix-generator.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
}

# --- Basic cross-product generation ---

@test "basic config generates correct 4-entry cross-product" {
  run bash "$SCRIPT" "$FIXTURES/basic.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 4 ]
}

@test "basic config contains expected OS values" {
  run bash "$SCRIPT" "$FIXTURES/basic.json"
  [ "$status" -eq 0 ]
  local os_values
  os_values=$(echo "$output" | jq -r '[.matrix.include[].os] | sort | unique | join(",")')
  [ "$os_values" = "macos-latest,ubuntu-latest" ]
}

@test "basic config contains expected language versions" {
  run bash "$SCRIPT" "$FIXTURES/basic.json"
  [ "$status" -eq 0 ]
  local lv_values
  lv_values=$(echo "$output" | jq -r '[.matrix.include[].language_version] | sort | unique | join(",")')
  [ "$lv_values" = "3.10,3.9" ]
}

@test "basic config has fail-fast true by default" {
  run bash "$SCRIPT" "$FIXTURES/basic.json"
  [ "$status" -eq 0 ]
  local ff
  ff=$(echo "$output" | jq '.["fail-fast"]')
  [ "$ff" = "true" ]
}

# --- Include rules ---

@test "include adds extra entry to matrix" {
  run bash "$SCRIPT" "$FIXTURES/with-include.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 3 ]
}

@test "include adds windows-latest entry" {
  run bash "$SCRIPT" "$FIXTURES/with-include.json"
  [ "$status" -eq 0 ]
  local has_windows
  has_windows=$(echo "$output" | jq '[.matrix.include[] | select(.os == "windows-latest")] | length')
  [ "$has_windows" -eq 1 ]
}

@test "included entry has correct properties" {
  run bash "$SCRIPT" "$FIXTURES/with-include.json"
  [ "$status" -eq 0 ]
  local win_entry
  win_entry=$(echo "$output" | jq '.matrix.include[] | select(.os == "windows-latest")')
  local lv ff
  lv=$(echo "$win_entry" | jq -r '.language_version')
  ff=$(echo "$win_entry" | jq -r '.feature_flags')
  [ "$lv" = "3.11" ]
  [ "$ff" = "beta" ]
}

# --- Exclude rules ---

@test "exclude removes matching entry from matrix" {
  run bash "$SCRIPT" "$FIXTURES/with-exclude.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 3 ]
}

@test "excluded combo is not present" {
  run bash "$SCRIPT" "$FIXTURES/with-exclude.json"
  [ "$status" -eq 0 ]
  local excluded
  excluded=$(echo "$output" | jq '[.matrix.include[] | select(.os == "macos-latest" and .language_version == "3.9")] | length')
  [ "$excluded" -eq 0 ]
}

# --- Options: max-parallel and fail-fast ---

@test "fail-fast false is respected" {
  run bash "$SCRIPT" "$FIXTURES/with-options.json"
  [ "$status" -eq 0 ]
  local ff
  ff=$(echo "$output" | jq '.["fail-fast"]')
  [ "$ff" = "false" ]
}

@test "max-parallel is set in output" {
  run bash "$SCRIPT" "$FIXTURES/with-options.json"
  [ "$status" -eq 0 ]
  local mp
  mp=$(echo "$output" | jq '.["max-parallel"]')
  [ "$mp" = "2" ]
}

@test "basic config has no max-parallel key" {
  run bash "$SCRIPT" "$FIXTURES/basic.json"
  [ "$status" -eq 0 ]
  local mp
  mp=$(echo "$output" | jq 'has("max-parallel")')
  [ "$mp" = "false" ]
}

# --- Matrix size validation ---

@test "too-large matrix is rejected" {
  run bash "$SCRIPT" "$FIXTURES/too-large.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceeds maximum"* ]]
}

@test "too-large error includes actual size" {
  run bash "$SCRIPT" "$FIXTURES/too-large.json"
  [[ "$output" == *"260"* ]]
}

# --- Error handling ---

@test "empty axis is rejected" {
  run bash "$SCRIPT" "$FIXTURES/empty-axis.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty"* ]]
}

@test "missing config file produces error" {
  run bash "$SCRIPT" "nonexistent.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "no arguments shows usage" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "invalid JSON produces error" {
  local tmpfile
  tmpfile=$(mktemp)
  echo "not json at all" > "$tmpfile"
  run bash "$SCRIPT" "$tmpfile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid JSON"* ]]
  rm -f "$tmpfile"
}

# --- Combined include + exclude ---

@test "combined include/exclude produces correct count" {
  run bash "$SCRIPT" "$FIXTURES/include-exclude-combo.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 12 ]
}

@test "combined config sets max-parallel to 4" {
  run bash "$SCRIPT" "$FIXTURES/include-exclude-combo.json"
  [ "$status" -eq 0 ]
  local mp
  mp=$(echo "$output" | jq '.["max-parallel"]')
  [ "$mp" = "4" ]
}

@test "combined config sets fail-fast to true" {
  run bash "$SCRIPT" "$FIXTURES/include-exclude-combo.json"
  [ "$status" -eq 0 ]
  local ff
  ff=$(echo "$output" | jq '.["fail-fast"]')
  [ "$ff" = "true" ]
}

@test "combined config excludes macos-latest+3.9+beta" {
  run bash "$SCRIPT" "$FIXTURES/include-exclude-combo.json"
  [ "$status" -eq 0 ]
  local excluded
  excluded=$(echo "$output" | jq '[.matrix.include[] | select(.os == "macos-latest" and .language_version == "3.9" and .feature_flags == "beta")] | length')
  [ "$excluded" -eq 0 ]
}

@test "combined config includes windows-latest+3.12+nightly" {
  run bash "$SCRIPT" "$FIXTURES/include-exclude-combo.json"
  [ "$status" -eq 0 ]
  local included
  included=$(echo "$output" | jq '[.matrix.include[] | select(.os == "windows-latest" and .language_version == "3.12" and .feature_flags == "nightly")] | length')
  [ "$included" -eq 1 ]
}

# --- Output is valid JSON ---

@test "output is valid JSON" {
  run bash "$SCRIPT" "$FIXTURES/basic.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
}
