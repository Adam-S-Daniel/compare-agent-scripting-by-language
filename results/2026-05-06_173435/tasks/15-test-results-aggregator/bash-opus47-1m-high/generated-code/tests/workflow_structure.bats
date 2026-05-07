#!/usr/bin/env bats

# Workflow-structure tests: parse the YAML, sanity-check the shape, and
# confirm every script path it references actually exists.

setup() {
    PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
    WORKFLOW="${PROJECT_ROOT}/.github/workflows/test-results-aggregator.yml"
}

# yaml_keys PATH — emit top-level keys at $PATH using yq if available, else
# fall back to a tolerant grep that pulls keys at indent zero.
yaml_keys() {
    if command -v yq >/dev/null 2>&1; then
        yq -r 'keys | .[]' "$1"
    else
        # Top-level keys: lines that start at column 0 and end with ":".
        grep -E '^[A-Za-z_][A-Za-z0-9_-]*:' "$1" | sed 's/:.*$//'
    fi
}

@test "workflow file exists" {
    [ -f "${WORKFLOW}" ]
}

@test "workflow defines name, on, jobs" {
    keys="$(yaml_keys "${WORKFLOW}")"
    [[ "${keys}" == *"name"* ]]
    [[ "${keys}" == *"on"* ]]
    [[ "${keys}" == *"jobs"* ]]
    [[ "${keys}" == *"permissions"* ]]
}

@test "workflow includes push, pull_request, workflow_dispatch, schedule triggers" {
    grep -qE '^[[:space:]]+push:' "${WORKFLOW}"
    grep -qE '^[[:space:]]+pull_request:' "${WORKFLOW}"
    grep -qE '^[[:space:]]+workflow_dispatch:' "${WORKFLOW}"
    grep -qE '^[[:space:]]+schedule:' "${WORKFLOW}"
}

@test "workflow declares lint, unit-tests, aggregate jobs" {
    grep -qE '^[[:space:]]+lint:' "${WORKFLOW}"
    grep -qE '^[[:space:]]+unit-tests:' "${WORKFLOW}"
    grep -qE '^[[:space:]]+aggregate:' "${WORKFLOW}"
}

@test "workflow uses actions/checkout@v4" {
    grep -qE 'uses:[[:space:]]+actions/checkout@v4' "${WORKFLOW}"
}

@test "workflow references aggregate.sh" {
    grep -q 'aggregate.sh' "${WORKFLOW}"
}

@test "workflow references tests/aggregate.bats" {
    grep -q 'tests/aggregate.bats' "${WORKFLOW}"
}

@test "every referenced script path exists" {
    [ -f "${PROJECT_ROOT}/aggregate.sh" ]
    [ -f "${PROJECT_ROOT}/tests/aggregate.bats" ]
    [ -d "${PROJECT_ROOT}/fixtures" ]
}

@test "workflow declares job dependencies (needs)" {
    # unit-tests should depend on lint; aggregate should depend on unit-tests.
    grep -qE '^[[:space:]]+needs:[[:space:]]+lint' "${WORKFLOW}"
    grep -qE '^[[:space:]]+needs:[[:space:]]+unit-tests' "${WORKFLOW}"
}

@test "workflow has read-only permissions" {
    grep -qE 'contents:[[:space:]]+read' "${WORKFLOW}"
}

@test "actionlint passes on the workflow" {
    if ! command -v actionlint >/dev/null 2>&1; then
        skip "actionlint not installed"
    fi
    run actionlint "${WORKFLOW}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
