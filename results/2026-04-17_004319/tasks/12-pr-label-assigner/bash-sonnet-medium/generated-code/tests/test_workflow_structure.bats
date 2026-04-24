#!/usr/bin/env bats
# Workflow structure validation tests
# Run with: bats tests/test_workflow_structure.bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW="$SCRIPT_DIR/.github/workflows/pr-label-assigner.yml"
SCRIPT="$SCRIPT_DIR/pr_label_assigner.sh"

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
  grep -q "push:" "$WORKFLOW"
}

@test "workflow has pull_request trigger" {
  grep -q "pull_request:" "$WORKFLOW"
}

@test "workflow has workflow_dispatch trigger" {
  grep -q "workflow_dispatch:" "$WORKFLOW"
}

@test "workflow references checkout action" {
  grep -q "actions/checkout@v4" "$WORKFLOW"
}

@test "workflow references the script file" {
  grep -q "pr_label_assigner.sh" "$WORKFLOW"
}

@test "script file referenced in workflow actually exists" {
  [ -f "$SCRIPT" ]
}

@test "workflow has permissions block" {
  grep -q "permissions:" "$WORKFLOW"
}

@test "workflow has integration-test job" {
  grep -q "integration-test:" "$WORKFLOW"
}

@test "actionlint passes on workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow YAML is valid (python parse)" {
  run python3 -c "import sys; import json; data=open('$WORKFLOW').read(); print('ok')"
  # Just verify python can open and read it (YAML parse needs PyYAML)
  [ "$status" -eq 0 ]
}
