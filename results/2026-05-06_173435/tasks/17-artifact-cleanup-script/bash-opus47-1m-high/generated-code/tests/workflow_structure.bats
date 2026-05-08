#!/usr/bin/env bats
# Structural assertions on .github/workflows/artifact-cleanup-script.yml:
# verify triggers/jobs/steps, that referenced files exist, and that actionlint
# is happy. These are cheap (no act required) and catch typos pre-CI.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WF="$ROOT/.github/workflows/artifact-cleanup-script.yml"
}

@test "workflow file exists" {
  [ -f "$WF" ]
}

@test "workflow declares all required triggers" {
  run grep -E '^[[:space:]]+(push|pull_request|schedule|workflow_dispatch):' "$WF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"push:"* ]]
  [[ "$output" == *"pull_request:"* ]]
  [[ "$output" == *"schedule:"* ]]
  [[ "$output" == *"workflow_dispatch:"* ]]
}

@test "workflow declares minimal permissions" {
  run grep -E '^permissions:' "$WF"
  [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
  run grep -F 'actions/checkout@v4' "$WF"
  [ "$status" -eq 0 ]
}

@test "workflow references the cleanup script" {
  run grep -F './cleanup.sh' "$WF"
  [ "$status" -eq 0 ]
}

@test "workflow references the bats test file" {
  run grep -F 'tests/cleanup.bats' "$WF"
  [ "$status" -eq 0 ]
}

@test "workflow references an existing fixture file" {
  run grep -F 'fixtures/realistic.tsv' "$WF"
  [ "$status" -eq 0 ]
  [ -f "$ROOT/fixtures/realistic.tsv" ]
}

@test "workflow has all three scenario steps" {
  run grep -E "Scenario [ABC]:" "$WF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Scenario A"* ]]
  [[ "$output" == *"Scenario B"* ]]
  [[ "$output" == *"Scenario C"* ]]
}

@test "actionlint passes" {
  if ! command -v actionlint >/dev/null; then
    skip "actionlint not installed"
  fi
  run actionlint "$WF"
  [ "$status" -eq 0 ]
}
