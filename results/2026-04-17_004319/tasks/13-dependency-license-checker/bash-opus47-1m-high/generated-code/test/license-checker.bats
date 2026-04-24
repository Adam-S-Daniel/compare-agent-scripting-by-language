#!/usr/bin/env bats
# Integration tests. Every test runs the workflow through `act push --rm`
# against an isolated temp git repo seeded with a specific fixture, then
# asserts on exact values in the captured output.
#
# TDD history (red -> green):
#   1. Started by writing a single failing test that asserted the script
#      existed and printed a usage message. It failed because the script
#      did not exist.
#   2. Added license-checker.sh stub with usage output -> green.
#   3. Added a parsing test for package.json -> failed. Implemented
#      extract_deps_from_package_json -> green.
#   4. Added a parsing test for requirements.txt -> failed. Implemented
#      extract_deps_from_requirements_txt -> green.
#   5. Added config allow/deny classification test -> failed. Implemented
#      classify_license -> green.
#   6. Added unknown-license case -> failed. Implemented UNKNOWN fallback -> green.
#   7. Added exit-code test (nonzero on any DENIED) -> green after wiring main.
#   8. Wrapped everything into the GitHub Actions workflow and rewrote tests
#      to run through `act push --rm` per the benchmark requirement.

setup_file() {
    # ACT_RESULT is appended to by every test; clear it once per run.
    export PROJECT_DIR
    PROJECT_DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )/.." && pwd )"
    export ACT_RESULT="$PROJECT_DIR/act-result.txt"
    : > "$ACT_RESULT"
}

setup() {
    TMPREPO="$(mktemp -d)"
    export TMPREPO
}

teardown() {
    if [[ -n "${TMPREPO:-}" && -d "$TMPREPO" ]]; then
        rm -rf "$TMPREPO"
    fi
}

# seed_repo CASE_NAME
# Copies project files + a fixture into a fresh git repo at $TMPREPO.
# The workflow reads fixtures/current/* from the checked-out repo.
seed_repo() {
    local case="$1"
    cp -r "$PROJECT_DIR/.github" "$TMPREPO/"
    cp "$PROJECT_DIR/license-checker.sh" "$TMPREPO/"
    cp "$PROJECT_DIR/mock-license-lookup.sh" "$TMPREPO/"
    cp "$PROJECT_DIR/.actrc" "$TMPREPO/" 2>/dev/null || true
    mkdir -p "$TMPREPO/fixtures/current"
    cp -r "$PROJECT_DIR/fixtures/$case/." "$TMPREPO/fixtures/current/"
    (
        cd "$TMPREPO"
        git init -q -b main
        git config user.email bench@example.com
        git config user.name bench
        git add -A
        git commit -q -m "seed $case"
    )
}

run_act_case() {
    local case="$1"
    seed_repo "$case"
    {
        echo
        echo "===== CASE: $case ====="
    } >> "$ACT_RESULT"
    run bash -c "cd '$TMPREPO' && act push --rm 2>&1"
    echo "$output" >> "$ACT_RESULT"
    echo "exit=$status" >> "$ACT_RESULT"
}

@test "workflow structure: file exists and actionlint passes" {
    local wf="$PROJECT_DIR/.github/workflows/dependency-license-checker.yml"
    [ -f "$wf" ]
    run actionlint "$wf"
    [ "$status" -eq 0 ]
}

@test "workflow structure: references script files that exist" {
    [ -f "$PROJECT_DIR/license-checker.sh" ]
    [ -f "$PROJECT_DIR/mock-license-lookup.sh" ]
    local wf="$PROJECT_DIR/.github/workflows/dependency-license-checker.yml"
    grep -q 'license-checker.sh' "$wf"
    grep -q 'mock-license-lookup.sh' "$wf"
    grep -q 'actions/checkout@v4' "$wf"
    # Sanity: triggers and a job are declared.
    grep -qE '^on:' "$wf"
    grep -qE '^jobs:' "$wf"
}

@test "approved-mix fixture: package.json with approved, denied, and unknown deps" {
    run_act_case approved-mix
    [ "$status" -eq 0 ]  # act exit code (the job should complete)
    # Exact classifications expected from fixture + config:
    echo "$output" | grep -F 'lodash | MIT | APPROVED'
    echo "$output" | grep -F 'express | MIT | APPROVED'
    echo "$output" | grep -F 'evil-pkg | GPL-3.0 | DENIED'
    echo "$output" | grep -F 'mystery | UNKNOWN | UNKNOWN'
    # Totals line with exact counts.
    echo "$output" | grep -F 'TOTALS: approved=2 denied=1 unknown=1'
    # Report exit code embedded in workflow output (non-zero because DENIED present).
    echo "$output" | grep -F 'REPORT_EXIT=1'
    echo "$output" | grep -qi 'Job succeeded'
}

@test "all-approved fixture: requirements.txt with only allow-listed licenses" {
    run_act_case all-approved
    [ "$status" -eq 0 ]
    echo "$output" | grep -F 'requests | Apache-2.0 | APPROVED'
    echo "$output" | grep -F 'flask | BSD-3-Clause | APPROVED'
    echo "$output" | grep -F 'numpy | BSD-3-Clause | APPROVED'
    echo "$output" | grep -F 'TOTALS: approved=3 denied=0 unknown=0'
    echo "$output" | grep -F 'REPORT_EXIT=0'
    echo "$output" | grep -qi 'Job succeeded'
}

@test "all-denied fixture: every dep resolves to a denied license" {
    run_act_case all-denied
    [ "$status" -eq 0 ]
    echo "$output" | grep -F 'badpkg-one | GPL-3.0 | DENIED'
    echo "$output" | grep -F 'badpkg-two | AGPL-3.0 | DENIED'
    echo "$output" | grep -F 'TOTALS: approved=0 denied=2 unknown=0'
    echo "$output" | grep -F 'REPORT_EXIT=1'
    echo "$output" | grep -qi 'Job succeeded'
}
