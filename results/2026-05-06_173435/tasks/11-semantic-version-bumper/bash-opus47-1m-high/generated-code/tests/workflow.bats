#!/usr/bin/env bats
#
# Workflow-level tests.
#
# These do *not* call bump-version.sh directly — every test case is
# executed end-to-end through the GitHub Actions workflow via `act`.
#
# Each `act push` run is expensive (30-90s), so we keep act runs to a
# minimum (3 cases) and assert exact expected values.

ROOT_DIR=""
WORK_DIR=""

setup_file() {
    export PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
    export ACT_RESULT_FILE="$PROJECT_ROOT/act-result.txt"
    : > "$ACT_RESULT_FILE"   # truncate at start of run
}

setup() {
    WORK_DIR="$(mktemp -d)"
    # Build a fresh repo with the project files. We copy rather than
    # symlink so each case can mutate VERSION/fixtures freely.
    cp -r "$PROJECT_ROOT"/. "$WORK_DIR"/
    rm -rf "$WORK_DIR/.git"
    cd "$WORK_DIR"
    git init -q -b main
    git config user.email ci@example.com
    git config user.name  ci
    git add -A
    git commit -q -m "init"
}

teardown() {
    cd /tmp || true
    rm -rf "$WORK_DIR"
}

# ---------- Workflow structure tests (cheap; run every time) -------------

@test "structure: workflow file exists and parses with actionlint" {
    run actionlint "$PROJECT_ROOT/.github/workflows/semantic-version-bumper.yml"
    [ "$status" -eq 0 ]
}

@test "structure: workflow declares expected triggers" {
    local wf="$PROJECT_ROOT/.github/workflows/semantic-version-bumper.yml"
    grep -q '^  push:'              "$wf"
    grep -q '^  pull_request:'      "$wf"
    grep -q '^  workflow_dispatch:' "$wf"
    grep -q '^  schedule:'          "$wf"
}

@test "structure: workflow references bump-version.sh and the bats tests" {
    local wf="$PROJECT_ROOT/.github/workflows/semantic-version-bumper.yml"
    grep -q 'bump-version.sh'           "$wf"
    grep -q 'tests/bump-version.bats'   "$wf"
    [ -f "$PROJECT_ROOT/bump-version.sh" ]
    [ -f "$PROJECT_ROOT/tests/bump-version.bats" ]
}

@test "structure: workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' \
        "$PROJECT_ROOT/.github/workflows/semantic-version-bumper.yml"
}

# ---------- act-based end-to-end test cases ------------------------------

# Helper: run act with the given env vars and append stdout/stderr to the
# shared act-result.txt. Echoes the output so bats `run` can also see it.
run_act_case() {
    local label="$1" version="$2" commits_fixture="$3"
    {
        printf '\n========== CASE: %s ==========\n' "$label"
        printf 'starting_version=%s commits_fixture=%s\n' "$version" "$commits_fixture"
    } >> "$ACT_RESULT_FILE"

    # Pre-seed VERSION so the workflow has something to read.
    echo "$version" > "$WORK_DIR/VERSION"

    local out
    out="$(act push --rm \
        --env "VERSION_FILE=VERSION" \
        --env "COMMITS_FILE=$commits_fixture" \
        --env "STARTING_VERSION=$version" \
        2>&1)" || {
            local rc=$?
            printf '%s\n' "$out" >> "$ACT_RESULT_FILE"
            printf '[act exited %d]\n' "$rc" >> "$ACT_RESULT_FILE"
            printf '%s\n' "$out"
            return "$rc"
        }
    printf '%s\n' "$out" >> "$ACT_RESULT_FILE"
    printf '%s\n' "$out"
}

@test "act: feat commit on 1.1.0 produces 1.2.0" {
    run run_act_case "feat-1.1.0-to-1.2.0" "1.1.0" "fixtures/feat-commits.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEW_VERSION=1.2.0"* ]]
    [[ "$output" == *"Job succeeded"* ]]
}

@test "act: fix-only commits on 0.5.0 produces 0.5.1" {
    run run_act_case "fix-0.5.0-to-0.5.1" "0.5.0" "fixtures/fix-commits.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEW_VERSION=0.5.1"* ]]
    [[ "$output" == *"Job succeeded"* ]]
}

@test "act: breaking change commit on 1.4.2 produces 2.0.0" {
    run run_act_case "breaking-1.4.2-to-2.0.0" "1.4.2" "fixtures/breaking-commits.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEW_VERSION=2.0.0"* ]]
    [[ "$output" == *"Job succeeded"* ]]
}

@test "act: act-result.txt was produced" {
    [ -s "$ACT_RESULT_FILE" ]
    grep -q "CASE:" "$ACT_RESULT_FILE"
}
