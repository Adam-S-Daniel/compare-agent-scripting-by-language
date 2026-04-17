#!/usr/bin/env bats
#
# Unit tests for bin/aggregate.sh — red/green TDD.
# Functions are sourced from aggregate.sh and emit TSV records:
#   run_id<TAB>suite<TAB>name<TAB>status<TAB>duration

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SCRIPT="${PROJECT_ROOT}/bin/aggregate.sh"
  FIXTURES="${PROJECT_ROOT}/tests/fixtures"
  export PROJECT_ROOT SCRIPT FIXTURES
  # Disable set -e triggering on source
  # shellcheck disable=SC1090
  source "$SCRIPT"
}

# ---- parse_json ----

@test "parse_json emits one TSV record per test" {
  run parse_json "$FIXTURES/simple.json"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "parse_json record has 5 tab-separated fields" {
  run parse_json "$FIXTURES/simple.json"
  [ "$status" -eq 0 ]
  # Each line must have 4 tabs (=> 5 fields)
  for line in "${lines[@]}"; do
    tab_count=$(awk -F'\t' '{print NF-1}' <<<"$line")
    [ "$tab_count" -eq 4 ]
  done
}

@test "parse_json extracts run_id, suite, name, status, duration" {
  run parse_json "$FIXTURES/simple.json"
  [ "$status" -eq 0 ]
  # First record is the passing test_add
  [ "${lines[0]}" = $'linux-py310\tCalc\ttest_add\tpassed\t0.12' ]
  [ "${lines[1]}" = $'linux-py310\tCalc\ttest_sub\tfailed\t0.34' ]
}

@test "parse_json errors on missing file" {
  run parse_json /nonexistent/path.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# ---- parse_junit ----

@test "parse_junit emits one TSV record per testcase" {
  run parse_junit "$FIXTURES/simple.xml"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "parse_junit classifies passed/failed/skipped correctly" {
  run parse_junit "$FIXTURES/simple.xml"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'simple\tCalc\ttest_add\tpassed\t0.10' ]
  [ "${lines[1]}" = $'simple\tCalc\ttest_sub\tfailed\t0.30' ]
  [ "${lines[2]}" = $'simple\tCalc\ttest_mul\tskipped\t0.06' ]
}

@test "parse_junit uses filename (without extension) as run_id" {
  run parse_junit "$FIXTURES/simple.xml"
  [ "$status" -eq 0 ]
  # All records have run_id = "simple"
  for line in "${lines[@]}"; do
    run_id="${line%%$'\t'*}"
    [ "$run_id" = "simple" ]
  done
}

@test "parse_junit errors on missing file" {
  run parse_junit /nonexistent/file.xml
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# ---- collect_results ----

@test "collect_results walks a directory and parses both formats" {
  # simple.xml has 3 tests, simple.json has 2 → total 5 records
  run collect_results "$FIXTURES"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
}

@test "collect_results errors on missing directory" {
  run collect_results /nonexistent/dir
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "collect_results exits 0 with empty output on directory with no matching files" {
  local tmp; tmp="$(mktemp -d)"
  run collect_results "$tmp"
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- compute_totals ----
#
# Given a TSV stream on stdin, emit five key=value lines on stdout:
#   total=<int> passed=<int> failed=<int> skipped=<int> duration=<float>
# "total" counts distinct (suite, name) pairs; "passed/failed/skipped" count
# row-level outcomes. Duration is the sum across all rows.

@test "compute_totals reports totals from a TSV stream" {
  # Combined fixture rows:
  #   xml  test_add passed 0.10 | test_sub failed 0.30 | test_mul skipped 0.06
  #   json test_add passed 0.12 | test_sub failed 0.34
  # passed=2, failed=2, skipped=1, total (distinct)=3, duration=0.92
  run bash -c "source '$SCRIPT' && collect_results '$FIXTURES' | compute_totals"
  [ "$status" -eq 0 ]
  [[ "$output" == *"passed=2"* ]]
  [[ "$output" == *"failed=2"* ]]
  [[ "$output" == *"skipped=1"* ]]
  [[ "$output" == *"total=3"* ]]
  [[ "$output" == *"duration=0.92"* ]]
}

@test "compute_totals handles empty stream" {
  run bash -c "source '$SCRIPT' && printf '' | compute_totals"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total=0"* ]]
  [[ "$output" == *"passed=0"* ]]
  [[ "$output" == *"failed=0"* ]]
  [[ "$output" == *"skipped=0"* ]]
  [[ "$output" == *"duration=0"* ]]
}

# ---- compute_flaky ----
#
# A test is flaky if (suite, name) has both a "passed" run and a "failed"
# run in the input stream. Emit one TSV line per flaky test:
#   suite<TAB>name<TAB>passes<TAB>fails

@test "compute_flaky identifies tests that pass in one run and fail in another" {
  # Build an in-memory stream: two runs of same test, different outcomes
  stream="$(printf 'run1\tCalc\ttest_a\tpassed\t0.1\nrun2\tCalc\ttest_a\tfailed\t0.1\nrun1\tCalc\ttest_b\tpassed\t0.1\nrun2\tCalc\ttest_b\tpassed\t0.1\n')"
  run bash -c "source '$SCRIPT' && printf '%s\n' '$stream' | compute_flaky"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'Calc\ttest_a\t1\t1' ]
}

@test "compute_flaky emits nothing when no test is flaky" {
  stream="$(printf 'run1\tCalc\ttest_a\tpassed\t0.1\nrun2\tCalc\ttest_a\tpassed\t0.1\n')"
  run bash -c "source '$SCRIPT' && printf '%s\n' '$stream' | compute_flaky"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "compute_flaky ignores skipped status when determining flakiness" {
  # passed + skipped should NOT be flaky; passed + failed should be.
  stream="$(printf 'run1\tCalc\ttest_a\tpassed\t0.1\nrun2\tCalc\ttest_a\tskipped\t0.0\n')"
  run bash -c "source '$SCRIPT' && printf '%s\n' '$stream' | compute_flaky"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- generate_markdown ----
#
# Produce a GitHub-Actions-compatible markdown job summary from totals +
# flaky-tests information. Expected sections:
#   # heading, totals table (Total/Passed/Failed/Skipped/Duration), and a
#   flaky-tests section (or explicit "No flaky tests detected" message).

@test "generate_markdown emits a heading and totals table" {
  run bash -c "source '$SCRIPT' && generate_markdown '$FIXTURES'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Test Results Summary"* ]]
  [[ "$output" == *"| Total |"* ]]
  [[ "$output" == *"| 3 |"* ]]  # total count
  [[ "$output" == *"| 2 |"* ]]  # passed or failed both 2
  [[ "$output" == *"0.92"* ]]   # duration
}

@test "generate_markdown flags overall status as FAILED when there are failures" {
  run bash -c "source '$SCRIPT' && generate_markdown '$FIXTURES'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status"*"FAILED"* ]]
}

@test "generate_markdown indicates no flaky tests when none detected" {
  # The baseline fixture has one run per format, so nothing is flaky.
  run bash -c "source '$SCRIPT' && generate_markdown '$FIXTURES'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No flaky tests detected"* ]]
}

@test "generate_markdown lists flaky tests when detected" {
  local tmp; tmp="$(mktemp -d)"
  # Create two JSON files so that test_a is flaky.
  cat >"$tmp/run1.json" <<'JSON'
{ "run_id": "run1", "tests": [ { "suite": "S", "name": "test_a", "status": "passed", "duration": 0.1 } ] }
JSON
  cat >"$tmp/run2.json" <<'JSON'
{ "run_id": "run2", "tests": [ { "suite": "S", "name": "test_a", "status": "failed", "duration": 0.1 } ] }
JSON
  run bash -c "source '$SCRIPT' && generate_markdown '$tmp'"
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Flaky Tests"* ]]
  [[ "$output" == *"test_a"* ]]
  [[ "$output" != *"No flaky tests detected"* ]]
}

# ---- CLI ----
#
# Running the script directly should produce the markdown summary on stdout
# and return 0 when all tests pass, non-zero when any fail.

@test "CLI prints summary and exits non-zero on failures" {
  run bash "$SCRIPT" "$FIXTURES"
  [ "$status" -ne 0 ]
  [[ "$output" == *"# Test Results Summary"* ]]
}

@test "CLI --help prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "CLI writes to --output file when requested" {
  local out; out="$(mktemp)"
  # Use a passing-only fixture so exit code is 0.
  local tmp; tmp="$(mktemp -d)"
  cat >"$tmp/ok.json" <<'JSON'
{ "run_id": "ok", "tests": [ { "suite": "S", "name": "test_ok", "status": "passed", "duration": 0.1 } ] }
JSON
  run bash "$SCRIPT" --output "$out" "$tmp"
  [ "$status" -eq 0 ]
  [ -s "$out" ]
  grep -q "Test Results Summary" "$out"
  rm -rf "$tmp" "$out"
}
