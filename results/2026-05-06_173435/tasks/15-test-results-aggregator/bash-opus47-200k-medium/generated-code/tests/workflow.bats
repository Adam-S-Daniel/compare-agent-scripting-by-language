#!/usr/bin/env bats

# Workflow / pipeline tests:
#   1. YAML structure assertions (instant — no act run).
#   2. actionlint must pass.
#   3. Each test case sets up a temp git repo with the project + that case's
#      fixtures, runs `act push --rm`, appends output to act-result.txt, and
#      asserts on EXACT expected counts derived from the fixtures.
#
# act runs are expensive, so each case is a single act invocation and we keep
# total runs <= 3.

ROOT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
ACT_LOG="${ROOT_DIR}/act-result.txt"
WORKFLOW="${ROOT_DIR}/.github/workflows/test-results-aggregator.yml"

setup_file() {
  : > "$ACT_LOG"
}

# Helper: stage a temp repo containing the project + the given fixtures dir,
# then invoke `act push --rm`. Stdout is the act log; stderr is also captured.
run_act_with_fixtures() {
  local case_name="$1"
  local fixtures_src="$2"

  local tmp
  tmp="$(mktemp -d)"
  # Mirror the project, but replace fixtures/ with the case's fixture set.
  cp -r "$ROOT_DIR/." "$tmp/"
  rm -rf "$tmp/fixtures" "$tmp/act-result.txt" "$tmp/.git"
  mkdir -p "$tmp/fixtures"
  cp -r "$fixtures_src"/. "$tmp/fixtures/"

  (
    cd "$tmp"
    git init -q
    git config user.email t@t.t
    git config user.name t
    git add -A
    git commit -q -m "case: $case_name"
  )

  {
    echo "===== BEGIN CASE: $case_name ====="
    (cd "$tmp" && act push --rm 2>&1)
    local rc=$?
    echo "===== END CASE: $case_name (exit=$rc) ====="
    return $rc
  } | tee -a "$ACT_LOG"
  # Return code of `act` is the first element of PIPESTATUS.
  return "${PIPESTATUS[0]}"
}

@test "workflow: YAML structure has expected triggers and jobs" {
  run grep -E '^\s*(push|pull_request|workflow_dispatch):' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q "uses: actions/checkout@v4" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q "aggregate.sh" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow: referenced script paths exist" {
  [ -f "$ROOT_DIR/aggregate.sh" ]
  [ -x "$ROOT_DIR/aggregate.sh" ]
}

@test "workflow: actionlint passes" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "act: case 1 — multi-format aggregation with two flaky tests" {
  # fixtures/run1.xml + fixtures/run2.json — see fixtures dir for content.
  # Combined totals: 8 records, 4 passed, 2 failed, 2 skipped.
  # Flaky: pkg.MathTest.divide (failed in run1, passed in run2) and
  #        pkg.NetTest.connect (passed in run1, failed in run2).
  run_act_with_fixtures "multi-format" "$ROOT_DIR/fixtures"
  rc=$?
  [ "$rc" -eq 0 ]

  # Pull only this case's slice from the log.
  slice="$(awk '/BEGIN CASE: multi-format/,/END CASE: multi-format/' "$ACT_LOG")"

  echo "$slice" | grep -q 'Job succeeded'
  echo "$slice" | grep -Eq '^\|\s*Total\s*\|\s*8\s*\|'
  echo "$slice" | grep -Eq '^\|\s*Passed\s*\|\s*4\s*\|'
  echo "$slice" | grep -Eq '^\|\s*Failed\s*\|\s*2\s*\|'
  echo "$slice" | grep -Eq '^\|\s*Skipped\s*\|\s*2\s*\|'
  echo "$slice" | grep -q 'pkg.MathTest.divide'
  echo "$slice" | grep -q 'pkg.NetTest.connect'
  echo "$slice" | grep -q 'Status: FAILED'
}

@test "act: case 2 — all-passing JSON-only run reports OK with no flaky" {
  local tmp
  tmp="$(mktemp -d)"
  cat > "$tmp/r.json" <<'EOF'
{"tests":[
  {"name":"a","status":"passed","duration":0.1},
  {"name":"b","status":"passed","duration":0.2},
  {"name":"c","status":"skipped","duration":0.0}
]}
EOF
  run_act_with_fixtures "all-pass" "$tmp"
  rc=$?
  [ "$rc" -eq 0 ]

  slice="$(awk '/BEGIN CASE: all-pass/,/END CASE: all-pass/' "$ACT_LOG")"

  echo "$slice" | grep -q 'Job succeeded'
  echo "$slice" | grep -Eq '^\|\s*Total\s*\|\s*3\s*\|'
  echo "$slice" | grep -Eq '^\|\s*Passed\s*\|\s*2\s*\|'
  echo "$slice" | grep -Eq '^\|\s*Failed\s*\|\s*0\s*\|'
  echo "$slice" | grep -Eq '^\|\s*Skipped\s*\|\s*1\s*\|'
  echo "$slice" | grep -q '_None detected._'
  echo "$slice" | grep -q 'Status: OK'
}

@test "act-result.txt was written" {
  [ -s "$ACT_LOG" ]
}
