#!/usr/bin/env bats
#
# Tests for aggregate.sh — test result aggregator.
# Approach: TDD. Each test targets one slice of behavior — parsing
# JUnit XML, parsing JSON, aggregating across files, flaky detection,
# and markdown summary generation.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../aggregate.sh"
    FIXTURES="$BATS_TEST_DIRNAME/../fixtures"
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "shows usage when no args" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "parses a single JUnit XML file and reports totals" {
    run "$SCRIPT" --format text "$FIXTURES/run1.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total=5"* ]]
    [[ "$output" == *"passed=3"* ]]
    [[ "$output" == *"failed=1"* ]]
    [[ "$output" == *"skipped=1"* ]]
}

@test "parses a single JSON file and reports totals" {
    run "$SCRIPT" --format text "$FIXTURES/run1.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total=4"* ]]
    [[ "$output" == *"passed=3"* ]]
    [[ "$output" == *"failed=1"* ]]
    [[ "$output" == *"skipped=0"* ]]
}

@test "aggregates multiple files (matrix build) and sums totals" {
    run "$SCRIPT" --format text "$FIXTURES/run1.xml" "$FIXTURES/run2.xml"
    [ "$status" -eq 0 ]
    # run1: 5 tests, run2: 5 tests => 10 total
    [[ "$output" == *"total=10"* ]]
}

@test "aggregates mixed XML and JSON formats" {
    run "$SCRIPT" --format text "$FIXTURES/run1.xml" "$FIXTURES/run1.json"
    [ "$status" -eq 0 ]
    # 5 + 4 = 9
    [[ "$output" == *"total=9"* ]]
}

@test "reports total duration as a sum across files" {
    run "$SCRIPT" --format text "$FIXTURES/run1.xml" "$FIXTURES/run2.xml"
    [ "$status" -eq 0 ]
    # run1 duration=1.5, run2 duration=2.5 => 4.0s
    [[ "$output" == *"duration=4.00s"* ]]
}

@test "identifies flaky tests (passed in some, failed in others)" {
    run "$SCRIPT" --format text "$FIXTURES/run1.xml" "$FIXTURES/run2.xml"
    [ "$status" -eq 0 ]
    # test_login passes in run1, fails in run2 => flaky
    [[ "$output" == *"flaky=1"* ]]
    [[ "$output" == *"test_login"* ]]
}

@test "does not mark consistent failures as flaky" {
    run "$SCRIPT" --format text "$FIXTURES/run1.xml"
    [ "$status" -eq 0 ]
    # single file — can't be flaky
    [[ "$output" == *"flaky=0"* ]]
}

@test "generates markdown output with --format markdown" {
    run "$SCRIPT" --format markdown "$FIXTURES/run1.xml" "$FIXTURES/run2.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary"* ]]
    [[ "$output" == *"| Metric |"* ]]
    [[ "$output" == *"Passed"* ]]
    [[ "$output" == *"Failed"* ]]
    [[ "$output" == *"Skipped"* ]]
    [[ "$output" == *"Duration"* ]]
}

@test "markdown output includes flaky tests section" {
    run "$SCRIPT" --format markdown "$FIXTURES/run1.xml" "$FIXTURES/run2.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Flaky Tests"* ]]
    [[ "$output" == *"test_login"* ]]
}

@test "markdown output has no flaky section when none detected" {
    run "$SCRIPT" --format markdown "$FIXTURES/run1.xml"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Flaky Tests"* ]] || [[ "$output" == *"No flaky tests"* ]]
}

@test "writes to GITHUB_STEP_SUMMARY when set" {
    local summary="$TMPDIR/summary.md"
    GITHUB_STEP_SUMMARY="$summary" run "$SCRIPT" --format markdown "$FIXTURES/run1.xml"
    [ "$status" -eq 0 ]
    [ -f "$summary" ]
    run cat "$summary"
    [[ "$output" == *"Test Results Summary"* ]]
}

@test "errors on non-existent input file" {
    run "$SCRIPT" --format text "$TMPDIR/nonexistent.xml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such"* ]]
}

@test "errors on unsupported file extension" {
    echo "garbage" > "$TMPDIR/foo.txt"
    run "$SCRIPT" --format text "$TMPDIR/foo.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unsupported"* ]] || [[ "$output" == *"format"* ]]
}

@test "errors on malformed JSON" {
    echo '{ not valid json' > "$TMPDIR/bad.json"
    run "$SCRIPT" --format text "$TMPDIR/bad.json"
    [ "$status" -ne 0 ]
}

@test "handles empty testsuite gracefully" {
    cat > "$TMPDIR/empty.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="empty" tests="0" failures="0" skipped="0" time="0">
</testsuite>
EOF
    run "$SCRIPT" --format text "$TMPDIR/empty.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total=0"* ]]
}

@test "pass rate is computed correctly in markdown output" {
    run "$SCRIPT" --format markdown "$FIXTURES/run1.xml"
    [ "$status" -eq 0 ]
    # 3 passed / (3 passed + 1 failed) = 75% (skipped excluded)
    [[ "$output" == *"75"* ]]
}
