#!/usr/bin/env bats

# Integration tests: runs the workflow through act, then asserts on exact output values.

setup_file() {
  export PROJECT_DIR="$BATS_TEST_DIRNAME/.."
  export ACT_RESULT="$PROJECT_DIR/act-result.txt"
  > "$ACT_RESULT"

  export WORK_DIR
  WORK_DIR=$(mktemp -d)
  cp -r "$PROJECT_DIR/matrix-generator.sh" "$WORK_DIR/"
  cp -r "$PROJECT_DIR/test" "$WORK_DIR/"
  cp -r "$PROJECT_DIR/.github" "$WORK_DIR/"
  cp "$PROJECT_DIR/.actrc" "$WORK_DIR/" 2>/dev/null || true

  cd "$WORK_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -q -m "initial"

  echo "========== ACT RUN ==========" >> "$ACT_RESULT"
  act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT"
  export ACT_EXIT=$?
  echo "" >> "$ACT_RESULT"
  echo "========== END ACT RUN ==========" >> "$ACT_RESULT"
}

teardown_file() {
  rm -rf "$WORK_DIR"
}

# Extract lines between two grep-style patterns from act output, stripping prefixes
extract_section() {
  local start_pat="$1"
  local end_pat="$2"
  awk -v s="$start_pat" -v e="$end_pat" '
    $0 ~ s { found=1; next }
    e != "" && $0 ~ e { found=0 }
    found && /\|/ { sub(/^[^|]*\| */, ""); print }
  ' "$ACT_RESULT"
}

# --- Workflow structure tests ---

@test "workflow file exists" {
  [ -f "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml" ]
}

@test "workflow has push trigger" {
  grep -q "push:" "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow has pull_request trigger" {
  grep -q "pull_request:" "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow has workflow_dispatch trigger" {
  grep -q "workflow_dispatch" "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow references matrix-generator.sh" {
  grep -q "matrix-generator.sh" "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "matrix-generator.sh script exists" {
  [ -f "$PROJECT_DIR/matrix-generator.sh" ]
}

@test "test fixtures directory exists" {
  [ -d "$PROJECT_DIR/test/fixtures" ]
}

@test "actionlint passes" {
  run actionlint "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
  [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow has permissions set" {
  grep -q "permissions:" "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

# --- Act execution tests ---

@test "act exited with code 0" {
  [ "$ACT_EXIT" -eq 0 ]
}

@test "act-result.txt exists and is not empty" {
  [ -s "$ACT_RESULT" ]
}

@test "validate job succeeded" {
  grep -q "Job succeeded" "$ACT_RESULT"
}

# --- Exact output value assertions ---

@test "basic matrix has exactly 4 entries" {
  local section
  section=$(extract_section "Basic Matrix" "Matrix with Include")
  local count
  count=$(echo "$section" | grep -c '"os":')
  [ "$count" -eq 4 ]
}

@test "basic matrix contains ubuntu-latest" {
  local section
  section=$(extract_section "Basic Matrix" "Matrix with Include")
  echo "$section" | grep -q '"ubuntu-latest"'
}

@test "basic matrix contains macos-latest" {
  local section
  section=$(extract_section "Basic Matrix" "Matrix with Include")
  echo "$section" | grep -q '"macos-latest"'
}

@test "basic matrix contains version 3.9" {
  local section
  section=$(extract_section "Basic Matrix" "Matrix with Include")
  echo "$section" | grep -q '"3.9"'
}

@test "basic matrix contains version 3.10" {
  local section
  section=$(extract_section "Basic Matrix" "Matrix with Include")
  echo "$section" | grep -q '"3.10"'
}

@test "basic matrix has fail-fast true" {
  local section
  section=$(extract_section "Basic Matrix" "Matrix with Include")
  echo "$section" | grep -q '"fail-fast": true'
}

@test "include demo has exactly 3 entries" {
  local section
  section=$(extract_section "Matrix with Include" "Matrix with Exclude")
  local count
  count=$(echo "$section" | grep -c '"os":')
  [ "$count" -eq 3 ]
}

@test "include demo adds windows-latest" {
  local section
  section=$(extract_section "Matrix with Include" "Matrix with Exclude")
  echo "$section" | grep -q '"windows-latest"'
}

@test "include demo has version 3.11" {
  local section
  section=$(extract_section "Matrix with Include" "Matrix with Exclude")
  echo "$section" | grep -q '"3.11"'
}

@test "include demo has beta feature flag" {
  local section
  section=$(extract_section "Matrix with Include" "Matrix with Exclude")
  echo "$section" | grep -q '"beta"'
}

@test "exclude demo has exactly 3 entries" {
  local section
  section=$(extract_section "Matrix with Exclude" "Matrix with Options")
  local count
  count=$(echo "$section" | grep -c '"os":')
  [ "$count" -eq 3 ]
}

@test "exclude demo: macos-latest appears once (3.9 excluded, 3.10 kept)" {
  local section
  section=$(extract_section "Matrix with Exclude" "Matrix with Options")
  local macos_count
  macos_count=$(echo "$section" | grep -c '"macos-latest"')
  [ "$macos_count" -eq 1 ]
}

@test "options demo shows fail-fast false" {
  local section
  section=$(extract_section "Matrix with Options" "Combined Include")
  echo "$section" | grep -q '"fail-fast": false'
}

@test "options demo shows max-parallel 2" {
  local section
  section=$(extract_section "Matrix with Options" "Combined Include")
  echo "$section" | grep -q '"max-parallel": 2'
}

@test "too-large matrix correctly rejected" {
  local section
  section=$(extract_section "Too Large Matrix" "Empty Axis")
  echo "$section" | grep -q "Correctly rejected oversized matrix"
}

@test "too-large error mentions exceeds maximum" {
  local section
  section=$(extract_section "Too Large Matrix" "Empty Axis")
  echo "$section" | grep -q "exceeds maximum"
}

@test "empty axis correctly rejected" {
  local section
  section=$(extract_section "Empty Axis" "END ACT RUN")
  echo "$section" | grep -q "Correctly rejected empty axis"
}

@test "combined demo has exactly 12 entries" {
  local section
  section=$(extract_section "Combined Include" "Too Large Matrix")
  local count
  count=$(echo "$section" | grep -c '"os":')
  [ "$count" -eq 12 ]
}

@test "combined demo includes windows-latest with 3.12 and nightly" {
  local section
  section=$(extract_section "Combined Include" "Too Large Matrix")
  echo "$section" | grep -q '"windows-latest"'
  echo "$section" | grep -q '"3.12"'
  echo "$section" | grep -q '"nightly"'
}

@test "combined demo has max-parallel 4" {
  local section
  section=$(extract_section "Combined Include" "Too Large Matrix")
  echo "$section" | grep -q '"max-parallel": 4'
}

@test "combined demo has fail-fast true" {
  local section
  section=$(extract_section "Combined Include" "Too Large Matrix")
  echo "$section" | grep -q '"fail-fast": true'
}

@test "bats tests passed in workflow" {
  grep -q "ok 24" "$ACT_RESULT"
}

@test "shellcheck step succeeded" {
  grep -q "Success - Main Run shellcheck" "$ACT_RESULT"
}

@test "syntax validation step succeeded" {
  grep -q "Success - Main Validate script syntax" "$ACT_RESULT"
}
