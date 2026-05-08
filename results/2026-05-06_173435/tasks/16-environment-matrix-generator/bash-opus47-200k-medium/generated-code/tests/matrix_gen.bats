#!/usr/bin/env bats
# Tests for matrix_gen.sh - environment matrix generator
# All tests written red/green TDD style.

setup() {
  ROOT="${BATS_TEST_DIRNAME}/.."
  SCRIPT="${ROOT}/matrix_gen.sh"
  chmod +x "$SCRIPT" 2>/dev/null || true
  FIX="${ROOT}/tests/fixtures"
}

# --- Basic Cartesian product --------------------------------------------------

@test "simple 2x2 matrix produces 4 combinations" {
  run bash "$SCRIPT" "$FIX/simple.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 4 ]
}

@test "simple matrix contains expected combination" {
  run bash "$SCRIPT" "$FIX/simple.json"
  [ "$status" -eq 0 ]
  found=$(echo "$output" | jq '[.matrix.include[] | select(.os=="ubuntu-latest" and .node=="20")] | length')
  [ "$found" -eq 1 ]
}

# --- Exclude rules -----------------------------------------------------------

@test "exclude rule drops matching combination" {
  run bash "$SCRIPT" "$FIX/with_exclude.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 3 ]
  excluded=$(echo "$output" | jq '[.matrix.include[] | select(.os=="macos-latest" and .node=="18")] | length')
  [ "$excluded" -eq 0 ]
}

# --- Include rules -----------------------------------------------------------

@test "include rule appends extra combination" {
  run bash "$SCRIPT" "$FIX/with_include.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 5 ]
  extra=$(echo "$output" | jq '[.matrix.include[] | select(.experimental==true)] | length')
  [ "$extra" -eq 1 ]
}

# --- max-parallel and fail-fast ---------------------------------------------

@test "max-parallel and fail-fast pass through" {
  run bash "$SCRIPT" "$FIX/with_options.json"
  [ "$status" -eq 0 ]
  mp=$(echo "$output" | jq '."max-parallel"')
  ff=$(echo "$output" | jq '."fail-fast"')
  [ "$mp" = "4" ]
  [ "$ff" = "false" ]
}

# --- max-size validation ------------------------------------------------------

@test "matrix exceeding max-size returns error" {
  run bash "$SCRIPT" "$FIX/too_big.json"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "exceeds max-size"
}

# --- Error handling ----------------------------------------------------------

@test "missing config file returns error" {
  run bash "$SCRIPT" "/nonexistent/file.json"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not found"
}

@test "invalid JSON returns error" {
  tmp=$(mktemp)
  echo "not json" > "$tmp"
  run bash "$SCRIPT" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "invalid"
}

@test "no dimensions returns error" {
  tmp=$(mktemp)
  echo '{"max-parallel": 2}' > "$tmp"
  run bash "$SCRIPT" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
}

# --- Three-dimensional matrix -----------------------------------------------

@test "three-dimensional matrix yields product" {
  run bash "$SCRIPT" "$FIX/three_dim.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 8 ]
}

# --- Default fail-fast behavior ---------------------------------------------

@test "fail-fast defaults to true when not specified" {
  run bash "$SCRIPT" "$FIX/simple.json"
  [ "$status" -eq 0 ]
  ff=$(echo "$output" | jq '."fail-fast"')
  [ "$ff" = "true" ]
}
