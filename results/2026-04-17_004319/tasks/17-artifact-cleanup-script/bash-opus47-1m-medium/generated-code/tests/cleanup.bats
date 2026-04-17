#!/usr/bin/env bats

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../cleanup.sh"
    FIXTURE="$BATS_TEST_DIRNAME/fixtures/basic.tsv"
    NOW="2026-04-17T00:00:00Z"
}

@test "shows usage when no args" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "errors when input file missing" {
    run "$SCRIPT" --input /nonexistent --now "$NOW"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "no policies: keeps everything" {
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Retained: 5"* ]]
    [[ "$output" == *"Deleted: 0"* ]]
    [[ "$output" == *"Space reclaimed: 0"* ]]
}

@test "max-age-days deletes old artifacts" {
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --max-age-days 30 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: artifact-old"* ]]
    [[ "$output" == *"DELETE: artifact-mid"* ]]
    [[ "$output" == *"Deleted: 2"* ]]
    [[ "$output" == *"Retained: 3"* ]]
    [[ "$output" == *"Space reclaimed: 3145728"* ]]
}

@test "keep-latest-n per workflow" {
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --keep-latest 1 --dry-run
    [ "$status" -eq 0 ]
    # Workflow 100: keep artifact-mid (newer), delete artifact-old
    # Workflow 101: keep artifact-newest, delete artifact-new, artifact-newer
    [[ "$output" == *"DELETE: artifact-old"* ]]
    [[ "$output" == *"DELETE: artifact-new"* ]]
    [[ "$output" == *"DELETE: artifact-newer"* ]]
    [[ "$output" == *"Deleted: 3"* ]]
    [[ "$output" == *"Retained: 2"* ]]
}

@test "max-total-size deletes oldest first" {
    # Total = 1048576+2097152+512000+256000+128000 = 4041728
    # Limit 1000000: need to delete until <= 1000000
    # Oldest first: remove 1048576 (old), 2097152 (mid) => remaining 896000 <= 1000000
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --max-total-size 1000000 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: artifact-old"* ]]
    [[ "$output" == *"DELETE: artifact-mid"* ]]
    [[ "$output" == *"Deleted: 2"* ]]
}

@test "dry-run mode announced" {
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --max-age-days 30 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: dry-run"* ]]
}

@test "actual mode announced" {
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --max-age-days 30
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: execute"* ]]
}

@test "combined policies apply union" {
    # keep-latest 1 marks old, new, newer for deletion
    # max-age 30 also marks old, mid
    # Union: old, new, newer, mid deleted; only newest retained
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --max-age-days 30 --keep-latest 1 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted: 4"* ]]
    [[ "$output" == *"Retained: 1"* ]]
}

@test "rejects negative max-age" {
    run "$SCRIPT" --input "$FIXTURE" --now "$NOW" --max-age-days -1
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid"* ]] || [[ "$output" == *"must be"* ]]
}
