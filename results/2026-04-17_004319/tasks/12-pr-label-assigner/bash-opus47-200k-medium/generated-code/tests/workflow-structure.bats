#!/usr/bin/env bats
# Workflow structure tests (run OUTSIDE act — these verify the workflow
# file itself, which cannot be validated from within its own execution).

WF="$BATS_TEST_DIRNAME/../.github/workflows/pr-label-assigner.yml"
SCRIPT="$BATS_TEST_DIRNAME/../pr-label-assigner.sh"

@test "workflow file exists" {
  [ -f "$WF" ]
}

@test "actionlint passes on workflow" {
  run actionlint "$WF"
  [ "$status" -eq 0 ]
}

@test "workflow declares expected triggers" {
  grep -q '^on:' "$WF"
  grep -q 'push:' "$WF"
  grep -q 'pull_request:' "$WF"
  grep -q 'workflow_dispatch:' "$WF"
  grep -q 'schedule:' "$WF"
}

@test "workflow references the script path that exists" {
  grep -q 'pr-label-assigner.sh' "$WF"
  [ -f "$SCRIPT" ]
}

@test "workflow declares contents:read permission" {
  grep -q 'permissions:' "$WF"
  grep -q 'contents: read' "$WF"
}

@test "workflow uses actions/checkout@v4" {
  grep -q 'actions/checkout@v4' "$WF"
}

@test "workflow references fixture files that exist" {
  grep -q 'fixtures/rules.conf' "$WF"
  grep -q 'fixtures/files.txt' "$WF"
  [ -f "$BATS_TEST_DIRNAME/../fixtures/rules.conf" ]
  [ -f "$BATS_TEST_DIRNAME/../fixtures/files.txt" ]
}

@test "workflow job depends on a runs-on runner" {
  grep -q 'runs-on: ubuntu-latest' "$WF"
}
