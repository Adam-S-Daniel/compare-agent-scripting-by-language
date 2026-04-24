#!/usr/bin/env bats
# Tests for secret-rotation-validator.sh
# We use a fixed --today date so tests are deterministic regardless of when run.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../secret-rotation-validator.sh"
    FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
    TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "${TMP}"
}

# --- Red 1: script must exist and be executable ----------------------------
@test "script exists and is executable" {
    [ -x "${SCRIPT}" ]
}

# --- Red 2: --help prints usage --------------------------------------------
@test "--help prints usage" {
    run "${SCRIPT}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"--config"* ]]
    [[ "${output}" == *"--format"* ]]
    [[ "${output}" == *"--warning-days"* ]]
}

# --- Red 3: missing --config errors gracefully ------------------------------
@test "missing --config arg errors with non-zero exit" {
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"--config"* ]]
}

# --- Red 4: nonexistent config file errors ----------------------------------
@test "nonexistent config file errors" {
    run "${SCRIPT}" --config /no/such/file.json
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not found"* || "${output}" == *"No such"* ]]
}

# --- Red 5: invalid JSON errors ---------------------------------------------
@test "invalid JSON errors with meaningful message" {
    echo "not-json{" > "${TMP}/bad.json"
    run "${SCRIPT}" --config "${TMP}/bad.json"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"JSON"* || "${output}" == *"parse"* ]]
}

# --- Red 6: classify expired secret in markdown output ----------------------
@test "markdown: classifies expired secret correctly" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format markdown
    [ "${status}" -eq 0 ]
    # api-token rotated 2025-01-01, policy 90d -> expired by Apr 2026
    [[ "${output}" == *"## Expired"* ]]
    [[ "${output}" == *"api-token"* ]]
    [[ "${output}" == *"## Warning"* ]]
    [[ "${output}" == *"## OK"* ]]
}

# --- Red 7: classify warning secret -----------------------------------------
@test "markdown: classifies warning secret correctly" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format markdown
    [ "${status}" -eq 0 ]
    # db-password rotated 2026-01-25, policy 90d -> expires 2026-04-25 -> 6 days -> warning
    [[ "${output}" == *"db-password"* ]]
}

# --- Red 8: classify OK secret ----------------------------------------------
@test "markdown: classifies ok secret correctly" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format markdown
    [ "${status}" -eq 0 ]
    # session-key rotated 2026-04-10, policy 90d -> expires 2026-07-09 -> ok
    [[ "${output}" == *"session-key"* ]]
}

# --- Red 9: markdown is a real table ----------------------------------------
@test "markdown: emits a markdown table with headers and services" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format markdown
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"| Name |"* ]]
    [[ "${output}" == *"| Last Rotated |"* ]]
    [[ "${output}" == *"| Days Until Expiry |"* ]]
    [[ "${output}" == *"| Services |"* ]]
    # Required-by services should appear
    [[ "${output}" == *"web-api"* ]]
    [[ "${output}" == *"billing-svc"* ]]
}

# --- Red 10: JSON output is valid and structured ----------------------------
@test "json: emits valid JSON grouped by urgency" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format json
    [ "${status}" -eq 0 ]
    # Output must be valid JSON
    echo "${output}" | jq . >/dev/null
    # Has expired/warning/ok arrays
    expired_count=$(echo "${output}" | jq '.expired | length')
    warning_count=$(echo "${output}" | jq '.warning | length')
    ok_count=$(echo "${output}" | jq '.ok | length')
    [ "${expired_count}" = "1" ]
    [ "${warning_count}" = "1" ]
    [ "${ok_count}" = "1" ]
}

# --- Red 11: JSON entries have full metadata --------------------------------
@test "json: entries include name, last_rotated, days_until_expiry, services" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format json
    [ "${status}" -eq 0 ]
    expired_name=$(echo "${output}" | jq -r '.expired[0].name')
    expired_days=$(echo "${output}" | jq -r '.expired[0].days_until_expiry')
    expired_services=$(echo "${output}" | jq -r '.expired[0].services | join(",")')
    [ "${expired_name}" = "api-token" ]
    # Negative or 0 days_until_expiry for expired secrets
    [ "${expired_days}" -le 0 ]
    [[ "${expired_services}" == *"web-api"* ]]
}

# --- Red 12: warning-days threshold is configurable -------------------------
@test "warning window is configurable" {
    # With warning-days=1, db-password (6 days out) becomes ok
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 1 --format json
    [ "${status}" -eq 0 ]
    warning_count=$(echo "${output}" | jq '.warning | length')
    ok_count=$(echo "${output}" | jq '.ok | length')
    [ "${warning_count}" = "0" ]
    [ "${ok_count}" = "2" ]
}

# --- Red 13: empty config produces empty groups -----------------------------
@test "empty config produces empty groups" {
    echo "[]" > "${TMP}/empty.json"
    run "${SCRIPT}" --config "${TMP}/empty.json" --format json --today 2026-04-19
    [ "${status}" -eq 0 ]
    [ "$(echo "${output}" | jq '.expired | length')" = "0" ]
    [ "$(echo "${output}" | jq '.warning | length')" = "0" ]
    [ "$(echo "${output}" | jq '.ok | length')" = "0" ]
}

# --- Red 14: invalid format errors ------------------------------------------
@test "invalid --format errors" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" --format yaml
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"format"* ]]
}

# --- Red 15: malformed secret entry errors ----------------------------------
@test "missing required field in entry errors" {
    echo '[{"name":"foo"}]' > "${TMP}/missing.json"
    run "${SCRIPT}" --config "${TMP}/missing.json" --format json --today 2026-04-19
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"required"* || "${output}" == *"missing"* ]]
}

# --- Red 16: exit code reflects urgency -------------------------------------
# Convention: exit 2 if any expired, exit 1 if any warning (and no expired),
# exit 0 if all ok. Useful for CI gates.
@test "exit code 2 when any secret is expired" {
    run "${SCRIPT}" --config "${FIXTURES}/sample.json" \
        --today 2026-04-19 --warning-days 14 --format json --strict
    [ "${status}" -eq 2 ]
}

@test "exit code 1 when only warnings present" {
    cat > "${TMP}/warn.json" <<'EOF'
[
  {"name":"k","last_rotated":"2026-04-10","rotation_policy_days":15,"services":["a"]}
]
EOF
    run "${SCRIPT}" --config "${TMP}/warn.json" \
        --today 2026-04-19 --warning-days 14 --format json --strict
    [ "${status}" -eq 1 ]
}

@test "exit code 0 when all secrets are ok" {
    cat > "${TMP}/ok.json" <<'EOF'
[
  {"name":"k","last_rotated":"2026-04-10","rotation_policy_days":365,"services":["a"]}
]
EOF
    run "${SCRIPT}" --config "${TMP}/ok.json" \
        --today 2026-04-19 --warning-days 14 --format json --strict
    [ "${status}" -eq 0 ]
}
