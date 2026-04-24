#!/usr/bin/env bash
# run_tests.sh - Test harness that validates the matrix generator via act
#
# Sets up a temp git repo, runs `act push --rm`, saves output to act-result.txt,
# then asserts on exact expected values from the workflow output.

set -euo pipefail

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$WORK_DIR/act-result.txt"

# Clear act-result.txt
true > "$ACT_RESULT"

log() { echo "[run_tests] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

# ── Setup temp git repo ────────────────────────────────────────────────────

TMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $TMP_DIR" EXIT

log "Setting up temp git repo in $TMP_DIR"

cd "$TMP_DIR"
git init -q
git config user.email "test@example.com"
git config user.name "CI Test"

# Copy all project files
cp "$WORK_DIR/generate_matrix.sh" .
cp -r "$WORK_DIR/tests" .
cp -r "$WORK_DIR/fixtures" .
cp -r "$WORK_DIR/.github" .
cp "$WORK_DIR/.actrc" .

chmod +x generate_matrix.sh

git add -A
git commit -q -m "test: environment matrix generator"

# ── Run act ────────────────────────────────────────────────────────────────

log "Running act push --rm (this may take 30-90 seconds)..."

{
  echo "=== ACT RUN: environment-matrix-generator ==="
  echo "=== Started: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo ""
} >> "$ACT_RESULT"

ACT_EXIT=0
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT" || ACT_EXIT=$?

{
  echo ""
  echo "=== ACT EXIT CODE: $ACT_EXIT ==="
  echo "=== Ended: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
} >> "$ACT_RESULT"

# ── Assertions ─────────────────────────────────────────────────────────────

log "Asserting results..."

# 1. Act must exit 0
if [[ "$ACT_EXIT" -ne 0 ]]; then
    fail "act exited with code $ACT_EXIT (expected 0)"
fi
log "PASS: act exited with code 0"

# 2. Every job must show "Job succeeded"
if ! grep -q "Job succeeded" "$ACT_RESULT"; then
    fail "'Job succeeded' not found in act output"
fi
log "PASS: Job succeeded found"

# 3. Exact value assertions from workflow echo output
assert_contains() {
    local pattern="$1"
    local description="$2"
    if ! grep -q "$pattern" "$ACT_RESULT"; then
        fail "Expected pattern not found: $pattern ($description)"
    fi
    log "PASS: $description"
}

assert_contains "VERIFIED_OS_COUNT=2"          "basic matrix OS count is 2"
assert_contains "VERIFIED_NODE_COUNT=2"        "basic matrix node-version count is 2"
assert_contains "VERIFIED_FAIL_FAST=false"     "basic matrix fail-fast is false"
assert_contains "VERIFIED_MAX_PARALLEL=2"      "max-parallel config produces 2"
assert_contains "VERIFIED_FAIL_FAST_TRUE=true" "fail-fast true is preserved"
assert_contains "VERIFIED_INCLUDE_COUNT=1"     "include rules count is 1"
assert_contains "VERIFIED_INCLUDE_NODE=22"     "include node-version is 22"
assert_contains "VERIFIED_EXCLUDE_COUNT=1"     "exclude rules count is 1"
assert_contains "VERIFIED_EXCLUDE_OS=windows-latest" "exclude OS is windows-latest"
assert_contains "VERIFIED_OVERSIZED_REJECTED=true"   "oversized matrix is rejected"
assert_contains "ALL VERIFICATIONS PASSED"     "workflow summary step ran"

log "All assertions passed!"
log "act-result.txt saved to: $ACT_RESULT"
