#!/usr/bin/env bats
# Tests for the test-results aggregator script.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../aggregate.sh"
    TMPDIR="$(mktemp -d)"
    export TMPDIR
}

teardown() {
    rm -rf "$TMPDIR"
}

# --- parse_junit: emits one "name<TAB>status<TAB>duration" record per testcase ---
@test "parse_junit extracts passed/failed/skipped testcases" {
    cat > "$TMPDIR/junit.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suiteA" tests="3" failures="1" skipped="1" time="0.300">
    <testcase classname="a" name="test_ok" time="0.100"/>
    <testcase classname="a" name="test_fail" time="0.100"><failure message="x">boom</failure></testcase>
    <testcase classname="a" name="test_skip" time="0.100"><skipped/></testcase>
  </testsuite>
</testsuites>
EOF
    run bash "$SCRIPT" parse_junit "$TMPDIR/junit.xml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_ok"$'\t'"passed"$'\t'"0.100"* ]]
    [[ "$output" == *"test_fail"$'\t'"failed"$'\t'"0.100"* ]]
    [[ "$output" == *"test_skip"$'\t'"skipped"$'\t'"0.100"* ]]
}

@test "parse_junit errors on missing file" {
    run bash "$SCRIPT" parse_junit "$TMPDIR/missing.xml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# --- parse_json: standard JSON format {"tests": [{"name","status","duration"}]} ---
@test "parse_json extracts test records" {
    cat > "$TMPDIR/results.json" <<'EOF'
{"tests":[
  {"name":"t1","status":"passed","duration":0.5},
  {"name":"t2","status":"failed","duration":0.7},
  {"name":"t3","status":"skipped","duration":0.0}
]}
EOF
    run bash "$SCRIPT" parse_json "$TMPDIR/results.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"t1"$'\t'"passed"$'\t'"0.5"* ]]
    [[ "$output" == *"t2"$'\t'"failed"* ]]
    [[ "$output" == *"t3"$'\t'"skipped"* ]]
}

# --- aggregate: totals across multiple files + flaky detection ---
@test "aggregate produces totals and flaky list" {
    mkdir -p "$TMPDIR/r1" "$TMPDIR/r2"
    cat > "$TMPDIR/r1/j.xml" <<'EOF'
<testsuites><testsuite name="s" tests="2" failures="0" skipped="0" time="0.2">
<testcase classname="s" name="stable" time="0.1"/>
<testcase classname="s" name="flaky" time="0.1"/>
</testsuite></testsuites>
EOF
    cat > "$TMPDIR/r2/j.json" <<'EOF'
{"tests":[
  {"name":"stable","status":"passed","duration":0.1},
  {"name":"flaky","status":"failed","duration":0.2}
]}
EOF
    run bash "$SCRIPT" aggregate "$TMPDIR/r1/j.xml" "$TMPDIR/r2/j.json"
    [ "$status" -eq 0 ]
    # Totals: 4 tests, 3 passed, 1 failed, 0 skipped
    [[ "$output" == *"total=4"* ]]
    [[ "$output" == *"passed=3"* ]]
    [[ "$output" == *"failed=1"* ]]
    [[ "$output" == *"skipped=0"* ]]
    [[ "$output" == *"flaky=flaky"* ]]
}

# --- summary: generates markdown ---
@test "summary writes markdown with totals and flaky section" {
    cat > "$TMPDIR/r1.json" <<'EOF'
{"tests":[{"name":"a","status":"passed","duration":0.1},{"name":"b","status":"failed","duration":0.2}]}
EOF
    cat > "$TMPDIR/r2.json" <<'EOF'
{"tests":[{"name":"a","status":"passed","duration":0.1},{"name":"b","status":"passed","duration":0.1}]}
EOF
    run bash "$SCRIPT" summary "$TMPDIR/r1.json" "$TMPDIR/r2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Test Results Summary"* ]]
    [[ "$output" == *"Passed"* ]]
    [[ "$output" == *"Failed"* ]]
    [[ "$output" == *"Flaky"* ]]
    [[ "$output" == *"| b |"* ]]
}

@test "summary reports no flaky when all stable" {
    cat > "$TMPDIR/r.json" <<'EOF'
{"tests":[{"name":"a","status":"passed","duration":0.1}]}
EOF
    run bash "$SCRIPT" summary "$TMPDIR/r.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No flaky tests detected"* ]]
}

@test "script fails with usage on unknown command" {
    run bash "$SCRIPT" bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}
