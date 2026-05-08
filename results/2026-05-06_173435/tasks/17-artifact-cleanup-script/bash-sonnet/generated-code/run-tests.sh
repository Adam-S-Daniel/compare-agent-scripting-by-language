#!/usr/bin/env bash

# Test harness: runs all tests through GitHub Actions via act.
# Sets up a temporary git repo containing the project, runs act push --rm,
# appends full output to act-result.txt, then asserts on exact expected values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT="$SCRIPT_DIR/act-result.txt"

# Clear previous results
: > "$ACT_RESULT"

log() { echo "[run-tests] $*"; }
fail() { echo "[run-tests] FAIL: $*" >&2; exit 1; }

# ── Setup temp git repo ───────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d)
REPO="$TMPDIR_BASE/repo"
mkdir -p "$REPO"

log "Copying project files to $REPO"
cp "$SCRIPT_DIR/artifact-cleanup.sh" "$REPO/"
cp -r "$SCRIPT_DIR/tests" "$REPO/"
cp -r "$SCRIPT_DIR/.github" "$REPO/"

# Copy .actrc so act uses the same container image
if [[ -f "$SCRIPT_DIR/.actrc" ]]; then
    cp "$SCRIPT_DIR/.actrc" "$REPO/"
fi

cd "$REPO"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git add -A
git commit -q -m "test: initial commit for artifact cleanup tests"

# ── Run act ───────────────────────────────────────────────────────────────────
log "Running: act push --rm"
log "Output will be appended to $ACT_RESULT"
{
    echo "====== act push run ======"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
} >> "$ACT_RESULT"

act_exit=0
act push --rm --pull=false 2>&1 | tee -a "$ACT_RESULT" || act_exit=$?

echo "" >> "$ACT_RESULT"
echo "====== act exit code: $act_exit ======" >> "$ACT_RESULT"

# ── Assertions ────────────────────────────────────────────────────────────────
log "Asserting act exited with code 0 (got: $act_exit)"
if [[ $act_exit -ne 0 ]]; then
    fail "act push exited with code $act_exit. Check $ACT_RESULT for details."
fi

log "Asserting 'Job succeeded' appears in output"
grep -q "Job succeeded" "$ACT_RESULT" \
    || fail "'Job succeeded' not found in act output"

# Assert exact expected test names (exact values from known-good fixture results)
EXPECTED_TESTS=(
    "ok 4 max-age policy marks 2 of 3 artifacts for deletion"
    "ok 6 max-age policy shows space reclaimed of 6291456 bytes"
    "ok 7 max-age deletion list includes old-artifact-a"
    "ok 10 keep-latest-n=2 marks 2 of 6 artifacts for deletion"
    "ok 11 keep-latest-n=2 retains 4 of 6 artifacts"
    "ok 14 max-total-size deletes 2 oldest artifacts to get under 52428800 bytes"
    "ok 16 max-total-size reclaims 41943040 bytes"
    "ok 18 dry-run mode includes DRY RUN notice in output"
    "ok 20 no deletions when all artifacts are within max-age policy"
    "ok 22 space reclaimed is 0 bytes when no artifacts deleted"
    "ok 26 actionlint passes on workflow file"
)

for expected in "${EXPECTED_TESTS[@]}"; do
    log "Asserting exact output: '$expected'"
    grep -qF "$expected" "$ACT_RESULT" \
        || fail "Expected test result not found: '$expected'"
done

# Assert the dry-run demo output also shows expected values
log "Asserting dry-run demo output contains Space reclaimed: 6291456 bytes"
grep -q "Space reclaimed: 6291456 bytes" "$ACT_RESULT" \
    || fail "Expected 'Space reclaimed: 6291456 bytes' in demo output"

log "Asserting dry-run demo output contains Space reclaimed: 41943040 bytes"
grep -q "Space reclaimed: 41943040 bytes" "$ACT_RESULT" \
    || fail "Expected 'Space reclaimed: 41943040 bytes' in demo output"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$TMPDIR_BASE"

log "All assertions passed."
log "act-result.txt written to: $ACT_RESULT"
echo ""
echo "SUCCESS: All tests passed through act."
