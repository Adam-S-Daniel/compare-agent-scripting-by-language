#!/usr/bin/env bats

# Workflow-structure checks: parse the YAML and assert structural claims.
# Runs without act; act is exercised by run-act-tests.sh.

setup() {
    PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
    WORKFLOW="$PROJECT_ROOT/.github/workflows/pr-label-assigner.yml"
}

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "actionlint passes on the workflow" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, and workflow_dispatch triggers" {
    run grep -E '^on:' "$WORKFLOW"
    [ "$status" -eq 0 ]
    grep -q '^  push:' "$WORKFLOW"
    grep -q '^  pull_request:' "$WORKFLOW"
    grep -q '^  workflow_dispatch:' "$WORKFLOW"
}

@test "workflow contains the three expected jobs" {
    grep -q '^  lint:' "$WORKFLOW"
    grep -q '^  test:' "$WORKFLOW"
    grep -q '^  assign-labels:' "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'uses: actions/checkout@v4' "$WORKFLOW"
}

@test "workflow references label-assigner.sh" {
    grep -q 'label-assigner.sh' "$WORKFLOW"
    [ -f "$PROJECT_ROOT/label-assigner.sh" ]
}

@test "workflow references tests directory via bats" {
    # Workflow runs the vendored bats binary against tests/label_assigner.bats.
    grep -q 'tests/label_assigner.bats' "$WORKFLOW"
    grep -q 'BATS_BIN' "$WORKFLOW"
    [ -d "$PROJECT_ROOT/tests" ]
    [ -f "$PROJECT_ROOT/tests/label_assigner.bats" ]
    [ -x "$PROJECT_ROOT/vendor/bats-core/bin/bats" ]
}

@test "workflow declares read-only contents permission" {
    grep -q 'contents: read' "$WORKFLOW"
}

@test "assign-labels job depends on test job" {
    awk '
        /^  assign-labels:/ { in_job=1 }
        in_job && /^    needs:/ { print; exit }
    ' "$WORKFLOW" | grep -q 'test'
}

@test "label output is framed with LABELS_START/LABELS_END markers" {
    grep -q 'LABELS_START' "$WORKFLOW"
    grep -q 'LABELS_END' "$WORKFLOW"
}
