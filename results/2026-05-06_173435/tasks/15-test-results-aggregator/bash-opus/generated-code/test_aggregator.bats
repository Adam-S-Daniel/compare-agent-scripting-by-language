#!/usr/bin/env bats

# Workflow structure tests (no act needed)

@test "workflow file exists" {
  [ -f ".github/workflows/test-results-aggregator.yml" ]
}

@test "actionlint passes on workflow" {
  run actionlint .github/workflows/test-results-aggregator.yml
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "main script exists" {
  [ -f "aggregate-test-results.sh" ]
}

@test "main script passes shellcheck" {
  run shellcheck aggregate-test-results.sh
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "main script passes bash -n syntax check" {
  run bash -n aggregate-test-results.sh
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "fixture directories exist with test data" {
  [ -d "fixtures/run1" ]
  [ -d "fixtures/run2" ]
  [ -d "fixtures/run3" ]
  [ -f "fixtures/run1/junit.xml" ]
  [ -f "fixtures/run1/results.json" ]
  [ -f "fixtures/run2/junit.xml" ]
  [ -f "fixtures/run3/results.json" ]
}

@test "workflow has push and pull_request triggers" {
  run bash -c "python3 -c \"
import yaml
with open('.github/workflows/test-results-aggregator.yml') as f:
    wf = yaml.safe_load(f)
triggers = list(wf.get('on', wf.get(True, {})).keys())
assert 'push' in triggers, 'missing push trigger'
assert 'pull_request' in triggers, 'missing pull_request trigger'
print('triggers OK:', triggers)
\""
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "workflow has workflow_dispatch trigger" {
  run bash -c "python3 -c \"
import yaml
with open('.github/workflows/test-results-aggregator.yml') as f:
    wf = yaml.safe_load(f)
triggers = list(wf.get('on', wf.get(True, {})).keys())
assert 'workflow_dispatch' in triggers, 'missing workflow_dispatch'
print('workflow_dispatch OK')
\""
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "workflow jobs contain aggregate job with correct steps" {
  run bash -c "python3 -c \"
import yaml
with open('.github/workflows/test-results-aggregator.yml') as f:
    wf = yaml.safe_load(f)
jobs = wf['jobs']
assert 'aggregate' in jobs, 'missing aggregate job'
steps = jobs['aggregate']['steps']
step_names = [s.get('name', s.get('uses', '')) for s in steps]
print('Steps:', step_names)
assert any('checkout' in str(s.get('uses', '')) for s in steps), 'missing checkout step'
assert any('aggregat' in str(s.get('name', '')).lower() for s in steps), 'missing aggregator step'
\""
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "workflow references script files that exist" {
  run bash -c "python3 -c \"
import yaml, os
with open('.github/workflows/test-results-aggregator.yml') as f:
    wf = yaml.safe_load(f)
for job in wf['jobs'].values():
    for step in job['steps']:
        run_cmd = step.get('run', '')
        if 'aggregate-test-results.sh' in run_cmd:
            assert os.path.isfile('aggregate-test-results.sh'), 'script not found'
            print('Script reference verified: aggregate-test-results.sh')
\""
  echo "$output"
  [ "$status" -eq 0 ]
}

# Act integration tests

setup_file() {
  export ORIG_DIR="$PWD"
  export ACT_RESULT_FILE="$ORIG_DIR/act-result.txt"
  > "$ACT_RESULT_FILE"
}

setup_act_repo() {
  local tmpdir
  tmpdir=$(mktemp -d)

  cd "$tmpdir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  cp -r "$ORIG_DIR/.github" .
  cp "$ORIG_DIR/aggregate-test-results.sh" .
  cp -r "$ORIG_DIR/fixtures" .
  cp "$ORIG_DIR/.actrc" . 2>/dev/null || true

  git add -A
  git commit -q -m "initial"

  echo "$tmpdir"
}

@test "act: full aggregation produces correct totals and flaky detection" {
  local tmpdir
  tmpdir=$(setup_act_repo)
  cd "$tmpdir"

  echo "=== ACT RUN: full aggregation ===" >> "$ACT_RESULT_FILE"

  run act push --rm --pull=false 2>&1
  echo "$output" >> "$ACT_RESULT_FILE"

  echo "--- act exit code: $status ---" >> "$ACT_RESULT_FILE"
  echo "=== END ACT RUN ===" >> "$ACT_RESULT_FILE"

  echo "$output"
  [ "$status" -eq 0 ]

  # Verify job succeeded
  echo "$output" | grep -q "Job succeeded"

  # Verify exact totals from the aggregator output
  echo "$output" | grep -q "TOTAL_TESTS=17"
  echo "$output" | grep -q "TOTAL_PASSED=10"
  echo "$output" | grep -q "TOTAL_FAILED=5"
  echo "$output" | grep -q "TOTAL_SKIPPED=2"
  echo "$output" | grep -q "TOTAL_DURATION=36.600s"

  # Verify flaky test detection found exactly the right tests
  echo "$output" | grep -q "FLAKY_TESTS=test_checkout test_create_user test_signup"

  # Verify markdown summary was generated and displayed
  echo "$output" | grep -q "=== MARKDOWN SUMMARY ==="
  echo "$output" | grep -q "# Test Results Summary"
  echo "$output" | grep -q "| Total Tests | 17 |"
  echo "$output" | grep -q "| Passed | 10 |"
  echo "$output" | grep -q "| Failed | 5 |"
  echo "$output" | grep -q "| Skipped | 2 |"
  echo "$output" | grep -q "| Flaky Tests | 3 |"

  # Verify flaky tests listed in markdown
  echo "$output" | grep -q "test_checkout"
  echo "$output" | grep -q "test_create_user"
  echo "$output" | grep -q "test_signup"

  # Verify consistently failed test is in the failed section
  echo "$output" | grep -q "test_payment"

  # Verify the verify step passed
  echo "$output" | grep -q "All assertions passed"

  cd "$ORIG_DIR"
  rm -rf "$tmpdir"
}

@test "act-result.txt exists and contains output" {
  [ -f "act-result.txt" ]
  [ -s "act-result.txt" ]
  grep -q "ACT RUN" act-result.txt
  grep -q "Job succeeded" act-result.txt
}
