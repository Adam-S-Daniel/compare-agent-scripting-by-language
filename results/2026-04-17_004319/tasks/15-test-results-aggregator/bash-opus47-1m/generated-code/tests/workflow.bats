#!/usr/bin/env bats
#
# Workflow structure tests — assert that the workflow file is well-formed,
# references existing script paths, and passes actionlint cleanly. These
# tests intentionally run locally (not through act) because they are about
# the workflow file itself rather than its runtime behavior.

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  WORKFLOW="${PROJECT_ROOT}/.github/workflows/test-results-aggregator.yml"
  export PROJECT_ROOT WORKFLOW
}

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "workflow passes actionlint" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, and workflow_dispatch triggers" {
  run grep -E '^on:' "$WORKFLOW"
  [ "$status" -eq 0 ]
  grep -qE '^[[:space:]]+push:'              "$WORKFLOW"
  grep -qE '^[[:space:]]+pull_request:'      "$WORKFLOW"
  grep -qE '^[[:space:]]+workflow_dispatch:' "$WORKFLOW"
}

@test "workflow declares read permissions" {
  grep -qE '^permissions:' "$WORKFLOW"
  grep -qE '^[[:space:]]+contents:[[:space:]]+read' "$WORKFLOW"
}

@test "workflow has two jobs: unit-tests and aggregate" {
  grep -qE '^[[:space:]]{2}unit-tests:' "$WORKFLOW"
  grep -qE '^[[:space:]]{2}aggregate:'  "$WORKFLOW"
}

@test "aggregate job declares needs: unit-tests" {
  grep -qE 'needs:[[:space:]]+unit-tests' "$WORKFLOW"
}

@test "workflow checks out code with actions/checkout@v4" {
  # Expect at least two usages (once per job).
  local count
  count=$(grep -cE 'uses:[[:space:]]+actions/checkout@v4' "$WORKFLOW")
  [ "$count" -ge 2 ]
}

@test "workflow references bin/aggregate.sh and the file exists" {
  grep -q 'bin/aggregate.sh' "$WORKFLOW"
  [ -f "${PROJECT_ROOT}/bin/aggregate.sh" ]
}

@test "workflow references tests/aggregate.bats and the file exists" {
  grep -q 'tests/aggregate.bats' "$WORKFLOW"
  [ -f "${PROJECT_ROOT}/tests/aggregate.bats" ]
}

@test "aggregate step writes to GITHUB_STEP_SUMMARY" {
  grep -q 'GITHUB_STEP_SUMMARY' "$WORKFLOW"
}
