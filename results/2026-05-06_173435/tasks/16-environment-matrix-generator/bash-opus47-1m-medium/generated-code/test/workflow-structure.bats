#!/usr/bin/env bats

# Workflow structure tests — validate the GH Actions YAML without running act.

setup() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    WF="$PROJECT_ROOT/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow file exists" {
    [ -f "$WF" ]
}

@test "actionlint passes on the workflow" {
    run actionlint "$WF"
    [ "$status" -eq 0 ]
}

@test "workflow has push, pull_request, and workflow_dispatch triggers" {
    run yq -r '.on | keys | join(",")' "$WF"
    if [ "$status" -ne 0 ]; then
        # Fallback to grep if yq unavailable
        grep -q "^  push:" "$WF"
        grep -q "^  pull_request:" "$WF"
        grep -q "^  workflow_dispatch:" "$WF"
    else
        [[ "$output" == *"push"* ]]
        [[ "$output" == *"pull_request"* ]]
        [[ "$output" == *"workflow_dispatch"* ]]
    fi
}

@test "workflow has a generate job that runs on ubuntu-latest" {
    grep -q "generate:" "$WF"
    grep -q "runs-on: ubuntu-latest" "$WF"
}

@test "workflow uses actions/checkout@v4" {
    grep -qE "uses: actions/checkout@v4\b" "$WF"
}

@test "workflow references generate-matrix.sh" {
    grep -q "generate-matrix.sh" "$WF"
    [ -f "$PROJECT_ROOT/generate-matrix.sh" ]
}

@test "workflow declares contents:read permission" {
    grep -q "contents: read" "$WF"
}
