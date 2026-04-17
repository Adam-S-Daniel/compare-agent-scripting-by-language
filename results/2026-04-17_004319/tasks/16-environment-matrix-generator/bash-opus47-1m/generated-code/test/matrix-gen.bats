#!/usr/bin/env bats
# Tests for the environment matrix generator script.
# Uses bats-core. Run with: bats test/

setup() {
  BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "$BATS_TEST_FILENAME")}"
  SCRIPT="$BATS_TEST_DIRNAME/../matrix-gen.sh"
  FIXTURES="$BATS_TEST_DIRNAME/../fixtures"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "basic matrix: one dimension (os)" {
  # Given a config with a single dimension `os`
  # The script should emit a matrix with that dimension preserved as an array.
  run "$SCRIPT" "$FIXTURES/basic-one-dim.json"
  [ "$status" -eq 0 ]
  # Assert we get a well-formed strategy.matrix with os array.
  echo "$output" | jq -e '.strategy.matrix.os == ["ubuntu-latest","macos-latest"]'
}

@test "basic matrix: multiple dimensions preserved" {
  run "$SCRIPT" "$FIXTURES/basic-multi-dim.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy.matrix.os == ["ubuntu-latest","windows-latest"]'
  echo "$output" | jq -e '.strategy.matrix.node == ["18","20"]'
  echo "$output" | jq -e '.strategy.matrix.feature == ["basic","full"]'
}

@test "include rules are passed into matrix.include" {
  run "$SCRIPT" "$FIXTURES/with-include.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy.matrix.include | length == 1'
  echo "$output" | jq -e '.strategy.matrix.include[0].os == "windows-latest"'
  echo "$output" | jq -e '.strategy.matrix.include[0].node == "21"'
}

@test "exclude rules are passed into matrix.exclude" {
  run "$SCRIPT" "$FIXTURES/with-exclude.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy.matrix.exclude | length == 1'
  echo "$output" | jq -e '.strategy.matrix.exclude[0].os == "macos-latest"'
}

@test "max-parallel is set on strategy" {
  run "$SCRIPT" "$FIXTURES/with-limits.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy["max-parallel"] == 4'
}

@test "fail-fast is set on strategy" {
  run "$SCRIPT" "$FIXTURES/with-limits.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy["fail-fast"] == false'
}

@test "fail-fast defaults to true when unspecified" {
  run "$SCRIPT" "$FIXTURES/basic-one-dim.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy["fail-fast"] == true'
}

@test "matrix size validation: exceeds max fails with error" {
  # A 3x3x3 config = 27 combos, with max-matrix-size=10 should fail.
  run "$SCRIPT" "$FIXTURES/too-big.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"matrix size"* ]] || [[ "$output" == *"exceeds"* ]]
}

@test "matrix size validation: includes add to count" {
  # Base 2x2=4, add 1 include, max-matrix-size=4 should fail.
  run "$SCRIPT" "$FIXTURES/size-with-include.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceeds"* ]]
}

@test "matrix size validation: excludes subtract from count" {
  # Base 3x3=9, exclude 6, max-matrix-size=3 should pass (9-6=3).
  run "$SCRIPT" "$FIXTURES/size-with-exclude.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.strategy.matrix.os != null'
}

@test "missing config file produces clear error" {
  run "$SCRIPT" "/tmp/nonexistent-config.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such"* ]]
}

@test "invalid JSON produces clear error" {
  tmpfile="$BATS_TEST_TMPDIR/bad.json"
  echo "not json {{{" > "$tmpfile"
  run "$SCRIPT" "$tmpfile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"JSON"* ]] || [[ "$output" == *"parse"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "help flag prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "config with no dimensions is rejected" {
  tmpfile="$BATS_TEST_TMPDIR/empty-dims.json"
  echo '{"dimensions": {}}' > "$tmpfile"
  run "$SCRIPT" "$tmpfile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dimension"* ]] || [[ "$output" == *"empty"* ]]
}

@test "dimension value must be non-empty array" {
  tmpfile="$BATS_TEST_TMPDIR/empty-arr.json"
  echo '{"dimensions": {"os": []}}' > "$tmpfile"
  run "$SCRIPT" "$tmpfile"
  [ "$status" -ne 0 ]
}

@test "output is valid JSON" {
  run "$SCRIPT" "$FIXTURES/basic-multi-dim.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "object"'
}
