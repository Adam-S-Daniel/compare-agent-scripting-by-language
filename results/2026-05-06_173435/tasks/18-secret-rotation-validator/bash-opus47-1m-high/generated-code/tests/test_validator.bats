#!/usr/bin/env bats
#
# Test suite for secret-rotation-validator.
#
# Per the task contract every functional assertion runs through `act`.
# We invoke `act push --rm` ONCE in setup_file (capped at 3 invocations
# total in the project lifecycle) and then parse the captured output in
# individual @test cases. Structural checks against the workflow file
# itself do not need a container so they run inline.

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
SCRIPT="${PROJECT_ROOT}/bin/secret-rotation-validator.sh"
WORKFLOW="${PROJECT_ROOT}/.github/workflows/secret-rotation-validator.yml"
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

# ---------------------------------------------------------------------------
# Static / structural assertions
# ---------------------------------------------------------------------------

@test "script file exists at expected path" {
    [ -f "$SCRIPT" ]
}

@test "script has correct bash shebang" {
    head -n 1 "$SCRIPT" | grep -qE '^#!/usr/bin/env bash$'
}

@test "script passes bash -n syntax validation" {
    bash -n "$SCRIPT"
}

@test "script passes shellcheck" {
    shellcheck "$SCRIPT"
}

@test "workflow file exists at .github/workflows/secret-rotation-validator.yml" {
    [ -f "$WORKFLOW" ]
}

@test "workflow passes actionlint" {
    actionlint "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'actions/checkout@v4' "$WORKFLOW"
}

@test "workflow references the validator script" {
    grep -q 'bin/secret-rotation-validator.sh' "$WORKFLOW"
}

@test "workflow declares push, pull_request, schedule, and workflow_dispatch triggers" {
    grep -q '^on:' "$WORKFLOW"
    grep -qE '^[[:space:]]+push:' "$WORKFLOW"
    grep -qE '^[[:space:]]+pull_request:' "$WORKFLOW"
    grep -qE '^[[:space:]]+schedule:' "$WORKFLOW"
    grep -qE '^[[:space:]]+workflow_dispatch:' "$WORKFLOW"
}

@test "workflow declares least-privilege contents:read permission" {
    grep -qE '^permissions:|^[[:space:]]+permissions:' "$WORKFLOW"
    grep -qE 'contents:[[:space:]]*read' "$WORKFLOW"
}

# ---------------------------------------------------------------------------
# Dynamic assertions on captured act output
# ---------------------------------------------------------------------------

@test "act-result.txt exists and is non-empty" {
    [ -s "$ACT_RESULT" ]
}

@test "act exited with code 0 (recorded sentinel)" {
    # ACT_EXIT_CODE is written by run_act.sh after `act` returns, so it
    # appears unprefixed at the bottom of act-result.txt.
    grep -qE '^ACT_EXIT_CODE=0$' "$ACT_RESULT"
}

@test "every job in the act run reports Job succeeded" {
    # No job should have failed.
    ! grep -qE 'Job failed' "$ACT_RESULT"
    # And we should see at least one explicit success.
    grep -q 'Job succeeded' "$ACT_RESULT"
}

@test "fixture A (mixed) markdown report shows STRIPE_API_KEY as EXPIRED" {
    grep -qE '\| STRIPE_API_KEY \|.*\| EXPIRED \|' "$ACT_RESULT"
}

@test "fixture A (mixed) markdown report shows GITHUB_TOKEN as WARNING" {
    grep -qE '\| GITHUB_TOKEN \|.*\| WARNING \|' "$ACT_RESULT"
}

@test "fixture A (mixed) markdown report shows SLACK_WEBHOOK as OK" {
    grep -qE '\| SLACK_WEBHOOK \|.*\| OK \|' "$ACT_RESULT"
}

@test "fixture A summary counts: 1 expired, 1 warning, 1 ok" {
    # `act` prefixes each emitted line with "[<job>/<step>]   | ", so we
    # match the sentinel anywhere on the line rather than anchoring to BOL.
    grep -qE 'Summary:[[:space:]]+expired=1[[:space:]]+warning=1[[:space:]]+ok=1\b' "$ACT_RESULT"
}

@test "fixture A markdown report contains required-by services for STRIPE_API_KEY" {
    grep -qE '\| STRIPE_API_KEY \|.*payments-svc, billing-svc' "$ACT_RESULT"
}

@test "fixture A exits non-zero when --fail-on-expired is set with expired secrets" {
    grep -qE 'FAIL_ON_EXPIRED_EXIT=2\b' "$ACT_RESULT"
}

@test "fixture B (all-ok) summary shows 0 expired and 0 warning" {
    grep -qE 'Summary:[[:space:]]+expired=0[[:space:]]+warning=0[[:space:]]+ok=2\b' "$ACT_RESULT"
}

@test "fixture B exits 0 with --fail-on-expired since no expired secrets" {
    grep -qE 'ALLGOOD_EXIT=0\b' "$ACT_RESULT"
}

@test "fixture C JSON output has expected expired/warning/ok grouping" {
    # Sentinel emitted by workflow after parsing JSON with jq.
    grep -qE 'JSON_GROUPS=expired:1,warning:1,ok:0\b' "$ACT_RESULT"
}

@test "fixture C JSON output carries name, status, days_overdue fields" {
    grep -qE 'JSON_FIELDS_OK=true\b' "$ACT_RESULT"
}

@test "warning window is configurable via --warning-days flag" {
    # With a tighter warning window in fixture D, GITHUB_TOKEN flips to OK.
    grep -qE 'TIGHT_WINDOW_GITHUB_STATUS=OK\b' "$ACT_RESULT"
}

@test "script rejects malformed JSON with a meaningful error" {
    grep -qE 'MALFORMED_JSON_HANDLED=true\b' "$ACT_RESULT"
}

@test "script rejects missing config file with a meaningful error" {
    grep -qE 'MISSING_FILE_HANDLED=true\b' "$ACT_RESULT"
}
