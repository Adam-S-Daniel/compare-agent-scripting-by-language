#!/usr/bin/env bats
# TDD harness for license-checker.sh
# NOTE: Per task rules, script behaviour is exercised exclusively through
# the GitHub Actions workflow via `act`. The only tests that touch files
# directly are workflow-structure / lint checks, which is explicitly allowed.
#
# Act output from every "act push" run is appended to act-result.txt
# (delimited) so it survives as a reviewable artifact.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")"/.. && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/dependency-license-checker.yml"
ACT_RESULT="$REPO_ROOT/act-result.txt"

# Build an isolated temp git repo containing project files + one fixture's
# manifest, run `act push --rm` once, append the full output to
# act-result.txt, and expose captured output via ACT_OUT / ACT_RC.
act_run() {
    local case_name="$1"
    local fixture_dir="$2"
    local tmp out rc

    tmp="$(mktemp -d)"
    cp "$REPO_ROOT/license-checker.sh"                 "$tmp/"
    cp -r "$REPO_ROOT/config"                          "$tmp/"
    cp -r "$REPO_ROOT/mock-data"                       "$tmp/"
    mkdir -p "$tmp/.github/workflows"
    cp "$WORKFLOW"                                     "$tmp/.github/workflows/"
    cp "$REPO_ROOT/.actrc"                             "$tmp/" 2>/dev/null || true
    cp "$fixture_dir/package.json" "$tmp/package.json"

    pushd "$tmp" >/dev/null
    git init -q -b main
    git config user.email "ci@example.com"
    git config user.name  "ci"
    git add -A
    git commit -q -m "fixture: $case_name"
    # Use if/else so a non-zero act exit (expected for denied fixture) does
    # not trip bats' errexit before we record the exit code.
    if out="$(act push --rm --pull=false --container-architecture linux/amd64 2>&1)"; then
        rc=0
    else
        rc=$?
    fi
    popd >/dev/null

    {
        printf '\n===== BEGIN CASE: %s (exit=%d) =====\n' "$case_name" "$rc"
        printf '%s\n' "$out"
        printf '===== END CASE: %s =====\n' "$case_name"
    } >> "$ACT_RESULT"

    rm -rf "$tmp"
    ACT_OUT="$out"
    ACT_RC=$rc
}

setup_file() {
    : > "$ACT_RESULT"
}

# ---------- Workflow structure / lint tests (no act) ----------

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "actionlint passes on workflow" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "bash -n syntax check passes on license-checker.sh" {
    run bash -n "$REPO_ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
}

@test "shellcheck passes on license-checker.sh" {
    run shellcheck "$REPO_ROOT/license-checker.sh"
    [ "$status" -eq 0 ]
}

@test "workflow has expected top-level triggers" {
    run grep -E '^on:' "$WORKFLOW"
    [ "$status" -eq 0 ]
    grep -q 'push:'              "$WORKFLOW"
    grep -q 'pull_request:'      "$WORKFLOW"
    grep -q 'workflow_dispatch:' "$WORKFLOW"
}

@test "workflow references license-checker.sh" {
    grep -q 'license-checker.sh' "$WORKFLOW"
}

@test "workflow references config and mock-data paths" {
    grep -q 'config/allowed-licenses.txt' "$WORKFLOW"
    grep -q 'config/denied-licenses.txt'  "$WORKFLOW"
    grep -q 'mock-data/license-db.tsv'    "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WORKFLOW"
}

@test "workflow grants minimal permissions" {
    grep -qE 'contents:[[:space:]]*read' "$WORKFLOW"
}

# ---------- act-driven end-to-end tests ----------

@test "act: approved fixture exits 0 and reports APPROVED" {
    act_run "approved" "$REPO_ROOT/fixtures/approved"
    [ "$ACT_RC" -eq 0 ]
    echo "$ACT_OUT" | grep -qE 'express@4\.18\.0[[:space:]]+MIT[[:space:]]+APPROVED'
    echo "$ACT_OUT" | grep -qE 'lodash@4\.17\.21[[:space:]]+MIT[[:space:]]+APPROVED'
    echo "$ACT_OUT" | grep -qE 'axios@1\.6\.2[[:space:]]+Apache-2\.0[[:space:]]+APPROVED'
    echo "$ACT_OUT" | grep -qE 'Result:[[:space:]]+PASS'
    echo "$ACT_OUT" | grep -q 'Job succeeded'
}

@test "act: denied fixture exits non-zero and reports DENIED" {
    act_run "denied" "$REPO_ROOT/fixtures/denied"
    [ "$ACT_RC" -ne 0 ]
    echo "$ACT_OUT" | grep -qE 'gpl-package@1\.0\.0[[:space:]]+GPL-3\.0[[:space:]]+DENIED'
    echo "$ACT_OUT" | grep -qE 'lodash@4\.17\.21[[:space:]]+MIT[[:space:]]+APPROVED'
    echo "$ACT_OUT" | grep -qE 'Result:[[:space:]]+FAIL'
    # The "Run license checker" step failed, but overall act reports Job failed.
    # We still want confirmation that act ran the job (not a container crash).
    echo "$ACT_OUT" | grep -qE 'Job failed'
}

@test "act: unknown fixture exits 0 and reports UNKNOWN for missing dep" {
    act_run "unknown" "$REPO_ROOT/fixtures/unknown"
    [ "$ACT_RC" -eq 0 ]
    echo "$ACT_OUT" | grep -qE 'mystery-pkg@0\.1\.0[[:space:]]+\(not found\)[[:space:]]+UNKNOWN'
    echo "$ACT_OUT" | grep -qE 'express@4\.18\.0[[:space:]]+MIT[[:space:]]+APPROVED'
    echo "$ACT_OUT" | grep -qE 'Result:[[:space:]]+PASS'
    echo "$ACT_OUT" | grep -q 'Job succeeded'
}

# ---------- File existence / layout sanity ----------

@test "fixtures directory contains all three test cases" {
    [ -f "$REPO_ROOT/fixtures/approved/package.json" ]
    [ -f "$REPO_ROOT/fixtures/denied/package.json" ]
    [ -f "$REPO_ROOT/fixtures/unknown/package.json" ]
}

@test "config and mock-data files exist" {
    [ -f "$REPO_ROOT/config/allowed-licenses.txt" ]
    [ -f "$REPO_ROOT/config/denied-licenses.txt" ]
    [ -f "$REPO_ROOT/mock-data/license-db.tsv" ]
}
