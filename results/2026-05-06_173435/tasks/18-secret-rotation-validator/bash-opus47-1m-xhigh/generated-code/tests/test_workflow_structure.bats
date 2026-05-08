#!/usr/bin/env bats
#
# Static-structure tests for the secret rotation validator project.
# These run on the host (no act, no Docker) and exercise:
#   * the script lints with shellcheck and parses with bash -n
#   * the workflow YAML lints with actionlint
#   * the workflow declares the expected triggers, job, and references

load helpers/act_helper.bash

WORKFLOW='.github/workflows/secret-rotation-validator.yml'
SCRIPT='secret-rotation-validator.sh'

setup() {
    cd "$(project_root)"
}

@test "secret-rotation-validator.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "secret-rotation-validator.sh passes bash -n" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "secret-rotation-validator.sh passes shellcheck" {
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "workflow file exists at canonical path" {
    [ -f "$WORKFLOW" ]
}

@test "workflow passes actionlint" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow declares push trigger" {
    grep -qE '^[[:space:]]+push:' "$WORKFLOW"
}

@test "workflow declares pull_request trigger" {
    grep -qE '^[[:space:]]+pull_request:' "$WORKFLOW"
}

@test "workflow declares schedule trigger" {
    grep -qE '^[[:space:]]+schedule:' "$WORKFLOW"
}

@test "workflow declares workflow_dispatch trigger" {
    grep -qE '^[[:space:]]+workflow_dispatch:' "$WORKFLOW"
}

@test "workflow defines validate job" {
    grep -qE '^[[:space:]]+validate:' "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -qF 'uses: actions/checkout@v4' "$WORKFLOW"
}

@test "workflow references the validator script by path" {
    grep -qF 'secret-rotation-validator.sh' "$WORKFLOW"
}

@test "workflow runs both markdown and json formats" {
    grep -qE '\-\-format markdown' "$WORKFLOW"
    grep -qE '\-\-format json' "$WORKFLOW"
}

@test "workflow declares contents:read permission" {
    grep -qE '^[[:space:]]+contents:[[:space:]]+read' "$WORKFLOW"
}

@test "workflow runner is ubuntu-latest" {
    grep -qF 'runs-on: ubuntu-latest' "$WORKFLOW"
}

@test "fixtures referenced by workflow exist on disk" {
    [ -f "tests/fixtures/all-ok/secrets.txt" ]
    [ -f "tests/fixtures/all-ok/params.env" ]
    [ -f "tests/fixtures/one-expired/secrets.txt" ]
    [ -f "tests/fixtures/one-expired/params.env" ]
    [ -f "tests/fixtures/mixed/secrets.txt" ]
    [ -f "tests/fixtures/mixed/params.env" ]
}
