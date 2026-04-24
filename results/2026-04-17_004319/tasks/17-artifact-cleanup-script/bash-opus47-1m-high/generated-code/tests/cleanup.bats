#!/usr/bin/env bats

# Tests for artifact-cleanup.sh. Built with TDD: each test
# was added before the corresponding implementation.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../artifact-cleanup.sh"
    FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR"
}

# --- basic invocation ---------------------------------------------------

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "script shows usage when run with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--max-age-days"* ]]
    [[ "$output" == *"--max-total-size"* ]]
    [[ "$output" == *"--keep-latest"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "script fails with clear error when input file is missing" {
    run "$SCRIPT" --input /does/not/exist.json
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* || "$output" == *"Error"* ]]
}

@test "script fails when input is not valid JSON" {
    echo "not json" > "$TMPDIR/bad.json"
    run "$SCRIPT" --input "$TMPDIR/bad.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* || "$output" == *"invalid"* ]]
}

# --- max-age retention policy ------------------------------------------

@test "max-age: artifacts older than cutoff are marked for deletion" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    # old-artifact (created 2026-01-01) should be deleted
    [[ "$output" == *"DELETE"*"old-artifact"* ]]
    # fresh-artifact (created 2026-04-18) should be retained
    [[ "$output" == *"KEEP"*"fresh-artifact"* ]]
}

@test "max-age: no artifacts deleted when all are within age limit" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 3650 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted: 0"* ]]
}

# --- max-total-size retention policy -----------------------------------

@test "max-total-size: largest/oldest artifacts deleted until under budget" {
    # fixture has total 1500 MB; budget 800 MB forces deletion of oldest first
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-total-size 800MB \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE"*"old-artifact"* ]]
}

# --- keep-latest-N per workflow ----------------------------------------

@test "keep-latest: only N newest per workflow are retained" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --keep-latest 1 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    # workflow-A has two artifacts; older one should be deleted
    [[ "$output" == *"DELETE"*"old-artifact"* ]]
    # workflow-B has one artifact; it should be kept
    [[ "$output" == *"KEEP"*"workflow-b-only"* ]]
}

# --- summary output ----------------------------------------------------

@test "summary includes total space reclaimed in bytes" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Space reclaimed"* ]]
}

@test "summary includes counts of deleted and retained" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted:"* ]]
    [[ "$output" == *"Retained:"* ]]
}

# --- dry-run vs real deletion ------------------------------------------

@test "dry-run prints DRY-RUN banner" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "non-dry-run does NOT print DRY-RUN banner" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19
    [ "$status" -eq 0 ]
    [[ "$output" != *"DRY-RUN"* ]]
    [[ "$output" == *"DELETED"* || "$output" == *"Deleted:"* ]]
}

# --- combined policies -------------------------------------------------

@test "multiple policies combine (age + keep-latest)" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --keep-latest 1 \
                  --now 2026-04-19 \
                  --dry-run
    [ "$status" -eq 0 ]
    # anything matching ANY policy-for-deletion is deleted
    [[ "$output" == *"DELETE"*"old-artifact"* ]]
}

# --- JSON output mode --------------------------------------------------

@test "JSON output mode emits parseable JSON plan" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19 \
                  --dry-run \
                  --json
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.summary.deleted_count' >/dev/null
    echo "$output" | jq -e '.summary.retained_count' >/dev/null
    echo "$output" | jq -e '.summary.space_reclaimed_bytes' >/dev/null
    echo "$output" | jq -e '.plan' >/dev/null
}

@test "JSON output: space_reclaimed_bytes equals sum of deleted sizes" {
    run "$SCRIPT" --input "$FIXTURES/unit-test-artifacts.json" \
                  --max-age-days 30 \
                  --now 2026-04-19 \
                  --dry-run \
                  --json
    [ "$status" -eq 0 ]
    reclaimed="$(echo "$output" | jq '.summary.space_reclaimed_bytes')"
    sum="$(echo "$output" | jq '[.plan[] | select(.action=="DELETE") | .size_bytes] | add // 0')"
    [ "$reclaimed" = "$sum" ]
}
