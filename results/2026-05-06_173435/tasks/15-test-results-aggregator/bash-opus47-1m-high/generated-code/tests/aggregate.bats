#!/usr/bin/env bats

# Tests for aggregate.sh - the test results aggregator.
# Each function is unit-tested by sourcing aggregate.sh in library mode
# (AGGREGATE_LIB=1 prevents main from running) and calling its functions
# directly.

setup() {
    PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
    SCRIPT="${PROJECT_ROOT}/aggregate.sh"
    FIXTURES="${PROJECT_ROOT}/fixtures"
    TMP="$(mktemp -d)"
    export TMP
}

teardown() {
    rm -rf "${TMP}"
}

# --- Smoke tests -------------------------------------------------------------

@test "aggregate.sh exists and is executable" {
    [ -x "${SCRIPT}" ]
}

@test "aggregate.sh --help prints usage" {
    run "${SCRIPT}" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "aggregate.sh fails with no inputs" {
    run "${SCRIPT}"
    [ "$status" -ne 0 ]
    [[ "$output" == *"error"* || "$output" == *"Error"* || "$output" == *"Usage"* ]]
}

# --- JUnit XML parsing -------------------------------------------------------

@test "parse_junit_file extracts testcase records from a single suite" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    cat > "${TMP}/junit.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="suite-a" tests="3" failures="1" skipped="1" time="1.5">
  <testcase name="test_one" classname="Suite" time="0.1"/>
  <testcase name="test_two" classname="Suite" time="0.2">
    <failure message="boom">stack</failure>
  </testcase>
  <testcase name="test_three" classname="Suite" time="0.3">
    <skipped/>
  </testcase>
</testsuite>
XML
    run parse_junit_file "${TMP}/junit.xml"
    [ "$status" -eq 0 ]
    # Each line: status<TAB>duration<TAB>name
    [[ "$output" == *$'passed\t0.1\tSuite::test_one'* ]]
    [[ "$output" == *$'failed\t0.2\tSuite::test_two'* ]]
    [[ "$output" == *$'skipped\t0.3\tSuite::test_three'* ]]
}

@test "parse_junit_file handles testsuites root element" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    cat > "${TMP}/junit.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite-a">
    <testcase name="alpha" classname="A" time="0.5"/>
  </testsuite>
  <testsuite name="suite-b">
    <testcase name="beta" classname="B" time="0.6">
      <error message="oops"/>
    </testcase>
  </testsuite>
</testsuites>
XML
    run parse_junit_file "${TMP}/junit.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'passed\t0.5\tA::alpha'* ]]
    [[ "$output" == *$'failed\t0.6\tB::beta'* ]]
}

@test "parse_junit_file rejects malformed input" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    echo "not xml" > "${TMP}/bad.xml"
    run parse_junit_file "${TMP}/bad.xml"
    [ "$status" -ne 0 ]
}

@test "parse_junit_file errors when file missing" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    run parse_junit_file "${TMP}/does-not-exist.xml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* || "$output" == *"No such"* ]]
}

# --- JSON parsing ------------------------------------------------------------

@test "parse_json_file extracts testcase records" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    cat > "${TMP}/results.json" <<'JSON'
{
  "tests": [
    {"name": "alpha", "suite": "Json", "status": "passed", "duration": 0.4},
    {"name": "beta", "suite": "Json", "status": "failed", "duration": 0.7},
    {"name": "gamma", "suite": "Json", "status": "skipped", "duration": 0.0}
  ]
}
JSON
    run parse_json_file "${TMP}/results.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'passed\t0.4\tJson::alpha'* ]]
    [[ "$output" == *$'failed\t0.7\tJson::beta'* ]]
    [[ "$output" == *$'skipped\t0'*$'\tJson::gamma'* ]]
}

@test "parse_json_file rejects invalid json" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    echo "{ not json" > "${TMP}/bad.json"
    run parse_json_file "${TMP}/bad.json"
    [ "$status" -ne 0 ]
}

# --- File-type detection -----------------------------------------------------

@test "detect_format identifies xml by extension" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    run detect_format "results.xml"
    [ "$status" -eq 0 ]
    [ "$output" = "junit" ]
}

@test "detect_format identifies json by extension" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    run detect_format "results.json"
    [ "$status" -eq 0 ]
    [ "$output" = "json" ]
}

@test "detect_format errors on unknown extension" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    run detect_format "results.txt"
    [ "$status" -ne 0 ]
}

# --- Aggregation -------------------------------------------------------------

# compute_totals reads TSV records (status<TAB>duration<TAB>name) on stdin
# and emits "passed=N\nfailed=N\nskipped=N\ntotal=N\nduration=X" key=value lines.
@test "compute_totals sums passed/failed/skipped and duration" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    records=$'passed\t0.1\tA::a\nfailed\t0.2\tA::b\nskipped\t0\tA::c\npassed\t0.3\tA::d'
    run bash -c "echo -e '${records}' | { source '${SCRIPT}'; compute_totals; }"
    [ "$status" -eq 0 ]
    [[ "$output" == *"passed=2"* ]]
    [[ "$output" == *"failed=1"* ]]
    [[ "$output" == *"skipped=1"* ]]
    [[ "$output" == *"total=4"* ]]
    [[ "$output" == *"duration=0.6"* ]]
}

# detect_flaky reads TSV records and emits flaky-test names (one per line).
# A test is flaky if it appears at least once with status=passed AND at least
# once with status=failed across the input set.
@test "detect_flaky finds tests with mixed pass/fail outcomes" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    records=$'passed\t0.1\tA::stable\npassed\t0.1\tA::flaky\nfailed\t0.2\tA::flaky\nfailed\t0.2\tA::broken'
    run bash -c "echo -e '${records}' | { source '${SCRIPT}'; detect_flaky; }"
    [ "$status" -eq 0 ]
    [[ "$output" == *"A::flaky"* ]]
    [[ "$output" != *"A::stable"* ]]
    [[ "$output" != *"A::broken"* ]]
}

# --- Markdown summary --------------------------------------------------------

@test "render_markdown emits a summary table with totals" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    cat > "${TMP}/totals" <<EOF
passed=10
failed=2
skipped=1
total=13
duration=4.5
EOF
    run render_markdown "${TMP}/totals" "${TMP}/empty-flaky"
    : > "${TMP}/empty-flaky"
    run render_markdown "${TMP}/totals" "${TMP}/empty-flaky"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results"* ]]
    [[ "$output" == *"Passed"* ]]
    [[ "$output" == *"10"* ]]
    [[ "$output" == *"Failed"* ]]
    [[ "$output" == *"2"* ]]
    [[ "$output" == *"4.5"* ]]
}

@test "render_markdown shows flaky tests when present" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    cat > "${TMP}/totals" <<EOF
passed=3
failed=1
skipped=0
total=4
duration=1.0
EOF
    printf 'A::flaky\nB::shaky\n' > "${TMP}/flaky"
    run render_markdown "${TMP}/totals" "${TMP}/flaky"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Flaky"* ]]
    [[ "$output" == *"A::flaky"* ]]
    [[ "$output" == *"B::shaky"* ]]
}

@test "render_markdown omits flaky section when none" {
    # shellcheck disable=SC1090
    AGGREGATE_LIB=1 source "${SCRIPT}"
    cat > "${TMP}/totals" <<EOF
passed=3
failed=0
skipped=0
total=3
duration=1.0
EOF
    : > "${TMP}/flaky"
    run render_markdown "${TMP}/totals" "${TMP}/flaky"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Flaky Tests"* ]]
}

# --- End-to-end CLI ----------------------------------------------------------

@test "aggregate.sh produces expected markdown for sample fixtures" {
    # The fixtures directory contains representative junit + json files
    # with overlap that yields one flaky test (Calc::test_divide).
    run "${SCRIPT}" "${FIXTURES}/run1.xml" "${FIXTURES}/run2.xml" "${FIXTURES}/run3.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results"* ]]
    [[ "$output" == *"Calc::test_divide"* ]]   # flaky
    [[ "$output" == *"Total"* ]]
}

@test "aggregate.sh accepts a directory and discovers files" {
    run "${SCRIPT}" "${FIXTURES}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results"* ]]
}

@test "aggregate.sh writes to GITHUB_STEP_SUMMARY when set" {
    summary_file="${TMP}/summary.md"
    GITHUB_STEP_SUMMARY="${summary_file}" run "${SCRIPT}" "${FIXTURES}"
    [ "$status" -eq 0 ]
    [ -s "${summary_file}" ]
    grep -q "# Test Results" "${summary_file}"
}

@test "aggregate.sh exits non-zero when there are failed tests and --fail-on-failures is set" {
    run "${SCRIPT}" --fail-on-failures "${FIXTURES}"
    [ "$status" -ne 0 ]
}

# --- Lint ---------------------------------------------------------------------

@test "aggregate.sh passes shellcheck" {
    run shellcheck "${SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "aggregate.sh passes bash -n syntax check" {
    run bash -n "${SCRIPT}"
    [ "$status" -eq 0 ]
}
