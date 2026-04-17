#!/usr/bin/env bats
# Tests the GitHub Actions workflow structure and end-to-end behavior via act.
#
# - Structure tests: YAML is parseable, has expected triggers/jobs/steps,
#   references the script + test paths that exist in the repo.
# - actionlint: must exit 0.
# - act execution: the harness stages a temp git repo per test case with
#   that case's fixture data, runs `act push --rm`, appends output to
#   act-result.txt, and asserts the EXACT expected NEW_VERSION.

setup_file() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORKFLOW="$ROOT/.github/workflows/semantic-version-bumper.yml"
    ACT_RESULT="$ROOT/act-result.txt"
    : > "$ACT_RESULT"          # truncate on each test-file run
    export ROOT WORKFLOW ACT_RESULT
}

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORKFLOW="$ROOT/.github/workflows/semantic-version-bumper.yml"
    ACT_RESULT="$ROOT/act-result.txt"
    export ROOT WORKFLOW ACT_RESULT
}

# Helper: stage a fresh temp repo containing the project + fixture data,
# run `act push --rm`, append output to act-result.txt, and set STAGE_OUT/STATUS.
_run_act_case() {
    local case_name="$1" version="$2" commits_content="$3"

    STAGE="$(mktemp -d)"
    # Copy project files the workflow needs.
    cp "$ROOT/bump-version.sh" "$STAGE/"
    cp -r "$ROOT/.github"      "$STAGE/"
    cp -r "$ROOT/test"         "$STAGE/"
    # Custom act container from the parent .actrc so runs use the prebuilt image.
    cp "$ROOT/.actrc"          "$STAGE/"

    # Write the per-case fixture data the workflow operates on.
    printf '%s\n' "$version" > "$STAGE/VERSION"
    printf '%s' "$commits_content" > "$STAGE/commits.log"

    # act requires a git repo.
    (
        cd "$STAGE"
        git init -q -b main
        git config user.email "ci@example.test"
        git config user.name  "ci"
        git add -A
        git commit -qm "fixture: $case_name"
    )

    # Record a header so the appended output per case is clearly delimited.
    {
        printf '==================================================\n'
        printf '=== CASE: %s\n' "$case_name"
        printf '=== VERSION input: %s\n' "$version"
        printf '=== commits input:\n%s\n' "$commits_content"
        printf '==================================================\n'
    } >> "$ACT_RESULT"

    # Run act. --rm cleans up the container. Capture exit status explicitly.
    OUT_FILE="$(mktemp)"
    set +e
    (cd "$STAGE" && act push --rm) >"$OUT_FILE" 2>&1
    STAGE_STATUS=$?
    set -e

    cat "$OUT_FILE" >> "$ACT_RESULT"
    printf '=== exit status: %d\n\n' "$STAGE_STATUS" >> "$ACT_RESULT"

    STAGE_OUT="$(cat "$OUT_FILE")"
    rm -f "$OUT_FILE"
    rm -rf "$STAGE"
    export STAGE_OUT STAGE_STATUS
}

# --- Structure tests (fast, no act) --------------------------------------

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "actionlint passes cleanly" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, workflow_dispatch triggers" {
    # No yq dependency: look for the on: block keys directly.
    grep -qE '^\s*push:'              "$WORKFLOW"
    grep -qE '^\s*pull_request:'      "$WORKFLOW"
    grep -qE '^\s*workflow_dispatch:' "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -qE 'uses:\s*actions/checkout@v4' "$WORKFLOW"
}

@test "workflow declares lint and bump jobs, bump depends on lint" {
    grep -qE '^\s*lint:' "$WORKFLOW"
    grep -qE '^\s*bump:' "$WORKFLOW"
    grep -qE 'needs:\s*lint' "$WORKFLOW"
}

@test "workflow references bump-version.sh and test path that exist" {
    grep -q 'bump-version.sh' "$WORKFLOW"
    grep -q 'test/bump-version.bats' "$WORKFLOW"
    [ -f "$ROOT/bump-version.sh" ]
    [ -f "$ROOT/test/bump-version.bats" ]
}

@test "workflow declares content-read permissions" {
    grep -qE '^\s*contents:\s*read' "$WORKFLOW"
}

# --- End-to-end via act --------------------------------------------------

@test "act case 1: feat commits bump 1.1.0 -> 1.2.0" {
    commits=$'feat: add login command\nfix: handle empty config\nchore: bump deps\n'
    _run_act_case "feat-minor" "1.1.0" "$commits"
    [ "$STAGE_STATUS" -eq 0 ]
    [[ "$STAGE_OUT" == *"NEW_VERSION=1.2.0"* ]]
    [[ "$STAGE_OUT" == *"Job succeeded"* ]]
}

@test "act case 2: fix-only commits bump 0.9.3 -> 0.9.4 (patch)" {
    commits=$'fix: correct off-by-one in pagination\nfix: retry on network timeout\n'
    _run_act_case "fix-patch" "0.9.3" "$commits"
    [ "$STAGE_STATUS" -eq 0 ]
    [[ "$STAGE_OUT" == *"NEW_VERSION=0.9.4"* ]]
    [[ "$STAGE_OUT" == *"Job succeeded"* ]]
}

@test "act case 3: breaking commit bumps 2.5.1 -> 3.0.0 (major)" {
    commits=$'feat!: rewrite CLI with new flag structure\nfix: escape metacharacters\n'
    _run_act_case "breaking-major" "2.5.1" "$commits"
    [ "$STAGE_STATUS" -eq 0 ]
    [[ "$STAGE_OUT" == *"NEW_VERSION=3.0.0"* ]]
    [[ "$STAGE_OUT" == *"Job succeeded"* ]]
}

@test "act case 4: no conventional commits leaves 1.0.0 unchanged" {
    commits=$'chore: update editor config\ndocs: expand README\n'
    _run_act_case "no-bump" "1.0.0" "$commits"
    [ "$STAGE_STATUS" -eq 0 ]
    [[ "$STAGE_OUT" == *"NEW_VERSION=1.0.0"* ]]
    [[ "$STAGE_OUT" == *"Job succeeded"* ]]
}

@test "act-result.txt was produced and is non-empty" {
    [ -s "$ACT_RESULT" ]
}
