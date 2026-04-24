#!/usr/bin/env bats
# Workflow tests: every test case runs through the GitHub Actions workflow
# under `act`. Each case sets up a temp git repo with project files plus a
# specific fixture set, runs `act push --rm`, appends output to act-result.txt
# (in the project root), and asserts on EXACT expected values.

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"
ACTRC="${PROJECT_ROOT}/.actrc"

setup_file() {
    : > "$ACT_RESULT"
}

# Build a throwaway git repo containing the project + selected fixture files,
# then run `act push --rm` and capture combined output.
# Args: <case-name> <fixture-glob...>
run_act_case() {
    local case_name="$1"; shift
    local sandbox
    sandbox="$(mktemp -d)"

    # Copy script + workflow into sandbox
    cp "$PROJECT_ROOT/aggregate.sh" "$sandbox/"
    cp "$ACTRC" "$sandbox/" 2>/dev/null || true
    mkdir -p "$sandbox/.github/workflows" "$sandbox/fixtures"
    cp "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml" \
        "$sandbox/.github/workflows/"

    # Copy only the fixtures specified for this case
    for fx in "$@"; do
        cp "$PROJECT_ROOT/fixtures/$fx" "$sandbox/fixtures/"
    done

    # Initialize git repo (act requires one)
    (
        cd "$sandbox"
        git init -q
        git config user.email "ci@example.com"
        git config user.name "ci"
        git add -A
        git commit -q -m "test fixture $case_name"
    )

    # Run act, capturing output
    local out_file="$sandbox/act.out"
    local rc=0
    ( cd "$sandbox" && act push --rm ) > "$out_file" 2>&1 || rc=$?

    {
        echo "===== CASE: $case_name (exit=$rc) ====="
        cat "$out_file"
        echo
    } >> "$ACT_RESULT"

    ACT_OUTPUT="$(cat "$out_file")"
    ACT_RC="$rc"
    rm -rf "$sandbox"
}

@test "workflow: full fixture set produces aggregate totals (7/4/2/1) and flaky test" {
    run_act_case "full" junit-run1.xml junit-run2.xml json-run1.json
    [ "$ACT_RC" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    # NB: junit-run1 + junit-run2 = same testcases re-run. Plus json-run1.
    # 4 + 3 + 3 = 10 records; 2+3+2 passed; 1+0+1 failed; 1 skipped.
    # suiteA.testB is flaky (failed in run1, passed in run2).
    [[ "$ACT_OUTPUT" == *"AGGREGATE_OK"* ]]
    [[ "$ACT_OUTPUT" == *"Total: 10"* ]]
    [[ "$ACT_OUTPUT" == *"Passed: 7"* ]]
    [[ "$ACT_OUTPUT" == *"Failed: 2"* ]]
    [[ "$ACT_OUTPUT" == *"Skipped: 1"* ]]
    [[ "$ACT_OUTPUT" == *"suiteA.testB"* ]]
}

@test "workflow: act-result.txt was created and is non-empty" {
    [ -s "$ACT_RESULT" ]
    grep -q "CASE: full" "$ACT_RESULT"
}
