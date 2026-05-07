#!/usr/bin/env bash
#
# run-act-tests.sh — execute the artifact-cleanup workflow under nektos/act and
# assert exact expected values for each scenario in the resulting log.
#
# Strategy: a single `act push --rm` runs the whole workflow, which exercises
# (a) the bats suite and (b) three scenario steps with delimited markers
# (=== SCENARIO X ===). We grep between markers and assert exact summary
# numbers against pre-computed values for the fixture.
#
# Why one act run rather than per-scenario containers? The benchmark imposes a
# 3-run cap, and act spin-up dominates wall time. Running everything in one
# pass and slicing the output is faster *and* equivalent: the workflow is
# deterministic (--now freezes the clock), and each scenario step lives in its
# own shell with its own stderr/stdout so failures still localize cleanly.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OUT="$ROOT/act-result.txt"
: > "$OUT"

# Initialize a temp git repo for act so it has a clean event payload, then run
# the workflow on `push`. We use --rm to clean up containers between cases if
# we ever expand to multiple runs.
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cp -r .actrc cleanup.sh tests fixtures .github "$WORKDIR/"
cd "$WORKDIR"
git init -q
git config user.email "ci@example.com"
git config user.name  "ci"
git add -A
git commit -q -m "snapshot for act"

echo "=== act push --rm ===" | tee -a "$OUT"
set +e
act push --rm 2>&1 | tee -a "$OUT"
status="${PIPESTATUS[0]}"
set -e
echo "=== act exit status: $status ===" | tee -a "$OUT"

cd "$ROOT"

if [ "$status" -ne 0 ]; then
  echo "FAIL: act exited non-zero ($status)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertions on captured output
# ---------------------------------------------------------------------------
fails=0
assert_contains() {
  local needle="$1"
  if grep -qF -- "$needle" "$OUT"; then
    echo "PASS: contains '$needle'"
  else
    echo "FAIL: missing '$needle'" >&2
    fails=$((fails + 1))
  fi
}

# Every job must report success.
assert_contains 'Job succeeded'

# bats: 18 tests, all green.
assert_contains '1..18'
assert_contains 'ok 18 script passes shellcheck'

# Scenario A: no policies → 8 artifacts kept, 0 deleted, 0 reclaimed.
assert_contains '=== SCENARIO A ==='
assert_contains 'Mode: execute'
assert_contains 'Total artifacts: 8'
assert_contains 'Kept: 8'

# Scenario B: --max-age-days 90 --keep-latest 1 --max-total-size 10000 --dry-run
# Computed by hand from fixtures/realistic.tsv (see fixture comments):
#   max-age (>90d) drops: build-1, build-2, test-coverage-1, release-bundle (4)
#   keep-latest 1 within workflow 101 then drops build-3 (build-4 is newer)
#   max-total-size: kept total = 500 + 5500 + 250 = 6250 ≤ 10000 → no further drops
# Final: Kept=3, Deleted=5, Reclaimed=1000+2000+5000+7000+1500 = 16500 bytes
assert_contains '=== SCENARIO B ==='
assert_contains 'Mode: dry-run'
assert_contains 'Kept: 3'
assert_contains 'Deleted: 5'
assert_contains 'Space reclaimed: 16500 bytes'

# Scenario C: 4 x 1000B, cap 2500 → drop oldest two; kept total = 2000.
assert_contains '=== SCENARIO C ==='
assert_contains 'Kept: 2'
assert_contains 'Deleted: 2'
assert_contains 'Space reclaimed: 2000 bytes'

if [ "$fails" -gt 0 ]; then
  echo "$fails assertion(s) failed" >&2
  exit 1
fi
echo "All assertions passed."
