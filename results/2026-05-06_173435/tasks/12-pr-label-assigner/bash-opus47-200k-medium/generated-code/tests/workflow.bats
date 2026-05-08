#!/usr/bin/env bats

# Workflow structure tests: parse the YAML file and verify expected
# triggers, jobs, and steps; also assert actionlint passes.

setup() {
  ROOT="${BATS_TEST_DIRNAME}/.."
  WF="${ROOT}/.github/workflows/pr-label-assigner.yml"
}

@test "workflow file exists" {
  [ -f "$WF" ]
}

@test "actionlint passes on workflow" {
  run actionlint "$WF"
  [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, workflow_dispatch triggers" {
  grep -qE '^on:' "$WF"
  grep -qE '^[[:space:]]*push:' "$WF"
  grep -qE '^[[:space:]]*pull_request:' "$WF"
  grep -qE '^[[:space:]]*workflow_dispatch:' "$WF"
}

@test "workflow uses actions/checkout@v4" {
  grep -qE 'uses: actions/checkout@v4' "$WF"
}

@test "workflow references the script path" {
  grep -qE 'pr-label-assigner\.sh' "$WF"
  [ -f "${ROOT}/pr-label-assigner.sh" ]
}

@test "workflow runs the bats test file (path exists)" {
  grep -qE 'tests/pr-label-assigner\.bats' "$WF"
  [ -f "${ROOT}/tests/pr-label-assigner.bats" ]
}

@test "workflow declares contents:read permission" {
  grep -qE 'contents: read' "$WF"
}

@test "workflow has a jobs section with at least one job" {
  grep -qE '^jobs:' "$WF"
  grep -qE '^[[:space:]]+test-and-run:' "$WF"
}
