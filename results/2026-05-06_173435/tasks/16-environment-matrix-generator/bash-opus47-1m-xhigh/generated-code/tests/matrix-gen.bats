#!/usr/bin/env bats

# Bats test suite for the Environment Matrix Generator.
#
# Strategy:
#   - Structural tests run locally (workflow file, syntax, lint).
#   - Functional tests run through GitHub Actions via `act`. Each functional
#     test sets up a temp git repo containing the script + workflow + a single
#     fixture JSON, runs `act push --rm`, captures output, and asserts on the
#     JSON the script printed.
#   - All `act` output is appended to act-result.txt in the project directory.

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"

setup_file() {
    # Resolve project dir to absolute path so subshells / temp dirs can find it.
    PROJECT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_DIR
    ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"
    export ACT_RESULT_FILE
    # Truncate the cumulative act log at the start of every full run.
    : > "$ACT_RESULT_FILE"
}

setup() {
    PROJECT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_DIR
    ACT_RESULT_FILE="${PROJECT_DIR}/act-result.txt"
    export ACT_RESULT_FILE
}

# Run one act test case.  Arguments:
#   $1 = test case name (used as a delimiter in act-result.txt)
#   $2 = path (relative to PROJECT_DIR/tests/fixtures) of the input JSON config
# Result:
#   Sets $output to the captured act stdout+stderr
#   Sets $status to act's exit code
#   Appends a delimited block to $ACT_RESULT_FILE
run_act_with_fixture() {
    local case_name="$1"
    local fixture_relpath="$2"

    local tmp
    tmp="$(mktemp -d -t matrix-gen-act.XXXXXX)"
    # Always clean up the temp dir, even on failure.
    trap 'rm -rf "$tmp"' RETURN

    # Lay out the project files inside the temp git repo.
    mkdir -p "$tmp/bin" "$tmp/.github/workflows" "$tmp/tests/fixtures"
    cp "$PROJECT_DIR/bin/matrix-gen.sh" "$tmp/bin/matrix-gen.sh"
    cp "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml" \
        "$tmp/.github/workflows/environment-matrix-generator.yml"
    cp "$PROJECT_DIR/.actrc" "$tmp/.actrc" 2>/dev/null || true
    # Stage exactly one fixture as the canonical config.json the workflow reads.
    cp "$PROJECT_DIR/tests/fixtures/$fixture_relpath" "$tmp/config.json"

    # Initialise the temp directory as a git repo so act picks up files.
    (
        cd "$tmp"
        git init -q
        git -c user.email=test@example.com -c user.name=Test \
            add -A
        git -c user.email=test@example.com -c user.name=Test \
            commit -q -m "fixture commit"
    )

    # Run act and capture stdout+stderr together.  We must tolerate a non-zero
    # exit (some test cases assert that the workflow *fails*), so do not let
    # bats' default `set -e` propagate it — capture the status explicitly.
    # NOTE: `if ! cmd; then act_status=$?` is wrong — inside the `then` branch
    # `$?` is the exit status of `!` (always 0), not the underlying command.
    # The `cmd || act_status=$?` form captures the genuine exit code AND
    # short-circuits set -e.
    local act_output="" act_status=0
    act_output="$(cd "$tmp" && act push --rm 2>&1)" || act_status=$?

    {
        printf '\n========== CASE: %s ==========\n' "$case_name"
        printf 'fixture: %s\n' "$fixture_relpath"
        printf 'exit: %d\n' "$act_status"
        printf -- '----- output -----\n%s\n' "$act_output"
        printf '========== END CASE: %s ==========\n' "$case_name"
    } >> "$ACT_RESULT_FILE"

    # Surface the captured data via bats' standard variables.
    output="$act_output"
    status="$act_status"
    export output status
}

# Extract the JSON the script printed from a captured act run.
# The workflow surrounds the script's stdout with sentinel markers so we can
# slice it out reliably even with act's prefixes ("| " etc.).
extract_matrix_json() {
    local raw="$1"
    # act prefixes log lines with things like "| " — strip leading "| " or "[..] | "
    # before we look for our markers.
    # Use awk to print lines strictly between BEGIN_MATRIX_JSON / END_MATRIX_JSON.
    printf '%s\n' "$raw" \
        | sed -E 's/^\[[^]]+\][[:space:]]*\|[[:space:]]?//; s/^\|[[:space:]]?//' \
        | awk '
            /BEGIN_MATRIX_JSON/ {capture=1; next}
            /END_MATRIX_JSON/   {capture=0; next}
            capture {print}
        '
}

# ---------------------------------------------------------------------------
# Structural tests (run locally)
# ---------------------------------------------------------------------------

@test "workflow file exists at expected path" {
    [ -f "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml" ]
}

@test "matrix-gen.sh script exists and is executable" {
    [ -x "$PROJECT_DIR/bin/matrix-gen.sh" ]
}

@test "script passes bash -n syntax check" {
    bash -n "$PROJECT_DIR/bin/matrix-gen.sh"
}

@test "script passes shellcheck" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    shellcheck "$PROJECT_DIR/bin/matrix-gen.sh"
}

@test "workflow passes actionlint" {
    if ! command -v actionlint >/dev/null 2>&1; then
        skip "actionlint not installed"
    fi
    actionlint "$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

@test "workflow YAML has expected top-level structure" {
    # We don't have yq guaranteed; use grep for stable, low-noise structural
    # checks. The workflow has push + workflow_dispatch triggers, a matrix
    # job, and references our script path.
    local wf="$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
    grep -qE '^on:' "$wf"
    grep -qE '^\s*push:' "$wf"
    grep -qE '^\s*workflow_dispatch:' "$wf"
    grep -qE '^\s*jobs:' "$wf"
    grep -q 'bin/matrix-gen.sh' "$wf"
    grep -q 'actions/checkout@' "$wf"
}

@test "fixture files referenced by tests exist" {
    [ -f "$PROJECT_DIR/tests/fixtures/simple.json" ]
    [ -f "$PROJECT_DIR/tests/fixtures/with-excludes.json" ]
    [ -f "$PROJECT_DIR/tests/fixtures/with-includes-augment.json" ]
    [ -f "$PROJECT_DIR/tests/fixtures/with-includes-new.json" ]
    [ -f "$PROJECT_DIR/tests/fixtures/exceeds-max-size.json" ]
    [ -f "$PROJECT_DIR/tests/fixtures/strategy-passthrough.json" ]
}

# ---------------------------------------------------------------------------
# Functional tests (each runs through act)
# ---------------------------------------------------------------------------

@test "act: simple 2x2 cartesian product produces 4 combinations" {
    run_act_with_fixture "simple-2x2" "simple.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]

    local json
    json="$(extract_matrix_json "$output")"
    # Sanity: the slice is non-empty and parses as JSON.
    [ -n "$json" ]
    echo "$json" | jq . >/dev/null

    # Exact assertions — every value is determined by the fixture.
    [ "$(echo "$json" | jq '.matrix.include | length')" = "4" ]
    [ "$(echo "$json" | jq -r '."fail-fast"')" = "true" ]
    [ "$(echo "$json" | jq -r '.size')" = "4" ]
    [ "$(echo "$json" | jq -r '
        [.matrix.include[] | "\(.os)/\(.node)"] | sort | join(",")
    ')" = "ubuntu-latest/18,ubuntu-latest/20,windows-latest/18,windows-latest/20" ]
}

@test "act: exclude rule removes matching combinations" {
    run_act_with_fixture "with-excludes" "with-excludes.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]

    local json
    json="$(extract_matrix_json "$output")"
    # 3 OS x 2 node = 6, minus exclude {os:windows-latest,node:18} = 5.
    [ "$(echo "$json" | jq '.matrix.include | length')" = "5" ]
    # The excluded combination must not appear.
    [ "$(echo "$json" | jq '
        .matrix.include[] | select(.os == "windows-latest" and .node == "18") | length
    ')" = "" ]
}

@test "act: include with matching axis values augments existing combinations" {
    # Fixture: matrix os=[ubuntu,windows] node=[18,20];
    # include {os: ubuntu, extra: turbo}  →  every ubuntu row gains extra=turbo.
    run_act_with_fixture "include-augment" "with-includes-augment.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]

    local json
    json="$(extract_matrix_json "$output")"
    [ "$(echo "$json" | jq '.matrix.include | length')" = "4" ]
    # Every ubuntu row has extra=turbo.
    [ "$(echo "$json" | jq '
        [.matrix.include[] | select(.os == "ubuntu-latest")
                            | select(.extra == "turbo")] | length
    ')" = "2" ]
    # No windows row has the extra key.
    [ "$(echo "$json" | jq '
        [.matrix.include[] | select(.os == "windows-latest")
                            | select(has("extra"))] | length
    ')" = "0" ]
}

@test "act: include with non-matching axis values appends a new row" {
    # Fixture: matrix os=[ubuntu] node=[18]; include {os: macos, node: 22}
    # → no match, so include is appended as a new row.
    run_act_with_fixture "include-new" "with-includes-new.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]

    local json
    json="$(extract_matrix_json "$output")"
    [ "$(echo "$json" | jq '.matrix.include | length')" = "2" ]
    [ "$(echo "$json" | jq -r '
        [.matrix.include[] | "\(.os)/\(.node)"] | sort | join(",")
    ')" = "macos-latest/22,ubuntu-latest/18" ]
}

@test "act: max-size violation makes the workflow fail" {
    # Fixture has max-size: 2 but produces 4 combinations → script exits non-zero
    # → workflow step fails.  The act run should report failure (non-zero exit)
    # AND the output should contain our diagnostic.
    run_act_with_fixture "exceeds-max-size" "exceeds-max-size.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"matrix size"* ]]
    [[ "$output" == *"exceeds max-size"* ]]
}

@test "act: fail-fast and max-parallel pass through to output" {
    run_act_with_fixture "strategy-passthrough" "strategy-passthrough.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Job succeeded"* ]]

    local json
    json="$(extract_matrix_json "$output")"
    [ "$(echo "$json" | jq -r '."fail-fast"')" = "false" ]
    [ "$(echo "$json" | jq -r '."max-parallel"')" = "3" ]
}
