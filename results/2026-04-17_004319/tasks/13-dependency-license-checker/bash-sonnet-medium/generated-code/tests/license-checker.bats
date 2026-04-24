#!/usr/bin/env bats
# tests/license-checker.bats
# TDD tests for the dependency license checker.
# Red/green cycle: each @test was written before its implementation.

SCRIPT="${BATS_TEST_DIRNAME}/../license-checker.sh"
FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"

# ── Test 1 (RED first): script exists and is executable ─────────────────────
@test "license-checker.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── Test 2: shows usage when no arguments provided ───────────────────────────
@test "shows usage on missing required arguments" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--manifest"* ]]
}

# ── Test 3: errors on missing manifest file ───────────────────────────────────
@test "errors when manifest file does not exist" {
    run "$SCRIPT" --manifest /nonexistent/file.json \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

# ── Test 4: parses package.json dependencies ──────────────────────────────────
@test "parses package.json and lists dependencies" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"express"* ]]
    [[ "$output" == *"lodash"* ]]
}

# ── Test 5: parses requirements.txt dependencies ──────────────────────────────
@test "parses requirements.txt and lists dependencies" {
    run "$SCRIPT" --manifest "$FIXTURES/requirements.txt" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"axios"* ]]
    [[ "$output" == *"bsd-lib"* ]]
}

# ── Test 6: marks MIT license as APPROVED ─────────────────────────────────────
@test "marks MIT-licensed package as approved" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"APPROVED"* ]]
    [[ "$output" == *"express"*"MIT"* ]]
}

# ── Test 7: marks GPL-2.0 license as DENIED ───────────────────────────────────
@test "marks GPL-2.0-licensed package as denied" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DENIED"* ]]
    [[ "$output" == *"node-gpl-lib"*"GPL-2.0"* ]]
}

# ── Test 8: marks unknown package as UNKNOWN ──────────────────────────────────
@test "marks package with no license data as unknown" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UNKNOWN"* ]]
    [[ "$output" == *"mystery-pkg"* ]]
}

# ── Test 9: summary line counts match ─────────────────────────────────────────
@test "summary line shows correct approved/denied/unknown counts for package.json" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    # express(MIT)+lodash(MIT)+typescript(Apache-2.0)=3 approved, node-gpl-lib=1 denied, mystery-pkg=1 unknown
    [[ "$output" == *"Summary: 3 approved, 1 denied, 1 unknown"* ]]
}

# ── Test 10: requirements.txt summary ─────────────────────────────────────────
@test "summary line shows correct counts for requirements.txt" {
    run "$SCRIPT" --manifest "$FIXTURES/requirements.txt" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    # axios(MIT)+bsd-lib(BSD-3-Clause)=2 approved, agpl-lib(AGPL-3.0)=1 denied, mystery-pkg2=1 unknown
    [[ "$output" == *"Summary: 2 approved, 1 denied, 1 unknown"* ]]
}

# ── Test 11: --strict flag exits 1 when denied packages exist ─────────────────
@test "strict mode exits 1 when denied packages are present" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json" \
                  --strict
    [ "$status" -eq 1 ]
}

# ── Test 12: --strict flag exits 0 when no denied packages ────────────────────
@test "strict mode exits 0 when no denied packages are present" {
    run "$SCRIPT" --manifest "$FIXTURES/approved-only.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json" \
                  --strict
    [ "$status" -eq 0 ]
    [[ "$output" == *"Summary: 3 approved, 0 denied, 0 unknown"* ]]
}

# ── Test 13: report header contains manifest path ─────────────────────────────
@test "report header identifies the manifest file" {
    run "$SCRIPT" --manifest "$FIXTURES/package.json" \
                  --config "$FIXTURES/license-config.json" \
                  --mock-db "$FIXTURES/mock-licenses.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dependency License Compliance Report"* ]]
    [[ "$output" == *"package.json"* ]]
}

# ── Test 14: rejects unsupported manifest formats ─────────────────────────────
@test "errors on unsupported manifest file type" {
    local tmpfile
    tmpfile=$(mktemp --suffix=.toml)
    echo "name = 'foo'" > "$tmpfile"
    run "$SCRIPT" --manifest "$tmpfile" \
                  --config "$FIXTURES/license-config.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"unsupported"* ]]
    rm -f "$tmpfile"
}
