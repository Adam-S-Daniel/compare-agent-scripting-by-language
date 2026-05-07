#!/usr/bin/env bats

# Test suite for secret-rotation-validator.sh
# Uses a fixed reference date (2026-05-07) for deterministic results.

SCRIPT="$BATS_TEST_DIRNAME/../secret-rotation-validator.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

# --- Argument validation tests ---

@test "exits with error when no --config provided" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required option: --config"* ]]
}

@test "exits with error for nonexistent config file" {
  run bash "$SCRIPT" --config /nonexistent/file.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"Config file not found"* ]]
}

@test "exits with error for invalid format option" {
  run bash "$SCRIPT" --config "$FIXTURES/all-ok.json" --format xml --reference-date 2026-05-07
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid format"* ]]
}

@test "exits with error for unknown option" {
  run bash "$SCRIPT" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "shows help with -h flag" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# --- Basic classification tests (reference date: 2026-05-07) ---

@test "basic secrets: classifies DB_PASSWORD as expired" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  # DB_PASSWORD last rotated 2026-01-15, policy 90d -> expired 2026-04-15
  expired_names=$(echo "$output" | jq -r '.expired[].name')
  [[ "$expired_names" == *"DB_PASSWORD"* ]]
}

@test "basic secrets: classifies API_KEY as warning" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json --warning-days 14
  # API_KEY last rotated 2026-04-20, policy 30d -> expires 2026-05-20
  # Days until expiry = 13, within 14-day warning window
  warning_names=$(echo "$output" | jq -r '.warning[].name')
  [[ "$warning_names" == *"API_KEY"* ]]
}

@test "basic secrets: classifies TLS_CERT as ok" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  ok_names=$(echo "$output" | jq -r '.ok[].name')
  [[ "$ok_names" == *"TLS_CERT"* ]]
}

@test "basic secrets: summary counts are correct" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json --warning-days 14
  expired=$(echo "$output" | jq '.report.summary.expired')
  warning=$(echo "$output" | jq '.report.summary.warning')
  ok=$(echo "$output" | jq '.report.summary.ok')
  [ "$expired" -eq 1 ]
  [ "$warning" -eq 1 ]
  [ "$ok" -eq 1 ]
}

# --- All-expired fixture ---

@test "all-expired: all secrets classified as expired" {
  run bash "$SCRIPT" --config "$FIXTURES/all-expired.json" \
    --reference-date 2026-05-07 --format json
  expired_count=$(echo "$output" | jq '.report.summary.expired')
  total=$(echo "$output" | jq '.report.total_secrets')
  [ "$expired_count" -eq "$total" ]
  [ "$expired_count" -eq 2 ]
}

@test "all-expired: exit code is 2" {
  run bash "$SCRIPT" --config "$FIXTURES/all-expired.json" \
    --reference-date 2026-05-07 --format json
  [ "$status" -eq 2 ]
}

# --- All-ok fixture ---

@test "all-ok: all secrets classified as ok" {
  run bash "$SCRIPT" --config "$FIXTURES/all-ok.json" \
    --reference-date 2026-05-07 --format json
  ok_count=$(echo "$output" | jq '.report.summary.ok')
  total=$(echo "$output" | jq '.report.total_secrets')
  [ "$ok_count" -eq "$total" ]
  [ "$ok_count" -eq 2 ]
}

@test "all-ok: exit code is 0" {
  run bash "$SCRIPT" --config "$FIXTURES/all-ok.json" \
    --reference-date 2026-05-07 --format json
  [ "$status" -eq 0 ]
}

# --- Empty secrets ---

@test "empty secrets: handles empty array gracefully" {
  run bash "$SCRIPT" --config "$FIXTURES/empty-secrets.json" \
    --reference-date 2026-05-07 --format json
  [ "$status" -eq 0 ]
  total=$(echo "$output" | jq '.report.total_secrets')
  [ "$total" -eq 0 ]
}

# --- Warning window customization ---

@test "warning window 0: API_KEY classified as ok with zero warning days" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json --warning-days 0
  # API_KEY expires in 13 days, no warning window -> ok
  ok_names=$(echo "$output" | jq -r '.ok[].name')
  [[ "$ok_names" == *"API_KEY"* ]]
}

@test "warning window 30: TLS_CERT still ok with 30-day window" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json --warning-days 30
  # TLS_CERT expires 2027-05-01, ~359 days out, still ok
  ok_names=$(echo "$output" | jq -r '.ok[].name')
  [[ "$ok_names" == *"TLS_CERT"* ]]
}

# --- Markdown output tests ---

@test "markdown output: contains report header" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format markdown
  [[ "$output" == *"# Secret Rotation Report"* ]]
  [[ "$output" == *"**Reference Date:** 2026-05-07"* ]]
}

@test "markdown output: contains summary section" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format markdown --warning-days 14
  [[ "$output" == *"**Expired:** 1"* ]]
  [[ "$output" == *"**Warning:** 1"* ]]
  [[ "$output" == *"**OK:** 1"* ]]
}

@test "markdown output: contains table with secret names" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format markdown
  [[ "$output" == *"DB_PASSWORD"* ]]
  [[ "$output" == *"API_KEY"* ]]
  [[ "$output" == *"TLS_CERT"* ]]
}

@test "markdown output: shows required_by services" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format markdown
  [[ "$output" == *"api-server"* ]]
  [[ "$output" == *"auth-service"* ]]
}

# --- JSON output structure tests ---

@test "json output: has correct top-level structure" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  echo "$output" | jq -e '.report' >/dev/null
  echo "$output" | jq -e '.expired' >/dev/null
  echo "$output" | jq -e '.warning' >/dev/null
  echo "$output" | jq -e '.ok' >/dev/null
}

@test "json output: expired item has correct fields" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  echo "$output" | jq -e '.expired[0].name' >/dev/null
  echo "$output" | jq -e '.expired[0].last_rotated' >/dev/null
  echo "$output" | jq -e '.expired[0].rotation_policy_days' >/dev/null
  echo "$output" | jq -e '.expired[0].days_since_rotation' >/dev/null
  echo "$output" | jq -e '.expired[0].expires_in_days' >/dev/null
  echo "$output" | jq -e '.expired[0].expiry_date' >/dev/null
  echo "$output" | jq -e '.expired[0].required_by' >/dev/null
}

@test "json output: days_since_rotation is correct for DB_PASSWORD" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  # 2026-01-15 to 2026-05-07 = 112 days
  days=$(echo "$output" | jq '.expired[] | select(.name=="DB_PASSWORD") | .days_since_rotation')
  [ "$days" -eq 112 ]
}

@test "json output: expiry_date is correct for DB_PASSWORD" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  # 2026-01-15 + 90 days = 2026-04-15
  expiry=$(echo "$output" | jq -r '.expired[] | select(.name=="DB_PASSWORD") | .expiry_date')
  [ "$expiry" = "2026-04-15" ]
}

@test "json output: reference_date matches input" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  ref_date=$(echo "$output" | jq -r '.report.reference_date')
  [ "$ref_date" = "2026-05-07" ]
}

# --- Exit code tests ---

@test "exit code 2 when expired secrets exist" {
  run bash "$SCRIPT" --config "$FIXTURES/basic-secrets.json" \
    --reference-date 2026-05-07 --format json
  [ "$status" -eq 2 ]
}

@test "exit code 1 when only warning secrets exist" {
  # Create a fixture where only warnings exist (API_KEY expires in 13 days)
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<'EOF'
{
  "secrets": [
    {
      "name": "WARN_SECRET",
      "last_rotated": "2026-04-20",
      "rotation_policy_days": 30,
      "required_by": ["svc"]
    }
  ]
}
EOF
  run bash "$SCRIPT" --config "$tmpfile" --reference-date 2026-05-07 --format json --warning-days 14
  rm -f "$tmpfile"
  [ "$status" -eq 1 ]
}

@test "exit code 0 when all secrets are ok" {
  run bash "$SCRIPT" --config "$FIXTURES/all-ok.json" \
    --reference-date 2026-05-07 --format json
  [ "$status" -eq 0 ]
}
