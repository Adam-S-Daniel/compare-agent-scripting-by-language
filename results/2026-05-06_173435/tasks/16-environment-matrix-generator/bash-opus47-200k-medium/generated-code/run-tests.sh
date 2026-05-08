#!/usr/bin/env bash
# run-tests.sh - drive the workflow through act and assert on its output.
#
# All tests must execute through the GitHub Actions workflow. We invoke
# `act push --rm` once and capture its full output to act-result.txt, then
# scan it for the expected per-test-case results emitted by the workflow.

set -euo pipefail

cd "$(dirname "$0")"

RESULT="act-result.txt"
: > "$RESULT"

# --- Workflow structure tests (run before act, instant) ----------------------

echo "[harness] structure: workflow file exists" | tee -a "$RESULT"
test -f .github/workflows/environment-matrix-generator.yml

echo "[harness] structure: actionlint passes" | tee -a "$RESULT"
actionlint .github/workflows/environment-matrix-generator.yml

echo "[harness] structure: workflow references matrix_gen.sh" | tee -a "$RESULT"
grep -q 'matrix_gen.sh' .github/workflows/environment-matrix-generator.yml

echo "[harness] structure: triggers include push, pull_request, workflow_dispatch, schedule" | tee -a "$RESULT"
for trig in push pull_request workflow_dispatch schedule; do
  grep -qE "^[[:space:]]*${trig}:" .github/workflows/environment-matrix-generator.yml
done

echo "[harness] structure: matrix_gen.sh and tests/matrix_gen.bats exist" | tee -a "$RESULT"
test -f matrix_gen.sh
test -f tests/matrix_gen.bats

# --- Run the workflow under act ----------------------------------------------

echo "[harness] running: act push --rm" | tee -a "$RESULT"
echo "===== BEGIN act push --rm =====" >> "$RESULT"
set +e
act push --rm --pull=false >>"$RESULT" 2>&1
act_status=$?
set -e
echo "===== END act push (exit=$act_status) =====" >> "$RESULT"

if (( act_status != 0 )); then
  echo "[harness] FAIL: act exited $act_status (see $RESULT)" >&2
  exit 1
fi

# --- Assert on captured output -----------------------------------------------

assert_in_result() {
  local pat="$1" desc="$2"
  if grep -qE "$pat" "$RESULT"; then
    echo "[harness] PASS: $desc"
  else
    echo "[harness] FAIL: $desc (pattern: $pat)" >&2
    exit 1
  fi
}

# Each line matches output produced by act for the workflow's job/steps.
assert_in_result 'Job succeeded' 'act reports Job succeeded'
assert_in_result 'ok 11 fail-fast defaults to true' 'all 11 bats tests passed inside act'
# Confirm no failures appear (negative assertion)
if grep -qE 'not ok [0-9]+ ' "$RESULT"; then
  echo "[harness] FAIL: bats reported a failing test inside act" >&2
  exit 1
fi
echo "[harness] PASS: no failing bats tests in act output"
assert_in_result 'simple\.json output' 'demo step ran for simple.json'
assert_in_result 'three_dim\.json output' 'demo step ran for three_dim.json'
assert_in_result 'with_exclude\.json output' 'demo step ran for with_exclude.json'
# Verify the simple matrix really produced the 4 expected combos in the demo step.
# The demo prints raw JSON; check exact expected key/value pairs appear.
assert_in_result '"os": "ubuntu-latest"' 'demo output contains ubuntu-latest combination'
assert_in_result '"os": "macos-latest"' 'demo output contains macos-latest combination'
assert_in_result '"node": "18"' 'demo output contains node 18'
assert_in_result '"node": "20"' 'demo output contains node 20'

echo "[harness] All assertions passed."
