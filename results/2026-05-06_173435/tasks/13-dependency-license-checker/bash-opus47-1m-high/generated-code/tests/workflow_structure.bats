#!/usr/bin/env bats
#
# Structural tests for the workflow + project files.
# These do NOT run act — they validate that the workflow YAML is well-formed,
# references real files, and passes actionlint cleanly.

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW="${PROJECT_ROOT}/.github/workflows/dependency-license-checker.yml"

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow defines push trigger" {
    # `push:` may appear bare or with sub-keys; the simple presence check is enough.
    grep -qE '^\s*push:' "$WORKFLOW"
}

@test "workflow defines pull_request trigger" {
    grep -qE '^\s*pull_request:' "$WORKFLOW"
}

@test "workflow defines workflow_dispatch trigger" {
    grep -qE '^\s*workflow_dispatch:' "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WORKFLOW"
}

@test "workflow declares contents:read permission" {
    grep -qE 'contents:\s*read' "$WORKFLOW"
}

@test "workflow references the license-check script path that exists" {
    # The script path referenced in the workflow must point to a real file.
    grep -q 'bin/license-check.sh' "$WORKFLOW"
    [ -x "${PROJECT_ROOT}/bin/license-check.sh" ]
}

@test "workflow references real fixture files" {
    [ -f "${PROJECT_ROOT}/fixtures/config.json" ]
    [ -f "${PROJECT_ROOT}/fixtures/license-db.json" ]
}

@test "actionlint passes on the workflow" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "license-check.sh passes shellcheck" {
    run shellcheck "${PROJECT_ROOT}/bin/license-check.sh"
    [ "$status" -eq 0 ]
}

@test "license-check.sh passes bash -n syntax check" {
    run bash -n "${PROJECT_ROOT}/bin/license-check.sh"
    [ "$status" -eq 0 ]
}
