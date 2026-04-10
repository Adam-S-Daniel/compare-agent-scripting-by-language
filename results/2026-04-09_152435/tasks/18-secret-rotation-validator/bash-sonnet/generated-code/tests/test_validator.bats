#!/usr/bin/env bats
# Tests for secret-rotation-validator.sh
#
# TDD approach: tests are written before the implementation.
# Reference date: 2026-04-10 is used throughout for deterministic results.
#
# Fixture secret states (with --date 2026-04-10 --warning 14, TZ=UTC):
#   DB_MASTER_PASSWORD: last_rotated=2025-12-11, policy=90d -> 120 days old -> EXPIRED (30 days overdue)
#   API_KEY:            last_rotated=2026-01-18, policy=90d -> 82 days old  -> WARNING (8 days until expiry)
#   JWT_SECRET:         last_rotated=2026-03-11, policy=90d -> 30 days old  -> OK (60 days until expiry)

# ---------------------------------------------------------------------------
# Test setup / teardown
# ---------------------------------------------------------------------------

setup() {
    # Resolve absolute path to the project root (one level up from tests/)
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SCRIPT="$SCRIPT_DIR/secret-rotation-validator.sh"
    FIXTURES_DIR="$SCRIPT_DIR/fixtures"

    # Temp directory for scratch files created by individual tests
    TEST_TMPDIR="$(mktemp -d)"

    # Fixed reference date for deterministic assertions.
    # Force UTC so date arithmetic is timezone-independent and matches the
    # GitHub Actions container (which also runs in UTC).
    export TZ="UTC"
    REF_DATE="2026-04-10"
    WARN_DAYS="14"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ===========================================================================
# RED TEST 1: script exists and has the correct shebang
# ===========================================================================
@test "script exists and has correct shebang" {
    [ -f "$SCRIPT" ]
    head -1 "$SCRIPT" | grep -q '#!/usr/bin/env bash'
}

# ===========================================================================
# RED TEST 2: error on missing config argument
# ===========================================================================
@test "exits with error when no config file argument is provided" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "error"
}

# ===========================================================================
# RED TEST 3: error when config file does not exist
# ===========================================================================
@test "exits with error when config file does not exist" {
    run "$SCRIPT" /nonexistent/path/secrets.json
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "error"
}

# ===========================================================================
# RED TEST 4: error on invalid output format
# ===========================================================================
@test "exits with error for invalid output format" {
    run "$SCRIPT" --format xml "$FIXTURES_DIR/secrets.json"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "error"
}

# ===========================================================================
# RED TEST 5: identifies expired secrets
# ===========================================================================
@test "identifies expired secrets correctly" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    # DB_MASTER_PASSWORD should be in the expired list
    echo "$output" | grep -q "DB_MASTER_PASSWORD"
    # Confirm it is in the expired section via JSON
    echo "$output" | jq -e '.expired | map(select(.name == "DB_MASTER_PASSWORD")) | length == 1' > /dev/null
}

# ===========================================================================
# RED TEST 6: expired secret has correct days_overdue
# ===========================================================================
@test "expired secret has correct days_overdue value" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    local overdue
    overdue=$(echo "$output" | jq -r '.expired[] | select(.name == "DB_MASTER_PASSWORD") | .days_overdue')
    [ "$overdue" -eq 30 ]
}

# ===========================================================================
# RED TEST 7: identifies warning secrets
# ===========================================================================
@test "identifies warning secrets correctly" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.warning | map(select(.name == "API_KEY")) | length == 1' > /dev/null
}

# ===========================================================================
# RED TEST 8: warning secret has correct days_until_expiry
# ===========================================================================
@test "warning secret has correct days_until_expiry value" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    local until_expiry
    until_expiry=$(echo "$output" | jq -r '.warning[] | select(.name == "API_KEY") | .days_until_expiry')
    [ "$until_expiry" -eq 8 ]
}

# ===========================================================================
# RED TEST 9: identifies OK secrets
# ===========================================================================
@test "identifies ok secrets correctly" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.ok | map(select(.name == "JWT_SECRET")) | length == 1' > /dev/null
}

# ===========================================================================
# RED TEST 10: JSON output has correct summary counts
# ===========================================================================
@test "JSON output has correct summary counts" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.summary.expired == 1' > /dev/null
    echo "$output" | jq -e '.summary.warning == 1' > /dev/null
    echo "$output" | jq -e '.summary.ok == 1' > /dev/null
}

# ===========================================================================
# RED TEST 11: JSON output has report_date field
# ===========================================================================
@test "JSON output includes report_date" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.report_date == "2026-04-10"' > /dev/null
}

# ===========================================================================
# RED TEST 12: markdown output contains expired section header
# ===========================================================================
@test "markdown output contains expired section with count" {
    run "$SCRIPT" --format markdown --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "## Expired (1)"
}

# ===========================================================================
# RED TEST 13: markdown output contains expired secret row
# ===========================================================================
@test "markdown output contains expired secret table row" {
    run "$SCRIPT" --format markdown --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DB_MASTER_PASSWORD"
    echo "$output" | grep -q "30"
}

# ===========================================================================
# RED TEST 14: markdown output contains warning section
# ===========================================================================
@test "markdown output contains warning section with count" {
    run "$SCRIPT" --format markdown --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "## Warning (1)"
}

# ===========================================================================
# RED TEST 15: markdown output contains ok section
# ===========================================================================
@test "markdown output contains ok section with count" {
    run "$SCRIPT" --format markdown --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "## OK (1)"
}

# ===========================================================================
# RED TEST 16: all-ok fixture produces no expired or warning secrets
# ===========================================================================
@test "all-ok fixture produces no expired or warning secrets" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets-all-ok.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.summary.expired == 0' > /dev/null
    echo "$output" | jq -e '.summary.warning == 0' > /dev/null
    echo "$output" | jq -e '.summary.ok == 3' > /dev/null
}

# ===========================================================================
# RED TEST 17: required_by field is included in JSON output
# ===========================================================================
@test "JSON output includes required_by field" {
    run "$SCRIPT" --format json --warning "$WARN_DAYS" --date "$REF_DATE" \
        "$FIXTURES_DIR/secrets.json"
    [ "$status" -eq 0 ]
    # DB_MASTER_PASSWORD is required by db-service and api-gateway
    echo "$output" | jq -e '
        .expired[] | select(.name == "DB_MASTER_PASSWORD") | .required_by
        | contains("db-service")
    ' > /dev/null
}

# ===========================================================================
# WORKFLOW STRUCTURE TESTS
# ===========================================================================

@test "workflow file exists" {
    [ -f "$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml" ]
}

@test "workflow references script file that exists" {
    local workflow="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"
    [ -f "$workflow" ]
    # Verify the script path referenced in the workflow actually exists
    grep -q "secret-rotation-validator.sh" "$workflow"
    [ -f "$SCRIPT_DIR/secret-rotation-validator.sh" ]
}

@test "workflow has expected triggers" {
    local workflow="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"
    grep -q "push" "$workflow"
    grep -q "pull_request\|workflow_dispatch" "$workflow"
}

@test "workflow has validate-secrets job" {
    local workflow="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"
    grep -q "validate-secrets" "$workflow"
}

@test "workflow uses actions/checkout@v4" {
    local workflow="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"
    grep -q "actions/checkout@v4" "$workflow"
}

@test "actionlint passes on workflow file" {
    local workflow="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"
    run actionlint "$workflow"
    [ "$status" -eq 0 ]
}
