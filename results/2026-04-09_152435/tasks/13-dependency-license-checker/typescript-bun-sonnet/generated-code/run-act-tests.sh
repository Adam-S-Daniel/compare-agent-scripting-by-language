#!/usr/bin/env bash
# Act test harness for the dependency license checker.
#
# This script:
#   1. Creates a temporary git repo with all project files
#   2. Runs `act push --rm` to execute the GitHub Actions workflow in Docker
#   3. Captures all output to act-result.txt in the project root
#   4. Asserts exact expected values appear in the output
#
# Usage: bash run-act-tests.sh
# Prerequisites: act, Docker (both pre-installed in the benchmark environment)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="${SCRIPT_DIR}/act-result.txt"

# --- helper: write to both stdout and the result file ---
log() { echo "$*" | tee -a "$ACT_RESULT_FILE"; }

# --- assertion helper ---
assert_contains() {
  local label="$1"
  local expected="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF "$expected"; then
    log "ASSERT PASS: ${label} — found '${expected}'"
  else
    log "ASSERT FAIL: ${label} — expected '${expected}' but not found in output"
    exit 1
  fi
}

# Truncate/create the result file
> "$ACT_RESULT_FILE"

log "============================================================"
log "ACT TEST HARNESS — Dependency License Checker"
log "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "============================================================"
log ""

# --- Set up a temporary git repo ---
TMPDIR_BASE=$(mktemp -d)
TMPDIR="${TMPDIR_BASE}/repo"
mkdir -p "$TMPDIR"

# Ensure cleanup on exit
cleanup() {
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

log "=== Setup: copying project files to temp repo ==="

# Copy all project files
cp -r "${SCRIPT_DIR}/." "${TMPDIR}/"

# Initialise git
cd "$TMPDIR"
git init -q
git config user.email "ci@test.local"
git config user.name "CI Test"

# Remove any nested .git to avoid submodule issues
find "${TMPDIR}" -mindepth 2 -name ".git" -exec rm -rf {} + 2>/dev/null || true

git add -A
git commit -q -m "chore: add project files for act test"

log "Temp repo initialised at: ${TMPDIR}"
log ""

# --- Run act ---
log "=== Running: act push --rm ==="
log ""

# Capture output, tee to result file, preserve exit code
ACT_EXIT_CODE=0
ACT_OUTPUT=$(act push --rm --pull=false 2>&1) || ACT_EXIT_CODE=$?

echo "$ACT_OUTPUT" >> "$ACT_RESULT_FILE"

log ""
log "=== act exit code: ${ACT_EXIT_CODE} ==="
log ""

# --- Assert exit code ---
if [ "${ACT_EXIT_CODE}" -ne 0 ]; then
  log "FAIL: act exited with non-zero code ${ACT_EXIT_CODE}"
  exit 1
fi

# --- Assert job success ---
assert_contains "Job succeeded" "Job succeeded" "$ACT_OUTPUT"

# --- Assert bun tests ran ---
assert_contains "bun test passed" "pass" "$ACT_OUTPUT"

# --- Assert sample-package.json compliance output ---
assert_contains "sample fixture: Total=4"   "Total: 4"       "$ACT_OUTPUT"
assert_contains "sample fixture: Approved=2" "Approved: 2"   "$ACT_OUTPUT"
assert_contains "sample fixture: Denied=1"   "Denied: 1"     "$ACT_OUTPUT"
assert_contains "sample fixture: Unknown=1"  "Unknown: 1"    "$ACT_OUTPUT"
assert_contains "sample fixture: NON-COMPLIANT" "NON-COMPLIANT" "$ACT_OUTPUT"
assert_contains "sample fixture: react entry"  "react@"      "$ACT_OUTPUT"
assert_contains "sample fixture: gpl entry"    "gpl-package@" "$ACT_OUTPUT"

# --- Assert approved-package.json compliance output ---
assert_contains "approved fixture: Total=2"    "Total: 2"    "$ACT_OUTPUT"
assert_contains "approved fixture: Approved=2" "Approved: 2" "$ACT_OUTPUT"
assert_contains "approved fixture: Denied=0"   "Denied: 0"   "$ACT_OUTPUT"
assert_contains "approved fixture: COMPLIANT"  "Status: COMPLIANT" "$ACT_OUTPUT"

log ""
log "============================================================"
log "ALL ACT ASSERTIONS PASSED"
log "============================================================"

cd "$SCRIPT_DIR"
