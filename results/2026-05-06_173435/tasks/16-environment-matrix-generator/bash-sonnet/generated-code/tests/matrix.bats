#!/usr/bin/env bats
# Tests for generate-matrix.sh — Environment Matrix Generator
# TDD: tests written before implementation (red phase first).

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_DIR="$(dirname "$TEST_DIR")"
  SCRIPT="$PROJECT_DIR/generate-matrix.sh"
  FIXTURES_DIR="$TEST_DIR/fixtures"
}

# ── Basic existence / CLI behaviour ─────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "fails with no arguments" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "fails with nonexistent config file" {
  run "$SCRIPT" /nonexistent/config.json
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Ee]rror ]]
}

# ── Cartesian product generation ─────────────────────────────────────────────

@test "basic 2x2 matrix generates 4 combinations" {
  run "$SCRIPT" "$FIXTURES_DIR/basic.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 4 ]
}

@test "basic matrix contains correct os values" {
  run "$SCRIPT" "$FIXTURES_DIR/basic.json"
  [ "$status" -eq 0 ]
  ubuntu=$(echo "$output" | jq '[.matrix.include[] | select(.os=="ubuntu-latest")] | length')
  windows=$(echo "$output" | jq '[.matrix.include[] | select(.os=="windows-latest")] | length')
  [ "$ubuntu" -eq 2 ]
  [ "$windows" -eq 2 ]
}

@test "basic matrix contains correct python versions" {
  run "$SCRIPT" "$FIXTURES_DIR/basic.json"
  [ "$status" -eq 0 ]
  v39=$(echo "$output" | jq '[.matrix.include[] | select(.python=="3.9")] | length')
  v310=$(echo "$output" | jq '[.matrix.include[] | select(.python=="3.10")] | length')
  [ "$v39" -eq 2 ]
  [ "$v310" -eq 2 ]
}

@test "3-dimensional matrix generates correct count (2x3x2=12)" {
  run "$SCRIPT" "$FIXTURES_DIR/three-dimensions.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 12 ]
}

@test "feature flags appear as boolean values in matrix entries" {
  run "$SCRIPT" "$FIXTURES_DIR/with-flags.json"
  [ "$status" -eq 0 ]
  true_count=$(echo "$output" | jq '[.matrix.include[] | select(.experimental==true)] | length')
  false_count=$(echo "$output" | jq '[.matrix.include[] | select(.experimental==false)] | length')
  [ "$true_count" -gt 0 ]
  [ "$false_count" -gt 0 ]
}

# ── Include rules ────────────────────────────────────────────────────────────

@test "include rule appends extra combination (4+1=5)" {
  run "$SCRIPT" "$FIXTURES_DIR/with-includes.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 5 ]
}

@test "include rule entry appears verbatim in matrix" {
  run "$SCRIPT" "$FIXTURES_DIR/with-includes.json"
  [ "$status" -eq 0 ]
  bleeding=$(echo "$output" | jq '[.matrix.include[] | select(.extra=="bleeding-edge")] | length')
  [ "$bleeding" -eq 1 ]
}

# ── Exclude rules ────────────────────────────────────────────────────────────

@test "exclude rule removes exactly one matching combination (4-1=3)" {
  run "$SCRIPT" "$FIXTURES_DIR/with-excludes.json"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.matrix.include | length')
  [ "$count" -eq 3 ]
}

@test "excluded combination is absent from matrix" {
  run "$SCRIPT" "$FIXTURES_DIR/with-excludes.json"
  [ "$status" -eq 0 ]
  # windows-latest + python 3.9 should be gone
  excluded=$(echo "$output" | jq '[.matrix.include[] | select(.os=="windows-latest" and .python=="3.9")] | length')
  [ "$excluded" -eq 0 ]
}

# ── max-parallel / fail-fast ──────────────────────────────────────────────────

@test "max-parallel is propagated to output" {
  run "$SCRIPT" "$FIXTURES_DIR/with-settings.json"
  [ "$status" -eq 0 ]
  mp=$(echo "$output" | jq '.["max-parallel"]')
  [ "$mp" -eq 4 ]
}

@test "fail-fast is propagated to output" {
  run "$SCRIPT" "$FIXTURES_DIR/with-settings.json"
  [ "$status" -eq 0 ]
  ff=$(echo "$output" | jq '.["fail-fast"]')
  [ "$ff" = "false" ]
}

@test "output has no max-parallel when not configured" {
  run "$SCRIPT" "$FIXTURES_DIR/basic.json"
  [ "$status" -eq 0 ]
  mp=$(echo "$output" | jq 'has("max-parallel")')
  [ "$mp" = "false" ]
}

# ── Max size validation ───────────────────────────────────────────────────────

@test "matrix exceeding max_size exits with error" {
  run "$SCRIPT" "$FIXTURES_DIR/too-large.json"
  [ "$status" -ne 0 ]
}

@test "max_size error message mentions exceeds" {
  run "$SCRIPT" "$FIXTURES_DIR/too-large.json"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Ee]xceed ]] || [[ "$output" =~ [Ee]rror ]]
}

# ── Workflow structure tests ──────────────────────────────────────────────────

@test "workflow file exists" {
  [ -f "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml" ]
}

@test "workflow references generate-matrix.sh" {
  grep -q "generate-matrix.sh" \
    "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow has push trigger" {
  grep -q "push:" \
    "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "actionlint passes on workflow file" {
  run actionlint \
    "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
  [ "$status" -eq 0 ]
}
