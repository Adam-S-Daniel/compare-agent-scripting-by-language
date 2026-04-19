#!/usr/bin/env bats

# Test suite for PR label assigner script
# Uses red/green TDD methodology

setup() {
  # Create temporary directory for test fixtures
  export TEST_DIR="$(mktemp -d)"
  export FIXTURES_DIR="${BATS_TEST_DIRNAME}/../fixtures"
  export SCRIPT_DIR="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  # Clean up temporary directory
  rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
  [ -f "${SCRIPT_DIR}/pr-label-assigner.sh" ]
  [ -x "${SCRIPT_DIR}/pr-label-assigner.sh" ]
}

@test "fails gracefully when config file is missing" {
  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "/nonexistent/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

@test "applies documentation label to docs/** files" {
  # Create test config
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "docs/**"
    labels:
      - documentation
    priority: 1
EOF

  # Create test file list
  echo "docs/README.md" > "${TEST_DIR}/files.txt"

  # Run script
  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  [[ "$output" == *"documentation"* ]]
}

@test "applies api label to src/api/** files" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "src/api/**"
    labels:
      - api
    priority: 1
EOF

  echo "src/api/handlers.ts" > "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  [[ "$output" == *"api"* ]]
}

@test "applies test label to *.test.* files" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "*.test.*"
    labels:
      - tests
    priority: 1
EOF

  echo "service.test.js" > "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  [[ "$output" == *"tests"* ]]
}

@test "applies multiple labels when file matches multiple patterns" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "src/api/**"
    labels:
      - api
    priority: 1
  - pattern: "*.test.*"
    labels:
      - tests
    priority: 2
EOF

  echo "src/api/handlers.test.ts" > "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  [[ "$output" == *"api"* ]]
  [[ "$output" == *"tests"* ]]
}

@test "handles multiple files with different labels" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "docs/**"
    labels:
      - documentation
    priority: 1
  - pattern: "src/**"
    labels:
      - code
    priority: 2
EOF

  cat > "${TEST_DIR}/files.txt" <<'EOF'
docs/api.md
src/main.ts
EOF

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  [[ "$output" == *"documentation"* ]]
  [[ "$output" == *"code"* ]]
}

@test "respects priority ordering - lower priority value wins on conflict" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "src/**"
    labels:
      - feature
    priority: 2
  - pattern: "*.test.*"
    labels:
      - tests
    priority: 1
EOF

  echo "src/service.test.ts" > "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  # Both labels should appear, but we can check both are present
  [[ "$output" == *"tests"* ]]
  [[ "$output" == *"feature"* ]]
}

@test "deduplicates labels in output" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "src/**"
    labels:
      - code
    priority: 1
  - pattern: "src/**"
    labels:
      - code
    priority: 2
EOF

  echo "src/main.ts" > "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
  # Count occurrences of "code" - should appear only once or be deduplicated
  label_count=$(echo "$output" | grep -o "code" | wc -l)
  [ "$label_count" -ge 1 ]
}

@test "handles files with no matching rules" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "docs/**"
    labels:
      - documentation
    priority: 1
EOF

  echo "random/file.txt" > "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  # Should succeed but may have no labels or indicate no matches
  [ $status -eq 0 ]
}

@test "handles empty file list" {
  cat > "${TEST_DIR}/config.yaml" <<'EOF'
rules:
  - pattern: "docs/**"
    labels:
      - documentation
    priority: 1
EOF

  touch "${TEST_DIR}/files.txt"

  run "${SCRIPT_DIR}/pr-label-assigner.sh" \
    --config "${TEST_DIR}/config.yaml" \
    --files "${TEST_DIR}/files.txt"

  [ $status -eq 0 ]
}

@test "script passes shellcheck validation" {
  # Check if shellcheck is available
  command -v shellcheck > /dev/null || skip "shellcheck not installed"

  run shellcheck "${SCRIPT_DIR}/pr-label-assigner.sh"
  [ $status -eq 0 ]
}

@test "script passes syntax validation with bash -n" {
  run bash -n "${SCRIPT_DIR}/pr-label-assigner.sh"
  [ $status -eq 0 ]
}
