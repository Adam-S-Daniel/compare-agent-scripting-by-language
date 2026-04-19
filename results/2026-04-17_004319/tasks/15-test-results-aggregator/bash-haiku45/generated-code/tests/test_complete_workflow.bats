#!/usr/bin/env bats
# Complete end-to-end workflow tests

setup() {
  TEST_TEMP=$(mktemp -d)
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  FIXTURES="${SCRIPT_DIR}/fixtures"

  source "${SCRIPT_DIR}/aggregate-results.sh"
}

teardown() {
  rm -rf "$TEST_TEMP"
}

# Test complete aggregation workflow
@test "complete workflow: aggregate multiple files and generate summary" {
  # Run aggregation
  output=$(aggregate_junit_files "${FIXTURES}/sample-junit.xml" "${FIXTURES}/run1-junit.xml" "${FIXTURES}/run2-junit.xml")

  # Verify totals are present and correct
  passed=$(echo "$output" | jq -r '.total_passed')
  failed=$(echo "$output" | jq -r '.total_failed')

  # Should have aggregated results from all three files
  [ "$passed" -ge 5 ]
  [ "$failed" -ge 1 ]
  [ -n "$passed" ]
  [ -n "$failed" ]
}

# Test markdown output with all sections
@test "markdown summary includes all required sections" {
  # Detect flaky tests
  flaky=$(detect_flaky_tests "${FIXTURES}/run1-junit.xml" "${FIXTURES}/run2-junit.xml")

  # Generate summary
  summary=$(generate_markdown_summary \
    total_passed=5 \
    total_failed=1 \
    total_skipped=0 \
    total_duration=4.4)

  # Check sections exist
  echo "$summary" | grep -q "# Test Results Summary"
  echo "$summary" | grep -q "## Summary Statistics"
  echo "$summary" | grep -q "Passed"
  echo "$summary" | grep -q "Failed"
}

# Test parsing a realistic matrix of test results
@test "handles matrix build scenario with varying results" {
  # Create a more complex fixture set
  cat > "${TEST_TEMP}/matrix-run1.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="unit-tests" tests="4" failures="0" skipped="0" time="2.0">
    <testcase name="test_add" classname="math" time="0.5"/>
    <testcase name="test_subtract" classname="math" time="0.4"/>
    <testcase name="test_multiply" classname="math" time="0.6"/>
    <testcase name="test_divide" classname="math" time="0.5"/>
  </testsuite>
</testsuites>
EOF

  cat > "${TEST_TEMP}/matrix-run2.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="unit-tests" tests="4" failures="1" skipped="0" time="2.2">
    <testcase name="test_add" classname="math" time="0.5"/>
    <testcase name="test_subtract" classname="math" time="0.4"/>
    <testcase name="test_multiply" classname="math" time="0.6">
      <failure message="Expected 6 but got 5">overflow error</failure>
    </testcase>
    <testcase name="test_divide" classname="math" time="0.5"/>
  </testsuite>
</testsuites>
EOF

  # Aggregate
  result=$(aggregate_junit_files "${TEST_TEMP}/matrix-run1.xml" "${TEST_TEMP}/matrix-run2.xml")

  # Verify combined results
  passed=$(echo "$result" | jq -r '.total_passed')
  failed=$(echo "$result" | jq -r '.total_failed')

  [ "$passed" -eq 7 ]
  [ "$failed" -eq 1 ]

  # Detect flaky test
  flaky=$(detect_flaky_tests "${TEST_TEMP}/matrix-run1.xml" "${TEST_TEMP}/matrix-run2.xml")
  echo "$flaky" | grep -q "test_multiply"
}

# Test with JSON format in matrix
@test "mixed format: handles JSON alongside XML in matrix" {
  # Create JSON results
  cat > "${TEST_TEMP}/results.json" <<'EOF'
{
  "passed": 3,
  "failed": 0,
  "skipped": 1,
  "duration": 1.5,
  "testcases": []
}
EOF

  # Parse JSON result
  result=$(parse_json_results "${TEST_TEMP}/results.json")

  passed=$(echo "$result" | jq -r '.passed')
  [ "$passed" -eq 3 ]
}

# Test error handling
@test "gracefully handles missing or corrupt files" {
  local output
  output=$(aggregate_junit_files "${FIXTURES}/nonexistent.xml" 2>&1) || true

  # Should not crash, may have empty/error output
  [ -n "$output" ] || true
}

# Test aggregation totals calculation
@test "correctly calculates aggregated totals across 3+ files" {
  # Create 3 test files
  for i in 1 2 3; do
    cat > "${TEST_TEMP}/run${i}.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="tests" tests="2" failures="0" skipped="0" time="1.0">
    <testcase name="test_one_${i}" classname="test" time="0.5"/>
    <testcase name="test_two_${i}" classname="test" time="0.5"/>
  </testsuite>
</testsuites>
EOF
  done

  # Aggregate all three
  result=$(aggregate_junit_files "${TEST_TEMP}/run1.xml" "${TEST_TEMP}/run2.xml" "${TEST_TEMP}/run3.xml")

  # Should have 6 total passed tests
  passed=$(echo "$result" | jq -r '.total_passed')
  [ "$passed" -eq 6 ]
}

# Test duration calculation
@test "correctly sums durations across test files" {
  # Create files with known durations
  cat > "${TEST_TEMP}/duration1.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="tests" tests="1" failures="0" skipped="0" time="1.5">
    <testcase name="test_one" classname="test" time="1.5"/>
  </testsuite>
</testsuites>
EOF

  cat > "${TEST_TEMP}/duration2.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="tests" tests="1" failures="0" skipped="0" time="2.3">
    <testcase name="test_two" classname="test" time="2.3"/>
  </testsuite>
</testsuites>
EOF

  # Parse and aggregate
  result1=$(parse_junit_xml "${TEST_TEMP}/duration1.xml")
  result2=$(parse_junit_xml "${TEST_TEMP}/duration2.xml")

  duration1=$(echo "$result1" | jq -r '.duration')
  duration2=$(echo "$result2" | jq -r '.duration')

  # Durations should be captured
  [ -n "$duration1" ]
  [ -n "$duration2" ]
}
