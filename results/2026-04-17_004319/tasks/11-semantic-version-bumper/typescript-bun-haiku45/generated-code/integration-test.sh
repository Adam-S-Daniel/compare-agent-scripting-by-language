#!/bin/bash
# Integration test runner using act to validate the GitHub Actions workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_FILE="act-result.txt"
TEST_COUNT=0
PASS_COUNT=0

# Cleanup function
cleanup_test_dir() {
    if [ -d "$1" ] && [ -n "$1" ]; then
        rm -rf "$1" 2>/dev/null || true
    fi
}

# Test case function
run_test_case() {
    local test_name="$1"
    local commits_file="$2"
    local initial_version="$3"
    local expected_version="$4"

    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    trap "cleanup_test_dir '$temp_dir'" RETURN

    # Copy project files
    cp -r "$SCRIPT_DIR"/.github "$temp_dir/" || true
    cp -r "$SCRIPT_DIR"/src "$temp_dir/" || true
    cp -r "$SCRIPT_DIR"/fixtures "$temp_dir/" || true
    cp "$SCRIPT_DIR"/package.json "$temp_dir/" || true
    cp "$SCRIPT_DIR"/tsconfig.json "$temp_dir/" || true
    cp "$SCRIPT_DIR"/bun.lockb "$temp_dir/" 2>/dev/null || true
    cp "$SCRIPT_DIR"/*.test.ts "$temp_dir/" 2>/dev/null || true

    # Initialize git repo
    cd "$temp_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Update initial version in package.json
    jq ".version = \"$initial_version\"" package.json > package.json.tmp
    mv package.json.tmp package.json

    # Add all files and create initial commit
    git add .
    git commit -q -m "Initial commit"

    # Add commits from fixture
    if [ -f "$commits_file" ]; then
        while IFS= read -r commit; do
            if [ -n "$(echo "$commit" | tr -d ' ')" ] && ! echo "$commit" | grep -q "^BREAKING"; then
                git commit -q --allow-empty -m "$commit"
            fi
        done < "$commits_file"
    fi

    # Run act workflow
    local output=$(act push --rm 2>&1 || true)

    # Check results
    local pass=0
    if echo "$output" | grep -q "Job succeeded"; then
        if echo "$output" | grep -q "$expected_version"; then
            pass=1
        fi
    fi

    # Record results
    {
        echo ""
        echo "========================================================================"
        echo "Test: $test_name"
        echo "Initial Version: $initial_version"
        echo "Expected Version: $expected_version"
        echo "Result: $([ $pass -eq 1 ] && echo "✓ PASS" || echo "✗ FAIL")"
        echo "========================================================================"
        echo "$output"
    } >> "$RESULTS_FILE"

    if [ $pass -eq 1 ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
}

# Initialize results file
: > "$RESULTS_FILE"

echo "Running GitHub Actions workflow integration tests..."
echo ""

# Run test cases
run_test_case \
    "Patch version bump (fix commits)" \
    "$SCRIPT_DIR/fixtures/commits-patch.txt" \
    "1.0.0" \
    "1.0.1"

run_test_case \
    "Minor version bump (feat commits)" \
    "$SCRIPT_DIR/fixtures/commits-minor.txt" \
    "1.0.0" \
    "1.1.0"

run_test_case \
    "Major version bump (breaking commits)" \
    "$SCRIPT_DIR/fixtures/commits-major.txt" \
    "1.0.0" \
    "2.0.0"

# Summary
echo ""
echo "========================================================================"
echo "Test Summary: $PASS_COUNT/$TEST_COUNT passed"
echo "Results saved to: $RESULTS_FILE"
echo "========================================================================"

if [ $PASS_COUNT -eq $TEST_COUNT ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
