#!/usr/bin/env bash
# Test harness that runs all tests through GitHub Actions via act.
# Creates a temporary git repo, runs act push, captures output, and asserts results.

set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
ACT_RESULT="$WORK_DIR/act-result.txt"

# Clear previous results
> "$ACT_RESULT"

echo "=============================================="
echo "WORKFLOW STRUCTURE TESTS"
echo "=============================================="

# Structure test 1: YAML has expected triggers
echo "--- Structure Test: Triggers ---" >> "$ACT_RESULT"
if python3 -c "
import yaml, sys
with open('$WORK_DIR/.github/workflows/artifact-cleanup-script.yml') as f:
    wf = yaml.safe_load(f)
# YAML parses 'on' as True (boolean), so check both keys
triggers = wf.get('on', wf.get(True, {}))
assert 'push' in triggers, 'Missing push trigger'
assert 'pull_request' in triggers, 'Missing pull_request trigger'
assert 'schedule' in triggers, 'Missing schedule trigger'
assert 'workflow_dispatch' in triggers, 'Missing workflow_dispatch trigger'
print('STRUCTURE TEST: All expected triggers present - PASSED')
"; then
    echo "STRUCTURE TEST: Triggers - PASSED" >> "$ACT_RESULT"
else
    echo "STRUCTURE TEST: Triggers - FAILED" >> "$ACT_RESULT"
    exit 1
fi

# Structure test 2: Jobs exist
echo "--- Structure Test: Jobs ---" >> "$ACT_RESULT"
if python3 -c "
import yaml
with open('$WORK_DIR/.github/workflows/artifact-cleanup-script.yml') as f:
    wf = yaml.safe_load(f)
jobs = wf.get('jobs', {})
assert 'unit-tests' in jobs, 'Missing unit-tests job'
assert 'test-max-age-policy' in jobs, 'Missing test-max-age-policy job'
assert 'test-keep-latest-policy' in jobs, 'Missing test-keep-latest-policy job'
assert 'test-combined-policies' in jobs, 'Missing test-combined-policies job'
print('STRUCTURE TEST: All expected jobs present - PASSED')
"; then
    echo "STRUCTURE TEST: Jobs - PASSED" >> "$ACT_RESULT"
else
    echo "STRUCTURE TEST: Jobs - FAILED" >> "$ACT_RESULT"
    exit 1
fi

# Structure test 3: Script files referenced in workflow exist
echo "--- Structure Test: File References ---" >> "$ACT_RESULT"
if python3 -c "
import os
files = ['artifact_cleanup.py', 'test_artifact_cleanup.py', 'test_fixtures.py',
         'fixtures/test_max_age.json', 'fixtures/test_keep_latest.json', 'fixtures/test_combined.json']
for f in files:
    path = os.path.join('$WORK_DIR', f)
    assert os.path.exists(path), f'Missing file: {f}'
print('STRUCTURE TEST: All referenced files exist - PASSED')
"; then
    echo "STRUCTURE TEST: File references - PASSED" >> "$ACT_RESULT"
else
    echo "STRUCTURE TEST: File references - FAILED" >> "$ACT_RESULT"
    exit 1
fi

# Structure test 4: actionlint passes
echo "--- Structure Test: actionlint ---" >> "$ACT_RESULT"
if actionlint "$WORK_DIR/.github/workflows/artifact-cleanup-script.yml"; then
    echo "STRUCTURE TEST: actionlint - PASSED" >> "$ACT_RESULT"
else
    echo "STRUCTURE TEST: actionlint - FAILED" >> "$ACT_RESULT"
    exit 1
fi

echo ""
echo "=============================================="
echo "ACT INTEGRATION TESTS"
echo "=============================================="

# Set up a temp git repo with all project files
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cp -r "$WORK_DIR"/.github "$TMPDIR/"
cp "$WORK_DIR"/artifact_cleanup.py "$TMPDIR/"
cp "$WORK_DIR"/test_artifact_cleanup.py "$TMPDIR/"
cp "$WORK_DIR"/test_fixtures.py "$TMPDIR/"
cp -r "$WORK_DIR"/fixtures "$TMPDIR/"
cp "$WORK_DIR"/.actrc "$TMPDIR/" 2>/dev/null || true

cd "$TMPDIR"
git init -q
git add -A
git commit -q -m "test commit"

echo ""
echo "--- Running act push ---"
echo "=============================================="  >> "$ACT_RESULT"
echo "ACT INTEGRATION TEST RUN"                        >> "$ACT_RESULT"
echo "=============================================="  >> "$ACT_RESULT"

# Run act and capture output
set +e
ACT_OUTPUT=$(act push --rm --pull=false 2>&1)
ACT_EXIT=$?
set -e

# Save act output to a temp file for reliable grep matching
ACT_OUTPUT_FILE="$TMPDIR/act_output.txt"
echo "$ACT_OUTPUT" > "$ACT_OUTPUT_FILE"
cat "$ACT_OUTPUT_FILE" >> "$ACT_RESULT"
echo "" >> "$ACT_RESULT"
echo "ACT EXIT CODE: $ACT_EXIT" >> "$ACT_RESULT"

cat "$ACT_OUTPUT_FILE"
echo ""
echo "Act exit code: $ACT_EXIT"

# Assert act succeeded
if [ "$ACT_EXIT" -ne 0 ]; then
    echo "FATAL: act exited with code $ACT_EXIT" >> "$ACT_RESULT"
    echo "FATAL: act failed with exit code $ACT_EXIT"
    exit 1
fi
echo "ASSERT: act exit code 0 - PASSED" >> "$ACT_RESULT"

# Assert all jobs succeeded
echo "" >> "$ACT_RESULT"
echo "--- Job Success Assertions ---" >> "$ACT_RESULT"

# Act uses display names, not job IDs. Check each job's display name appears with "Job succeeded"
JOB_COUNT=$(grep -c "Job succeeded" "$ACT_OUTPUT_FILE" || true)
if [ "$JOB_COUNT" -ge 4 ]; then
    echo "ASSERT: All 4 jobs succeeded ($JOB_COUNT found) - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: All 4 jobs succeeded ($JOB_COUNT found, expected 4) - FAILED" >> "$ACT_RESULT"
fi

for JOB_NAME in "Run unit tests" "Test max age" "Test keep-latest" "Test combined"; do
    if grep -F "$JOB_NAME" "$ACT_OUTPUT_FILE" | grep -Fq "Job succeeded"; then
        echo "ASSERT: '$JOB_NAME' job succeeded - PASSED" >> "$ACT_RESULT"
    else
        echo "ASSERT: '$JOB_NAME' job succeeded - FAILED" >> "$ACT_RESULT"
    fi
done

# Assert specific output values
echo "" >> "$ACT_RESULT"
echo "--- Value Assertions ---" >> "$ACT_RESULT"

# Use grep -F for fixed-string matching (avoids regex issues with parentheses)
# All greps read from $ACT_OUTPUT_FILE for reliability

# Max age test: 1 deleted, 6 retained, 8.0 MB reclaimed
if grep -Fq "1 artifact(s) to delete" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Max age - 1 artifact to delete - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Max age - 1 artifact to delete - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "6 artifact(s) to retain" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Max age - 6 artifacts retained - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Max age - 6 artifacts retained - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "Space reclaimed: 8.0 MB" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Max age - space reclaimed 8.0 MB - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Max age - space reclaimed 8.0 MB - FAILED" >> "$ACT_RESULT"
fi

# Keep latest test: 4 deleted, 3 retained, 140.0 MB reclaimed
if grep -Fq "4 artifact(s) to delete" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Keep latest - 4 artifacts to delete - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Keep latest - 4 artifacts to delete - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "3 artifact(s) to retain" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Keep latest - 3 artifacts retained - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Keep latest - 3 artifacts retained - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "Space reclaimed: 140.0 MB" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Keep latest - space reclaimed 140.0 MB - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Keep latest - space reclaimed 140.0 MB - FAILED" >> "$ACT_RESULT"
fi

# Combined test: 3 deleted, 4 retained, 128.0 MB reclaimed, 152.0 MB retained
if grep -Fq "3 artifact(s) to delete" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Combined - 3 artifacts to delete - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Combined - 3 artifacts to delete - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "4 artifact(s) to retain" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Combined - 4 artifacts retained - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Combined - 4 artifacts retained - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "Space reclaimed: 128.0 MB" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Combined - space reclaimed 128.0 MB - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Combined - space reclaimed 128.0 MB - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "Space retained: 152.0 MB" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Combined - space retained 152.0 MB - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Combined - space retained 152.0 MB - FAILED" >> "$ACT_RESULT"
fi

# Dry run / live mode
if grep -Fq "DRY RUN" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Dry run mode present - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Dry run mode present - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "LIVE" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Live mode present - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Live mode present - FAILED" >> "$ACT_RESULT"
fi

# Empty input handling
if grep -Fq "No artifacts to process" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Empty input handled - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Empty input handled - FAILED" >> "$ACT_RESULT"
fi

# Unit tests all passed
if grep -Fq "ALL TESTS PASSED" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: All unit tests passed - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: All unit tests passed - FAILED" >> "$ACT_RESULT"
fi

if grep -Fq "14 passed, 0 failed" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: 14 tests passed, 0 failed - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: 14 tests passed, 0 failed - FAILED" >> "$ACT_RESULT"
fi

# Error handling
if grep -Fq "Non-zero exit code for invalid input - PASSED" "$ACT_OUTPUT_FILE"; then
    echo "ASSERT: Error handling - non-zero exit - PASSED" >> "$ACT_RESULT"
else
    echo "ASSERT: Error handling - non-zero exit - FAILED" >> "$ACT_RESULT"
fi

echo "" >> "$ACT_RESULT"
echo "=============================================="  >> "$ACT_RESULT"
echo "ALL TESTS COMPLETE"                              >> "$ACT_RESULT"
echo "=============================================="  >> "$ACT_RESULT"

echo ""
echo "=============================================="
echo "ALL TESTS COMPLETE"
echo "=============================================="
echo "Results saved to: $ACT_RESULT"
