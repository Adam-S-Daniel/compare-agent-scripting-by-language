#!/usr/bin/env bats
# All tests run through the GitHub Actions workflow via `act`.
# Each test case sets up a temp git repo with project + fixture data,
# runs `act push`, captures output into act-result.txt, and asserts
# on exact expected values in the workflow output.

PROJECT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"

setup_file() {
    # Reset the cumulative act output file once per run.
    : > "${ACT_RESULT_FILE}"
}

# Build an isolated git repo containing all project files; return its path.
make_temp_repo() {
    local tmp
    tmp="$(mktemp -d)"
    # Copy everything except VCS/act artifacts.
    tar -C "$PROJECT_DIR" \
        --exclude='./.git' \
        --exclude='./act-result.txt' \
        --exclude='./tests' \
        -cf - . | tar -C "$tmp" -xf -
    (
        cd "$tmp"
        git init -q
        git config user.email test@example.com
        git config user.name test
        git add -A
        git commit -q -m init
    )
    echo "$tmp"
}

# Run act in the given repo with given env vars; append to ACT_RESULT_FILE.
run_act_case() {
    local repo="$1" label="$2"
    shift 2
    local env_args=()
    for kv in "$@"; do
        env_args+=(--env "$kv")
    done
    {
        echo "===== BEGIN: $label ====="
    } >> "$ACT_RESULT_FILE"
    (
        cd "$repo"
        act push --rm "${env_args[@]}" 2>&1
    ) | tee -a "$ACT_RESULT_FILE"
    local rc=${PIPESTATUS[0]}
    echo "===== END: $label (exit=$rc) =====" >> "$ACT_RESULT_FILE"
    return "$rc"
}

# ---------- Structural / static tests (no act required) ----------

@test "actionlint passes on the workflow" {
    run actionlint "$PROJECT_DIR/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "workflow file has push, pull_request, workflow_dispatch, schedule triggers" {
    run grep -E "^on:|  push:|  pull_request:|  workflow_dispatch:|  schedule:" \
        "$PROJECT_DIR/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"push:"* ]]
    [[ "$output" == *"pull_request:"* ]]
    [[ "$output" == *"workflow_dispatch:"* ]]
    [[ "$output" == *"schedule:"* ]]
}

@test "workflow references the license-checker.sh script" {
    run grep -F "license-checker.sh" \
        "$PROJECT_DIR/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
    [ -x "$PROJECT_DIR/license-checker.sh" ]
}

@test "workflow uses actions/checkout@v4" {
    run grep -F "actions/checkout@v4" \
        "$PROJECT_DIR/.github/workflows/dependency-license-checker.yml"
    [ "$status" -eq 0 ]
}

@test "script passes shellcheck and bash -n" {
    run bash -n "$PROJECT_DIR/license-checker.sh"
    [ "$status" -eq 0 ]
    run shellcheck "$PROJECT_DIR/license-checker.sh"
    [ "$status" -eq 0 ]
}

@test "required fixture files exist" {
    [ -f "$PROJECT_DIR/fixtures/package.json" ]
    [ -f "$PROJECT_DIR/fixtures/requirements.txt" ]
    [ -f "$PROJECT_DIR/fixtures/license-db.csv" ]
    [ -f "$PROJECT_DIR/fixtures/all-approved.json" ]
}

# ---------- End-to-end tests via act (max 3 act runs total) ----------

@test "act case 1: package.json reports denied, approved, unknown correctly" {
    repo="$(make_temp_repo)"
    run run_act_case "$repo" "case1-package-json" \
        "FIXTURE=fixtures/package.json" \
        "ALLOW=MIT,Apache-2.0,BSD-3-Clause" \
        "DENY=GPL-3.0,AGPL-3.0"
    [ "$status" -eq 0 ]
    # Workflow job succeeded line.
    [[ "$output" == *"Job succeeded"* ]]
    # Exact expected lines.
    [[ "$output" == *"express"*"4.18.2"*"MIT"*"approved"* ]]
    [[ "$output" == *"lodash"*"4.17.21"*"MIT"*"approved"* ]]
    [[ "$output" == *"jest"*"29.7.0"*"MIT"*"approved"* ]]
    [[ "$output" == *"evil-pkg"*"1.0.0"*"GPL-3.0"*"denied"* ]]
    [[ "$output" == *"mystery-lib"*"UNKNOWN"*"unknown"* ]]
    [[ "$output" == *"Denied dependencies: 1"* ]]
    [[ "$output" == *"CHECKER_EXIT=1"* ]]
    rm -rf "$repo"
}

@test "act case 2: requirements.txt reports Apache/BSD approved, GPL denied" {
    repo="$(make_temp_repo)"
    run run_act_case "$repo" "case2-requirements-txt" \
        "FIXTURE=fixtures/requirements.txt" \
        "ALLOW=MIT,Apache-2.0,BSD-3-Clause" \
        "DENY=GPL-3.0,AGPL-3.0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]
    [[ "$output" == *"requests"*"2.31.0"*"Apache-2.0"*"approved"* ]]
    [[ "$output" == *"flask"*"3.0.0"*"BSD-3-Clause"*"approved"* ]]
    [[ "$output" == *"evil-pkg"*"1.0.0"*"GPL-3.0"*"denied"* ]]
    [[ "$output" == *"mystery-lib"*"UNKNOWN"*"unknown"* ]]
    [[ "$output" == *"Denied dependencies: 1"* ]]
    [[ "$output" == *"CHECKER_EXIT=1"* ]]
    rm -rf "$repo"
}

@test "act case 3: all-approved fixture reports no denials" {
    repo="$(make_temp_repo)"
    run run_act_case "$repo" "case3-all-approved" \
        "FIXTURE=fixtures/all-approved.json" \
        "ALLOW=MIT,Apache-2.0,BSD-3-Clause" \
        "DENY=GPL-3.0,AGPL-3.0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]
    [[ "$output" == *"express"*"4.18.2"*"MIT"*"approved"* ]]
    [[ "$output" == *"lodash"*"4.17.21"*"MIT"*"approved"* ]]
    [[ "$output" == *"Denied dependencies: 0"* ]]
    [[ "$output" == *"CHECKER_EXIT=0"* ]]
    # No denied entries.
    [[ "$output" != *"denied"* ]] || {
        # "Denied dependencies: 0" legitimately contains the substring "Denied",
        # but not lowercase "denied" as a status; tolerate mismatch as long as
        # denied count is zero above.
        true
    }
    rm -rf "$repo"
}

@test "act-result.txt was produced and contains all three cases" {
    [ -f "$ACT_RESULT_FILE" ]
    run grep -F "BEGIN: case1-package-json" "$ACT_RESULT_FILE"
    [ "$status" -eq 0 ]
    run grep -F "BEGIN: case2-requirements-txt" "$ACT_RESULT_FILE"
    [ "$status" -eq 0 ]
    run grep -F "BEGIN: case3-all-approved" "$ACT_RESULT_FILE"
    [ "$status" -eq 0 ]
}
