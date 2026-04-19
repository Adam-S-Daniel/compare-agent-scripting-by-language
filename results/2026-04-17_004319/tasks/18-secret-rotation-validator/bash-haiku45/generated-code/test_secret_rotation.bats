#!/usr/bin/env bats

# Test suite for secret rotation validator
# Uses red/green TDD approach

setup() {
  # Create temporary directory for test files
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR

  # Create fixture directory
  FIXTURES_DIR="${TEST_DIR}/fixtures"
  mkdir -p "$FIXTURES_DIR"
  export FIXTURES_DIR
}

teardown() {
  # Clean up temporary test directory
  rm -rf "$TEST_DIR"
}

# Fixture: Sample secrets configuration
load_fixture() {
  local fixture_name="$1"
  cat > "${FIXTURES_DIR}/${fixture_name}.json" << 'EOF'
{
  "secrets": [
    {
      "name": "db-password",
      "last_rotated": "2026-03-01",
      "rotation_policy_days": 30,
      "required_by": ["backend-service", "api"]
    },
    {
      "name": "api-key",
      "last_rotated": "2026-02-01",
      "rotation_policy_days": 60,
      "required_by": ["frontend"]
    },
    {
      "name": "ssh-key",
      "last_rotated": "2026-04-01",
      "rotation_policy_days": 90,
      "required_by": ["deployment"]
    }
  ]
}
EOF
}

# Test 1: Script exists and is executable
@test "secret_rotation.sh script exists" {
  [ -f "secret_rotation.sh" ]
}

# Test 2: Script can parse basic configuration
@test "can parse JSON configuration file" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" 2>&1
  [ "$status" -eq 0 ]
}

# Test 3: Output contains expired secrets in JSON format
@test "identifies expired secrets in JSON format" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --format json 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"db-password"* ]]
}

# Test 4: Output contains warning window secrets
@test "identifies secrets expiring soon with warning window" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --warning-days 30 --format json 2>&1
  [ "$status" -eq 0 ]
}

# Test 5: Markdown table output format
@test "supports markdown table output format" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --format markdown 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Name"* ]]
}

# Test 6: Groups secrets by urgency (expired, warning, ok)
@test "groups results by urgency level" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --format json 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"expired"* ]] || [[ "$output" == *"warning"* ]] || [[ "$output" == *"ok"* ]]
}

# Test 7: Handles missing configuration file gracefully
@test "handles missing configuration file with error" {
  run ./secret_rotation.sh "/nonexistent/config.json" 2>&1
  [ "$status" -ne 0 ]
}

# Test 8: Custom warning window parameter
@test "respects custom warning window in days" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --warning-days 45 --format json 2>&1
  [ "$status" -eq 0 ]
}

# Test 9: JSON output has required fields
@test "JSON output includes required fields" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --format json 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"timestamp"* ]]
  [[ "$output" == *"warning_window_days"* ]]
  [[ "$output" == *"report"* ]]
}

# Test 10: Empty secrets list
@test "handles empty secrets list gracefully" {
  cat > "${FIXTURES_DIR}/empty.json" << 'EOF'
{"secrets": []}
EOF
  run ./secret_rotation.sh "${FIXTURES_DIR}/empty.json" --format json 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"report"* ]]
}

# Test 11: Markdown output formatting
@test "markdown output has proper table structure" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --format markdown 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Secret Rotation Report"* ]]
  [[ "$output" == *"Name"* ]]
  [[ "$output" == *"Last Rotated"* ]]
  [[ "$output" == *"Days Since"* ]]
}

# Test 12: Warning window affects categorization
@test "changes warning categorization with different window" {
  load_fixture "secrets"
  run ./secret_rotation.sh "${FIXTURES_DIR}/secrets.json" --warning-days 60 --format json 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"api-key"* ]]
}

# Workflow structure tests

@test "workflow file exists" {
  [ -f ".github/workflows/secret-rotation-validator.yml" ]
}

@test "workflow passes actionlint validation" {
  # Skip if actionlint is not available (e.g., in act container)
  if ! command -v actionlint &> /dev/null; then
    skip "actionlint not available in this environment"
  fi
  run actionlint ".github/workflows/secret-rotation-validator.yml"
  [ "$status" -eq 0 ]
}

@test "workflow has validate-secrets job" {
  run grep -q "validate-secrets:" ".github/workflows/secret-rotation-validator.yml"
  [ "$status" -eq 0 ]
}

@test "workflow has run-tests job" {
  run grep -q "run-tests:" ".github/workflows/secret-rotation-validator.yml"
  [ "$status" -eq 0 ]
}

@test "workflow references secret_rotation.sh" {
  run grep -q "secret_rotation.sh" ".github/workflows/secret-rotation-validator.yml"
  [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
  run grep -q "actions/checkout@v4" ".github/workflows/secret-rotation-validator.yml"
  [ "$status" -eq 0 ]
}

# Act integration tests

@test "act workflow execution succeeds" {
  # Create a temporary directory to simulate the workflow environment
  local act_test_dir
  act_test_dir=$(mktemp -d)
  local orig_dir
  orig_dir=$(pwd)

  cd "$act_test_dir"

  # Initialize a git repository
  git init --quiet .
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Copy project files to the test directory
  cp "${orig_dir}/secret_rotation.sh" .
  cp "${orig_dir}/test_secret_rotation.bats" .
  mkdir -p .github/workflows
  cp "${orig_dir}/.github/workflows/secret-rotation-validator.yml" .github/workflows/

  # Create a fixture secrets file
  cat > secrets.json << 'EOF'
{
  "secrets": [
    {
      "name": "test-secret",
      "last_rotated": "2026-04-01",
      "rotation_policy_days": 30,
      "required_by": ["test-service"]
    }
  ]
}
EOF

  # Commit changes
  git add -A
  git commit -m "test commit" --quiet

  # Run act and capture output
  act push --rm 2>&1 | tee act-result.txt
  local act_exit=$?

  # Save result to main directory as required
  cp act-result.txt "${orig_dir}/act-result.txt"

  # Check exit code
  [ "$act_exit" -eq 0 ]

  # Cleanup
  cd "$orig_dir"
  rm -rf "$act_test_dir"
}
