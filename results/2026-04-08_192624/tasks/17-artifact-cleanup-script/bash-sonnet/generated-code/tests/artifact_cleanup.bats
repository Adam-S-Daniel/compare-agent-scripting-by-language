#!/usr/bin/env bats
# Tests for artifact_cleanup.sh using bats-core
# TDD approach: tests written first, then implementation added to make them pass

# --- Setup / Teardown ---

setup() {
    # Create a temp directory for test files
    TEST_TEMP=$(mktemp -d)
    SCRIPT="$BATS_TEST_DIRNAME/../artifact_cleanup.sh"
    chmod +x "$SCRIPT"

    # Fixed reference epoch for deterministic age calculations.
    # 9999999999 is far in the future; old epochs will always be "old".
    REFDATE=9999999999
}

teardown() {
    rm -rf "$TEST_TEMP"
}

# Helper: write a CSV fixture file
write_fixture() {
    local file="$1"
    shift
    printf 'name,size_bytes,created_epoch,workflow_run_id\n' > "$file"
    # Each remaining arg is one CSV data row
    for row in "$@"; do
        printf '%s\n' "$row" >> "$file"
    done
}

# -----------------------------------------------------------------------
# TEST 1: max-age policy
# Artifacts older than --max-age days should be marked DELETE.
# -----------------------------------------------------------------------
@test "max-age policy: old artifact is deleted, new artifact retained" {
    # old-artifact created at epoch 1000000000 (~2001), new at 9999999000 (~1 second ago)
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "old-artifact,1048576,1000000000,run-001" \
        "new-artifact,2097152,9999999000,run-001"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-age 30 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE old-artifact"* ]]
    [[ "$output" == *"RETAIN new-artifact"* ]]
    [[ "$output" == *"space_reclaimed=1048576"* ]]
}

@test "max-age policy: summary counts are correct" {
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "old-artifact,1048576,1000000000,run-001" \
        "new-artifact,2097152,9999999000,run-001"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-age 30 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"total=2"* ]]
    [[ "$output" == *"retained=1"* ]]
    [[ "$output" == *"deleted=1"* ]]
}

# -----------------------------------------------------------------------
# TEST 2: keep-latest-N policy
# Within each workflow_run_id group keep only the N newest artifacts;
# delete the rest.
# -----------------------------------------------------------------------
@test "keep-latest-N policy: oldest artifact in group is deleted" {
    # Three artifacts in run-001, keep latest 2 → artifact-v1 (oldest) deleted
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "artifact-v1,524288,1000000000,run-001" \
        "artifact-v2,524288,1000001000,run-001" \
        "artifact-v3,524288,1000002000,run-001"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --keep-latest 2 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE artifact-v1"* ]]
    [[ "$output" == *"RETAIN artifact-v2"* ]]
    [[ "$output" == *"RETAIN artifact-v3"* ]]
    [[ "$output" == *"space_reclaimed=524288"* ]]
}

@test "keep-latest-N policy: different workflow runs are independent" {
    # Two artifacts per run, keep latest 1 → oldest in each run deleted
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "run-a-old,262144,1000000000,run-a" \
        "run-a-new,262144,1000001000,run-a" \
        "run-b-old,262144,1000000000,run-b" \
        "run-b-new,262144,1000001000,run-b"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --keep-latest 1 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE run-a-old"* ]]
    [[ "$output" == *"RETAIN run-a-new"* ]]
    [[ "$output" == *"DELETE run-b-old"* ]]
    [[ "$output" == *"RETAIN run-b-new"* ]]
    [[ "$output" == *"space_reclaimed=524288"* ]]
}

# -----------------------------------------------------------------------
# TEST 3: max-total-size policy
# If the total size of artifacts exceeds the limit, delete oldest first
# until total falls at or below the limit.
# -----------------------------------------------------------------------
@test "max-total-size policy: oldest artifact deleted when size exceeded" {
    # Three 3 MB artifacts, total=9 MB; limit=6 MB → delete artifact-a (oldest, 3 MB)
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "artifact-a,3145728,1000000000,run-001" \
        "artifact-b,3145728,1000001000,run-002" \
        "artifact-c,3145728,1000002000,run-003"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-total-size 6291456 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE artifact-a"* ]]
    [[ "$output" == *"RETAIN artifact-b"* ]]
    [[ "$output" == *"RETAIN artifact-c"* ]]
    [[ "$output" == *"space_reclaimed=3145728"* ]]
}

@test "max-total-size policy: no deletion when under limit" {
    # Total=6 MB, limit=6 MB → nothing deleted
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "artifact-a,3145728,1000000000,run-001" \
        "artifact-b,3145728,1000001000,run-002"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-total-size 6291456 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" != *"DELETE"* ]]
    [[ "$output" == *"space_reclaimed=0"* ]]
}

# -----------------------------------------------------------------------
# TEST 4: combined policies (max-age + keep-latest)
# -----------------------------------------------------------------------
@test "combined policies: max-age and keep-latest applied together" {
    # old-v1 and old-v2: very old → deleted by max-age
    # new-v1, new-v2, new-v3: recent; keep-latest=2 → new-v1 deleted
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "old-v1,1048576,1000000000,run-001" \
        "old-v2,1048576,1000001000,run-001" \
        "new-v1,1048576,9999998000,run-002" \
        "new-v2,1048576,9999999000,run-002" \
        "new-v3,1048576,9999999500,run-002"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-age 30 \
        --keep-latest 2 \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE old-v1"* ]]
    [[ "$output" == *"DELETE old-v2"* ]]
    [[ "$output" == *"DELETE new-v1"* ]]
    [[ "$output" == *"RETAIN new-v2"* ]]
    [[ "$output" == *"RETAIN new-v3"* ]]
    [[ "$output" == *"space_reclaimed=3145728"* ]]
}

# -----------------------------------------------------------------------
# TEST 5: dry-run mode
# With --dry-run the output must indicate no real deletion occurs.
# -----------------------------------------------------------------------
@test "dry-run mode: output includes DRY-RUN header" {
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "old-artifact,1048576,1000000000,run-001" \
        "new-artifact,2097152,9999999000,run-001"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-age 30 \
        --reference-date "$REFDATE" \
        --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN MODE"* ]]
}

@test "dry-run mode: still reports what would be deleted" {
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "old-artifact,1048576,1000000000,run-001" \
        "new-artifact,2097152,9999999000,run-001"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --max-age 30 \
        --reference-date "$REFDATE" \
        --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE old-artifact"* ]]
    [[ "$output" == *"RETAIN new-artifact"* ]]
    [[ "$output" == *"space_reclaimed=1048576"* ]]
}

# -----------------------------------------------------------------------
# TEST 6: error handling
# -----------------------------------------------------------------------
@test "error: missing --artifacts flag exits non-zero" {
    run "$SCRIPT" --max-age 30
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "error: non-existent artifact file exits non-zero" {
    run "$SCRIPT" --artifacts /nonexistent/path.csv --max-age 30
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "no policies specified: all artifacts retained" {
    write_fixture "$TEST_TEMP/artifacts.csv" \
        "artifact-a,1048576,1000000000,run-001" \
        "artifact-b,2097152,1000001000,run-002"

    run "$SCRIPT" \
        --artifacts "$TEST_TEMP/artifacts.csv" \
        --reference-date "$REFDATE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"RETAIN artifact-a"* ]]
    [[ "$output" == *"RETAIN artifact-b"* ]]
    [[ "$output" == *"space_reclaimed=0"* ]]
}
