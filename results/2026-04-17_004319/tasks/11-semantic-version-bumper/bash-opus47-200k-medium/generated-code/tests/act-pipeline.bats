#!/usr/bin/env bats

# Integration tests that run the full GitHub Actions workflow via `act`.
# Each test case sets up an isolated temp git repo with fixture data,
# runs `act push --rm`, appends output to act-result.txt, and asserts on
# exact expected values.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
ACT_RESULT_FILE="$REPO_ROOT/act-result.txt"
WORKFLOW=".github/workflows/semantic-version-bumper.yml"

# Reset act-result.txt once per bats run.
setup_file() {
    : > "$ACT_RESULT_FILE"
}

# Build a scratch git repo containing our project + caller-supplied VERSION and
# fixtures/commits.txt content, run act, append output, return exit code.
_run_case() {
    local name="$1" start_version="$2" commits_content="$3"
    local tmp
    tmp=$(mktemp -d)
    # Copy required project files into the scratch repo.
    cp "$REPO_ROOT/bump-version.sh" "$tmp/"
    mkdir -p "$tmp/.github/workflows" "$tmp/fixtures"
    cp "$REPO_ROOT/$WORKFLOW" "$tmp/.github/workflows/"
    [[ -f "$REPO_ROOT/.actrc" ]] && cp "$REPO_ROOT/.actrc" "$tmp/"

    printf '%s\n' "$start_version" > "$tmp/VERSION"
    printf '%s' "$commits_content" > "$tmp/fixtures/commits-feat.txt"

    (
        cd "$tmp"
        git init -q
        git config user.email test@example.com
        git config user.name test
        git add -A
        git commit -qm "seed"
    )

    {
        printf '\n========== CASE: %s ==========\n' "$name"
        printf 'start_version=%s\n' "$start_version"
        printf 'commits:\n%s\n' "$commits_content"
        printf -- '---- act output ----\n'
    } >> "$ACT_RESULT_FILE"

    local out status
    out=$(cd "$tmp" && act push --rm --workflows .github/workflows/semantic-version-bumper.yml 2>&1) || true
    status=$?
    printf '%s\n' "$out" >> "$ACT_RESULT_FILE"
    printf -- '---- exit=%s ----\n' "$status" >> "$ACT_RESULT_FILE"

    # Export captured values via globals for the caller.
    LAST_OUT="$out"
    LAST_STATUS=$status
    LAST_TMP="$tmp"
}

@test "act: feat commits bump 1.1.0 -> 1.2.0" {
    _run_case "feat-minor" "1.1.0" "feat: add search
fix: typo
chore: deps
"
    [ "$LAST_STATUS" -eq 0 ]
    [[ "$LAST_OUT" == *"Job succeeded"* ]]
    [[ "$LAST_OUT" == *"RESULT_VERSION=1.2.0"* ]]
    [[ "$LAST_OUT" == *"## 1.2.0"* ]]
    [[ "$LAST_OUT" == *"add search"* ]]
}

@test "act: BREAKING CHANGE commits bump 1.1.0 -> 2.0.0" {
    _run_case "breaking-major" "1.1.0" "feat!: rewrite API
BREAKING CHANGE: removed endpoints
fix: patch race
"
    [ "$LAST_STATUS" -eq 0 ]
    [[ "$LAST_OUT" == *"Job succeeded"* ]]
    [[ "$LAST_OUT" == *"RESULT_VERSION=2.0.0"* ]]
    [[ "$LAST_OUT" == *"BREAKING CHANGES"* ]]
}

@test "act: no feat/fix commits -> version unchanged at 1.1.0" {
    _run_case "none" "1.1.0" "chore: deps
docs: readme
"
    [ "$LAST_STATUS" -eq 0 ]
    [[ "$LAST_OUT" == *"Job succeeded"* ]]
    [[ "$LAST_OUT" == *"RESULT_VERSION=1.1.0"* ]]
}

# --- Workflow structure tests (static, no act) ---

@test "workflow: actionlint passes" {
    run actionlint "$REPO_ROOT/$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow: references bump-version.sh and the script exists" {
    grep -q "bump-version.sh" "$REPO_ROOT/$WORKFLOW"
    [ -f "$REPO_ROOT/bump-version.sh" ]
}

@test "workflow: declares push, pull_request, workflow_dispatch triggers" {
    grep -qE '^  push:' "$REPO_ROOT/$WORKFLOW"
    grep -qE '^  pull_request:' "$REPO_ROOT/$WORKFLOW"
    grep -qE '^  workflow_dispatch:' "$REPO_ROOT/$WORKFLOW"
}

@test "workflow: uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" "$REPO_ROOT/$WORKFLOW"
}

@test "workflow: defines a bump job" {
    grep -qE '^  bump:' "$REPO_ROOT/$WORKFLOW"
}

@test "act-result.txt exists and is non-empty" {
    [ -s "$ACT_RESULT_FILE" ]
}
