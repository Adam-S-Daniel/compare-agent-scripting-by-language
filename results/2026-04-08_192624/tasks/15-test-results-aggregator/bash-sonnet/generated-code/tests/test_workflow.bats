#!/usr/bin/env bats
# Workflow structure tests — validate the GitHub Actions workflow file.

WORKFLOW=".github/workflows/test-results-aggregator.yml"
SCRIPT="aggregator.sh"

@test "workflow file exists" {
  [ -f "$BATS_TEST_DIRNAME/../$WORKFLOW" ]
}

@test "workflow has push trigger" {
  grep -q "push:" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}

@test "workflow has pull_request trigger" {
  grep -q "pull_request:" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}

@test "workflow has workflow_dispatch trigger" {
  grep -q "workflow_dispatch:" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}

@test "workflow references aggregator.sh" {
  grep -q "aggregator.sh" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}

@test "workflow references fixture files" {
  grep -q "fixtures/" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}

@test "aggregator.sh exists (referenced by workflow)" {
  [ -f "$BATS_TEST_DIRNAME/../$SCRIPT" ]
}

@test "fixture files exist (referenced by workflow)" {
  [ -f "$BATS_TEST_DIRNAME/../fixtures/junit-pass.xml" ]
  [ -f "$BATS_TEST_DIRNAME/../fixtures/junit-fail.xml" ]
  [ -f "$BATS_TEST_DIRNAME/../fixtures/junit-skip.xml" ]
  [ -f "$BATS_TEST_DIRNAME/../fixtures/results.json" ]
  [ -f "$BATS_TEST_DIRNAME/../fixtures/run1.json" ]
  [ -f "$BATS_TEST_DIRNAME/../fixtures/run2.json" ]
}

@test "actionlint passes on workflow" {
  run actionlint "$BATS_TEST_DIRNAME/../$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow has jobs section" {
  grep -q "^jobs:" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "$BATS_TEST_DIRNAME/../$WORKFLOW"
}
