#!/usr/bin/env bats
# Tests for secret-rotation-validator.sh
# TDD approach: tests written first, then implementation added to make them pass.
# Reference date 2024-03-15 used throughout for deterministic results.

SCRIPT="$BATS_TEST_DIRNAME/../secret-rotation-validator.sh"
FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

# ── RED phase 1: script existence ────────────────────────────────────────────
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── RED phase 2: basic invocation ─────────────────────────────────────────────
@test "shows usage when run with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--config"* ]]
}

@test "exits non-zero without --config" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--config"* ]] || [[ "$output" == *"required"* ]]
}

@test "exits non-zero when config file does not exist" {
    run "$SCRIPT" --config /nonexistent/path.json
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such"* ]]
}

# ── RED phase 3: expired secret detection ─────────────────────────────────────
# fixtures/secrets-mixed.json contains:
#   EXPIRED_SECRET: last_rotated=2024-01-01, rotation_days=30 → expires 2024-01-31
#     days_remaining=-44 at ref-date 2024-03-15 → EXPIRED
@test "EXPIRED_SECRET is classified as expired in markdown output" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXPIRED_SECRET"* ]]
    # Must appear in the EXPIRED section (before WARNING section)
    expired_line=$(echo "$output" | grep -n "EXPIRED_SECRET" | head -1 | cut -d: -f1)
    warning_line=$(echo "$output" | grep -n "## WARNING" | head -1 | cut -d: -f1)
    [ -n "$expired_line" ]
    [ -n "$warning_line" ]
    [ "$expired_line" -lt "$warning_line" ]
}

@test "markdown output contains expiry date 2024-01-31 for EXPIRED_SECRET" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"2024-01-31"* ]]
}

@test "markdown output shows 44 days overdue for EXPIRED_SECRET" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"44"* ]]
}

# ── RED phase 4: warning secret detection ─────────────────────────────────────
# WARNING_SECRET: last_rotated=2024-02-01, rotation_days=45 → expires 2024-03-17
#   days_remaining=2 at ref-date 2024-03-15 → WARNING (2 <= warning_days=14)
@test "WARNING_SECRET is classified as warning in markdown output" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING_SECRET"* ]]
    # Must appear in WARNING section
    warning_section_line=$(echo "$output" | grep -n "## WARNING" | head -1 | cut -d: -f1)
    ok_section_line=$(echo "$output" | grep -n "## OK" | head -1 | cut -d: -f1)
    warning_secret_line=$(echo "$output" | grep -n "WARNING_SECRET" | head -1 | cut -d: -f1)
    [ -n "$warning_section_line" ]
    [ "$warning_secret_line" -gt "$warning_section_line" ]
    [ "$warning_secret_line" -lt "$ok_section_line" ]
}

@test "markdown output contains expiry date 2024-03-17 for WARNING_SECRET" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"2024-03-17"* ]]
}

# ── RED phase 5: ok secret detection ──────────────────────────────────────────
# OK_SECRET: last_rotated=2024-03-01, rotation_days=90 → expires 2024-05-30
#   days_remaining=76 at ref-date 2024-03-15 → OK (76 > 14)
@test "OK_SECRET is classified as ok in markdown output" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK_SECRET"* ]]
    ok_section_line=$(echo "$output" | grep -n "## OK" | head -1 | cut -d: -f1)
    ok_secret_line=$(echo "$output" | grep -n "OK_SECRET" | head -1 | cut -d: -f1)
    [ -n "$ok_section_line" ]
    [ "$ok_secret_line" -gt "$ok_section_line" ]
}

@test "markdown output contains expiry date 2024-05-30 for OK_SECRET" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"2024-05-30"* ]]
}

# ── RED phase 6: markdown format structure ─────────────────────────────────────
@test "markdown output has EXPIRED WARNING and OK sections" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"## EXPIRED"* ]]
    [[ "$output" == *"## WARNING"* ]]
    [[ "$output" == *"## OK"* ]]
}

@test "markdown output has summary line with counts" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    # Should have summary: 1 expired, 1 warning, 1 ok
    [[ "$output" == *"1 expired"* ]]
    [[ "$output" == *"1 warning"* ]]
    [[ "$output" == *"1 ok"* ]]
}

@test "markdown output contains required-by services" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"service-a"* ]]
    [[ "$output" == *"service-b"* ]]
    [[ "$output" == *"service-d"* ]]
}

# ── RED phase 7: JSON output format ───────────────────────────────────────────
@test "JSON output is valid JSON" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}

@test "JSON output has expired WARNING_SECRET in warning array" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    warning_name=$(echo "$output" | jq -r '.notifications.warning[0].name')
    [ "$warning_name" = "WARNING_SECRET" ]
}

@test "JSON output EXPIRED_SECRET has correct days_remaining" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    days=$(echo "$output" | jq -r '.notifications.expired[0].days_remaining')
    [ "$days" -lt 0 ]
    # Should be -44 (expired 44 days ago)
    [ "$days" -eq -44 ]
}

@test "JSON output has correct urgency fields" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    expired_urgency=$(echo "$output" | jq -r '.notifications.expired[0].urgency')
    warning_urgency=$(echo "$output" | jq -r '.notifications.warning[0].urgency')
    ok_urgency=$(echo "$output" | jq -r '.notifications.ok[0].urgency')
    [ "$expired_urgency" = "expired" ]
    [ "$warning_urgency" = "warning" ]
    [ "$ok_urgency" = "ok" ]
}

@test "JSON output summary counts are correct" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    expired_count=$(echo "$output" | jq -r '.summary.expired')
    warning_count=$(echo "$output" | jq -r '.summary.warning')
    ok_count=$(echo "$output" | jq -r '.summary.ok')
    [ "$expired_count" -eq 1 ]
    [ "$warning_count" -eq 1 ]
    [ "$ok_count" -eq 1 ]
}

# ── RED phase 8: configurable warning window ───────────────────────────────────
# WARNING_SECRET has 2 days remaining. With warning_days=1, it should be OK.
@test "warning window override: 2-day secret is OK with --warning-days 1" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --warning-days 1 \
                  --format json
    [ "$status" -eq 0 ]
    # With warning_days=1, WARNING_SECRET (2 days remaining) should move to ok
    ok_count=$(echo "$output" | jq -r '.summary.ok')
    [ "$ok_count" -eq 2 ]
    warning_count=$(echo "$output" | jq -r '.summary.warning')
    [ "$warning_count" -eq 0 ]
}

@test "warning window override: 2-day secret is WARNING with --warning-days 30" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --warning-days 30 \
                  --format json
    [ "$status" -eq 0 ]
    warning_count=$(echo "$output" | jq -r '.summary.warning')
    [ "$warning_count" -eq 1 ]
}

# ── RED phase 9: all-expired fixture ──────────────────────────────────────────
@test "all-expired fixture: all secrets classified as expired" {
    run "$SCRIPT" --config "$FIXTURES/secrets-expired.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    expired_count=$(echo "$output" | jq -r '.summary.expired')
    warning_count=$(echo "$output" | jq -r '.summary.warning')
    ok_count=$(echo "$output" | jq -r '.summary.ok')
    [ "$expired_count" -gt 0 ]
    [ "$warning_count" -eq 0 ]
    [ "$ok_count" -eq 0 ]
}

# ── RED phase 10: all-ok fixture ───────────────────────────────────────────────
@test "all-ok fixture: all secrets classified as ok" {
    run "$SCRIPT" --config "$FIXTURES/secrets-ok.json" \
                  --date 2024-03-15 \
                  --format json
    [ "$status" -eq 0 ]
    expired_count=$(echo "$output" | jq -r '.summary.expired')
    warning_count=$(echo "$output" | jq -r '.summary.warning')
    ok_count=$(echo "$output" | jq -r '.summary.ok')
    [ "$expired_count" -eq 0 ]
    [ "$warning_count" -eq 0 ]
    [ "$ok_count" -gt 0 ]
}

# ── RED phase 11: invalid format ───────────────────────────────────────────────
@test "exits non-zero for unknown output format" {
    run "$SCRIPT" --config "$FIXTURES/secrets-mixed.json" \
                  --date 2024-03-15 \
                  --format xml
    [ "$status" -ne 0 ]
    [[ "$output" == *"xml"* ]] || [[ "$output" == *"format"* ]]
}

# ── Workflow structure tests ───────────────────────────────────────────────────
@test "GitHub Actions workflow file exists" {
    [ -f "$BATS_TEST_DIRNAME/../.github/workflows/secret-rotation-validator.yml" ]
}

@test "workflow has push trigger" {
    local wf="$BATS_TEST_DIRNAME/../.github/workflows/secret-rotation-validator.yml"
    grep -q "push" "$wf"
}

@test "workflow references the validator script" {
    local wf="$BATS_TEST_DIRNAME/../.github/workflows/secret-rotation-validator.yml"
    grep -q "secret-rotation-validator.sh" "$wf"
}

@test "workflow references fixtures directory" {
    local wf="$BATS_TEST_DIRNAME/../.github/workflows/secret-rotation-validator.yml"
    grep -q "fixtures" "$wf"
}

@test "actionlint passes on workflow file" {
    run actionlint "$BATS_TEST_DIRNAME/../.github/workflows/secret-rotation-validator.yml"
    [ "$status" -eq 0 ]
}

@test "shellcheck passes on the main script" {
    run shellcheck "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "bash syntax check passes on the main script" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}
