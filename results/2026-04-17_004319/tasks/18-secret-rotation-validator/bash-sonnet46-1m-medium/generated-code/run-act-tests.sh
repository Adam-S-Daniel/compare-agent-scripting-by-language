#!/usr/bin/env bash
# run-act-tests.sh
# Outer test harness: sets up a temp git repo, runs act push, captures output
# to act-result.txt, and asserts on exact expected values.
#
# All tests must pass through the GitHub Actions pipeline (via act).
# Usage: ./run-act-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACT_RESULT_FILE="${SCRIPT_DIR}/act-result.txt"

# Truncate/create the result file
: > "$ACT_RESULT_FILE"

# Colour helpers (degrade gracefully if no tty)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}PASS${NC}: $*"; }
fail() { echo -e "${RED}FAIL${NC}: $*" >&2; exit 1; }
info() { echo -e "${YELLOW}INFO${NC}: $*"; }

# ─── Helper: assert a string appears in act output ───────────────────────────
assert_contains() {
  local output="$1" needle="$2" label="$3"
  if echo "$output" | grep -qF "$needle"; then
    ok "$label"
  else
    fail "$label — expected to find: $needle"
  fi
}

# ─── Helper: run one act test case ───────────────────────────────────────────
run_act_test_case() {
  local case_name="$1"

  info "Running test case: $case_name"

  # Create isolated temp git repo with all project files
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" EXIT

  cp -r "${SCRIPT_DIR}/." "${tmpdir}/"
  cd "$tmpdir"

  # Copy .actrc so act uses the custom container image
  cp "${SCRIPT_DIR}/.actrc" "$tmpdir/.actrc" 2>/dev/null || true

  git init -q
  git config user.email "test@example.com"
  git config user.name "Test Runner"
  git add -A
  git commit -q -m "test: $case_name"

  # Run act; --pull=false prevents re-pulling locally-built images
  local act_output
  local act_exit=0
  act_output=$(act push --rm --pull=false 2>&1) || act_exit=$?

  cd "$SCRIPT_DIR"

  # Append to the required artifact
  {
    echo "================================================================"
    echo "=== TEST CASE: $case_name"
    echo "=== Exit code: $act_exit"
    echo "================================================================"
    echo "$act_output"
    echo ""
  } >> "$ACT_RESULT_FILE"

  echo "$act_output"   # also print to console for visibility
  return "$act_exit"
}

# ─── Test case 1: main fixture (expired + warning + ok) ──────────────────────
run_test_case_basic() {
  info "=== Test case: basic (DB_PASSWORD=EXPIRED, API_KEY=WARNING, TLS_CERT=OK) ==="

  local output
  output=$(run_act_test_case "basic")
  local act_exit=$?

  # Job must succeed
  [ "$act_exit" -eq 0 ] || fail "act exited with code $act_exit — see $ACT_RESULT_FILE"
  assert_contains "$output" "Job succeeded" "Job succeeded"

  # Bats TAP output: "1..24" means 24 tests planned, all ok lines mean all passed
  assert_contains "$output" "1..24" "bats planned 24 tests"
  # Verify last test passed (no "not ok" lines)
  if echo "$output" | grep -qF "not ok"; then
    fail "some bats tests failed — see act-result.txt"
  fi
  ok "all 24 bats tests passed (no 'not ok' lines)"

  # JSON report: expired secret
  assert_contains "$output" '"status": "EXPIRED"'    "DB_PASSWORD classified as EXPIRED"
  assert_contains "$output" '"name": "DB_PASSWORD"'  "DB_PASSWORD present in report"
  assert_contains "$output" '"days_overdue": 20'     "DB_PASSWORD has 20 days overdue"

  # JSON report: warning secret
  assert_contains "$output" '"status": "WARNING"'    "API_KEY classified as WARNING"
  assert_contains "$output" '"days_remaining": 5'    "API_KEY has 5 days remaining"

  # JSON report: ok secret
  assert_contains "$output" '"status": "OK"'         "TLS_CERT classified as OK"
  assert_contains "$output" '"days_remaining": 71'   "TLS_CERT has 71 days remaining"

  # Summary counts
  assert_contains "$output" '"expired": 1'  "summary: 1 expired"
  assert_contains "$output" '"warning": 1'  "summary: 1 warning"
  assert_contains "$output" '"ok": 1'       "summary: 1 ok"
  assert_contains "$output" '"total": 3'    "summary: total 3"

  # Markdown report must include urgency sections
  assert_contains "$output" "## EXPIRED"  "markdown has EXPIRED section"
  assert_contains "$output" "## WARNING"  "markdown has WARNING section"
  assert_contains "$output" "## OK"       "markdown has OK section"

  # All-expired fixture check
  assert_contains "$output" '"warning": 0' "all-expired: warning count is 0"
  assert_contains "$output" '"ok": 0'      "all-expired: ok count is 0"

  ok "Test case 'basic' complete"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  info "Starting act test harness"
  info "Results will be saved to: $ACT_RESULT_FILE"
  echo ""

  # Validate workflow passes actionlint before spending time on act
  info "Pre-flight: actionlint check..."
  if ! actionlint "${SCRIPT_DIR}/.github/workflows/secret-rotation-validator.yml"; then
    fail "actionlint failed — fix the workflow before running act"
  fi
  ok "actionlint passed"
  echo ""

  run_test_case_basic

  echo ""
  info "All test cases passed."
  info "Full act output saved to: $ACT_RESULT_FILE"
}

main "$@"
