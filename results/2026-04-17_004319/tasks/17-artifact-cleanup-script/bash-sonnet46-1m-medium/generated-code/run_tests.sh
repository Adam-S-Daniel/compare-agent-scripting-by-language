#!/usr/bin/env bash
# Test harness: runs all tests through GitHub Actions via act.
# Writes all act output to act-result.txt (required artifact).
# Asserts exact expected values from integration test steps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="${SCRIPT_DIR}/act-result.txt"

: > "$ACT_RESULT"  # Create/clear the output file

log() { echo "$*" | tee -a "$ACT_RESULT"; }
fail() { echo "FAIL: $*" | tee -a "$ACT_RESULT"; exit 1; }
pass() { echo "PASS: $*" | tee -a "$ACT_RESULT"; }

# --- Workflow structure checks (instant, no Docker) ---
log ""
log "=== WORKFLOW STRUCTURE CHECKS ==="

WF="${SCRIPT_DIR}/.github/workflows/artifact-cleanup-script.yml"

[[ -f "$WF" ]] || fail "Workflow file not found: $WF"
pass "Workflow file exists"

[[ "$(cat "$WF")" == *"artifact_cleanup.sh"* ]] || fail "Workflow does not reference artifact_cleanup.sh"
pass "Workflow references artifact_cleanup.sh"

[[ "$(cat "$WF")" == *"push"* ]]             || fail "Workflow missing push trigger"
pass "Workflow has push trigger"

[[ "$(cat "$WF")" == *"workflow_dispatch"* ]] || fail "Workflow missing workflow_dispatch trigger"
pass "Workflow has workflow_dispatch trigger"

actionlint "$WF" >> "$ACT_RESULT" 2>&1 || fail "actionlint failed on workflow file"
pass "actionlint passes"

# --- Set up temp git repo with project files ---
log ""
log "=== SETTING UP TEMP GIT REPO ==="

TMP_REPO=$(mktemp -d)
cleanup() { rm -rf "$TMP_REPO"; }
trap cleanup EXIT

# Copy all project files (not act-result.txt or the temp repo itself)
cp "${SCRIPT_DIR}/artifact_cleanup.sh"  "$TMP_REPO/"
cp -r "${SCRIPT_DIR}/tests"             "$TMP_REPO/"
cp -r "${SCRIPT_DIR}/.github"           "$TMP_REPO/"

# Reproduce the .actrc if present (sets default image for act)
[[ -f "${SCRIPT_DIR}/.actrc" ]] && cp "${SCRIPT_DIR}/.actrc" "$TMP_REPO/"

cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name  "Test Runner"
git add -A
git commit -q -m "ci: run artifact cleanup tests"
log "Temp repo created at $TMP_REPO"

# --- Run act (single push run covering all test cases via bats + integration steps) ---
log ""
log "=== ACT PUSH RUN ==="
log "--- act output start ---"

set +e
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT"
ACT_EXIT="${PIPESTATUS[0]}"
set -e

log "--- act output end ---"
log "act exit code: $ACT_EXIT"

[[ "$ACT_EXIT" -eq 0 ]] || fail "act exited with code $ACT_EXIT"
pass "act exited with code 0"

grep -q "Job succeeded" "$ACT_RESULT" || fail "'Job succeeded' not found in act output"
pass "Job succeeded"

# --- Assert exact expected values from integration test step outputs ---
log ""
log "=== EXACT VALUE ASSERTIONS ==="

# Age policy integration test: 2 deletes, space reclaimed = 1048576 + 2097152 = 3145728
grep -q "delete_count=2"              "$ACT_RESULT" || fail "Expected delete_count=2"
pass "delete_count=2 found"

grep -q "space_reclaimed_bytes=3145728" "$ACT_RESULT" || fail "Expected space_reclaimed_bytes=3145728"
pass "space_reclaimed_bytes=3145728 found"

grep -q "DELETE: artifact-alpha"       "$ACT_RESULT" || fail "Expected DELETE: artifact-alpha"
pass "DELETE: artifact-alpha found"

# Size policy integration test: 1 delete, space reclaimed = 400000
grep -q "delete_count=1"              "$ACT_RESULT" || fail "Expected delete_count=1"
pass "delete_count=1 found"

grep -q "space_reclaimed_bytes=400000" "$ACT_RESULT" || fail "Expected space_reclaimed_bytes=400000"
pass "space_reclaimed_bytes=400000 found"

grep -q "DELETE: artifact-size-a"      "$ACT_RESULT" || fail "Expected DELETE: artifact-size-a"
pass "DELETE: artifact-size-a found"

# Keep-N integration test: 2 deletes (alpha-1 and beta-1)
grep -q "DELETE: alpha-1"              "$ACT_RESULT" || fail "Expected DELETE: alpha-1"
pass "DELETE: alpha-1 found"

grep -q "DELETE: beta-1"               "$ACT_RESULT" || fail "Expected DELETE: beta-1"
pass "DELETE: beta-1 found"

# Combined policy integration test: combined-a and combined-b deleted
grep -q "DELETE: combined-a"           "$ACT_RESULT" || fail "Expected DELETE: combined-a"
pass "DELETE: combined-a found"

grep -q "DELETE: combined-b"           "$ACT_RESULT" || fail "Expected DELETE: combined-b"
pass "DELETE: combined-b found"

log ""
log "=== ALL ASSERTIONS PASSED ==="
