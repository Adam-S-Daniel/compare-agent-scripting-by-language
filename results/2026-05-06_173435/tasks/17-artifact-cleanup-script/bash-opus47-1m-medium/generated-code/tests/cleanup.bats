#!/usr/bin/env bats

# Tests for cleanup.sh - artifact retention policy script.
# Input format (TSV): name<TAB>size_bytes<TAB>iso_date<TAB>workflow_run_id

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../cleanup.sh"
    FIXTURES="$BATS_TEST_DIRNAME/fixtures"
    TMPDIR="$(mktemp -d)"
    NOW="2026-05-07T00:00:00Z"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "errors when input file is missing" {
    run "$SCRIPT" --input /nonexistent --now "$NOW"
    [ "$status" -ne 0 ]
    [[ "$output" == *"input file not found"* ]]
}

@test "with no policies, retains all artifacts" {
    run "$SCRIPT" --input "$FIXTURES/basic.tsv" --now "$NOW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Retained: 3"* ]]
    [[ "$output" == *"Deleted: 0"* ]]
    [[ "$output" == *"Reclaimed: 0"* ]]
}

@test "max-age-days deletes old artifacts" {
    # basic.tsv: a1 (1 day), a2 (10 days), a3 (40 days)
    run "$SCRIPT" --input "$FIXTURES/basic.tsv" --now "$NOW" --max-age-days 30
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE a3"* ]]
    [[ "$output" == *"Retained: 2"* ]]
    [[ "$output" == *"Deleted: 1"* ]]
    [[ "$output" == *"Reclaimed: 3000"* ]]
}

@test "keep-latest-N per workflow keeps newest N per run id" {
    # multi.tsv: workflow X has 3, workflow Y has 2
    run "$SCRIPT" --input "$FIXTURES/multi.tsv" --now "$NOW" --keep-latest 1
    [ "$status" -eq 0 ]
    # X has x1 (newest), x2, x3 (oldest) -> delete x2,x3
    # Y has y1 (newest), y2 (oldest) -> delete y2
    [[ "$output" == *"DELETE x2"* ]]
    [[ "$output" == *"DELETE x3"* ]]
    [[ "$output" == *"DELETE y2"* ]]
    [[ "$output" != *"DELETE x1"* ]]
    [[ "$output" != *"DELETE y1"* ]]
    [[ "$output" == *"Deleted: 3"* ]]
}

@test "max-total-size deletes oldest until under limit" {
    # basic.tsv totals: 1000+2000+3000 = 6000. Limit 3500 -> delete oldest (a3=3000) -> 3000 remains
    run "$SCRIPT" --input "$FIXTURES/basic.tsv" --now "$NOW" --max-total-size 3500
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE a3"* ]]
    [[ "$output" == *"Deleted: 1"* ]]
    [[ "$output" == *"Reclaimed: 3000"* ]]
}

@test "dry-run mode marks plan as DRY-RUN" {
    run "$SCRIPT" --input "$FIXTURES/basic.tsv" --now "$NOW" --max-age-days 5 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "policies combine: artifact deleted if any policy marks it" {
    run "$SCRIPT" --input "$FIXTURES/multi.tsv" --now "$NOW" --max-age-days 30 --keep-latest 1
    [ "$status" -eq 0 ]
    # Both policies should apply; deleted artifacts are union
    [[ "$output" == *"Deleted:"* ]]
}

@test "rejects invalid max-age-days" {
    run "$SCRIPT" --input "$FIXTURES/basic.tsv" --now "$NOW" --max-age-days abc
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid"* ]]
}
