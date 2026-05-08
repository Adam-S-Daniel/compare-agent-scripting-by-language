#!/bin/bash

# Test harness for running MatrixGenerator tests through GitHub Actions workflow
# All tests run through act in a single execution to ensure CI/CD compatibility

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$SCRIPT_DIR/act-result.txt"

# Initialize result file
> "$RESULT_FILE"

echo "========================================"
echo "Environment Matrix Generator Test Suite"
echo "Running tests through GitHub Actions CI"
echo "========================================"
echo ""

# Step 1: Validate workflow structure
echo "Step 1: Validating workflow structure..."
echo "======== WORKFLOW STRUCTURE VALIDATION ========" >> "$RESULT_FILE"

if [ -f "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml" ]; then
    echo "✓ Workflow file exists" | tee -a "$RESULT_FILE"
else
    echo "✗ Workflow file not found" | tee -a "$RESULT_FILE"
    exit 1
fi

if [ -f "$SCRIPT_DIR/MatrixGenerator.ps1" ]; then
    echo "✓ MatrixGenerator.ps1 exists" | tee -a "$RESULT_FILE"
else
    echo "✗ MatrixGenerator.ps1 not found" | tee -a "$RESULT_FILE"
    exit 1
fi

if [ -f "$SCRIPT_DIR/MatrixGenerator.Tests.ps1" ]; then
    echo "✓ MatrixGenerator.Tests.ps1 exists" | tee -a "$RESULT_FILE"
else
    echo "✗ MatrixGenerator.Tests.ps1 not found" | tee -a "$RESULT_FILE"
    exit 1
fi

# Validate actionlint (before running act, as it's faster)
echo ""
echo "Step 2: Validating workflow YAML with actionlint..."
echo "" >> "$RESULT_FILE"
echo "======== ACTIONLINT VALIDATION ========" >> "$RESULT_FILE"

if actionlint "$SCRIPT_DIR/.github/workflows/environment-matrix-generator.yml" >> "$RESULT_FILE" 2>&1; then
    echo "✓ actionlint validation PASSED" | tee -a "$RESULT_FILE"
else
    echo "✗ actionlint validation FAILED" | tee -a "$RESULT_FILE"
    cat "$RESULT_FILE"
    exit 1
fi

# Step 3: Run tests through act
echo ""
echo "Step 3: Running all tests through GitHub Actions workflow..."
echo "This will take 30-90 seconds..."
echo ""
echo "" >> "$RESULT_FILE"
echo "======== GITHUB ACTIONS WORKFLOW EXECUTION ========" >> "$RESULT_FILE"

cd "$SCRIPT_DIR"

# Run act and capture output
# Use -P to map ubuntu-latest to the local act-ubuntu-pwsh image
# Use --pull=false to use locally cached image
if act push --rm -j test-matrix-generator -P ubuntu-latest=act-ubuntu-pwsh:latest --pull=false 2>&1 | tee -a "$RESULT_FILE"; then
    ACT_EXIT_CODE=0
else
    ACT_EXIT_CODE=$?
fi

echo "" >> "$RESULT_FILE"
echo "======== END WORKFLOW EXECUTION ========" >> "$RESULT_FILE"

# Step 4: Parse results from act output
echo ""
echo "Step 4: Validating test results..."

# Check for job success indicators
if grep -q "Job succeeded" "$RESULT_FILE"; then
    echo "✓ Job execution succeeded" | tee -a "$RESULT_FILE"
else
    echo "⚠ Job success indicator not found - checking exit code"
    if [ $ACT_EXIT_CODE -ne 0 ]; then
        echo "✗ act exited with non-zero status: $ACT_EXIT_CODE" | tee -a "$RESULT_FILE"
        exit 1
    fi
fi

# Verify key test outcomes
echo ""
echo "Step 5: Verifying test outcomes..."
echo "" >> "$RESULT_FILE"
echo "======== TEST RESULT VERIFICATION ========" >> "$RESULT_FILE"

test_count=0
passed_count=0

# Check for Pester test execution
if grep -q "Test Summary:" "$RESULT_FILE"; then
    echo "✓ Pester tests executed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
    test_count=$((test_count + 1))
fi

# Check for matrix generation validation
if grep -q "Matrix generation validated successfully" "$RESULT_FILE"; then
    echo "✓ Matrix generation validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Matrix generation validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for exclude rules validation
if grep -q "Exclude rules validated successfully" "$RESULT_FILE"; then
    echo "✓ Exclude rules validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Exclude rules validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for include rules validation
if grep -q "Include rules validated successfully" "$RESULT_FILE"; then
    echo "✓ Include rules validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Include rules validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for max-parallel validation
if grep -q "Max-parallel configuration validated successfully" "$RESULT_FILE"; then
    echo "✓ Max-parallel validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Max-parallel validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for fail-fast validation
if grep -q "Fail-fast configuration validated successfully" "$RESULT_FILE"; then
    echo "✓ Fail-fast validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Fail-fast validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for matrix size validation
if grep -q "Matrix size validation working correctly" "$RESULT_FILE"; then
    echo "✓ Matrix size validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Matrix size validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for valid matrix size test
if grep -q "Valid matrix size test passed" "$RESULT_FILE"; then
    echo "✓ Valid matrix size test passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ Valid matrix size test failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Check for JSON output validation
if grep -q "JSON output validation successful" "$RESULT_FILE"; then
    echo "✓ JSON output validation passed" | tee -a "$RESULT_FILE"
    passed_count=$((passed_count + 1))
else
    echo "✗ JSON output validation failed or not found" | tee -a "$RESULT_FILE"
fi
test_count=$((test_count + 1))

# Final summary
echo ""
echo "========================================"
echo "Test Execution Summary"
echo "========================================"
echo ""
echo "Test Cases Validated: $test_count"
echo "Passed: $passed_count"
echo "Failed: $((test_count - passed_count))"
echo ""
echo "Full results saved to: $RESULT_FILE"
echo ""

if [ $passed_count -eq $test_count ]; then
    echo "✓ All tests PASSED successfully"
    echo "" >> "$RESULT_FILE"
    echo "======== FINAL RESULT: ALL TESTS PASSED ========" >> "$RESULT_FILE"
    exit 0
else
    echo "✗ Some tests did not pass"
    echo "" >> "$RESULT_FILE"
    echo "======== FINAL RESULT: SOME TESTS FAILED ========" >> "$RESULT_FILE"
    exit 1
fi
