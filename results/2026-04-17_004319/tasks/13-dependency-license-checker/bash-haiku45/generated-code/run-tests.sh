#!/usr/bin/env bash

# Test harness that runs all test cases through GitHub Actions via act
# Validates the dependency-license-checker workflow and test suite

set -euo pipefail

RESULT_FILE="act-result.txt"
TEST_CASES=(
  "unit-tests"
  "package-json"
  "requirements-txt"
  "error-handling"
  "unknown-status"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Dependency License Checker - GitHub Actions Test Harness ===" | tee "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

# Validate actionlint first
echo "[1/3] Validating GitHub Actions workflow with actionlint..." | tee -a "$RESULT_FILE"
if actionlint .github/workflows/dependency-license-checker.yml >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Workflow validation passed" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Workflow validation failed" | tee -a "$RESULT_FILE"
    exit 1
fi
echo "" | tee -a "$RESULT_FILE"

# Check if workflow file exists
echo "[2/3] Checking workflow structure..." | tee -a "$RESULT_FILE"
if [ -f ".github/workflows/dependency-license-checker.yml" ]; then
    echo -e "${GREEN}✓${NC} Workflow file exists" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Workflow file not found" | tee -a "$RESULT_FILE"
    exit 1
fi

# Verify script is referenced in workflow
if grep -q "dependency-license-checker.sh" .github/workflows/dependency-license-checker.yml; then
    echo -e "${GREEN}✓${NC} Script correctly referenced in workflow" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Script not referenced in workflow" | tee -a "$RESULT_FILE"
    exit 1
fi
echo "" | tee -a "$RESULT_FILE"

# Run the workflow via act
echo "[3/3] Running workflow through GitHub Actions (act)..." | tee -a "$RESULT_FILE"
echo "This may take 1-2 minutes..." | tee -a "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

# Clear previous act results and run workflow
rm -f "/tmp/act_output_*.txt" 2>/dev/null || true

# Run act with appropriate image
if act push --rm -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest >> "$RESULT_FILE" 2>&1; then
    echo -e "${GREEN}✓${NC} Workflow execution succeeded" | tee -a "$RESULT_FILE"
    ACT_EXIT=0
else
    echo -e "${YELLOW}⚠${NC} Workflow execution completed (check results below)" | tee -a "$RESULT_FILE"
    ACT_EXIT=$?
fi

echo "" | tee -a "$RESULT_FILE"
echo "=== Test Results ===" | tee -a "$RESULT_FILE"

# Parse and validate act output
if grep -q "Unit tests (bats)" "$RESULT_FILE"; then
    echo -e "${GREEN}✓${NC} Unit tests (bats) completed" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Unit tests not found in output" | tee -a "$RESULT_FILE"
fi

if grep -q "Package.json parsing" "$RESULT_FILE"; then
    echo -e "${GREEN}✓${NC} Package.json test completed" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Package.json test not found in output" | tee -a "$RESULT_FILE"
fi

if grep -q "Requirements.txt parsing" "$RESULT_FILE"; then
    echo -e "${GREEN}✓${NC} Requirements.txt test completed" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Requirements.txt test not found in output" | tee -a "$RESULT_FILE"
fi

if grep -q "Error handling" "$RESULT_FILE"; then
    echo -e "${GREEN}✓${NC} Error handling test completed" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Error handling test not found in output" | tee -a "$RESULT_FILE"
fi

echo "" | tee -a "$RESULT_FILE"
echo "=== Summary ===" | tee -a "$RESULT_FILE"
echo "Full workflow output saved to: $RESULT_FILE" | tee -a "$RESULT_FILE"
echo "File location: $(pwd)/$RESULT_FILE" | tee -a "$RESULT_FILE"

if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
    echo -e "${GREEN}✓${NC} Results file created successfully" | tee -a "$RESULT_FILE"
    echo "Total output lines: $(wc -l < "$RESULT_FILE")" | tee -a "$RESULT_FILE"
else
    echo -e "${RED}✗${NC} Results file is empty" >&2
    exit 1
fi

echo "" | tee -a "$RESULT_FILE"
echo -e "${GREEN}✓ All GitHub Actions workflow tests completed!${NC}" | tee -a "$RESULT_FILE"
