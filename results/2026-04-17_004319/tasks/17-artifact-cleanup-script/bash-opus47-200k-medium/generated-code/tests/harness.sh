#!/usr/bin/env bash
# End-to-end harness: validates the workflow structure, lints it, then runs
# `act push --rm` three times against three fixture cases. All act output is
# captured into act-result.txt in the project root and asserted against
# EXACT expected values derived from the fixtures.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

WORKFLOW=".github/workflows/artifact-cleanup-script.yml"
RESULT_FILE="$here/act-result.txt"
: > "$RESULT_FILE"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# ---------- 1. Workflow structure checks (grep-based, no yq dependency).
echo "[1/3] Workflow structure checks"
grep -q "^name: artifact-cleanup-script$" "$WORKFLOW" || fail "missing name"
grep -q "^  push:" "$WORKFLOW" || fail "missing push trigger"
grep -q "^  pull_request:" "$WORKFLOW" || fail "missing pull_request trigger"
grep -q "^  workflow_dispatch:" "$WORKFLOW" || fail "missing workflow_dispatch"
grep -q "^  schedule:" "$WORKFLOW" || fail "missing schedule"
grep -q "actions/checkout@v4" "$WORKFLOW" || fail "missing checkout@v4"
grep -q "bats tests/cleanup.bats" "$WORKFLOW" || fail "workflow does not reference bats test file"
grep -q "cleanup.sh" "$WORKFLOW" || fail "workflow does not reference cleanup.sh"
grep -q "permissions:" "$WORKFLOW" || fail "missing permissions block"
[[ -f cleanup.sh ]] || fail "cleanup.sh does not exist"
[[ -f tests/cleanup.bats ]] || fail "tests/cleanup.bats does not exist"
pass "workflow structure"

# ---------- 2. actionlint.
echo "[2/3] actionlint"
actionlint "$WORKFLOW"
pass "actionlint exit=0"

# ---------- 3. Three act runs with varied fixtures.
NOW=1700000000
D1=$((NOW - 86400))         # 1 day ago
D2=$((NOW - 2 * 86400))     # 2 days ago
D3=$((NOW - 3 * 86400))     # 3 days ago
D60=$((NOW - 60 * 86400))   # 60 days ago

write_case() {
  local args="$1"; shift
  : > fixtures/sample.tsv
  for row in "$@"; do
    printf '%s\n' "$row" >> fixtures/sample.tsv
  done
  printf '%s\n' "$args" > fixtures/args.txt
}

run_act_case() {
  # Writes progress to stderr (so command substitution can capture just the
  # tempfile path on stdout). Appends the act log to act-result.txt.
  local label="$1" log
  log="$(mktemp)"
  echo "---- CASE: $label ----" >&2
  echo "---- CASE: $label ----" >> "$RESULT_FILE"
  set +e
  act push --rm >"$log" 2>&1
  local ec=$?
  set -e
  cat "$log" >> "$RESULT_FILE"
  echo "---- EXIT: $ec ----" >&2
  echo "---- EXIT: $ec ----" >> "$RESULT_FILE"
  if [[ $ec -ne 0 ]]; then
    echo "---- act failed for case $label ----" >&2
    tail -80 "$log" >&2
    fail "act exit code $ec for case $label"
  fi
  grep -q "Job succeeded" "$log" || fail "no 'Job succeeded' for case $label"
  printf '%s' "$log"
}

assert_contains() {
  local file="$1" needle="$2" label="$3"
  grep -qF -- "$needle" "$file" || {
    echo "--- expected in $label output: $needle ---" >&2
    fail "missing expected output for $label: $needle"
  }
}

# Case A: max-age-days only.
# Two artifacts: one 60 days old (must be deleted), one 1 day old (must be kept).
write_case "--max-age-days 30 --now $NOW" \
  "old.zip	1000	$D60	w1" \
  "new.zip	500	$D1	w1"
logA=$(run_act_case "A-age")
assert_contains "$logA" "DELETE	old.zip" "A-age"
assert_contains "$logA" "reason=age>30d" "A-age"
assert_contains "$logA" "KEEP	new.zip" "A-age"
assert_contains "$logA" "deleted=1" "A-age"
assert_contains "$logA" "retained=1" "A-age"
assert_contains "$logA" "reclaimed_bytes=1000" "A-age"
assert_contains "$logA" "retained_bytes=500" "A-age"
assert_contains "$logA" "mode=execute" "A-age"
pass "Case A (max-age-days)"

# Case B: keep-latest-N per workflow.
# 3 items in w1, keep-latest=1 -> delete 2 oldest.
write_case "--keep-latest 1 --now $NOW" \
  "w1-a	10	$D3	w1" \
  "w1-b	20	$D2	w1" \
  "w1-c	30	$D1	w1"
logB=$(run_act_case "B-keep-latest")
assert_contains "$logB" "DELETE	w1-a" "B-keep-latest"
assert_contains "$logB" "DELETE	w1-b" "B-keep-latest"
assert_contains "$logB" "KEEP	w1-c" "B-keep-latest"
assert_contains "$logB" "reason=beyond-keep-latest-1" "B-keep-latest"
assert_contains "$logB" "deleted=2" "B-keep-latest"
assert_contains "$logB" "retained=1" "B-keep-latest"
assert_contains "$logB" "reclaimed_bytes=30" "B-keep-latest"
assert_contains "$logB" "retained_bytes=30" "B-keep-latest"
pass "Case B (keep-latest)"

# Case C: max-total-size + dry-run.
# 3 x 100B, budget 150 -> evict 2 oldest.
write_case "--max-total-size 150 --dry-run --now $NOW" \
  "a	100	$D3	w1" \
  "b	100	$D2	w1" \
  "c	100	$D1	w1"
logC=$(run_act_case "C-size-dryrun")
assert_contains "$logC" "DELETE	a" "C-size-dryrun"
assert_contains "$logC" "DELETE	b" "C-size-dryrun"
assert_contains "$logC" "KEEP	c" "C-size-dryrun"
assert_contains "$logC" "reason=over-budget>150B" "C-size-dryrun"
assert_contains "$logC" "deleted=2" "C-size-dryrun"
assert_contains "$logC" "retained=1" "C-size-dryrun"
assert_contains "$logC" "reclaimed_bytes=200" "C-size-dryrun"
assert_contains "$logC" "retained_bytes=100" "C-size-dryrun"
assert_contains "$logC" "mode=dry-run" "C-size-dryrun"
pass "Case C (max-total-size + dry-run)"

echo
echo "All harness checks passed. act-result.txt written to $RESULT_FILE"
