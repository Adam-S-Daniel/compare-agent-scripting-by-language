#!/usr/bin/env bats
# Tests for secret-rotation-validator.sh
# Use a fixed --now so tests are deterministic regardless of wall clock.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../secret-rotation-validator.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  NOW="2026-05-08"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "prints usage with --help and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "errors with non-zero exit when --config missing" {
  run "$SCRIPT" --warning-days 14
  [ "$status" -ne 0 ]
  [[ "$output" == *"--config"* ]]
}

@test "errors when config file does not exist" {
  run "$SCRIPT" --config /nonexistent/path.json --warning-days 14
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "markdown output groups secrets into expired/warning/ok by status" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --format markdown --now "$NOW"
  [ "$status" -eq 1 ]  # mixed fixture has an expired entry → exit 1 by design
  # Headings
  [[ "$output" == *"# Secret Rotation Report"* ]]
  [[ "$output" == *"## Expired (1)"* ]]
  [[ "$output" == *"## Warning (1)"* ]]
  [[ "$output" == *"## OK (1)"* ]]
  # Specific entries
  [[ "$output" == *"db-password"* ]]      # expired (rotated 2025-01-01, policy 90 days)
  [[ "$output" == *"api-token"* ]]        # warning (rotated 2026-02-15, policy 90 days)
  [[ "$output" == *"signing-key"* ]]      # ok (rotated 2026-04-01, policy 90 days)
  # Service list rendered
  [[ "$output" == *"api, worker"* ]]
}

@test "markdown output contains table headers" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --format markdown --now "$NOW"
  [ "$status" -eq 1 ]
  [[ "$output" == *"| Name | Last Rotated | Policy (days) | Days Until Expiry | Services |"* ]]
}

@test "json output is valid JSON with expected structure" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --format json --now "$NOW"
  [ "$status" -eq 1 ]
  echo "$output" | jq . >/dev/null
  # Counts
  [ "$(echo "$output" | jq '.expired | length')" -eq 1 ]
  [ "$(echo "$output" | jq '.warning | length')" -eq 1 ]
  [ "$(echo "$output" | jq '.ok | length')" -eq 1 ]
  [ "$(echo "$output" | jq -r '.expired[0].name')" = "db-password" ]
  [ "$(echo "$output" | jq -r '.warning[0].name')" = "api-token" ]
  [ "$(echo "$output" | jq -r '.ok[0].name')" = "signing-key" ]
  # Services parsed as array
  [ "$(echo "$output" | jq -r '.expired[0].services | length')" -eq 2 ]
  # Summary block
  [ "$(echo "$output" | jq -r '.summary.expired')" -eq 1 ]
  [ "$(echo "$output" | jq -r '.summary.warning')" -eq 1 ]
  [ "$(echo "$output" | jq -r '.summary.ok')" -eq 1 ]
}

@test "all-ok fixture produces zero expired/warning entries" {
  run "$SCRIPT" --config "$FIXTURES/all_ok.json" --warning-days 14 --format json --now "$NOW"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '.expired | length')" -eq 0 ]
  [ "$(echo "$output" | jq '.warning | length')" -eq 0 ]
  [ "$(echo "$output" | jq '.ok | length')" -eq 2 ]
}

@test "exit code is 1 when there are expired secrets (CI gating)" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --format markdown --now "$NOW"
  [ "$status" -eq 1 ]
}

@test "exit code is 0 when nothing is expired" {
  run "$SCRIPT" --config "$FIXTURES/all_ok.json" --warning-days 14 --format markdown --now "$NOW"
  [ "$status" -eq 0 ]
}

@test "configurable warning window expands warning bucket" {
  # With a 365-day window, all non-expired secrets fall into warning.
  run "$SCRIPT" --config "$FIXTURES/all_ok.json" --warning-days 365 --format json --now "$NOW"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '.warning | length')" -eq 2 ]
  [ "$(echo "$output" | jq '.ok | length')" -eq 0 ]
}

@test "rejects invalid --now date" {
  run "$SCRIPT" --config "$FIXTURES/all_ok.json" --now "not-a-date"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]]
}

@test "rejects unknown --format" {
  run "$SCRIPT" --config "$FIXTURES/all_ok.json" --format yaml --now "$NOW"
  [ "$status" -ne 0 ]
  [[ "$output" == *"format"* ]]
}
