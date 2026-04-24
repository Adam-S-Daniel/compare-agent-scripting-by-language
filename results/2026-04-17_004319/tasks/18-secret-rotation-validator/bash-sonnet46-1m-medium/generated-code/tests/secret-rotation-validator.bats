#!/usr/bin/env bats
# Tests for secret-rotation-validator.sh using bats-core
# TDD: tests are written first, then the implementation is built to pass them.

SCRIPT="${BATS_TEST_DIRNAME}/../secret-rotation-validator.sh"
FIXTURES_DIR="${BATS_TEST_DIRNAME}/../fixtures"

# Fixed reference date so tests are deterministic
REF_DATE="2026-04-20"

# ─── Red/Green cycle 1: script existence ────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script prints usage when called with --help" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ─── Red/Green cycle 2: expired detection ────────────────────────────────────
# DB_PASSWORD: last_rotated=2026-03-01, rotation_days=30
# reference=2026-04-20 → 50 days since rotation → 20 days overdue → EXPIRED

@test "expired secret is classified as EXPIRED in JSON output" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "EXPIRED"'* ]]
}

@test "expired secret DB_PASSWORD appears in JSON output" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name": "DB_PASSWORD"'* ]]
}

@test "expired secret has correct days_overdue in JSON output" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  # DB_PASSWORD: 50 days since rotation, 30-day policy → 20 days overdue
  [[ "$output" == *'"days_overdue": 20'* ]]
}

# ─── Red/Green cycle 3: warning detection ────────────────────────────────────
# API_KEY: last_rotated=2026-04-18, rotation_days=7
# reference=2026-04-20 → 2 days since rotation → 5 days remaining → WARNING (< 7-day window)

@test "warning secret is classified as WARNING in JSON output" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "WARNING"'* ]]
}

@test "warning secret API_KEY has correct days_remaining" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  # API_KEY: 2 days since rotation, 7-day policy → 5 days remaining
  [[ "$output" == *'"days_remaining": 5'* ]]
}

# ─── Red/Green cycle 4: ok detection ─────────────────────────────────────────
# TLS_CERT: last_rotated=2026-04-01, rotation_days=90
# reference=2026-04-20 → 19 days since rotation → 71 days remaining → OK

@test "ok secret is classified as OK in JSON output" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "OK"'* ]]
}

@test "ok secret TLS_CERT has correct days_remaining" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  # TLS_CERT: 19 days since rotation, 90-day policy → 71 days remaining
  [[ "$output" == *'"days_remaining": 71'* ]]
}

# ─── Red/Green cycle 5: summary counts ───────────────────────────────────────

@test "JSON output includes summary with correct counts" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"expired": 1'* ]]
  [[ "$output" == *'"warning": 1'* ]]
  [[ "$output" == *'"ok": 1'* ]]
  [[ "$output" == *'"total": 3'* ]]
}

# ─── Red/Green cycle 6: required_by services ─────────────────────────────────

@test "JSON output includes required_by services" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"api"'* ]]
  [[ "$output" == *'"worker"'* ]]
}

# ─── Red/Green cycle 7: markdown output ──────────────────────────────────────

@test "markdown output contains secret names" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"DB_PASSWORD"* ]]
  [[ "$output" == *"API_KEY"* ]]
  [[ "$output" == *"TLS_CERT"* ]]
}

@test "markdown output contains status labels" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"EXPIRED"* ]]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"OK"* ]]
}

@test "markdown output contains a table header" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Name |"* ]]
  [[ "$output" == *"| Status |"* ]]
}

@test "markdown output groups secrets by urgency section" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"## EXPIRED"* ]]
  [[ "$output" == *"## WARNING"* ]]
  [[ "$output" == *"## OK"* ]]
}

# ─── Red/Green cycle 8: all-expired fixture ──────────────────────────────────

@test "all-expired fixture produces no WARNING or OK secrets" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-all-expired.json" \
    --reference-date "$REF_DATE" \
    --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"warning": 0'* ]]
  [[ "$output" == *'"ok": 0'* ]]
}

# ─── Red/Green cycle 9: configurable warning window ──────────────────────────

@test "warning window can be overridden via --warning-days flag" {
  # API_KEY has 5 days remaining; with window=3 it should be OK not WARNING
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --reference-date "$REF_DATE" \
    --warning-days 3 \
    --format json
  [ "$status" -eq 0 ]
  # With 3-day window, API_KEY (5 days remaining) should be OK
  [[ "$output" == *'"warning": 0'* ]]
  [[ "$output" == *'"ok": 2'* ]]
}

# ─── Red/Green cycle 10: error handling ──────────────────────────────────────

@test "missing config file prints error and exits non-zero" {
  run "$SCRIPT" --config /nonexistent/path.json --format json
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

@test "invalid format option prints error and exits non-zero" {
  run "$SCRIPT" \
    --config "$FIXTURES_DIR/secrets-basic.json" \
    --format xml
  [ "$status" -ne 0 ]
}

# ─── Red/Green cycle 11: workflow structure tests ────────────────────────────

@test "GitHub Actions workflow file exists" {
  [ -f "${BATS_TEST_DIRNAME}/../.github/workflows/secret-rotation-validator.yml" ]
}

@test "workflow references script file that exists" {
  local workflow="${BATS_TEST_DIRNAME}/../.github/workflows/secret-rotation-validator.yml"
  # Check that the workflow references secret-rotation-validator.sh
  grep -q "secret-rotation-validator.sh" "$workflow"
  # Check that the script file actually exists
  [ -f "${BATS_TEST_DIRNAME}/../secret-rotation-validator.sh" ]
}

@test "workflow has expected triggers" {
  local workflow="${BATS_TEST_DIRNAME}/../.github/workflows/secret-rotation-validator.yml"
  grep -q "push:" "$workflow"
  grep -q "workflow_dispatch" "$workflow"
}

@test "workflow has validate job" {
  local workflow="${BATS_TEST_DIRNAME}/../.github/workflows/secret-rotation-validator.yml"
  grep -q "validate:" "$workflow"
}

@test "actionlint passes on workflow file" {
  local workflow="${BATS_TEST_DIRNAME}/../.github/workflows/secret-rotation-validator.yml"
  run actionlint "$workflow"
  [ "$status" -eq 0 ]
}
