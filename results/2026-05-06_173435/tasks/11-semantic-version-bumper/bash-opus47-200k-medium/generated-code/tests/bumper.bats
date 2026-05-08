#!/usr/bin/env bats
# All tests run the bumper exclusively through the GitHub Actions workflow.
# We stage every fixture case under fixture/cases/<name>/ in the repo,
# commit them, run `act push --rm` ONCE, and assert exact-value markers
# for each case in the captured output.

setup_file() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export REPO_ROOT
    export ACT_LOG="$REPO_ROOT/act-result.txt"
    export ACT_OUT_FILE="$REPO_ROOT/.bats-act-output"

    : > "$ACT_LOG"

    # Stage all three fixture cases under fixture/cases/<name>/
    rm -rf "$REPO_ROOT/fixture"
    mkdir -p "$REPO_ROOT/fixture/cases/patch" \
             "$REPO_ROOT/fixture/cases/minor" \
             "$REPO_ROOT/fixture/cases/major"

    printf '1.0.0\n'  > "$REPO_ROOT/fixture/cases/patch/VERSION"
    cp "$REPO_ROOT/tests/fixtures/case_patch_commits.txt" \
       "$REPO_ROOT/fixture/cases/patch/commits.txt"

    printf '1.2.3\n'  > "$REPO_ROOT/fixture/cases/minor/VERSION"
    cp "$REPO_ROOT/tests/fixtures/case_minor_commits.txt" \
       "$REPO_ROOT/fixture/cases/minor/commits.txt"

    printf '1.4.9\n'  > "$REPO_ROOT/fixture/cases/major/VERSION"
    cp "$REPO_ROOT/tests/fixtures/case_major_commits.txt" \
       "$REPO_ROOT/fixture/cases/major/commits.txt"

    cd "$REPO_ROOT"
    git add -A
    git -c user.email=t@t -c user.name=t commit -m "test: stage fixtures" \
        --allow-empty >/dev/null

    # Single act run for the whole suite. Output captured to a file so
    # individual @test cases can grep without re-running act.
    {
        echo "===== act push --rm (single run for all cases) ====="
        act push --rm 2>&1
        echo "===== exit=$? ====="
    } | tee "$ACT_OUT_FILE" > "$ACT_LOG" || true
}

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export REPO_ROOT
    export ACT_OUT_FILE="$REPO_ROOT/.bats-act-output"
}

# ---------- Workflow-structure tests ----------

@test "workflow file exists" {
    [ -f "$REPO_ROOT/.github/workflows/semantic-version-bumper.yml" ]
}

@test "actionlint passes on workflow" {
    run actionlint "$REPO_ROOT/.github/workflows/semantic-version-bumper.yml"
    [ "$status" -eq 0 ]
}

@test "workflow declares expected triggers and bump job" {
    local wf="$REPO_ROOT/.github/workflows/semantic-version-bumper.yml"
    grep -qE '^on:' "$wf"
    grep -qE '^[[:space:]]+push:' "$wf"
    grep -qE '^[[:space:]]+pull_request:' "$wf"
    grep -qE '^[[:space:]]+workflow_dispatch:' "$wf"
    grep -qE '^[[:space:]]+schedule:' "$wf"
    grep -qE '^[[:space:]]+bump:' "$wf"
}

@test "workflow references the bumper script and the script is executable" {
    local wf="$REPO_ROOT/.github/workflows/semantic-version-bumper.yml"
    grep -q 'bump-version.sh' "$wf"
    [ -f "$REPO_ROOT/bump-version.sh" ]
    [ -x "$REPO_ROOT/bump-version.sh" ]
}

@test "bump-version.sh passes shellcheck and bash -n" {
    bash -n "$REPO_ROOT/bump-version.sh"
    run shellcheck "$REPO_ROOT/bump-version.sh"
    [ "$status" -eq 0 ]
}

# ---------- act-driven case assertions ----------
# These re-read ACT_OUT_FILE captured by setup_file (no extra act runs).

@test "act run produced output" {
    [ -s "$ACT_OUT_FILE" ]
}

@test "act run reported a Job succeeded" {
    grep -qE 'Job succeeded' "$ACT_OUT_FILE"
}

@test "patch case: 1.0.0 + fix commits -> 1.0.1" {
    grep -qE 'SVB_CASE=patch SVB_NEW_VERSION=1\.0\.1' "$ACT_OUT_FILE"
}

@test "minor case: 1.2.3 + feat commits -> 1.3.0" {
    grep -qE 'SVB_CASE=minor SVB_NEW_VERSION=1\.3\.0' "$ACT_OUT_FILE"
}

@test "major case: 1.4.9 + breaking change -> 2.0.0" {
    grep -qE 'SVB_CASE=major SVB_NEW_VERSION=2\.0\.0' "$ACT_OUT_FILE"
}

@test "act-result.txt artifact exists and is non-empty" {
    [ -s "$REPO_ROOT/act-result.txt" ]
}
