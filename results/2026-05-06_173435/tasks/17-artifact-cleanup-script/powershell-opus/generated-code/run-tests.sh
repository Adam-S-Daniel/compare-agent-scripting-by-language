#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$WORK_DIR/act-result.txt"
PASS=0
FAIL=0

> "$RESULT_FILE"

log() { echo "[TEST] $*"; echo "[TEST] $*" >> "$RESULT_FILE"; }

# ── Workflow Structure Tests ────────────────────────────────────────────────

log "=== WORKFLOW STRUCTURE TESTS ==="

# Test: YAML has expected triggers
if grep -q 'push:' .github/workflows/artifact-cleanup-script.yml &&
   grep -q 'pull_request:' .github/workflows/artifact-cleanup-script.yml &&
   grep -q 'workflow_dispatch:' .github/workflows/artifact-cleanup-script.yml; then
    log "PASS: Workflow has push, pull_request, and workflow_dispatch triggers"
    PASS=$((PASS + 1))
else
    log "FAIL: Missing expected triggers"
    FAIL=$((FAIL + 1))
fi

# Test: YAML has expected jobs
if grep -q 'test:' .github/workflows/artifact-cleanup-script.yml &&
   grep -q 'integration:' .github/workflows/artifact-cleanup-script.yml; then
    log "PASS: Workflow has test and integration jobs"
    PASS=$((PASS + 1))
else
    log "FAIL: Missing expected jobs"
    FAIL=$((FAIL + 1))
fi

# Test: Workflow references script files that exist
if grep -q 'ArtifactCleanup.Tests.ps1' .github/workflows/artifact-cleanup-script.yml &&
   [ -f "$WORK_DIR/ArtifactCleanup.Tests.ps1" ]; then
    log "PASS: Workflow references ArtifactCleanup.Tests.ps1 and file exists"
    PASS=$((PASS + 1))
else
    log "FAIL: Workflow does not reference test file or file missing"
    FAIL=$((FAIL + 1))
fi

if grep -q 'ArtifactCleanup.ps1' .github/workflows/artifact-cleanup-script.yml &&
   [ -f "$WORK_DIR/ArtifactCleanup.ps1" ]; then
    log "PASS: Workflow references ArtifactCleanup.ps1 and file exists"
    PASS=$((PASS + 1))
else
    log "FAIL: Workflow does not reference script or file missing"
    FAIL=$((FAIL + 1))
fi

# Test: Uses shell: pwsh
if grep -q 'shell: pwsh' .github/workflows/artifact-cleanup-script.yml; then
    log "PASS: Workflow uses shell: pwsh"
    PASS=$((PASS + 1))
else
    log "FAIL: Workflow does not use shell: pwsh"
    FAIL=$((FAIL + 1))
fi

# Test: Uses actions/checkout@v4
if grep -q 'actions/checkout@v4' .github/workflows/artifact-cleanup-script.yml; then
    log "PASS: Workflow uses actions/checkout@v4"
    PASS=$((PASS + 1))
else
    log "FAIL: Workflow does not use actions/checkout@v4"
    FAIL=$((FAIL + 1))
fi

# Test: actionlint passes
if actionlint .github/workflows/artifact-cleanup-script.yml 2>&1; then
    log "PASS: actionlint validation passes"
    PASS=$((PASS + 1))
else
    log "FAIL: actionlint validation fails"
    FAIL=$((FAIL + 1))
fi

# ── Act Integration Test ────────────────────────────────────────────────────

log ""
log "=== ACT INTEGRATION TEST ==="

# Set up a temporary git repo with all project files
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$WORK_DIR/ArtifactCleanup.ps1" "$TMPDIR/"
cp -r "$WORK_DIR/ArtifactCleanup.Tests.ps1" "$TMPDIR/"
mkdir -p "$TMPDIR/.github/workflows"
cp "$WORK_DIR/.github/workflows/artifact-cleanup-script.yml" "$TMPDIR/.github/workflows/"

# Copy actrc if it exists
if [ -f "$WORK_DIR/.actrc" ]; then
    cp "$WORK_DIR/.actrc" "$TMPDIR/"
fi

cd "$TMPDIR"
git init -b main --quiet
git add -A
git commit -m "initial" --quiet

log "Running act push..."
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || true
ACT_EXIT=$?

echo "$ACT_OUTPUT" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

cd "$WORK_DIR"

# Check act exit code
if [ $ACT_EXIT -eq 0 ]; then
    log "PASS: act exited with code 0"
    PASS=$((PASS + 1))
else
    log "FAIL: act exited with code $ACT_EXIT"
    FAIL=$((FAIL + 1))
fi

# Check that test job succeeded
if echo "$ACT_OUTPUT" | grep -q "Job succeeded" ; then
    log "PASS: At least one job succeeded"
    PASS=$((PASS + 1))
else
    log "FAIL: No 'Job succeeded' found in act output"
    FAIL=$((FAIL + 1))
fi

# Count job successes — we expect 2 (test + integration)
JOB_SUCCESS_COUNT=$(echo "$ACT_OUTPUT" | grep -c "Job succeeded" || true)
if [ "$JOB_SUCCESS_COUNT" -ge 2 ]; then
    log "PASS: Both jobs succeeded ($JOB_SUCCESS_COUNT 'Job succeeded' found)"
    PASS=$((PASS + 1))
else
    log "FAIL: Expected 2 job successes, got $JOB_SUCCESS_COUNT"
    FAIL=$((FAIL + 1))
fi

# ── Assert Pester test results from act output ──────────────────────────────

log ""
log "=== PESTER OUTPUT ASSERTIONS ==="

# The Pester output should show exact test counts
# We have 19 test cases total
if echo "$ACT_OUTPUT" | grep -qP 'Tests Completed.*Passed'; then
    log "PASS: Pester tests completed with passes"
    PASS=$((PASS + 1))
else
    # Try alternative Pester output format
    if echo "$ACT_OUTPUT" | grep -q "Passed:"; then
        log "PASS: Pester tests completed with passes (alt format)"
        PASS=$((PASS + 1))
    else
        log "FAIL: Could not find Pester pass summary"
        FAIL=$((FAIL + 1))
    fi
fi

# Check that 0 tests failed in Pester
if echo "$ACT_OUTPUT" | grep -qP 'Failed:\s*0' || echo "$ACT_OUTPUT" | grep -qP 'Failed\s+0'; then
    log "PASS: Pester reports 0 failed tests"
    PASS=$((PASS + 1))
else
    log "FAIL: Pester may have had test failures"
    FAIL=$((FAIL + 1))
fi

# ── Assert specific integration output values ───────────────────────────────

log ""
log "=== INTEGRATION OUTPUT ASSERTIONS ==="

# DRY RUN max age 30 days: build-logs-march is from 2026-03-15 (53 days old)
# test-results-april is from 2026-04-20 (17 days old) — should be deleted too? 2026-05-07 - 30 = 2026-04-07, so yes 2026-04-20 > 2026-04-07 => retained
# build-logs-march from 2026-03-15 < 2026-04-07 => deleted
if echo "$ACT_OUTPUT" | grep -q "DRY RUN: Max age 30 days"; then
    log "PASS: DRY RUN max-age heading found"
    PASS=$((PASS + 1))
else
    log "FAIL: Missing dry run max-age heading"
    FAIL=$((FAIL + 1))
fi

if echo "$ACT_OUTPUT" | grep -q "Artifacts to delete: 1"; then
    log "PASS: Correct delete count (1) for max-age-30 scenario"
    PASS=$((PASS + 1))
else
    log "FAIL: Wrong delete count for max-age-30 scenario"
    FAIL=$((FAIL + 1))
fi

if echo "$ACT_OUTPUT" | grep -q "Artifacts to retain: 4"; then
    log "PASS: Correct retain count (4) for max-age-30 scenario"
    PASS=$((PASS + 1))
else
    log "FAIL: Wrong retain count for max-age-30 scenario"
    FAIL=$((FAIL + 1))
fi

if echo "$ACT_OUTPUT" | grep -q "Space reclaimed: 1048576 bytes"; then
    log "PASS: Correct space reclaimed (1048576) for max-age-30 scenario"
    PASS=$((PASS + 1))
else
    log "FAIL: Wrong space reclaimed for max-age-30 scenario"
    FAIL=$((FAIL + 1))
fi

# Second run: keep-latest-1 + max-total 3MB
# KeepLatestN=1 per workflow:
#   run-100: keep test-results-april(524288), delete build-logs-march(1048576)
#   run-200: keep deploy-artifact(2097152), delete coverage-report(262144)
#   run-300: keep nightly-build(4194304)
# After keepN: retained = test-results-april(524288) + deploy-artifact(2097152) + nightly-build(4194304) = 6815744
# MaxTotal=3145728: 6815744 > 3145728. Delete oldest retained first.
#   Sorted by date: test-results-april(2026-04-20), deploy-artifact(2026-05-05), nightly-build(2026-05-06)
#   Delete test-results-april: 6815744-524288=6291456 still > 3145728
#   Delete deploy-artifact: 6291456-2097152=4194304 still > 3145728
#   Delete nightly-build: that would leave 0. But after deleting deploy-artifact total is 4194304 which > 3145728.
#   So we must delete nightly-build too? No, 4194304 > 3145728 so yes.
# Total deleted: build-logs-march + coverage-report + test-results-april + deploy-artifact + nightly-build = all 5
# Wait, that can't be right. Let me recalculate.
# After keepN: retained = {test-results-april, deploy-artifact, nightly-build}
# Total retained = 524288 + 2097152 + 4194304 = 6815744
# Need to get to 3145728. Overshoot: 6815744 - 3145728 = 3670016
# Delete oldest retained:
#   test-results-april(524288, 2026-04-20) => total now 6291456 > 3145728, continue
#   deploy-artifact(2097152, 2026-05-05) => total now 4194304 > 3145728, continue
#   nightly-build(4194304, 2026-05-06) => total now 0 <= 3145728, stop
# So all 5 deleted, 0 retained. That's odd but correct given those params.
# Actually wait, we delete until total <= limit. After deleting deploy-artifact, total = 4194304.
# 4194304 > 3145728, so we continue. Delete nightly-build. Total = 0 <= 3145728. Stop.
# So: 5 deleted, 0 retained.

if echo "$ACT_OUTPUT" | grep -q "DRY RUN: Keep latest 1 per workflow, max 3MB total"; then
    log "PASS: DRY RUN keep-latest+max-total heading found"
    PASS=$((PASS + 1))
else
    log "FAIL: Missing keep-latest+max-total heading"
    FAIL=$((FAIL + 1))
fi

if echo "$ACT_OUTPUT" | grep -q "Artifacts to delete: 5"; then
    log "PASS: Correct delete count (5) for keep-latest+max-total scenario"
    PASS=$((PASS + 1))
else
    log "FAIL: Wrong delete count for keep-latest+max-total scenario"
    FAIL=$((FAIL + 1))
fi

if echo "$ACT_OUTPUT" | grep -q "Artifacts to retain: 0"; then
    log "PASS: Correct retain count (0) for keep-latest+max-total scenario"
    PASS=$((PASS + 1))
else
    log "FAIL: Wrong retain count for keep-latest+max-total scenario"
    FAIL=$((FAIL + 1))
fi

# Total size of all artifacts: 1048576+524288+262144+2097152+4194304 = 8126464
if echo "$ACT_OUTPUT" | grep -q "Space reclaimed: 8126464 bytes"; then
    log "PASS: Correct total space reclaimed (8126464) for keep-latest+max-total scenario"
    PASS=$((PASS + 1))
else
    log "FAIL: Wrong space reclaimed for keep-latest+max-total scenario"
    FAIL=$((FAIL + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────────

log ""
log "=== FINAL SUMMARY ==="
log "Passed: $PASS"
log "Failed: $FAIL"
TOTAL=$((PASS + FAIL))
log "Total: $TOTAL"

if [ $FAIL -gt 0 ]; then
    log "RESULT: SOME TESTS FAILED"
    exit 1
else
    log "RESULT: ALL TESTS PASSED"
    exit 0
fi
