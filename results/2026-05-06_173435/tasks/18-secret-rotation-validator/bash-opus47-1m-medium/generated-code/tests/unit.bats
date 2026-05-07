#!/usr/bin/env bats
# Unit-style tests that exercise the validator script's pure logic.
# These are NOT used as the official acceptance gate (act-based tests are),
# but they let us drive the script via classic red/green TDD while we develop
# the script logic. Once the script behaves, the act harness validates the
# end-to-end pipeline.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/validate-rotation.sh"
  FIXTURES="$REPO_ROOT/fixtures"
  TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP"
}

# --- syntax & lint gates ------------------------------------------------------

@test "validate-rotation.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "validate-rotation.sh passes bash -n" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "validate-rotation.sh passes shellcheck" {
  run shellcheck "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- behavior -----------------------------------------------------------------

@test "shows usage on --help" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "errors out without --config" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--config"* ]]
}

@test "errors on missing config file" {
  run "$SCRIPT" --config /no/such/file.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "errors on invalid JSON config" {
  echo "not json" > "$TMP/bad.json"
  run "$SCRIPT" --config "$TMP/bad.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid config"* ]] || [[ "$output" == *"secrets"* ]]
}

@test "errors on bad --format" {
  cp "$FIXTURES/all-ok.json" "$TMP/c.json"
  run "$SCRIPT" --config "$TMP/c.json" --format yaml --now 2026-05-07
  [ "$status" -ne 0 ]
  [[ "$output" == *"format"* ]]
}

@test "markdown: classifies expired/warning/ok in mixed fixture" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --now 2026-05-07 --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Secret Rotation Report"* ]]
  [[ "$output" == *"## Expired"* ]]
  [[ "$output" == *"## Warning"* ]]
  [[ "$output" == *"## OK"* ]]
  # OLD_API_KEY is 200 days past rotation in mixed fixture -> expired
  [[ "$output" == *"OLD_API_KEY"* ]]
  # SOON_TOKEN expires in <=14 days -> warning
  [[ "$output" == *"SOON_TOKEN"* ]]
  # FRESH_KEY just rotated -> ok
  [[ "$output" == *"FRESH_KEY"* ]]
}

@test "json: produces grouped object" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --now 2026-05-07 --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.expired | length >= 1' >/dev/null
  echo "$output" | jq -e '.warning | length >= 1' >/dev/null
  echo "$output" | jq -e '.ok      | length >= 1' >/dev/null
  # services must be an array (list of required-by services)
  echo "$output" | jq -e '.expired[0].services | type == "array"' >/dev/null
}

@test "all-ok fixture produces empty expired and warning groups" {
  run "$SCRIPT" --config "$FIXTURES/all-ok.json" --warning-days 14 --now 2026-05-07 --format json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '.expired | length')" -eq 0 ]
  [ "$(echo "$output" | jq '.warning | length')" -eq 0 ]
  [ "$(echo "$output" | jq '.ok | length')" -gt 0 ]
}

@test "warning window is configurable" {
  # With a huge warning window, even healthy secrets should slip into 'warning'.
  run "$SCRIPT" --config "$FIXTURES/all-ok.json" --warning-days 9999 --now 2026-05-07 --format json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '.ok | length')" -eq 0 ]
  [ "$(echo "$output" | jq '.warning | length')" -gt 0 ]
}

@test "--strict exits non-zero when expired secrets exist" {
  run "$SCRIPT" --config "$FIXTURES/mixed.json" --warning-days 14 --now 2026-05-07 --format json --strict
  [ "$status" -eq 1 ]
}

@test "--strict exits zero when no expired secrets" {
  run "$SCRIPT" --config "$FIXTURES/all-ok.json" --warning-days 14 --now 2026-05-07 --format json --strict
  [ "$status" -eq 0 ]
}
