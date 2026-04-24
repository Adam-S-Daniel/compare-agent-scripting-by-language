#!/usr/bin/env bats

# Workflow structure tests. These validate the YAML layout of the
# GitHub Actions workflow WITHOUT running act.

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
    WF="${ROOT}/.github/workflows/artifact-cleanup-script.yml"
}

@test "workflow file exists" {
    [ -f "$WF" ]
}

@test "actionlint passes" {
    run actionlint "$WF"
    [ "$status" -eq 0 ]
}

@test "workflow declares all expected triggers" {
    for trig in "push:" "pull_request:" "schedule:" "workflow_dispatch:"; do
        grep -q "$trig" "$WF" || {
            echo "missing trigger: $trig" >&2
            return 1
        }
    done
}

@test "workflow references the cleanup script path" {
    grep -q "artifact-cleanup.sh" "$WF"
    [ -f "${ROOT}/artifact-cleanup.sh" ]
}

@test "workflow references the fixture path" {
    grep -q "fixtures/sample-artifacts.json" "$WF"
    [ -f "${ROOT}/fixtures/sample-artifacts.json" ]
}

@test "workflow declares expected jobs" {
    grep -qE "^  lint-and-test:" "$WF"
    grep -qE "^  run-cleanup:" "$WF"
}

@test "workflow declares permissions and uses checkout@v4" {
    grep -q "permissions:" "$WF"
    grep -q "actions/checkout@v4" "$WF"
}

@test "workflow uses actions/checkout twice (once per job)" {
    count=$(grep -c "actions/checkout@v4" "$WF")
    [ "$count" -ge 2 ]
}
