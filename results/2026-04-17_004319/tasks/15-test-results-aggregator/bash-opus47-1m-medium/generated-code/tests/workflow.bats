#!/usr/bin/env bats
# Integration tests: run the workflow through `act` for several fixture
# variants. Each case spins up a temp git repo, writes fixtures, invokes
# act, captures output, and asserts exact expected aggregate values.

PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
ACT_LOG="$PROJECT_ROOT/act-result.txt"

setup_file() {
    : > "$ACT_LOG"  # fresh log for the whole file
}

# Spin up a clean git repo containing the project plus the provided fixture
# override (directory copied on top of fixtures/). Prints the repo path.
_make_repo() {
    local override="$1"
    local repo
    repo="$(mktemp -d)"
    cp -r "$PROJECT_ROOT/." "$repo/"
    rm -rf "$repo/.git"
    if [[ -n "$override" && -d "$override" ]]; then
        cp -r "$override"/. "$repo/fixtures/"
    fi
    (
        cd "$repo"
        git init -q
        git config user.email test@example.com
        git config user.name test
        git add -A
        git commit -q -m init
    )
    echo "$repo"
}

# Run act in the given repo and append its output to ACT_LOG.
_run_act() {
    local repo="$1"
    local label="$2"
    {
        echo "===== BEGIN CASE: $label ====="
        (cd "$repo" && act push --rm 2>&1)
        local rc=$?
        echo "===== END CASE: $label (exit=$rc) ====="
        echo
        return $rc
    } | tee -a "$ACT_LOG"
}

@test "workflow structure: triggers and job steps present" {
    local wf="$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ -f "$wf" ]
    grep -q '^on:' "$wf"
    grep -q 'push:' "$wf"
    grep -q 'pull_request:' "$wf"
    grep -q 'workflow_dispatch:' "$wf"
    grep -q 'actions/checkout@v4' "$wf"
    # Script referenced by workflow must exist in the repo.
    grep -q 'aggregate.sh' "$wf"
    [ -f "$PROJECT_ROOT/aggregate.sh" ]
    [ -f "$PROJECT_ROOT/fixtures/run1/junit.xml" ]
    [ -f "$PROJECT_ROOT/fixtures/run2/results.json" ]
    [ -f "$PROJECT_ROOT/fixtures/run3/junit.xml" ]
}

@test "actionlint passes cleanly" {
    run actionlint "$PROJECT_ROOT/.github/workflows/test-results-aggregator.yml"
    [ "$status" -eq 0 ]
}

@test "act: default fixtures produce expected totals with flaky test" {
    local repo; repo="$(_make_repo "")"
    run _run_act "$repo" "default-fixtures"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total=12"* ]]
    [[ "$output" == *"passed=8"* ]]
    [[ "$output" == *"failed=1"* ]]
    [[ "$output" == *"skipped=3"* ]]
    [[ "$output" == *"flaky=test_flaky_net"* ]]
    [[ "$output" == *"AGGREGATE_OK"* ]]
    [[ "$output" == *"Job succeeded"* ]]
    rm -rf "$repo"
}

@test "act: all-green fixtures (no flaky, no failures) still passes assertions when overridden" {
    # Override the default fixtures so all three runs agree — test_flaky_net is
    # now stable, and totals remain the same shape but with 0 failures.
    local ov; ov="$(mktemp -d)"
    mkdir -p "$ov/run1" "$ov/run2" "$ov/run3"
    # Reuse run3 (all green) for all three runs.
    cp "$PROJECT_ROOT/fixtures/run3/junit.xml" "$ov/run1/junit.xml"
    # Still need run2/results.json to keep the workflow's file list valid.
    cat > "$ov/run2/results.json" <<'EOF'
{"tests":[
  {"name":"test_login","status":"passed","duration":0.2},
  {"name":"test_logout","status":"passed","duration":0.3},
  {"name":"test_flaky_net","status":"passed","duration":0.4},
  {"name":"test_wip","status":"skipped","duration":0.0}
]}
EOF
    cp "$PROJECT_ROOT/fixtures/run3/junit.xml" "$ov/run3/junit.xml"

    local repo; repo="$(_make_repo "$ov")"
    # Swap in an assertion step expecting failed=0 and no flaky test.
    # Rewrite the workflow's assertion block on the fly.
    python3 - "$repo/.github/workflows/test-results-aggregator.yml" <<'PY'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace("grep -q '^passed=8$'    aggregate.txt",
              "grep -q '^passed=9$'    aggregate.txt")
s = s.replace("grep -q '^failed=1$'    aggregate.txt",
              "grep -q '^failed=0$'    aggregate.txt")
s = s.replace("grep -q '^flaky=test_flaky_net$' aggregate.txt",
              "grep -q '^flaky=$' aggregate.txt")
p.write_text(s)
PY
    (cd "$repo" && git add -A && git commit -q -m override)

    run _run_act "$repo" "all-green-fixtures"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total=12"* ]]
    [[ "$output" == *"failed=0"* ]]
    [[ "$output" == *"flaky="* ]]
    [[ "$output" == *"AGGREGATE_OK"* ]]
    [[ "$output" == *"Job succeeded"* ]]
    rm -rf "$repo" "$ov"
}
