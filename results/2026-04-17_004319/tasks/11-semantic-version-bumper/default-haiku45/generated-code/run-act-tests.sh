#!/bin/bash

# Test harness for GitHub Actions workflow via act
# Runs semantic-version-bumper workflow with different test fixtures
# Validates output and version bumps

set -e

RESULT_FILE="act-result.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clear result file
> "$RESULT_FILE"

echo "Running semantic version bumper tests through act..."
echo "======================================================" | tee -a "$RESULT_FILE"

# Test cases: (fixture_name, expected_version)
declare -a TESTS=(
  "feature-commit,1.1.0"
  "breaking-change,2.0.0"
  "patch-only,1.0.1"
)

# Reset package.json version for each test
reset_package_json() {
  cat > package.json <<'EOF'
{
  "name": "semantic-version-bumper",
  "version": "1.0.0",
  "description": "Semantic version bumper based on conventional commits",
  "main": "src/semantic-version-bumper.js",
  "scripts": {
    "test": "jest",
    "bump": "node src/cli.js"
  },
  "devDependencies": {
    "jest": "^29.5.0"
  },
  "keywords": [
    "semantic-versioning",
    "conventional-commits"
  ]
}
EOF
}

test_count=0
pass_count=0

for test_case in "${TESTS[@]}"; do
  IFS=',' read -r fixture expected_version <<< "$test_case"
  test_count=$((test_count + 1))

  echo "" | tee -a "$RESULT_FILE"
  echo "=== Test $test_count: $fixture ===" | tee -a "$RESULT_FILE"
  echo "Expected version: $expected_version" | tee -a "$RESULT_FILE"

  # Reset package.json to 1.0.0
  reset_package_json

  # Run act with this test fixture
  echo "Running: act push --input test_fixture=$fixture --rm" | tee -a "$RESULT_FILE"

  if act push --input "test_fixture=$fixture" --rm 2>&1 | tee -a "$RESULT_FILE"; then
    act_exit_code=$?
  else
    act_exit_code=$?
  fi

  # Check that act succeeded
  if [ $act_exit_code -eq 0 ]; then
    echo "✓ act executed successfully (exit code 0)" | tee -a "$RESULT_FILE"
  else
    echo "✗ act failed with exit code $act_exit_code" | tee -a "$RESULT_FILE"
    continue
  fi

  # Verify the version was bumped correctly
  actual_version=$(jq -r '.version' package.json 2>/dev/null || echo "ERROR")

  echo "Actual version in package.json: $actual_version" | tee -a "$RESULT_FILE"

  if [ "$actual_version" = "$expected_version" ]; then
    echo "✓ Version bump correct: $actual_version" | tee -a "$RESULT_FILE"
    pass_count=$((pass_count + 1))
  else
    echo "✗ Version mismatch! Expected $expected_version, got $actual_version" | tee -a "$RESULT_FILE"
  fi

  echo "--- End Test $test_count ---" | tee -a "$RESULT_FILE"
done

echo "" | tee -a "$RESULT_FILE"
echo "======================================================" | tee -a "$RESULT_FILE"
echo "Test Summary: $pass_count/$test_count passed" | tee -a "$RESULT_FILE"
echo "Results saved to: $RESULT_FILE" | tee -a "$RESULT_FILE"

# Exit with appropriate code
if [ $pass_count -eq $test_count ]; then
  echo "✓ All tests passed!" | tee -a "$RESULT_FILE"
  exit 0
else
  echo "✗ Some tests failed" | tee -a "$RESULT_FILE"
  exit 1
fi
