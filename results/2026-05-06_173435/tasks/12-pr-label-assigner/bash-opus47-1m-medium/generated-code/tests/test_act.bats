#!/usr/bin/env bats
# End-to-end tests that drive the GitHub Actions workflow via `act`.
#
# We run `act push --rm` once per test case in an isolated temp git repo
# that holds a copy of the project plus the case-specific fixture data.
# All act output is appended to ./act-result.txt for inspection.
#
# To stay under the 3-act-run budget we have exactly 3 cases.

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ACT_RESULT="$PROJECT_ROOT/act-result.txt"

setup_file() {
    : >"$ACT_RESULT"   # truncate at start of suite
}

# Run a single act test case. Args:
#   $1 = case label (for header in act-result.txt)
#   $2 = path (relative to PROJECT_ROOT) to fixture file containing the
#        changed-files list under test
# Sets globals: ACT_OUTPUT, ACT_STATUS
run_act_case() {
    local case_name="$1"
    local fixture_rel="$2"

    # Build an isolated working tree containing only the project files
    # the workflow needs, plus the case's fixture installed at the path
    # the workflow reads (tests/fixtures/active_case.txt).
    local workdir
    workdir="$(mktemp -d)"
    cp -r \
        "$PROJECT_ROOT/.github" \
        "$PROJECT_ROOT/pr-label-assigner.sh" \
        "$PROJECT_ROOT/tests" \
        "$workdir/"
    cp "$PROJECT_ROOT/.actrc" "$workdir/.actrc"
    cp "$PROJECT_ROOT/$fixture_rel" "$workdir/tests/fixtures/active_case.txt"

    (
        cd "$workdir"
        git init -q
        git config user.email t@t
        git config user.name t
        git add -A
        git -c commit.gpgsign=false commit -q -m "case: $case_name"
    )

    {
        printf '\n=========================================\n'
        printf 'CASE: %s\n' "$case_name"
        printf '=========================================\n'
    } >>"$ACT_RESULT"

    set +e
    ACT_OUTPUT="$(cd "$workdir" && act push --rm 2>&1)"
    ACT_STATUS=$?
    set -e

    printf '%s\n' "$ACT_OUTPUT" >>"$ACT_RESULT"
    printf '[exit=%d]\n' "$ACT_STATUS" >>"$ACT_RESULT"

    rm -rf "$workdir"
}

# Extract the labels block emitted between sentinels in act output.
extract_labels() {
    # Pull lines between the sentinels emitted by the workflow, stripping
    # act's log prefix (anything up through the last "| ") from each line.
    awk '/===LABELS-BEGIN===/{flag=1; next} /===LABELS-END===/{flag=0} flag {
        n = match($0, /\| /)
        if (n > 0) {
            line = substr($0, n + 2)
        } else {
            line = $0
        }
        # Strip the next "| " pair if act double-prefixed (e.g. "  | foo | bar")
        # by finding the *last* one.
        while (match(line, /\| /) > 0) {
            line = substr(line, RSTART + 2)
        }
        print line
    }' <<<"$1"
}

@test "workflow file passes actionlint" {
    run actionlint "$PROJECT_ROOT/.github/workflows/pr-label-assigner.yml"
    [ "$status" -eq 0 ]
}

@test "workflow YAML structure is correct" {
    local wf="$PROJECT_ROOT/.github/workflows/pr-label-assigner.yml"
    # Required triggers
    run grep -E '^\s*push:'             "$wf"; [ "$status" -eq 0 ]
    run grep -E '^\s*pull_request:'     "$wf"; [ "$status" -eq 0 ]
    run grep -E '^\s*workflow_dispatch:' "$wf"; [ "$status" -eq 0 ]
    # Required job + steps
    run grep -E 'jobs:'                  "$wf"; [ "$status" -eq 0 ]
    run grep -E 'assign-labels:'         "$wf"; [ "$status" -eq 0 ]
    run grep -E 'actions/checkout@v4'    "$wf"; [ "$status" -eq 0 ]
    run grep -E 'pr-label-assigner.sh'   "$wf"; [ "$status" -eq 0 ]
}

@test "referenced script and fixtures exist" {
    [ -x "$PROJECT_ROOT/pr-label-assigner.sh" ]
    [ -f "$PROJECT_ROOT/tests/fixtures/rules.txt" ]
    [ -f "$PROJECT_ROOT/tests/fixtures/case_docs.txt" ]
    [ -f "$PROJECT_ROOT/tests/fixtures/case_mixed.txt" ]
    [ -f "$PROJECT_ROOT/tests/fixtures/case_none.txt" ]
}

@test "act case 1: docs-only PR labels as 'documentation'" {
    run_act_case "docs-only" "tests/fixtures/case_docs.txt"
    [ "$ACT_STATUS" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    local labels
    labels="$(extract_labels "$ACT_OUTPUT")"
    [ "$labels" = "documentation" ]
}

@test "act case 2: mixed PR labels in priority order" {
    run_act_case "mixed" "tests/fixtures/case_mixed.txt"
    [ "$ACT_STATUS" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    local labels expected
    labels="$(extract_labels "$ACT_OUTPUT")"
    expected=$'documentation\napi\nbackend\ntests'
    [ "$labels" = "$expected" ]
}

@test "act case 3: PR with no rule matches yields empty label set" {
    run_act_case "no-match" "tests/fixtures/case_none.txt"
    [ "$ACT_STATUS" -eq 0 ]
    [[ "$ACT_OUTPUT" == *"Job succeeded"* ]]
    local labels
    labels="$(extract_labels "$ACT_OUTPUT")"
    [ -z "$labels" ]
}

@test "act-result.txt artifact was produced" {
    [ -s "$ACT_RESULT" ]
    run grep -c "Job succeeded" "$ACT_RESULT"
    [ "$status" -eq 0 ]
    [ "$output" -ge 3 ]
}
