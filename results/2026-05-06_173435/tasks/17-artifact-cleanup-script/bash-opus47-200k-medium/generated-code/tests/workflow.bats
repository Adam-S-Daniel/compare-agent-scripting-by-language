#!/usr/bin/env bats

# End-to-end workflow tests. Each test runs the GitHub Actions workflow via
# `act push` and asserts on exact expected output values.
#
# All `act` output (stdout + stderr) is appended to act-result.txt in the project
# root, with clear delimiters between cases. The test harness budget is 3 act
# runs total (one per case).

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW_FILE="${PROJECT_ROOT}/.github/workflows/artifact-cleanup-script.yml"
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

setup_file() {
    # Reset accumulated act output once per test file.
    : > "${PROJECT_ROOT}/act-result.txt"
}

run_act_case() {
    # $1=label  $2=fixture path  $3=max_age  $4=keep_latest  $5=max_total_size
    local label="$1" fixture="$2" max_age="$3" keep_latest="$4" max_total_size="$5"
    {
        echo ""
        echo "================ ACT CASE: ${label} ================"
        echo "fixture=${fixture} max_age=${max_age} keep_latest=${keep_latest} max_total_size=${max_total_size}"
    } >> "$ACT_RESULT"

    pushd "$PROJECT_ROOT" >/dev/null
    set +e
    act push --rm --pull=false \
        --env CLEANUP_FIXTURE="$fixture" \
        --env CLEANUP_MAX_AGE="$max_age" \
        --env CLEANUP_KEEP_LATEST="$keep_latest" \
        --env CLEANUP_MAX_TOTAL_SIZE="$max_total_size" \
        --env CLEANUP_NOW="1778457600" \
        2>&1 | tee -a "$ACT_RESULT"
    local rc=${PIPESTATUS[0]}
    set -e
    popd >/dev/null
    {
        echo "---- act exit code: ${rc} ----"
    } >> "$ACT_RESULT"
    return "$rc"
}

# ---------- Workflow structure tests ----------

@test "workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "actionlint passes" {
    run actionlint "$WORKFLOW_FILE"
    # run_act_case returns the act exit code; bats fails the test on a non-zero
    # simple command, so the call above already gates this test on act success.
    [ -f "$ACT_RESULT" ]
}

@test "workflow references the cleanup script" {
    grep -q 'cleanup-artifacts.sh' "$WORKFLOW_FILE"
    [ -f "${PROJECT_ROOT}/cleanup-artifacts.sh" ]
}

@test "workflow has push, pull_request, schedule, and workflow_dispatch triggers" {
    grep -qE '^[[:space:]]*push:' "$WORKFLOW_FILE"
    grep -qE '^[[:space:]]*pull_request:' "$WORKFLOW_FILE"
    grep -qE '^[[:space:]]*schedule:' "$WORKFLOW_FILE"
    grep -qE '^[[:space:]]*workflow_dispatch:' "$WORKFLOW_FILE"
}

@test "workflow declares contents:read permission" {
    grep -qE 'contents:[[:space:]]*read' "$WORKFLOW_FILE"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WORKFLOW_FILE"
}

@test "all referenced fixtures exist" {
    [ -f "${PROJECT_ROOT}/fixtures/case1_max_age.tsv" ]
    [ -f "${PROJECT_ROOT}/fixtures/case2_keep_latest.tsv" ]
    [ -f "${PROJECT_ROOT}/fixtures/case3_combined.tsv" ]
}

# ---------- Act-based end-to-end tests (one run per case, 3 total) ----------

@test "act case 1: max-age policy" {
    run_act_case "case1_max_age" "fixtures/case1_max_age.tsv" 14 2 10000000
    # run_act_case returns the act exit code; bats fails the test on a non-zero
    # simple command, so the call above already gates this test on act success.
    [ -f "$ACT_RESULT" ]
    grep -q 'Job succeeded' "$ACT_RESULT"

    # Walk back the most recent case block and assert exact counts.
    last_block="$(awk '/ACT CASE: case1_max_age/{flag=1; next} /ACT CASE: /{flag=0} flag' "$ACT_RESULT")"
    [[ "$last_block" == *"DELETE: old-build"* ]]
    [[ "$last_block" == *"max_age"* ]]
    [[ "$last_block" == *"KEEP: mid-build"* ]]
    [[ "$last_block" == *"KEEP: new-build"* ]]
    [[ "$last_block" == *"Total artifacts: 3"* ]]
    [[ "$last_block" == *"Retained: 2"* ]]
    [[ "$last_block" == *"Deleted: 1"* ]]
    [[ "$last_block" == *"Space reclaimed: 100"* ]]
    [[ "$last_block" == *"Mode: dry-run"* ]]
}

@test "act case 2: keep-latest-N policy" {
    run_act_case "case2_keep_latest" "fixtures/case2_keep_latest.tsv" 14 2 10000000
    # run_act_case returns the act exit code; bats fails the test on a non-zero
    # simple command, so the call above already gates this test on act success.
    [ -f "$ACT_RESULT" ]
    last_block="$(awk '/ACT CASE: case2_keep_latest/{flag=1; next} /ACT CASE: /{flag=0} flag' "$ACT_RESULT")"
    [[ "$last_block" == *"Job succeeded"* ]]
    [[ "$last_block" == *"DELETE: a1"* ]]
    [[ "$last_block" == *"DELETE: a2"* ]]
    [[ "$last_block" == *"keep_latest"* ]]
    [[ "$last_block" == *"KEEP: a3"* ]]
    [[ "$last_block" == *"KEEP: a4"* ]]
    [[ "$last_block" == *"KEEP: b1"* ]]
    [[ "$last_block" == *"Total artifacts: 5"* ]]
    [[ "$last_block" == *"Retained: 3"* ]]
    [[ "$last_block" == *"Deleted: 2"* ]]
    [[ "$last_block" == *"Space reclaimed: 30"* ]]
}

@test "act case 3: combined policies (age + keep-latest + size)" {
    run_act_case "case3_combined" "fixtures/case3_combined.tsv" 15 2 150
    # run_act_case returns the act exit code; bats fails the test on a non-zero
    # simple command, so the call above already gates this test on act success.
    [ -f "$ACT_RESULT" ]
    last_block="$(awk '/ACT CASE: case3_combined/{flag=1; next} /ACT CASE: /{flag=0} flag' "$ACT_RESULT")"
    [[ "$last_block" == *"Job succeeded"* ]]
    [[ "$last_block" == *"DELETE: a30"* ]]
    [[ "$last_block" == *"DELETE: a20"* ]]
    [[ "$last_block" == *"DELETE: a10"* ]]
    [[ "$last_block" == *"DELETE: a5"* ]]
    [[ "$last_block" == *"KEEP: a1"* ]]
    [[ "$last_block" == *"max_age"* ]]
    [[ "$last_block" == *"keep_latest"* ]]
    [[ "$last_block" == *"max_total_size"* ]]
    [[ "$last_block" == *"Total artifacts: 5"* ]]
    [[ "$last_block" == *"Retained: 1"* ]]
    [[ "$last_block" == *"Deleted: 4"* ]]
    [[ "$last_block" == *"Space reclaimed: 400"* ]]
}
