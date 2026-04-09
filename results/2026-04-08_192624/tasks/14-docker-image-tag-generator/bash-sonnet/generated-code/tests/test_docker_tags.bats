#!/usr/bin/env bats
# tests/test_docker_tags.bats
#
# TDD Methodology:
#   RED   — Test written first; fails because generate-tags.sh doesn't exist
#   GREEN — Minimum code in generate-tags.sh makes the test pass
#   REFACTOR — Code cleaned up while all tests stay green
#   Repeat for each new behaviour.
#
# Two test categories:
#   1. WORKFLOW STRUCTURE TESTS  — run locally, no act required (fast)
#   2. ACT INTEGRATION TESTS     — each test case runs the full pipeline via `act`
#
# Run with:  bats tests/test_docker_tags.bats

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
WORKFLOW_FILE="${SCRIPT_DIR}/.github/workflows/docker-image-tag-generator.yml"
GENERATE_SCRIPT="${SCRIPT_DIR}/generate-tags.sh"
ACT_RESULT="${SCRIPT_DIR}/act-result.txt"

# ---------------------------------------------------------------------------
# Lifecycle hooks
# ---------------------------------------------------------------------------
setup_file() {
    # RED: at this point generate-tags.sh and the workflow don't exist.
    # GREEN: after implementation, all tests below will pass.
    : > "$ACT_RESULT"   # reset act-result.txt for this run
}

# ---------------------------------------------------------------------------
# Helper: run one test case through the GitHub Actions pipeline via `act`
#
# Usage: run_act_case <branch> <sha> <tag> <pr_number>
# Prints act output; returns act exit code.
# ---------------------------------------------------------------------------
run_act_case() {
    local branch="$1" sha="$2" tag="$3" pr_number="$4"

    # Build isolated temp git repo so act has a clean workspace
    local tmpdir
    tmpdir=$(mktemp -d)

    # Copy project files into temp repo (skip .git and act-result.txt)
    cp "${GENERATE_SCRIPT}" "${tmpdir}/"
    mkdir -p "${tmpdir}/.github/workflows"
    cp "${WORKFLOW_FILE}" "${tmpdir}/.github/workflows/"

    # Write fixture env file — act reads this with --env-file
    printf 'INPUT_BRANCH=%s\nINPUT_SHA=%s\nINPUT_TAG=%s\nINPUT_PR_NUMBER=%s\n' \
        "$branch" "$sha" "$tag" "$pr_number" \
        > "${tmpdir}/.env.test"

    # Minimal git repo so actions/checkout doesn't complain
    git -C "$tmpdir" init -q
    git -C "$tmpdir" config user.email "ci@test.local"
    git -C "$tmpdir" config user.name  "CI Test"
    git -C "$tmpdir" add .
    git -C "$tmpdir" commit -q -m "ci: fixture commit"

    # Run the pipeline; capture all output
    local out
    out=$(
        cd "$tmpdir" && act push \
            --rm \
            -P ubuntu-latest=catthehacker/ubuntu:act-latest \
            --env-file .env.test \
            2>&1
    )
    local rc=$?

    rm -rf "$tmpdir"
    printf '%s\n' "$out"
    return $rc
}

# ---------------------------------------------------------------------------
# SECTION 1: WORKFLOW STRUCTURE TESTS (no act, fast)
# ---------------------------------------------------------------------------

# RED #1 — fails immediately: generate-tags.sh does not exist yet
@test "generate-tags.sh exists" {
    [ -f "$GENERATE_SCRIPT" ]
}

# RED #2 — fails: workflow file does not exist yet
@test "workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "workflow has 'push' trigger" {
    grep -q "push:" "$WORKFLOW_FILE"
}

@test "workflow has 'pull_request' trigger" {
    grep -q "pull_request" "$WORKFLOW_FILE"
}

@test "workflow has 'workflow_dispatch' trigger" {
    grep -q "workflow_dispatch" "$WORKFLOW_FILE"
}

@test "workflow references generate-tags.sh" {
    grep -q "generate-tags.sh" "$WORKFLOW_FILE"
}

@test "generate-tags.sh uses bash shebang" {
    head -1 "$GENERATE_SCRIPT" | grep -qF '#!/usr/bin/env bash'
}

@test "generate-tags.sh passes bash -n syntax check" {
    run bash -n "$GENERATE_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "generate-tags.sh passes shellcheck" {
    run shellcheck "$GENERATE_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "workflow passes actionlint" {
    run actionlint "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# SECTION 2: ACT INTEGRATION TESTS
# Each test: sets up temp repo → runs act push → asserts exact output
# All output appended to act-result.txt
# ---------------------------------------------------------------------------

# RED #3 — fails because the workflow / script don't exist yet
@test "[ACT] main branch → 'latest' and 'main-{shortsha}'" {
    local branch="main" sha="abc1234def5678" tag="" pr=""

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: main branch → latest + main-abc1234 ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    # EXACT expected value: both tags on one line
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=latest main-abc1234"
}

@test "[ACT] feature branch → sanitized '{branch}-{shortsha}'" {
    local branch="feature/my-feature" sha="def5678abc1234" tag="" pr=""

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: feature branch → feature-my-feature-def5678 ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    # EXACT expected value: sanitized branch + short SHA
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=feature-my-feature-def5678"
}

@test "[ACT] semver tag → 'v{semver}'" {
    local branch="main" sha="aaa0000bbb1111" tag="v2.3.4" pr=""

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: tag v2.3.4 → v2.3.4 ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    # EXACT expected value
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=v2.3.4"
}

@test "[ACT] tag without 'v' prefix → 'v' is prepended" {
    local branch="main" sha="ccc1111ddd2222" tag="1.0.0" pr=""

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: tag 1.0.0 → v1.0.0 ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=v1.0.0"
}

@test "[ACT] pull request → 'pr-{number}'" {
    local branch="feature/login" sha="eee2222fff3333" tag="" pr="42"

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: PR #42 → pr-42 ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    # EXACT expected value
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=pr-42"
}

@test "[ACT] uppercase branch name is lowercased" {
    local branch="Feature/UpperCase" sha="fff3333ggg4444" tag="" pr=""

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: uppercase branch → lowercased ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    # EXACT expected: lowercase sanitized
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=feature-uppercase-fff3333"
}

@test "[ACT] special chars in branch are replaced with dashes" {
    local branch="feat/my_feature.v2" sha="ggg4444hhh5555" tag="" pr=""

    run run_act_case "$branch" "$sha" "$tag" "$pr"

    {
        echo "=== TEST: special chars sanitized ==="
        echo "$output"
        echo "=== EXIT: $status ==="
    } >> "$ACT_RESULT"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Job succeeded"
    echo "$output" | grep -qF "DOCKER_IMAGE_TAGS=feat-my-feature-v2-ggg4444"
}
