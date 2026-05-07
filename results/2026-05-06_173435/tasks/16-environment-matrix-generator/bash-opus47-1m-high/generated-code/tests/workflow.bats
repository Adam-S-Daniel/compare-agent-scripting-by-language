#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Workflow structure tests. These verify the static shape of the generated
# GitHub Actions workflow file: that it has the expected triggers, that the
# job references the script paths that actually exist, and that actionlint
# accepts it.

setup() {
    PROJECT="${BATS_TEST_DIRNAME}/.."
    WF="${PROJECT}/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow: file exists" {
    [ -f "$WF" ]
}

@test "workflow: actionlint passes cleanly" {
    run --separate-stderr actionlint "$WF"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -z "$stderr" ]
}

@test "workflow: declares push, pull_request, and workflow_dispatch triggers" {
    # Use yq if available; otherwise fall back to grep on top-level keys.
    if command -v yq >/dev/null 2>&1; then
        run --separate-stderr yq -r '.on | keys | sort | join(",")' "$WF"
        [ "$status" -eq 0 ]
        [[ "$output" == *"push"* ]]
        [[ "$output" == *"pull_request"* ]]
        [[ "$output" == *"workflow_dispatch"* ]]
    else
        grep -qE '^[[:space:]]*push:' "$WF"
        grep -qE '^[[:space:]]*pull_request:' "$WF"
        grep -qE '^[[:space:]]*workflow_dispatch:' "$WF"
    fi
}

@test "workflow: references generate-matrix.sh and the script exists" {
    grep -qF "./generate-matrix.sh" "$WF"
    [ -x "${PROJECT}/generate-matrix.sh" ]
}

@test "workflow: references tests/matrix.bats and the file exists" {
    grep -qF "tests/matrix.bats" "$WF"
    [ -f "${PROJECT}/tests/matrix.bats" ]
}

@test "workflow: uses pinned actions/checkout@v4" {
    grep -qE 'uses:[[:space:]]*actions/checkout@v4' "$WF"
}

@test "workflow: declares minimal contents:read permission" {
    grep -qE '^[[:space:]]*contents:[[:space:]]*read' "$WF"
}
