#!/usr/bin/env bats
# Workflow-structure tests: verify the workflow YAML has the shape we expect
# without executing it. These run quickly and catch silent breakage of
# triggers, jobs, or step references that would otherwise only surface in
# a slow act run.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow passes actionlint" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow declares the expected triggers" {
    grep -qE '^on:' "$WORKFLOW"
    grep -qE '^[[:space:]]+push:' "$WORKFLOW"
    grep -qE '^[[:space:]]+pull_request:' "$WORKFLOW"
    grep -qE '^[[:space:]]+workflow_dispatch:' "$WORKFLOW"
    grep -qE '^[[:space:]]+schedule:' "$WORKFLOW"
}

@test "workflow declares both lint and bump jobs" {
    grep -qE '^[[:space:]]+lint:' "$WORKFLOW"
    grep -qE '^[[:space:]]+bump:' "$WORKFLOW"
}

@test "bump job depends on lint job" {
    grep -qE 'needs:[[:space:]]+lint' "$WORKFLOW"
}

@test "workflow uses pinned actions/checkout@v4" {
    grep -qE 'uses:[[:space:]]+actions/checkout@v4' "$WORKFLOW"
}

@test "workflow declares contents: read permissions" {
    grep -qE 'permissions:' "$WORKFLOW"
    grep -qE 'contents:[[:space:]]+read' "$WORKFLOW"
}

@test "workflow references the bump_version.sh script" {
    grep -q "bump_version.sh" "$WORKFLOW"
    [ -f "${BATS_TEST_DIRNAME}/../bump_version.sh" ]
}

@test "workflow installs bats and shellcheck" {
    grep -qE 'apt-get install.*bats' "$WORKFLOW"
    grep -qE 'apt-get install.*shellcheck' "$WORKFLOW"
}

@test "workflow runs the bats unit tests" {
    grep -qE 'bats[[:space:]]+tests/bump_version.bats' "$WORKFLOW"
}

@test "workflow emits a parseable NEW_VERSION line" {
    grep -q 'NEW_VERSION=' "$WORKFLOW"
}
