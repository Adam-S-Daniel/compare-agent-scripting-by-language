#!/usr/bin/env bats
# Drives the GitHub Actions workflow end-to-end via `act` with varying policies.
# Each case assembles an isolated temp git repo, runs `act push --rm`, and
# asserts on EXACT expected output.

PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

setup_file() {
    : > "$ACT_RESULT"
}

# Prepare an isolated workspace under $tmp with project files, fixture, and policy.
prepare_repo() {
    local tmp="$1" fixture_content="$2" policy_content="$3"
    mkdir -p "$tmp/.github/workflows" "$tmp/tests/fixtures"
    cp "$PROJECT_ROOT/cleanup.sh" "$tmp/cleanup.sh"
    cp "$PROJECT_ROOT/.github/workflows/artifact-cleanup-script.yml" \
        "$tmp/.github/workflows/artifact-cleanup-script.yml"
    cp "$PROJECT_ROOT/.actrc" "$tmp/.actrc"
    printf '%s' "$fixture_content" > "$tmp/tests/fixtures/basic.tsv"
    printf '%s' "$policy_content" > "$tmp/tests/policy.env"
    (
        cd "$tmp"
        git init -q
        git config user.email t@t
        git config user.name t
        git add -A
        git commit -q -m init
    )
}

run_act_case() {
    local label="$1" tmp="$2"
    {
        echo "===== BEGIN ${label} ====="
        (cd "$tmp" && act push --rm 2>&1) || true
        echo "===== END ${label} ====="
    } | tee -a "$ACT_RESULT"
}

@test "structure: workflow YAML parses and references script" {
    run grep -q 'cleanup.sh' "$PROJECT_ROOT/.github/workflows/artifact-cleanup-script.yml"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/cleanup.sh" ]
}

@test "structure: workflow has push+pull_request+workflow_dispatch+schedule triggers" {
    local wf="$PROJECT_ROOT/.github/workflows/artifact-cleanup-script.yml"
    run grep -q '^on:' "$wf"; [ "$status" -eq 0 ]
    run grep -q 'push:' "$wf"; [ "$status" -eq 0 ]
    run grep -q 'pull_request:' "$wf"; [ "$status" -eq 0 ]
    run grep -q 'workflow_dispatch:' "$wf"; [ "$status" -eq 0 ]
    run grep -q 'schedule:' "$wf"; [ "$status" -eq 0 ]
}

@test "structure: actionlint passes" {
    run actionlint "$PROJECT_ROOT/.github/workflows/artifact-cleanup-script.yml"
    [ "$status" -eq 0 ]
}

@test "act case 1: max-age-days=30 → 2 deleted, reclaimed 3145728" {
    local tmp
    tmp=$(mktemp -d)
    local fix="artifact-old	1048576	2026-01-01T00:00:00Z	100
artifact-mid	2097152	2026-03-01T00:00:00Z	100
artifact-new	512000	2026-04-15T00:00:00Z	101
artifact-newer	256000	2026-04-16T00:00:00Z	101
artifact-newest	128000	2026-04-17T00:00:00Z	101
"
    local pol='MAX_AGE_DAYS=30
DRY_RUN=true
'
    prepare_repo "$tmp" "$fix" "$pol"
    local out
    out=$(run_act_case "case1-max-age" "$tmp")
    echo "$out" | grep -q "Job succeeded"
    echo "$out" | grep -q "DELETE: artifact-old"
    echo "$out" | grep -q "DELETE: artifact-mid"
    echo "$out" | grep -q "Deleted: 2"
    echo "$out" | grep -q "Retained: 3"
    echo "$out" | grep -q "Space reclaimed: 3145728"
    echo "$out" | grep -q "Mode: dry-run"
    rm -rf "$tmp"
}

@test "act case 2: keep-latest=1 → 3 deleted" {
    local tmp
    tmp=$(mktemp -d)
    local fix="artifact-old	1048576	2026-01-01T00:00:00Z	100
artifact-mid	2097152	2026-03-01T00:00:00Z	100
artifact-new	512000	2026-04-15T00:00:00Z	101
artifact-newer	256000	2026-04-16T00:00:00Z	101
artifact-newest	128000	2026-04-17T00:00:00Z	101
"
    local pol='KEEP_LATEST=1
DRY_RUN=true
'
    prepare_repo "$tmp" "$fix" "$pol"
    local out
    out=$(run_act_case "case2-keep-latest" "$tmp")
    echo "$out" | grep -q "Job succeeded"
    echo "$out" | grep -q "DELETE: artifact-old"
    echo "$out" | grep -q "DELETE: artifact-new "
    echo "$out" | grep -q "DELETE: artifact-newer"
    echo "$out" | grep -q "KEEP: artifact-mid"
    echo "$out" | grep -q "KEEP: artifact-newest"
    echo "$out" | grep -q "Deleted: 3"
    echo "$out" | grep -q "Retained: 2"
    rm -rf "$tmp"
}

@test "act case 3: max-age=30 + keep-latest=1 → 4 deleted, 1 retained" {
    local tmp
    tmp=$(mktemp -d)
    local fix="artifact-old	1048576	2026-01-01T00:00:00Z	100
artifact-mid	2097152	2026-03-01T00:00:00Z	100
artifact-new	512000	2026-04-15T00:00:00Z	101
artifact-newer	256000	2026-04-16T00:00:00Z	101
artifact-newest	128000	2026-04-17T00:00:00Z	101
"
    local pol='MAX_AGE_DAYS=30
KEEP_LATEST=1
DRY_RUN=true
'
    prepare_repo "$tmp" "$fix" "$pol"
    local out
    out=$(run_act_case "case3-combined" "$tmp")
    echo "$out" | grep -q "Job succeeded"
    echo "$out" | grep -q "Deleted: 4"
    echo "$out" | grep -q "Retained: 1"
    echo "$out" | grep -q "KEEP: artifact-newest"
    echo "$out" | grep -q "Space reclaimed: 3913728"
    rm -rf "$tmp"
}
