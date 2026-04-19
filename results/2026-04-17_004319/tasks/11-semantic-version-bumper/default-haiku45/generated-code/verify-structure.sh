#!/bin/bash

echo "=== Semantic Version Bumper - Project Verification ==="
echo ""

success_count=0
total_count=0

check_file() {
  local file=$1
  local desc=$2
  total_count=$((total_count + 1))

  if [ -f "$file" ]; then
    echo "✓ $desc ($file)"
    success_count=$((success_count + 1))
  else
    echo "✗ $desc ($file) - NOT FOUND"
  fi
}

check_cmd() {
  local cmd=$1
  local desc=$2
  total_count=$((total_count + 1))

  if command -v $cmd > /dev/null 2>&1; then
    echo "✓ $desc ($cmd available)"
    success_count=$((success_count + 1))
  else
    echo "✗ $desc ($cmd) - NOT FOUND"
  fi
}

echo "1. Core Source Files:"
check_file "src/semantic-version-bumper.js" "Version bumper logic"
check_file "src/file-handler.js" "File I/O operations"
check_file "src/cli.js" "Command-line interface"

echo ""
echo "2. Test Files:"
check_file "tests/semantic-version-bumper.test.js" "Core unit tests"
check_file "tests/integration.test.js" "Integration tests"

echo ""
echo "3. Test Fixtures:"
check_file "tests/fixtures/feature-commit.txt" "Feature commit fixture"
check_file "tests/fixtures/breaking-change.txt" "Breaking change fixture"
check_file "tests/fixtures/patch-only.txt" "Patch only fixture"

echo ""
echo "4. GitHub Actions:"
check_file ".github/workflows/semantic-version-bumper.yml" "GitHub Actions workflow"

echo ""
echo "5. Test Harness:"
check_file "run-act-tests.sh" "Act test harness"

echo ""
echo "6. Configuration:"
check_file "package.json" "NPM configuration"
check_file "README.md" "Project documentation"

echo ""
echo "7. Required Commands:"
check_cmd "node" "Node.js runtime"
check_cmd "npm" "NPM package manager"
check_cmd "act" "Act CI/CD runner"
check_cmd "actionlint" "ActionLint validator"
check_cmd "docker" "Docker container runtime"

echo ""
echo "=== Test Execution Status ==="

if [ -f "act-result.txt" ]; then
  lines=$(wc -l < act-result.txt)
  echo "act-result.txt: $lines lines"
  if grep -q "Test Summary:" act-result.txt; then
    echo "✓ Tests completed!"
    echo ""
    grep "Test Summary:" act-result.txt
  else
    echo "⚠ Tests still running..."
  fi
else
  echo "act-result.txt not yet created"
fi

echo ""
echo "=== Summary ==="
echo "Files/Commands verified: $success_count/$total_count"
if [ $success_count -eq $total_count ]; then
  echo "✓ All files present and commands available"
  exit 0
else
  echo "✗ Some files or commands missing"
  exit 1
fi
