#!/usr/bin/env bash
# verify.sh - re-run only the assertion phase against an existing act-result.txt.
# Use this to validate harness assertions without spending another act invocation.
set -euo pipefail
cd "$(dirname "$0")"
RESULT="act-result.txt"
test -s "$RESULT" || { echo "no $RESULT" >&2; exit 1; }

assert_in_result() {
  local pat="$1" desc="$2"
  if grep -qE "$pat" "$RESULT"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (pattern: $pat)" >&2
    exit 1
  fi
}

assert_in_result 'Job succeeded' 'act reports Job succeeded'
assert_in_result 'ok 11 fail-fast defaults to true' 'all 11 bats tests passed'
if grep -qE 'not ok [0-9]+ ' "$RESULT"; then
  echo "FAIL: bats reported a failing test" >&2; exit 1
fi
echo "PASS: no failing bats tests"
assert_in_result 'simple\.json output' 'demo simple.json'
assert_in_result 'three_dim\.json output' 'demo three_dim.json'
assert_in_result 'with_exclude\.json output' 'demo with_exclude.json'
assert_in_result '"os": "ubuntu-latest"' 'ubuntu-latest combination'
assert_in_result '"os": "macos-latest"' 'macos-latest combination'
assert_in_result '"node": "18"' 'node 18'
assert_in_result '"node": "20"' 'node 20'
echo "All assertions passed."
