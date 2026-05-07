#!/usr/bin/env bats
# Integration tests: every assertion is made on output captured from running
# the GitHub Actions workflow inside `act`. We never invoke aggregate.sh
# directly here — all behavior is verified through the CI pipeline.

PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
ACT_RESULT_FILE="$PROJECT_ROOT/act-result.txt"

setup_file() {
    : > "$ACT_RESULT_FILE"
    export ACT_RESULT_FILE
    export PROJECT_ROOT
}

# Build an ephemeral git repo containing the project files plus a chosen
# fixture directory copied to RESULTS_DIR (which the workflow consumes).
# Args: <case-name> <source-fixtures-dir>
run_act_case() {
    local case_name=$1
    local fixtures_src=$2
    local tmp
    tmp=$(mktemp -d)
    # Copy required project files
    cp "$PROJECT_ROOT/aggregate.sh" "$tmp/"
    mkdir -p "$tmp/.github/workflows"
    cp "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml" \
        "$tmp/.github/workflows/"
    cp "$PROJECT_ROOT/.actrc" "$tmp/" 2>/dev/null || true
    # Always feed via fixtures/ since RESULTS_DIR=fixtures in the workflow
    mkdir -p "$tmp/fixtures"
    cp -r "$fixtures_src"/. "$tmp/fixtures/"
    (
        cd "$tmp"
        git init -q
        git config user.email t@e
        git config user.name t
        git add -A
        git commit -qm "case: $case_name"
        # Run act, capture combined output
        act push --rm 2>&1
    ) > "$tmp/out.txt"
    local rc=$?
    {
        echo "===== BEGIN CASE: $case_name (rc=$rc) ====="
        cat "$tmp/out.txt"
        echo "===== END CASE: $case_name ====="
        echo
    } >> "$ACT_RESULT_FILE"
    LAST_ACT_OUT=$(cat "$tmp/out.txt")
    rm -rf "$tmp"
    return "$rc"
}

@test "workflow file exists and has required structure" {
    [ -f "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml" ]
    run grep -E '^on:' "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ "$status" -eq 0 ]
    run grep -E 'actions/checkout@v4' "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ "$status" -eq 0 ]
    run grep -E 'aggregate.sh' "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ "$status" -eq 0 ]
}

@test "workflow references existing script path" {
    [ -f "$PROJECT_ROOT/aggregate.sh" ]
    run bash -n "$PROJECT_ROOT/aggregate.sh"
    [ "$status" -eq 0 ]
}

@test "actionlint passes on workflow" {
    run actionlint "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ "$status" -eq 0 ]
}

@test "shellcheck passes on aggregate.sh" {
    run shellcheck "$PROJECT_ROOT/aggregate.sh"
    [ "$status" -eq 0 ]
}

@test "act case 1: mixed JUnit+JSON fixtures with flaky test" {
    run_act_case "mixed" "$PROJECT_ROOT/fixtures"
    rc=$?
    [ "$rc" -eq 0 ]
    [[ "$LAST_ACT_OUT" == *"Job succeeded"* ]]
    # Exact aggregate values for fixtures/
    [[ "$LAST_ACT_OUT" == *"| Total    | 10 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Passed   | 7 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Failed   | 2 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Skipped  | 1 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Duration | 2.900s |"* ]]
    [[ "$LAST_ACT_OUT" == *"## Flaky Tests (1)"* ]]
    [[ "$LAST_ACT_OUT" == *"- test_flaky_network"* ]]
    [[ "$LAST_ACT_OUT" == *":x: FAILED"* ]]
}

@test "act case 2: clean fixtures (no failures, no flakes)" {
    run_act_case "clean" "$PROJECT_ROOT/fixtures-clean"
    rc=$?
    [ "$rc" -eq 0 ]
    [[ "$LAST_ACT_OUT" == *"Job succeeded"* ]]
    [[ "$LAST_ACT_OUT" == *"| Total    | 3 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Passed   | 2 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Failed   | 0 |"* ]]
    [[ "$LAST_ACT_OUT" == *"| Skipped  | 1 |"* ]]
    [[ "$LAST_ACT_OUT" == *"## Flaky Tests (0)"* ]]
    [[ "$LAST_ACT_OUT" == *"_No flaky tests detected._"* ]]
    [[ "$LAST_ACT_OUT" == *":white_check_mark: PASSED"* ]]
}

@test "act-result.txt artifact was produced" {
    [ -s "$ACT_RESULT_FILE" ]
    run grep -c "BEGIN CASE:" "$ACT_RESULT_FILE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
}
