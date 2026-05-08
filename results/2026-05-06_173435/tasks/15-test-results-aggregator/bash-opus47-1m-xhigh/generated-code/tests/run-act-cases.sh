#!/usr/bin/env bash
# Orchestrates the GH-Actions-via-act portion of the test suite.
# For each test case it:
#   1. Builds a temp git repo containing the project + that case's fixture
#      data dropped into ./fixtures/
#   2. Runs `act push --rm` against that repo
#   3. Appends stdout+stderr of the act run to act-result.txt with a clear
#      delimiter so bats tests can parse per-case sections
#
# act and Docker must be installed and the act-ubuntu-pwsh:latest image
# must be available (configured via .actrc at the project root).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_FILE="$PROJECT_ROOT/act-result.txt"

# Wipe previous run output so the file is a fresh artifact every time.
: >"$RESULT_FILE"

# run_case NAME FIXTURE [FIXTURE ...] — assemble a temp project, copy the
# named fixtures into ./fixtures/, run act, record output.
run_case() {
    local case_name=$1
    shift

    local tmpdir
    tmpdir=$(mktemp -d -t "act-case-${case_name}-XXXXXX")

    # Copy project files into the temp dir. We only need files referenced
    # by the workflow (aggregate.sh + .github/) and act config (.actrc).
    cp -r "$PROJECT_ROOT/aggregate.sh" "$tmpdir/"
    cp -r "$PROJECT_ROOT/.github" "$tmpdir/"
    cp -r "$PROJECT_ROOT/.actrc" "$tmpdir/"

    # Drop the case's fixture files into ./fixtures/ — the workflow reads
    # from there.
    mkdir -p "$tmpdir/fixtures"
    local fx
    for fx in "$@"; do
        cp "$PROJECT_ROOT/tests/fixtures/$fx" "$tmpdir/fixtures/"
    done

    # act needs a git repo for `act push` to work.
    (
        cd "$tmpdir"
        git init -q
        git -c user.email=test@example.com -c user.name=Test \
            add . >/dev/null
        git -c user.email=test@example.com -c user.name=Test \
            commit -qm "case: $case_name" --no-verify
    )

    # Delimit the output for this case so bats can grep within it.
    {
        printf '\n=== ACT CASE: %s ===\n' "$case_name"
        printf 'fixtures: %s\n' "$*"
    } >>"$RESULT_FILE"

    # Run act. Capture both stdout and stderr; never bail out on non-zero
    # exit because bats asserts exit code separately. Capture exit code
    # in a sentinel line.
    # --pull=false: the .actrc points at the local act-ubuntu-pwsh image.
    # Without this flag act tries to pull from a registry where the image
    # does not exist and the run errors before the workflow even starts.
    local act_status=0
    (
        cd "$tmpdir"
        act push --rm --pull=false 2>&1
    ) >>"$RESULT_FILE" || act_status=$?

    printf '\n=== ACT EXIT: %s = %d ===\n' "$case_name" "$act_status" \
        >>"$RESULT_FILE"

    rm -rf "$tmpdir"
}

# Three test cases — one act invocation each, well within the 3-run limit.
# Each case maps a known fixture set to a known summary outcome:
#   all-pass:     2 XML + 2 JSON tests, all passing  -> PASSED, 0 flaky
#   single-fail:  one mixed JUnit file               -> FAILED, 0 flaky
#   matrix-flaky: 4-shard matrix with 2 flaky tests  -> FAILED, 2 flaky
run_case "all-pass"     "junit-pass.xml" "results-pass.json"
run_case "single-fail"  "junit-mixed.xml"
run_case "matrix-flaky" "shard-a.xml" "shard-b.xml" "shard-c.json" "shard-d.json"

echo "Wrote $RESULT_FILE"
