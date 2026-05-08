#!/usr/bin/env bats
# Test harness for pr-label-assigner.
#
# This file drives every functional test case through `act push --rm`
# so the script is exercised end-to-end via the GitHub Actions workflow,
# never bypassed. Workflow-structure tests (YAML shape, file refs,
# actionlint) live alongside but do NOT invoke act.
#
# Each act-driven case:
#   1. Builds a temp git repo containing the project files + that
#      case's fixture data.
#   2. Runs `act push --rm --env LABEL_FIXTURE=<case>` from the temp
#      repo.
#   3. Appends a delimited section of the combined act output to
#      ../act-result.txt (next to this file's project root).
#   4. Asserts: act exit == 0, every job shows "Job succeeded", and the
#      labels block parsed from act output equals the case's
#      expected.txt byte-for-byte.

PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
ACT_RESULT="$PROJECT_ROOT/act-result.txt"
WORKFLOW="$PROJECT_ROOT/.github/workflows/pr-label-assigner.yml"
SCRIPT="$PROJECT_ROOT/pr-label-assigner.sh"

setup_file() {
    # Truncate the cumulative act log once for this whole file run.
    : > "$ACT_RESULT"
}

# ---------------------------------------------------------------------
# Workflow structure tests (do not invoke act).
# ---------------------------------------------------------------------

@test "structure: workflow file exists and references the script" {
    [ -f "$WORKFLOW" ]
    [ -f "$SCRIPT" ]
    grep -q 'pr-label-assigner.sh' "$WORKFLOW"
    grep -q 'actions/checkout@v4' "$WORKFLOW"
}

@test "structure: workflow declares push, pull_request, workflow_dispatch triggers" {
    grep -qE '^\s*push:' "$WORKFLOW"
    grep -qE '^\s*pull_request:' "$WORKFLOW"
    grep -qE '^\s*workflow_dispatch:' "$WORKFLOW"
}

@test "structure: workflow declares contents:read permission and assign-labels job" {
    grep -qE '^\s*contents:\s*read' "$WORKFLOW"
    grep -qE '^\s*assign-labels:' "$WORKFLOW"
    grep -qE 'runs-on:\s*ubuntu-latest' "$WORKFLOW"
}

@test "structure: every fixture referenced by the harness exists with required files" {
    for case_name in case_basic case_priority case_multi; do
        for required in files.txt labels.conf expected.txt; do
            [ -f "$PROJECT_ROOT/tests/fixtures/$case_name/$required" ]
        done
    done
}

@test "structure: actionlint passes on the workflow file" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "structure: shellcheck + bash -n pass on the script" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------
# Act-driven functional tests. Each test case is a single `act push`
# invocation in a fresh temp git repo.
# ---------------------------------------------------------------------

# Build a temp git repo containing the project, then `act push --rm`
# with LABEL_FIXTURE pointed at the requested case.
run_act_for_case() {
    local case_name="$1"
    local tmp
    tmp="$(mktemp -d -t prlabel-XXXXXX)"
    # Copy project files into the temp repo. Exclude .git so we can
    # initialize a clean repo, and exclude the running harness's
    # cumulative log to avoid feedback loops.
    (
        cd "$PROJECT_ROOT"
        # tar | tar pattern keeps us portable (no rsync required).
        tar --exclude='./.git' \
            --exclude='./act-result.txt' \
            -cf - . | tar -xf - -C "$tmp"
    )
    (
        cd "$tmp"
        git init -q -b main
        git -c user.email=t@t.example -c user.name=test add -A
        git -c user.email=t@t.example -c user.name=test commit -q -m "init"
    )
    local out status_code
    set +e
    # --pull=false because the act image is pre-loaded locally
    # (see .actrc); without it, act tries a registry pull and fails
    # in the offline benchmark sandbox.
    out="$(cd "$tmp" && act push --rm --pull=false \
        --env "LABEL_FIXTURE=${case_name}" \
        --env "GITHUB_TOKEN=dummy" \
        2>&1)"
    status_code=$?
    set -e
    {
        printf '\n========== act run for fixture: %s ==========\n' "$case_name"
        printf '%s\n' "$out"
        printf '\n========== fixture %s: act exit status = %s ==========\n' \
            "$case_name" "$status_code"
    } >> "$ACT_RESULT"
    ACT_OUTPUT="$out"
    ACT_STATUS="$status_code"
    rm -rf "$tmp"
}

# Pull the labels block (between the BEGIN/END sentinels for this case)
# out of act's prefixed output, stripping the "[Workflow/Job]  | " prefix
# that act adds to every step line.
extract_labels() {
    local case_name="$1"
    local payload="$2"
    awk -v start="===PR-LABELS-BEGIN:${case_name}===" \
        -v end="===PR-LABELS-END:${case_name}===" '
        function clean(s,    r) {
            r = s
            # Strip ANSI color escape sequences act may emit.
            gsub(/\033\[[0-9;]*m/, "", r)
            # Strip trailing CR (unlikely on linux but cheap insurance).
            sub(/\r$/, "", r)
            # act prefixes step output as "[Workflow/Job]  | line".
            # Strip everything up to and including the first "| ".
            if (match(r, /\] +\| ?/)) {
                r = substr(r, RSTART + RLENGTH)
            }
            return r
        }
        { line = clean($0) }
        index(line, start) { cap = 1; next }
        index(line, end)   { exit }
        cap { print line }
    ' <<<"$payload"
}

assert_act_success() {
    local case_name="$1"
    [ "$ACT_STATUS" -eq 0 ] \
        || { echo "act exit was $ACT_STATUS for $case_name"; echo "$ACT_OUTPUT" | tail -40; return 1; }
    # act 0.2.87 prints "Success - Complete job" as the per-job
    # success marker (its closest analog to "Job succeeded").
    [[ "$ACT_OUTPUT" == *"Success - Complete job"* ]] \
        || { echo "no job-success marker for $case_name"; echo "$ACT_OUTPUT" | tail -40; return 1; }
    # Defense-in-depth: no failure markers should appear for any step/job.
    if [[ "$ACT_OUTPUT" == *"Failure - "* ]]; then
        echo "found failure marker in act output for $case_name"
        echo "$ACT_OUTPUT" | grep -F "Failure -" | head -10
        return 1
    fi
}

assert_labels_match_expected() {
    local case_name="$1"
    local actual expected
    actual="$(extract_labels "$case_name" "$ACT_OUTPUT")"
    expected="$(cat "$PROJECT_ROOT/tests/fixtures/$case_name/expected.txt")"
    if [ "$actual" != "$expected" ]; then
        printf 'EXPECTED:\n%s\n---\nACTUAL:\n%s\n' "$expected" "$actual"
        return 1
    fi
}

@test "act case_basic: docs/** + *.md fixture yields 'documentation','markdown'" {
    run_act_for_case "case_basic"
    assert_act_success "case_basic"
    assert_labels_match_expected "case_basic"
    # Sanity: explicit exact-value assertion (not just "matches expected").
    actual="$(extract_labels "case_basic" "$ACT_OUTPUT")"
    [ "$actual" = "$(printf 'documentation\nmarkdown')" ]
}

@test "act case_priority: catch-all + multi-label rules yield 'api','backend','everything','docs'" {
    run_act_for_case "case_priority"
    assert_act_success "case_priority"
    assert_labels_match_expected "case_priority"
    actual="$(extract_labels "case_priority" "$ACT_OUTPUT")"
    [ "$actual" = "$(printf 'api\nbackend\neverything\ndocs')" ]
}

@test "act case_multi: glob-overlap rules yield 'tests','src','ci','documentation'" {
    run_act_for_case "case_multi"
    assert_act_success "case_multi"
    assert_labels_match_expected "case_multi"
    actual="$(extract_labels "case_multi" "$ACT_OUTPUT")"
    [ "$actual" = "$(printf 'tests\nsrc\nci\ndocumentation')" ]
}

@test "act-result.txt artifact exists and contains all three fixtures' output" {
    [ -s "$ACT_RESULT" ]
    grep -q 'fixture: case_basic'    "$ACT_RESULT"
    grep -q 'fixture: case_priority' "$ACT_RESULT"
    grep -q 'fixture: case_multi'    "$ACT_RESULT"
    # Every recorded run must have ended with exit status 0.
    ! grep -qE 'act exit status = [^0]' "$ACT_RESULT"
}
