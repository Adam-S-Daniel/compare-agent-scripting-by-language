#!/usr/bin/env bats
# Tests for validate-secrets.sh using red/green TDD methodology.
# Reference date: 2026-04-19 (used for deterministic date calculations)
#
# Fixture layout (reference date 2026-04-19, warning_window=14 days):
#   DB_PASSWORD: last_rotated=2025-11-01, rotation=90d → expiry=2026-01-30 → EXPIRED (79d overdue)
#   API_KEY:     last_rotated=2026-01-20, rotation=90d → expiry=2026-04-20 → WARNING (1d left)
#   JWT_SECRET:  last_rotated=2026-02-15, rotation=90d → expiry=2026-05-16 → OK     (27d left)

SCRIPT="${BATS_TEST_DIRNAME}/../validate-secrets.sh"
FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
REF_DATE="2026-04-19"

# ---------------------------------------------------------------------------
# Test 1 (RED → GREEN): script exists and is executable
# ---------------------------------------------------------------------------
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ---------------------------------------------------------------------------
# Test 2 (RED → GREEN): expired secret is classified as expired in JSON output
# ---------------------------------------------------------------------------
@test "expired secret is classified as expired" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    # DB_PASSWORD should appear in the "expired" array
    echo "$output" | jq -e '.expired[] | select(.name == "DB_PASSWORD")' >/dev/null
}

# ---------------------------------------------------------------------------
# Test 3 (RED → GREEN): warning secret is classified as warning
# ---------------------------------------------------------------------------
@test "warning secret is classified as warning" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.warning[] | select(.name == "API_KEY")' >/dev/null
}

# ---------------------------------------------------------------------------
# Test 4 (RED → GREEN): ok secret is classified as ok
# ---------------------------------------------------------------------------
@test "ok secret is classified as ok" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.ok[] | select(.name == "JWT_SECRET")' >/dev/null
}

# ---------------------------------------------------------------------------
# Test 5 (RED → GREEN): JSON output contains summary counts
# ---------------------------------------------------------------------------
@test "JSON output summary counts are correct" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    local expired_count
    expired_count=$(echo "$output" | jq '.summary.expired')
    local warning_count
    warning_count=$(echo "$output" | jq '.summary.warning')
    local ok_count
    ok_count=$(echo "$output" | jq '.summary.ok')
    [ "$expired_count" -eq 1 ]
    [ "$warning_count" -eq 1 ]
    [ "$ok_count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Test 6 (RED → GREEN): expired secret has correct days_overdue field
# ---------------------------------------------------------------------------
@test "expired secret shows correct days_overdue" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    local days_overdue
    days_overdue=$(echo "$output" | jq '.expired[] | select(.name == "DB_PASSWORD") | .days_overdue')
    # DB_PASSWORD expiry=2026-01-30, reference=2026-04-19 → 79 days overdue
    [ "$days_overdue" -eq 79 ]
}

# ---------------------------------------------------------------------------
# Test 7 (RED → GREEN): warning secret has days_until field
# ---------------------------------------------------------------------------
@test "warning secret shows correct days_until_expiry" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    local days_until
    days_until=$(echo "$output" | jq '.warning[] | select(.name == "API_KEY") | .days_until_expiry')
    # API_KEY expiry=2026-04-20, reference=2026-04-19 → 1 day left
    [ "$days_until" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Test 8 (RED → GREEN): required_by services are included in output
# ---------------------------------------------------------------------------
@test "expired secret includes required_by services" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    local services
    services=$(echo "$output" | jq -r '.expired[] | select(.name == "DB_PASSWORD") | .required_by | join(",")')
    [ "$services" = "web,api" ]
}

# ---------------------------------------------------------------------------
# Test 9 (RED → GREEN): markdown output contains expected headers
# ---------------------------------------------------------------------------
@test "markdown output contains urgency section headers" {
    run "$SCRIPT" --format markdown --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Expired"
    echo "$output" | grep -q "Warning"
    echo "$output" | grep -q "OK"
}

# ---------------------------------------------------------------------------
# Test 10 (RED → GREEN): markdown output contains secret names
# ---------------------------------------------------------------------------
@test "markdown output contains secret names" {
    run "$SCRIPT" --format markdown --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DB_PASSWORD"
    echo "$output" | grep -q "API_KEY"
    echo "$output" | grep -q "JWT_SECRET"
}

# ---------------------------------------------------------------------------
# Test 11 (RED → GREEN): configurable warning window via --warning-days
# ---------------------------------------------------------------------------
@test "configurable warning window changes classifications" {
    # With warning_window=0, warning secrets become ok
    run "$SCRIPT" --format json --reference-date "$REF_DATE" --warning-days 0 "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    # API_KEY has 1 day left → with 0-day window, it should be OK
    echo "$output" | jq -e '.ok[] | select(.name == "API_KEY")' >/dev/null
}

# ---------------------------------------------------------------------------
# Test 12 (RED → GREEN): warning window from config file is used by default
# ---------------------------------------------------------------------------
@test "warning window from config file is respected" {
    # secrets-mixed.json has warning_window_days=14; API_KEY has 1 day left → WARNING
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.warning[] | select(.name == "API_KEY")' >/dev/null
}

# ---------------------------------------------------------------------------
# Test 13 (RED → GREEN): error on missing config file
# ---------------------------------------------------------------------------
@test "error on missing config file" {
    run "$SCRIPT" --format json /nonexistent/file.json
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "error\|not found\|no such"
}

# ---------------------------------------------------------------------------
# Test 14 (RED → GREEN): error on invalid format option
# ---------------------------------------------------------------------------
@test "error on invalid output format" {
    run "$SCRIPT" --format xml --reference-date "$REF_DATE" "$FIXTURES/secrets-mixed.json"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "error\|invalid\|unknown"
}

# ---------------------------------------------------------------------------
# Test 15 (RED → GREEN): all-expired fixture produces correct output
# ---------------------------------------------------------------------------
@test "all-expired fixture shows all secrets as expired" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-expired.json"
    [ "$status" -eq 0 ]
    local total_ok
    total_ok=$(echo "$output" | jq '.summary.ok')
    local total_warning
    total_warning=$(echo "$output" | jq '.summary.warning')
    [ "$total_ok" -eq 0 ]
    [ "$total_warning" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 16 (RED → GREEN): all-ok fixture produces correct output
# ---------------------------------------------------------------------------
@test "all-ok fixture shows all secrets as ok" {
    run "$SCRIPT" --format json --reference-date "$REF_DATE" "$FIXTURES/secrets-ok.json"
    [ "$status" -eq 0 ]
    local total_expired
    total_expired=$(echo "$output" | jq '.summary.expired')
    [ "$total_expired" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Workflow structure tests (required)
# ---------------------------------------------------------------------------
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/secret-rotation-validator.yml"

@test "workflow file exists" {
    [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
    grep -q "push" "$WORKFLOW"
}

@test "workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch" "$WORKFLOW"
}

@test "workflow references validate-secrets.sh" {
    grep -q "validate-secrets.sh" "$WORKFLOW"
}

@test "validate-secrets.sh exists at path referenced by workflow" {
    [ -f "${BATS_TEST_DIRNAME}/../validate-secrets.sh" ]
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW"
    [ "$status" -eq 0 ]
}
