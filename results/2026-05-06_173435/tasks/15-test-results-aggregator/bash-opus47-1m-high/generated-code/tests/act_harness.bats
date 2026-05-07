#!/usr/bin/env bats

# End-to-end harness: run the workflow through `act` against three fixture
# scenarios and assert exact output values for each. All act invocations
# happen in setup_file (one act run per case) so the per-test asserts
# below are cheap.
#
# Each case appends its captured output to act-result.txt in the project
# root, clearly delimited.

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT
    export ACT_RESULT_FILE="${PROJECT_ROOT}/act-result.txt"
    : > "${ACT_RESULT_FILE}"

    # Run each case once and stash output paths for the per-test asserts.
    # FIXTURES_DIR is passed *into* the workflow container via act --env, so
    # the project tree itself is unchanged across cases — only the input
    # data the aggregator job consumes differs.
    _run_case "default"        "tests/cases/default"
    _run_case "all-pass"       "tests/cases/all-pass"
    _run_case "mixed-no-flaky" "tests/cases/mixed-no-flaky"
}

# _run_case CASE_NAME FIXTURES_REL_PATH
# Stages a temp git repo with the project files (unchanged), runs
# `act push --rm --env FIXTURES_DIR=<rel_path>`, captures stdout+stderr,
# appends a delimited block to act-result.txt, and stashes the exit code
# in a sidecar file for the per-test asserts to consult.
_run_case() {
    local case_name="$1"
    local fixtures_rel="$2"
    local tmp out_file exit_file
    tmp="$(mktemp -d)"
    out_file="${PROJECT_ROOT}/.act-out-${case_name}.txt"
    exit_file="${PROJECT_ROOT}/.act-exit-${case_name}.txt"

    # Stage project files. We exclude the prior git repo and any leftover
    # harness artifacts so the temp tree is clean.
    rsync -a \
        --exclude='.git' \
        --exclude='act-result.txt' \
        --exclude='.act-out-*.txt' \
        --exclude='.act-exit-*.txt' \
        "${PROJECT_ROOT}/" "${tmp}/"

    # Initialize a git repo so act can resolve HEAD for the push event.
    (
        cd "${tmp}"
        git init -q -b main
        git -c user.email=t@example.com -c user.name=harness add -A
        git -c user.email=t@example.com -c user.name=harness commit -q -m "case ${case_name}"
    )

    local rc=0
    (
        cd "${tmp}"
        act push --rm --env "FIXTURES_DIR=${fixtures_rel}" 2>&1
    ) > "${out_file}" || rc=$?
    echo "${rc}" > "${exit_file}"

    {
        printf '\n=========================================================\n'
        printf 'CASE: %s\n' "${case_name}"
        printf 'FIXTURES_DIR: %s\n' "${fixtures_rel}"
        printf 'EXIT: %d\n' "${rc}"
        printf '=========================================================\n'
        cat "${out_file}"
        printf '\n--------- end %s ---------\n' "${case_name}"
    } >> "${ACT_RESULT_FILE}"

    rm -rf "${tmp}"
}

# Helper for per-test asserts: read a case's output file.
_case_output() {
    cat "${PROJECT_ROOT}/.act-out-$1.txt"
}
_case_exit() {
    cat "${PROJECT_ROOT}/.act-exit-$1.txt"
}

# --- Common assertions ------------------------------------------------------

@test "act-result.txt was created" {
    [ -s "${ACT_RESULT_FILE}" ]
}

# --- Case: default (mixed pass/fail with two flaky tests) -------------------

@test "[default] act exited 0" {
    [ "$(_case_exit default)" = "0" ]
}

@test "[default] every job reported success" {
    output="$(_case_output default)"
    # act prints "Job succeeded" for each job.
    count="$(printf '%s\n' "$output" | grep -c 'Job succeeded' || true)"
    # We have three jobs (lint, unit-tests, aggregate).
    [ "$count" -ge 3 ]
}

@test "[default] aggregator counted 11 passed" {
    _case_output default | grep -q 'AGG_PASSED=11'
}

@test "[default] aggregator counted 2 failed" {
    _case_output default | grep -q 'AGG_FAILED=2'
}

@test "[default] aggregator counted 2 skipped" {
    _case_output default | grep -q 'AGG_SKIPPED=2'
}

@test "[default] aggregator total is 15" {
    _case_output default | grep -q 'AGG_TOTAL=15'
}

@test "[default] aggregator detected 2 flaky tests" {
    _case_output default | grep -q 'AGG_FLAKY_COUNT=2'
}

@test "[default] flaky list contains Calc::test_divide" {
    _case_output default | grep -q 'Calc::test_divide'
}

@test "[default] flaky list contains String::test_lower" {
    _case_output default | grep -q 'String::test_lower'
}

# --- Case: all-pass ---------------------------------------------------------

@test "[all-pass] act exited 0" {
    [ "$(_case_exit all-pass)" = "0" ]
}

@test "[all-pass] every job reported success" {
    output="$(_case_output all-pass)"
    count="$(printf '%s\n' "$output" | grep -c 'Job succeeded' || true)"
    [ "$count" -ge 3 ]
}

@test "[all-pass] aggregator counted 5 passed" {
    _case_output all-pass | grep -q 'AGG_PASSED=5'
}

@test "[all-pass] aggregator counted 0 failed" {
    _case_output all-pass | grep -q 'AGG_FAILED=0'
}

@test "[all-pass] aggregator total is 5" {
    _case_output all-pass | grep -q 'AGG_TOTAL=5'
}

@test "[all-pass] aggregator detected 0 flaky tests" {
    _case_output all-pass | grep -q 'AGG_FLAKY_COUNT=0'
}

# --- Case: mixed-no-flaky ---------------------------------------------------

@test "[mixed-no-flaky] act exited 0" {
    [ "$(_case_exit mixed-no-flaky)" = "0" ]
}

@test "[mixed-no-flaky] every job reported success" {
    output="$(_case_output mixed-no-flaky)"
    count="$(printf '%s\n' "$output" | grep -c 'Job succeeded' || true)"
    [ "$count" -ge 3 ]
}

@test "[mixed-no-flaky] aggregator counted 2 passed" {
    _case_output mixed-no-flaky | grep -q 'AGG_PASSED=2'
}

@test "[mixed-no-flaky] aggregator counted 2 failed" {
    _case_output mixed-no-flaky | grep -q 'AGG_FAILED=2'
}

@test "[mixed-no-flaky] aggregator counted 2 skipped" {
    _case_output mixed-no-flaky | grep -q 'AGG_SKIPPED=2'
}

@test "[mixed-no-flaky] aggregator total is 6" {
    _case_output mixed-no-flaky | grep -q 'AGG_TOTAL=6'
}

@test "[mixed-no-flaky] no flaky tests detected" {
    _case_output mixed-no-flaky | grep -q 'AGG_FLAKY_COUNT=0'
}
