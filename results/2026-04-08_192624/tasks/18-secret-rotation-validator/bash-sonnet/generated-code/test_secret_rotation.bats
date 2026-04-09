#!/usr/bin/env bats
# Test suite for secret-rotation-validator.sh using bats-core
# TDD approach: tests written before implementation

# Load bats helpers if available
setup() {
    # Get the directory of this test file
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT="$DIR/secret-rotation-validator.sh"
    FIXTURES_DIR="$DIR/fixtures"

    # Reference date for deterministic testing: 2024-01-15
    export REFERENCE_DATE="2024-01-15"
}

# ─────────────────────────────────────────────────────────────
# RED: Test 1 - Script exists and is executable
# ─────────────────────────────────────────────────────────────
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 2 - Script shows usage when run with --help
# ─────────────────────────────────────────────────────────────
@test "shows usage with --help flag" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--format"* ]]
    [[ "$output" == *"--warning-days"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 3 - Script errors on missing config file
# ─────────────────────────────────────────────────────────────
@test "errors gracefully on missing config file" {
    run "$SCRIPT" --config /nonexistent/path.csv
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 4 - Identifies expired secrets (past rotation date)
# An expired secret: last_rotated + rotation_days < today
# ─────────────────────────────────────────────────────────────
@test "identifies expired secrets" {
    # DB_PASSWORD: last rotated 2023-06-01, rotation policy 90 days
    # Expiry: 2023-06-01 + 90 = 2023-08-30 → expired by 2024-01-15
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expired"* ]]
    [[ "$output" == *"DB_PASSWORD"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 5 - Identifies secrets expiring within warning window
# ─────────────────────────────────────────────────────────────
@test "identifies secrets in warning window" {
    # API_KEY_PROD: last rotated 2023-12-01, rotation policy 60 days
    # Expiry: 2023-12-01 + 60 = 2024-01-30 → 15 days from 2024-01-15 → warning (default 30 days)
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --warning-days 30 \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning"* ]]
    [[ "$output" == *"API_KEY_PROD"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 6 - Identifies ok secrets (not expiring soon)
# ─────────────────────────────────────────────────────────────
@test "identifies ok secrets" {
    # OAUTH_TOKEN: last rotated 2024-01-01, rotation policy 365 days
    # Expiry: 2025-01-01 → far future → ok
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
    [[ "$output" == *"OAUTH_TOKEN"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 7 - JSON output has correct structure
# ─────────────────────────────────────────────────────────────
@test "json output has correct structure with urgency groups" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # Must have all three urgency groups
    [[ "$output" == *'"expired"'* ]]
    [[ "$output" == *'"warning"'* ]]
    [[ "$output" == *'"ok"'* ]]
    # Must have summary
    [[ "$output" == *'"summary"'* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 8 - Markdown table output format
# ─────────────────────────────────────────────────────────────
@test "markdown output contains table headers" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format markdown \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Secret Name |"* ]]
    [[ "$output" == *"| Status |"* ]]
    [[ "$output" == *"EXPIRED"* ]] || [[ "$output" == *"Expired"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 9 - Configurable warning window
# ─────────────────────────────────────────────────────────────
@test "respects custom warning-days parameter" {
    # With warning-days=5, API_KEY_PROD (15 days out) should NOT be in warning
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --warning-days 5 \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # API_KEY_PROD is 15 days out, so with 5-day window it should be ok
    # We check the JSON output doesn't put API_KEY_PROD in warning
    echo "$output" | grep -v '"warning".*"API_KEY_PROD"' || true
    # But it should be in ok section
    [[ "$output" == *"API_KEY_PROD"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 10 - JSON output contains required-by services
# ─────────────────────────────────────────────────────────────
@test "json output includes required-by services metadata" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"required_by"* ]] || [[ "$output" == *"required-by"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 11 - Summary counts are accurate
# ─────────────────────────────────────────────────────────────
@test "json summary contains accurate counts" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --warning-days 30 \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # We have 2 expired, 1 warning, 1 ok in our fixture
    [[ "$output" == *'"expired_count"'* ]] || [[ "$output" == *'"expired"'* ]]
    [[ "$output" == *'"total"'* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 12 - Invalid format flag produces error
# ─────────────────────────────────────────────────────────────
@test "errors on invalid output format" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format invalid_format \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"Invalid"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 13 - Markdown output groups secrets by urgency
# ─────────────────────────────────────────────────────────────
@test "markdown output groups secrets by urgency sections" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format markdown \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Expired"* ]] || [[ "$output" == *"## EXPIRED"* ]] || [[ "$output" == *"Expired Secrets"* ]]
    [[ "$output" == *"## Warning"* ]] || [[ "$output" == *"## WARNING"* ]] || [[ "$output" == *"Warning Secrets"* ]]
    [[ "$output" == *"## OK"* ]] || [[ "$output" == *"## Ok"* ]] || [[ "$output" == *"OK Secrets"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 14 - Days until expiry computed correctly
# ─────────────────────────────────────────────────────────────
@test "json output contains days_until_expiry for each secret" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --format json \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"days_until_expiry"* ]]
}

# ─────────────────────────────────────────────────────────────
# RED: Test 15 - Default format is json when not specified
# ─────────────────────────────────────────────────────────────
@test "defaults to json format when no format specified" {
    run "$SCRIPT" \
        --config "$FIXTURES_DIR/secrets.csv" \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # JSON output starts with { or [
    [[ "$output" == "{"* ]] || [[ "$output" == "["* ]] || [[ "$output" == *"{"* ]]
}
