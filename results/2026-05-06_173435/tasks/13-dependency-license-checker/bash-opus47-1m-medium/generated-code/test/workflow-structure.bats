#!/usr/bin/env bats
# Workflow structure tests — pure YAML/static checks (no act).

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WF="$ROOT/.github/workflows/dependency-license-checker.yml"
}

@test "workflow file exists" {
    [ -f "$WF" ]
}

@test "workflow declares all required triggers" {
    run grep -E '^(on:|  push:|  pull_request:|  workflow_dispatch:|  schedule:)' "$WF"
    [ "$status" -eq 0 ]
    [[ "$output" == *"push:"* ]]
    [[ "$output" == *"pull_request:"* ]]
    [[ "$output" == *"workflow_dispatch:"* ]]
    [[ "$output" == *"schedule:"* ]]
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WF"
}

@test "workflow declares license-check job" {
    grep -q '^  license-check:' "$WF"
}

@test "workflow references license-checker.sh" {
    grep -q 'license-checker.sh' "$WF"
    [ -x "$ROOT/license-checker.sh" ]
}

@test "workflow references fixtures that exist" {
    grep -q 'fixtures/' "$WF"
    [ -f "$ROOT/fixtures/package.json" ]
    [ -f "$ROOT/fixtures/config.json" ]
    [ -f "$ROOT/fixtures/licenses.tsv" ]
}

@test "workflow declares contents:read permission" {
    grep -A2 '^permissions:' "$WF" | grep -q 'contents: read'
}

@test "actionlint passes on workflow" {
    run actionlint "$WF"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "shellcheck passes on script" {
    run shellcheck "$ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
}

@test "bash -n syntax check passes" {
    run bash -n "$ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
}
