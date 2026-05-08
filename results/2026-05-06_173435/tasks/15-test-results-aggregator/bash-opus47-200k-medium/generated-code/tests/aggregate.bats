#!/usr/bin/env bats

# Tests for aggregate.sh — parses JUnit XML & JSON test results,
# aggregates totals, detects flaky tests, and emits a markdown summary.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../aggregate.sh"
  TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "errors when no directory argument given" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "errors when directory does not exist" {
  run "$SCRIPT" /nonexistent/path/xyz
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a directory"* ]]
}

@test "empty directory produces zero totals" {
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total"* ]]
  [[ "$output" == *"| 0 |"* ]]
}

@test "parses single JUnit XML file" {
  cat > "$TMP/junit.xml" <<'EOF'
<?xml version="1.0"?>
<testsuite tests="3" failures="1" skipped="1" time="1.5">
  <testcase classname="A" name="t1" time="0.5"/>
  <testcase classname="A" name="t2" time="0.5"><failure message="boom"/></testcase>
  <testcase classname="A" name="t3" time="0.5"><skipped/></testcase>
</testsuite>
EOF
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Passed"*"1"* ]]
  [[ "$output" == *"Failed"*"1"* ]]
  [[ "$output" == *"Skipped"*"1"* ]]
}

@test "parses single JSON file" {
  cat > "$TMP/results.json" <<'EOF'
{"tests":[
  {"name":"j1","status":"passed","duration":0.1},
  {"name":"j2","status":"failed","duration":0.2},
  {"name":"j3","status":"passed","duration":0.3}
]}
EOF
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Passed"* ]]
  [[ "$output" == *"Failed"* ]]
}

@test "aggregates across multiple files and detects flaky tests" {
  cat > "$TMP/run1.xml" <<'EOF'
<?xml version="1.0"?>
<testsuite tests="2" failures="1" time="2.0">
  <testcase classname="X" name="stable" time="1.0"/>
  <testcase classname="X" name="flaky" time="1.0"><failure/></testcase>
</testsuite>
EOF
  cat > "$TMP/run2.json" <<'EOF'
{"tests":[
  {"name":"X.stable","status":"passed","duration":1.0},
  {"name":"X.flaky","status":"passed","duration":1.0}
]}
EOF
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Flaky"* ]]
  [[ "$output" == *"X.flaky"* ]]
}

@test "writes summary to GITHUB_STEP_SUMMARY when set" {
  cat > "$TMP/r.json" <<'EOF'
{"tests":[{"name":"a","status":"passed","duration":0.1}]}
EOF
  SUMMARY="$TMP/summary.md"
  GITHUB_STEP_SUMMARY="$SUMMARY" run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [ -f "$SUMMARY" ]
  grep -q "Test Results" "$SUMMARY"
}
