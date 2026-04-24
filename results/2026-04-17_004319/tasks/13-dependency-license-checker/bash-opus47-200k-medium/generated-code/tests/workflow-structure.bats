#!/usr/bin/env bats
# Workflow structure tests: validate the YAML shape, referenced file paths,
# and actionlint cleanliness.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/dependency-license-checker.yml"
PROJECT="${BATS_TEST_DIRNAME}/.."

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "actionlint passes" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow declares expected trigger events" {
  grep -q "^on:" "$WORKFLOW"
  grep -qE "^\s+push:" "$WORKFLOW"
  grep -qE "^\s+pull_request:" "$WORKFLOW"
  grep -qE "^\s+workflow_dispatch:" "$WORKFLOW"
  grep -qE "^\s+schedule:" "$WORKFLOW"
}

@test "workflow declares the bats-tests and compliance-check jobs" {
  grep -qE "^\s+bats-tests:" "$WORKFLOW"
  grep -qE "^\s+compliance-check:" "$WORKFLOW"
}

@test "compliance-check depends on bats-tests" {
  grep -qE "needs:\s*bats-tests" "$WORKFLOW"
}

@test "workflow references the license-check.sh script" {
  grep -q "license-check.sh" "$WORKFLOW"
  [ -f "${PROJECT}/license-check.sh" ]
}

@test "workflow references fixture paths that exist" {
  [ -f "${PROJECT}/fixtures/licenses.csv" ]
  [ -f "${PROJECT}/fixtures/allow.txt" ]
  [ -f "${PROJECT}/fixtures/deny.txt" ]
  [ -f "${PROJECT}/fixtures/sample-manifest.txt" ]
}

@test "workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "$WORKFLOW"
}

@test "workflow sets read-only contents permission" {
  grep -qE "contents:\s*read" "$WORKFLOW"
}
