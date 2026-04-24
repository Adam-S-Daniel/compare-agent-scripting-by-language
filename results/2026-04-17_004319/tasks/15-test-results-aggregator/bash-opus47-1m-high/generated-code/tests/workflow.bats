#!/usr/bin/env bats
#
# workflow.bats — structural assertions on the GitHub Actions workflow.
# The end-to-end `act` harness lives in run-act-tests.sh and produces
# act-result.txt; these tests are cheap structural checks.

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    WF="$REPO_ROOT/.github/workflows/test-results-aggregator.yml"
}

@test "workflow file exists" {
    [ -f "$WF" ]
}

@test "workflow passes actionlint" {
    run actionlint "$WF"
    [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, workflow_dispatch triggers" {
    grep -q '^on:' "$WF"
    grep -qE '^\s*push:' "$WF"
    grep -qE '^\s*pull_request:' "$WF"
    grep -qE '^\s*workflow_dispatch:' "$WF"
}

@test "workflow references aggregate.sh" {
    grep -q 'aggregate.sh' "$WF"
    [ -f "$REPO_ROOT/aggregate.sh" ]
}

@test "workflow references bats tests path" {
    grep -q 'tests/aggregate.bats' "$WF"
    [ -f "$REPO_ROOT/tests/aggregate.bats" ]
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WF"
}

@test "workflow declares three jobs: lint, test, aggregate" {
    grep -qE '^\s{2}lint:' "$WF"
    grep -qE '^\s{2}test:' "$WF"
    grep -qE '^\s{2}aggregate:' "$WF"
}

@test "workflow declares read permissions" {
    grep -qE 'contents:\s*read' "$WF"
}
