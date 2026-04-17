#!/usr/bin/env bats
#
# Act output validation. The heavy lifting (invoking `act push --rm` per
# test case) is done by tests/run-act-cases.sh which writes delimited
# sections to act-result.txt. These tests parse that file and assert the
# exact expected strings appear for each case.
#
# Run `tests/run-act-cases.sh` once before running this bats file. A fresh
# run-act-cases invocation truncates act-result.txt and re-populates it.

setup_file() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  ACT_RESULT="${PROJECT_ROOT}/act-result.txt"
  export PROJECT_ROOT ACT_RESULT
}

# Print the delimited section for CASE ($1) out of act-result.txt. Returns
# empty output when the case is missing.
_case_section() {
  # Match either the exact case name or a case label that starts with
  # "<case>-..." (allowing descriptive suffixes like "case1-all-green").
  awk -v c="$1" '
    $0 ~ ("^CASE: " c "(-|$)")     { inside = 1; next }
    inside && $0 ~ ("^END CASE: " c "(-|$)") { inside = 0 }
    inside { print }
  ' "$ACT_RESULT"
}

_job_succeeded_count() {
  grep -c 'Job succeeded' <<<"$1" || true
}

@test "act-result.txt exists and is non-empty" {
  [ -s "$ACT_RESULT" ]
}

@test "case1 (all green, mixed formats) — expected totals and no flaky tests" {
  section="$(_case_section "case1")"
  [ -n "$section" ]
  # Act exited 0 for the case.
  [[ "$section" == *"ACT_EXIT: 0"* ]]
  # Every job shows "Job succeeded" — the workflow has 2 jobs.
  jobs="$(_job_succeeded_count "$section")"
  [ "$jobs" -ge 2 ]
  # 23 unit tests ran (TAP plan line).
  [[ "$section" == *"1..23"* ]]
  # Summary content matches the expected case1 output.
  [[ "$section" == *"**Status**: PASSED"* ]]
  [[ "$section" == *"| 2 | 4 | 0 | 0 | 0.64 |"* ]]
  [[ "$section" == *"No flaky tests detected"* ]]
  [[ "$section" == *"AGGREGATOR_EXIT=0"* ]]
}

@test "case2 (failures + flaky) — expected totals and flaky row" {
  section="$(_case_section "case2")"
  [ -n "$section" ]
  [[ "$section" == *"ACT_EXIT: 0"* ]]
  jobs="$(_job_succeeded_count "$section")"
  [ "$jobs" -ge 2 ]
  [[ "$section" == *"1..23"* ]]
  [[ "$section" == *"**Status**: FAILED"* ]]
  [[ "$section" == *"| 2 | 2 | 4 | 0 | 1.02 |"* ]]
  [[ "$section" == *"| Core | test_a | 2 | 1 |"* ]]
  # Aggregator exits 1 because the fixture has test failures; the step
  # captures that exit code without propagating it to the job's status.
  [[ "$section" == *"AGGREGATOR_EXIT=1"* ]]
}

@test "case3 (skipped-heavy) — expected totals with no flaky tests" {
  section="$(_case_section "case3")"
  [ -n "$section" ]
  [[ "$section" == *"ACT_EXIT: 0"* ]]
  jobs="$(_job_succeeded_count "$section")"
  [ "$jobs" -ge 2 ]
  [[ "$section" == *"1..23"* ]]
  [[ "$section" == *"**Status**: PASSED"* ]]
  [[ "$section" == *"| 3 | 1 | 0 | 2 | 0.5 |"* ]]
  [[ "$section" == *"No flaky tests detected"* ]]
  [[ "$section" == *"AGGREGATOR_EXIT=0"* ]]
}
