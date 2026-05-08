#!/usr/bin/env bats

# Tests for cleanup-artifacts.sh
#
# Input format: TSV with columns: name<TAB>size_bytes<TAB>created_epoch<TAB>workflow_run_id
# All tests use --now to make them deterministic (no real wall-clock dependency).

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../cleanup-artifacts.sh"
    TMPDIR_TEST="$(mktemp -d)"
    # NOW pinned to 2026-05-08T00:00:00Z = 1778457600
    NOW=1778457600
    DAY=86400
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ---- Help / arg parsing ----

@test "exits with usage when no input file given" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "errors if input file does not exist" {
    run "$SCRIPT" --input "$TMPDIR_TEST/nope.tsv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such"* ]]
}

# ---- Empty input ----

@test "handles empty input cleanly" {
    : > "$TMPDIR_TEST/empty.tsv"
    run "$SCRIPT" --input "$TMPDIR_TEST/empty.tsv" --now "$NOW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total artifacts: 0"* ]]
    [[ "$output" == *"Retained: 0"* ]]
    [[ "$output" == *"Deleted: 0"* ]]
}

# ---- Max-age policy ----

@test "max-age deletes artifacts older than threshold" {
    # 3 artifacts: 5 days, 10 days, 30 days old; max-age=14 deletes only the 30-day one.
    {
        printf 'old\t100\t%d\twf1\n' $((NOW - 30 * DAY))
        printf 'mid\t200\t%d\twf1\n' $((NOW - 10 * DAY))
        printf 'new\t300\t%d\twf1\n' $((NOW - 5 * DAY))
    } > "$TMPDIR_TEST/in.tsv"

    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW" --max-age 14
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: old"* ]]
    [[ "$output" == *"max_age"* ]]
    [[ "$output" == *"KEEP: mid"* ]]
    [[ "$output" == *"KEEP: new"* ]]
    [[ "$output" == *"Deleted: 1"* ]]
    [[ "$output" == *"Retained: 2"* ]]
    [[ "$output" == *"Space reclaimed: 100"* ]]
}

# ---- Keep-latest-N policy ----

@test "keep-latest-N retains N newest per workflow" {
    # wf1 has 4 artifacts; keep latest 2 -> delete 2 oldest of wf1
    # wf2 has 1 artifact; nothing deleted
    {
        printf 'a1\t10\t%d\twf1\n' $((NOW - 4 * DAY))
        printf 'a2\t20\t%d\twf1\n' $((NOW - 3 * DAY))
        printf 'a3\t30\t%d\twf1\n' $((NOW - 2 * DAY))
        printf 'a4\t40\t%d\twf1\n' $((NOW - 1 * DAY))
        printf 'b1\t50\t%d\twf2\n' $((NOW - 1 * DAY))
    } > "$TMPDIR_TEST/in.tsv"

    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW" --keep-latest 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: a1"* ]]
    [[ "$output" == *"DELETE: a2"* ]]
    [[ "$output" == *"KEEP: a3"* ]]
    [[ "$output" == *"KEEP: a4"* ]]
    [[ "$output" == *"KEEP: b1"* ]]
    [[ "$output" == *"keep_latest"* ]]
    [[ "$output" == *"Deleted: 2"* ]]
    [[ "$output" == *"Retained: 3"* ]]
    [[ "$output" == *"Space reclaimed: 30"* ]]
}

# ---- Max-total-size policy ----

@test "max-total-size deletes oldest until under cap" {
    # 4 artifacts total 1000 bytes; cap at 600 -> delete oldest until <= 600
    # Sizes (oldest->newest): 100, 200, 300, 400. Cumulative newest-first: 400, 700, 900, 1000
    # Keep newest while running sum <= 600: 400 (400 <= 600 keep), +300=700 > 600 stop.
    # So delete a1, a2, a3 (oldest three) and keep a4.
    {
        printf 'a1\t100\t%d\twf1\n' $((NOW - 4 * DAY))
        printf 'a2\t200\t%d\twf1\n' $((NOW - 3 * DAY))
        printf 'a3\t300\t%d\twf1\n' $((NOW - 2 * DAY))
        printf 'a4\t400\t%d\twf1\n' $((NOW - 1 * DAY))
    } > "$TMPDIR_TEST/in.tsv"

    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW" --max-total-size 600
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: a1"* ]]
    [[ "$output" == *"DELETE: a2"* ]]
    [[ "$output" == *"DELETE: a3"* ]]
    [[ "$output" == *"KEEP: a4"* ]]
    [[ "$output" == *"max_total_size"* ]]
    [[ "$output" == *"Space reclaimed: 600"* ]]
}

# ---- Combined policies ----

@test "combined policies apply: age + keep-latest + max-total-size" {
    # 5 artifacts in wf1, sizes 100 each = 500.
    # Ages (days): 30, 20, 10, 5, 1
    # max-age=15 -> delete 30d, 20d via max_age
    # keep-latest=2 from remaining (10d, 5d, 1d) -> delete 10d via keep_latest
    # max-total-size=150 from remaining (5d=100, 1d=100, total 200) -> delete 5d via size
    # Final: keep only 1d. Reclaimed: 400.
    {
        printf 'a30\t100\t%d\twf1\n' $((NOW - 30 * DAY))
        printf 'a20\t100\t%d\twf1\n' $((NOW - 20 * DAY))
        printf 'a10\t100\t%d\twf1\n' $((NOW - 10 * DAY))
        printf 'a5\t100\t%d\twf1\n'  $((NOW -  5 * DAY))
        printf 'a1\t100\t%d\twf1\n'  $((NOW -  1 * DAY))
    } > "$TMPDIR_TEST/in.tsv"

    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW" \
        --max-age 15 --keep-latest 2 --max-total-size 150
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: a30"*"max_age"* ]] || [[ "$output" == *"max_age"* ]]
    [[ "$output" == *"KEEP: a1"* ]]
    [[ "$output" == *"Deleted: 4"* ]]
    [[ "$output" == *"Retained: 1"* ]]
    [[ "$output" == *"Space reclaimed: 400"* ]]
}

# ---- Dry-run ----

@test "dry-run mode is reported" {
    printf 'old\t100\t%d\twf1\n' $((NOW - 30 * DAY)) > "$TMPDIR_TEST/in.tsv"
    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW" --max-age 14 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: dry-run"* ]]
}

@test "non-dry-run reports live mode" {
    printf 'old\t100\t%d\twf1\n' $((NOW - 30 * DAY)) > "$TMPDIR_TEST/in.tsv"
    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW" --max-age 14
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: live"* ]]
}

# ---- Malformed input ----

@test "errors on malformed input row" {
    printf 'just-name-no-tabs\n' > "$TMPDIR_TEST/in.tsv"
    run "$SCRIPT" --input "$TMPDIR_TEST/in.tsv" --now "$NOW"
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed"* ]] || [[ "$output" == *"invalid"* ]]
}
