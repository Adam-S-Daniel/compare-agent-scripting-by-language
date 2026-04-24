#!/usr/bin/env bats
# Structural checks on the workflow YAML and referenced files.

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
WF="${PROJECT_ROOT}/.github/workflows/test-results-aggregator.yml"

@test "workflow file exists" {
    [ -f "$WF" ]
}

@test "actionlint passes on the workflow" {
    run actionlint "$WF"
    [ "$status" -eq 0 ]
}

@test "workflow declares expected triggers" {
    grep -qE '^\s*push:'              "$WF"
    grep -qE '^\s*pull_request:'      "$WF"
    grep -qE '^\s*workflow_dispatch:' "$WF"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WF"
}

@test "workflow references aggregate.sh and that script exists" {
    grep -q 'aggregate.sh' "$WF"
    [ -x "$PROJECT_ROOT/aggregate.sh" ]
}

@test "workflow references fixtures dir and it exists" {
    grep -q 'fixtures' "$WF"
    [ -d "$PROJECT_ROOT/fixtures" ]
}

@test "workflow declares permissions block" {
    grep -qE '^\s*permissions:' "$WF"
}
