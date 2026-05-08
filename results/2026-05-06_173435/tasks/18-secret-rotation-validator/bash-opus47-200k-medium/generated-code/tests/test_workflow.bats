#!/usr/bin/env bats
# Workflow-structure tests + end-to-end act runs.
#
# These tests exercise the GitHub Actions workflow itself:
#   1) YAML structure / required fields are present.
#   2) Script paths referenced by the workflow exist.
#   3) actionlint passes.
#   4) `act push` runs end-to-end against three fixture configurations
#      (mixed, all_ok, and a wide warning window) and emits the exact
#      summary counts we expect.
#
# Each act run's output is appended to act-result.txt with delimiters.

setup_file() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PROJECT_ROOT
  export WORKFLOW="$PROJECT_ROOT/.github/workflows/secret-rotation-validator.yml"
  export ACT_RESULT="$PROJECT_ROOT/act-result.txt"
  : > "$ACT_RESULT"
}

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PROJECT_ROOT
  export WORKFLOW="$PROJECT_ROOT/.github/workflows/secret-rotation-validator.yml"
  export ACT_RESULT="$PROJECT_ROOT/act-result.txt"
}

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "workflow declares expected triggers" {
  run grep -E '^\s*(push|pull_request|schedule|workflow_dispatch):' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"push"* ]]
  [[ "$output" == *"pull_request"* ]]
  [[ "$output" == *"schedule"* ]]
  [[ "$output" == *"workflow_dispatch"* ]]
}

@test "workflow references the validator script and fixtures" {
  grep -q 'secret-rotation-validator.sh' "$WORKFLOW"
  grep -q 'tests/fixtures' "$WORKFLOW"
  [ -f "$PROJECT_ROOT/secret-rotation-validator.sh" ]
  [ -d "$PROJECT_ROOT/tests/fixtures" ]
  [ -f "$PROJECT_ROOT/tests/fixtures/mixed.json" ]
  [ -f "$PROJECT_ROOT/tests/fixtures/all_ok.json" ]
}

@test "workflow declares an explicit permissions block" {
  grep -qE '^permissions:' "$WORKFLOW"
  grep -qE 'contents:\s*read' "$WORKFLOW"
}

@test "actionlint passes on the workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# Helper: run a single act invocation in a fresh temp git repo so each test
# case is hermetic, then append delimited output to act-result.txt.
_run_act_case() {
  local case_name="$1" fixture="$2" warning_days="$3"
  local expected_expired="$4" expected_warning="$5" expected_ok="$6"

  local tmp
  tmp=$(mktemp -d)
  # Copy the project skeleton (script, fixtures, workflow) into the temp repo.
  cp -r \
    "$PROJECT_ROOT/.github" \
    "$PROJECT_ROOT/secret-rotation-validator.sh" \
    "$PROJECT_ROOT/tests" \
    "$tmp/"
  ( cd "$tmp" && git init -q && git add -A && \
      git -c user.email=ci@example.com -c user.name=ci commit -q -m init )

  # Pass overrides via workflow_dispatch-style env so we don't have to
  # fiddle with the workflow per case. The workflow defaults already use
  # mixed.json/14, but we still drive it explicitly via env to be safe.
  local out
  out=$( cd "$tmp" && \
    FIXTURE="$fixture" WARNING_DAYS="$warning_days" \
    act push --rm \
      --env FIXTURE="$fixture" \
      --env WARNING_DAYS="$warning_days" \
      2>&1 ) || true
  local rc=$?

  {
    echo "===== BEGIN CASE: $case_name (rc=$rc) ====="
    echo "$out"
    echo "===== END CASE: $case_name ====="
    echo
  } >> "$ACT_RESULT"

  rm -rf "$tmp"

  # Surface the captured output if assertions fail.
  echo "$out"
  echo "---"
  echo "rc=$rc"

  # Every job must succeed end-to-end.
  [[ "$out" == *"Job succeeded"* ]] || return 1
  [ "$rc" -eq 0 ] || return 1
  # Exact expected summary line emitted by the "Print summary counts" step.
  local expected="EXPIRED=${expected_expired} WARNING=${expected_warning} OK=${expected_ok}"
  [[ "$out" == *"$expected"* ]] || { echo "Missing: $expected"; return 1; }
}

@test "act run: mixed fixture with 14-day window → 1/1/1" {
  _run_act_case "mixed-14d" "mixed.json" "14" 1 1 1
}

@test "act run: all_ok fixture with 14-day window → 0/0/2" {
  _run_act_case "all_ok-14d" "all_ok.json" "14" 0 0 2
}

@test "act run: all_ok fixture with 365-day warning window → 0/2/0" {
  _run_act_case "all_ok-365d" "all_ok.json" "365" 0 2 0
}

@test "act-result.txt was produced" {
  [ -s "$ACT_RESULT" ]
  grep -q "BEGIN CASE: mixed-14d" "$ACT_RESULT"
  grep -q "BEGIN CASE: all_ok-14d" "$ACT_RESULT"
  grep -q "BEGIN CASE: all_ok-365d" "$ACT_RESULT"
}
