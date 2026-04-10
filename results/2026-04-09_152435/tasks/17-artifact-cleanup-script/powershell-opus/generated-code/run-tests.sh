#!/usr/bin/env bash
# Test harness: runs the workflow through act and validates output.
# Produces act-result.txt with all output.
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$WORK_DIR/act-result.txt"

# Clear previous results
> "$RESULT_FILE"

echo "=== Setting up temp git repo for act ===" | tee -a "$RESULT_FILE"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Copy project files into temp repo
cp -r "$WORK_DIR/ArtifactCleanup.psm1" "$TEMP_DIR/"
cp -r "$WORK_DIR/ArtifactCleanup.Tests.ps1" "$TEMP_DIR/"
cp -r "$WORK_DIR/fixtures" "$TEMP_DIR/"
cp -r "$WORK_DIR/.github" "$TEMP_DIR/"
if [ -f "$WORK_DIR/.actrc" ]; then
  cp "$WORK_DIR/.actrc" "$TEMP_DIR/"
fi

cd "$TEMP_DIR"
git init -b main
git add -A
git -c user.name="test" -c user.email="test@test.com" commit -m "initial"

echo "" | tee -a "$RESULT_FILE"
echo "=== Running act push ===" | tee -a "$RESULT_FILE"

# Run act and capture output (allow non-zero exit for diagnostics)
ACT_EXIT=0
act push --rm --pull=false 2>&1 | tee -a "$RESULT_FILE" || ACT_EXIT=$?

echo "" >> "$RESULT_FILE"
echo "=== ACT EXIT CODE: $ACT_EXIT ===" >> "$RESULT_FILE"

cd "$WORK_DIR"

echo ""
echo "=== Validating results ==="

ERRORS=0

# 1. Assert act exited with code 0
if [ "$ACT_EXIT" -ne 0 ]; then
  echo "FAIL: act exited with code $ACT_EXIT"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: act exited with code 0"
fi

# 2. Assert job succeeded
if grep -q "Job succeeded" "$RESULT_FILE"; then
  echo "PASS: Found 'Job succeeded' in output"
else
  echo "FAIL: 'Job succeeded' not found in output"
  ERRORS=$((ERRORS + 1))
fi

# 3. Validate Pester tests passed
if grep -q "Tests Passed" "$RESULT_FILE"; then
  echo "PASS: Pester tests passed"
else
  echo "FAIL: Pester test pass marker not found"
  ERRORS=$((ERRORS + 1))
fi

# 4. Validate age-policy fixture exact values
echo "--- Checking age-policy fixture ---"
if grep -q "FIXTURE:age-policy" "$RESULT_FILE"; then
  echo "PASS: age-policy fixture ran"
else
  echo "FAIL: age-policy fixture not found"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "DELETE_COUNT:1" "$RESULT_FILE"; then
  echo "PASS: age-policy DELETE_COUNT=1"
else
  echo "FAIL: age-policy DELETE_COUNT != 1"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "RETAIN_COUNT:1" "$RESULT_FILE"; then
  echo "PASS: age-policy RETAIN_COUNT=1"
else
  echo "FAIL: age-policy RETAIN_COUNT != 1"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "SPACE_RECLAIMED:500" "$RESULT_FILE"; then
  echo "PASS: age-policy SPACE_RECLAIMED=500"
else
  echo "FAIL: age-policy SPACE_RECLAIMED != 500"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "DELETED:old-artifact" "$RESULT_FILE"; then
  echo "PASS: age-policy deleted old-artifact"
else
  echo "FAIL: age-policy did not delete old-artifact"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "RETAINED:recent-artifact" "$RESULT_FILE"; then
  echo "PASS: age-policy retained recent-artifact"
else
  echo "FAIL: age-policy did not retain recent-artifact"
  ERRORS=$((ERRORS + 1))
fi

# 5. Validate keep-latest fixture exact values
echo "--- Checking keep-latest fixture ---"
if grep -q "FIXTURE:keep-latest" "$RESULT_FILE"; then
  echo "PASS: keep-latest fixture ran"
else
  echo "FAIL: keep-latest fixture not found"
  ERRORS=$((ERRORS + 1))
fi
# keep-latest-2 for wf-100: keeps build-v3 and build-v2, deletes build-v1. wf-200 has 1 artifact (kept).
# DELETE_COUNT:1, RETAIN_COUNT:3, SPACE_RECLAIMED:100
if grep -q "DELETED:build-v1" "$RESULT_FILE"; then
  echo "PASS: keep-latest deleted build-v1"
else
  echo "FAIL: keep-latest did not delete build-v1"
  ERRORS=$((ERRORS + 1))
fi

# 6. Validate combined-policy fixture exact values
echo "--- Checking combined-policy fixture ---"
if grep -q "FIXTURE:combined-policy" "$RESULT_FILE"; then
  echo "PASS: combined-policy fixture ran"
else
  echo "FAIL: combined-policy fixture not found"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "DELETE_COUNT:3" "$RESULT_FILE"; then
  echo "PASS: combined-policy DELETE_COUNT=3"
else
  echo "FAIL: combined-policy DELETE_COUNT != 3"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "RETAIN_COUNT:2" "$RESULT_FILE"; then
  echo "PASS: combined-policy RETAIN_COUNT=2"
else
  echo "FAIL: combined-policy RETAIN_COUNT != 2"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "SPACE_RECLAIMED:600" "$RESULT_FILE"; then
  echo "PASS: combined-policy SPACE_RECLAIMED=600"
else
  echo "FAIL: combined-policy SPACE_RECLAIMED != 600"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "DELETED:a1" "$RESULT_FILE" && grep -q "DELETED:a2" "$RESULT_FILE" && grep -q "DELETED:a4" "$RESULT_FILE"; then
  echo "PASS: combined-policy deleted a1, a2, a4"
else
  echo "FAIL: combined-policy did not delete expected artifacts"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "RETAINED:a3" "$RESULT_FILE" && grep -q "RETAINED:a5" "$RESULT_FILE"; then
  echo "PASS: combined-policy retained a3, a5"
else
  echo "FAIL: combined-policy did not retain expected artifacts"
  ERRORS=$((ERRORS + 1))
fi

# 7. Validate workflow structure
echo "--- Checking workflow structure ---"
WORKFLOW="$WORK_DIR/.github/workflows/artifact-cleanup-script.yml"
if [ -f "$WORKFLOW" ]; then
  echo "PASS: workflow file exists"
else
  echo "FAIL: workflow file missing"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "actions/checkout@v4" "$WORKFLOW"; then
  echo "PASS: workflow uses actions/checkout@v4"
else
  echo "FAIL: workflow missing actions/checkout@v4"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "shell: pwsh" "$WORKFLOW"; then
  echo "PASS: workflow uses shell: pwsh"
else
  echo "FAIL: workflow missing shell: pwsh"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "push:" "$WORKFLOW"; then
  echo "PASS: workflow has push trigger"
else
  echo "FAIL: workflow missing push trigger"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "workflow_dispatch:" "$WORKFLOW"; then
  echo "PASS: workflow has workflow_dispatch trigger"
else
  echo "FAIL: workflow missing workflow_dispatch trigger"
  ERRORS=$((ERRORS + 1))
fi
# Verify script files referenced in workflow exist
if grep -q "ArtifactCleanup.psm1" "$WORKFLOW"; then
  echo "PASS: workflow references ArtifactCleanup.psm1"
else
  echo "FAIL: workflow does not reference ArtifactCleanup.psm1"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "ArtifactCleanup.Tests.ps1" "$WORKFLOW"; then
  echo "PASS: workflow references ArtifactCleanup.Tests.ps1"
else
  echo "FAIL: workflow does not reference ArtifactCleanup.Tests.ps1"
  ERRORS=$((ERRORS + 1))
fi

# 8. Validate actionlint passes
echo "--- Checking actionlint ---"
LINT_EXIT=0
actionlint "$WORKFLOW" 2>&1 || LINT_EXIT=$?
if [ "$LINT_EXIT" -eq 0 ]; then
  echo "PASS: actionlint passed"
else
  echo "FAIL: actionlint failed with exit code $LINT_EXIT"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== SUMMARY ==="
if [ "$ERRORS" -eq 0 ]; then
  echo "All checks passed!"
else
  echo "$ERRORS check(s) failed."
  exit 1
fi
