#!/usr/bin/env bats
# Tests for the test-results aggregator. Each test follows red/green TDD:
# the test was written first; the script grew just enough code to pass it.

setup() {
    BATS_TEST_TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    AGGREGATE="$PROJECT_ROOT/aggregate.sh"
    FIXTURES="$PROJECT_ROOT/tests/fixtures"
    export PROJECT_ROOT AGGREGATE FIXTURES
}

# --- parse-junit ------------------------------------------------------------

@test "parse-junit emits one canonical line per testcase for an all-pass file" {
    run "$AGGREGATE" parse-junit "$FIXTURES/junit-pass.xml"
    [ "$status" -eq 0 ]
    # canonical line format: <classname>::<name>|<status>|<duration>
    [ "${lines[0]}" = "alpha.MathTests::adds_numbers|passed|0.500" ]
    [ "${lines[1]}" = "alpha.MathTests::multiplies_numbers|passed|1.000" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "parse-junit distinguishes passed / failed / error / skipped" {
    run "$AGGREGATE" parse-junit "$FIXTURES/junit-mixed.xml"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "beta.AuthTests::login_succeeds|passed|0.250" ]
    [ "${lines[1]}" = "beta.AuthTests::login_invalid_password|failed|0.500" ]
    # <error> is treated as a failure for aggregation purposes
    [ "${lines[2]}" = "beta.AuthTests::oauth_callback_handles_timeout|failed|2.000" ]
    [ "${lines[3]}" = "beta.AuthTests::legacy_session_lookup|skipped|0.250" ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "parse-junit fails loudly when the file does not exist" {
    run "$AGGREGATE" parse-junit "$FIXTURES/does-not-exist.xml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"file not found"* ]]
}

# --- parse-json -------------------------------------------------------------

@test "parse-json normalizes status synonyms (PASS -> passed)" {
    run "$AGGREGATE" parse-json "$FIXTURES/results-pass.json"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "ui.WidgetTests::renders_widget|passed|0.42" ]
    [ "${lines[1]}" = "ui.DashboardTests::renders_dashboard|passed|1.10" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "parse-json handles failed/skipped and missing classname" {
    run "$AGGREGATE" parse-json "$FIXTURES/results-mixed.json"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "ui.WidgetTests::renders_widget|passed|0.42" ]
    [ "${lines[1]}" = "ui.FormTests::submits_form|failed|1.75" ]
    [ "${lines[2]}" = "ui.LegacyTests::obsolete_path|skipped|0.0" ]
    # missing classname falls through to the bare name
    [ "${lines[3]}" = "missing_class_test|failed|0.30" ]
}

@test "parse autodetects format from extension" {
    run "$AGGREGATE" parse "$FIXTURES/junit-pass.xml"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "alpha.MathTests::adds_numbers|passed|0.500" ]]

    run "$AGGREGATE" parse "$FIXTURES/results-pass.json"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "ui.WidgetTests::renders_widget|passed|0.42" ]]
}

# --- summary: totals --------------------------------------------------------

# The four shard fixtures simulate a 2x2 matrix build (auth/data shards
# in JUnit XML / JSON formats). Counts:
#   shard-a.xml:  3 passed
#   shard-b.xml:  1 passed, 1 failed, 1 skipped
#   shard-c.json: 2 passed, 1 failed
#   shard-d.json: 1 passed, 2 failed
# Totals: passed=7, failed=4, skipped=1, duration=9.200
# Flaky: auth.LoginTests::flaky_login, data.SyncTests::flaky_sync

@test "summary computes totals across XML and JSON inputs" {
    run "$AGGREGATE" summary \
        "$FIXTURES/shard-a.xml" "$FIXTURES/shard-b.xml" \
        "$FIXTURES/shard-c.json" "$FIXTURES/shard-d.json"
    [ "$status" -eq 0 ]

    # Spot-check exact numeric values in the markdown totals table.
    [[ "$output" == *"| Total tests | 12 |"* ]]
    [[ "$output" == *"| Passed | 7 |"* ]]
    [[ "$output" == *"| Failed | 4 |"* ]]
    [[ "$output" == *"| Skipped | 1 |"* ]]
    [[ "$output" == *"| Flaky | 2 |"* ]]
    [[ "$output" == *"| Duration (s) | 9.200 |"* ]]
    [[ "$output" == *"| Files aggregated | 4 |"* ]]
}

@test "summary shows FAILED status emoji when any test fails" {
    run "$AGGREGATE" summary "$FIXTURES/shard-a.xml" "$FIXTURES/shard-b.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary :x:"* ]]
    [[ "$output" == *"**Status:** FAILED"* ]]
}

@test "summary shows PASSED status when everything passes" {
    run "$AGGREGATE" summary "$FIXTURES/junit-pass.xml" "$FIXTURES/results-pass.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary :white_check_mark:"* ]]
    [[ "$output" == *"**Status:** PASSED"* ]]
}

# --- summary: flaky detection ---------------------------------------------

@test "summary identifies tests that pass in one run and fail in another" {
    run "$AGGREGATE" summary \
        "$FIXTURES/shard-a.xml" "$FIXTURES/shard-b.xml" \
        "$FIXTURES/shard-c.json" "$FIXTURES/shard-d.json"
    [ "$status" -eq 0 ]
    # Both flaky tests appear in the Flaky tests section.
    [[ "$output" == *'`auth.LoginTests::flaky_login`'* ]]
    [[ "$output" == *'`data.SyncTests::flaky_sync`'* ]]
    # Tests that always pass or always fail are NOT flaky.
    [[ "$output" != *'`auth.LoginTests::login_succeeds`'* ]]
    [[ "$output" != *'`data.SyncTests::always_failing_legacy`'* ]]
}

@test "summary reports 'No flaky tests detected' when none are flaky" {
    # Only one shard means a test cannot be both passed and failed.
    run "$AGGREGATE" summary "$FIXTURES/shard-a.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"_No flaky tests detected._"* ]]
}

# --- summary: per-file breakdown ------------------------------------------

@test "summary includes a per-file breakdown table" {
    run "$AGGREGATE" summary \
        "$FIXTURES/shard-a.xml" "$FIXTURES/shard-b.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| shard-a.xml | 3 | 0 | 0 |"* ]]
    [[ "$output" == *"| shard-b.xml | 1 | 1 | 1 |"* ]]
}

# --- markdown shape --------------------------------------------------------

@test "summary output contains the four required sections" {
    run "$AGGREGATE" summary "$FIXTURES/shard-a.xml" "$FIXTURES/shard-b.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary"* ]]
    [[ "$output" == *"## Totals"* ]]
    [[ "$output" == *"## Per-file breakdown"* ]]
    [[ "$output" == *"## Flaky tests"* ]]
}

@test "summary errors when no input files are provided" {
    run "$AGGREGATE" summary
    [ "$status" -ne 0 ]
    [[ "$output" == *"at least one input file"* ]]
}
