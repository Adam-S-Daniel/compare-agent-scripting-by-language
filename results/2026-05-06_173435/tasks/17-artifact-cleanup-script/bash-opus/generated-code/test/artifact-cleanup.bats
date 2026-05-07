#!/usr/bin/env bats

# Test suite for artifact-cleanup.sh

SCRIPT="$BATS_TEST_DIRNAME/../artifact-cleanup.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
    # Ensure script exists and is executable
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# --- Input validation tests ---

@test "exits with error when no arguments provided" {
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "exits with error when file does not exist" {
    run bash "$SCRIPT" --max-age 7 nonexistent-file.txt
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "exits with error when no retention policy specified" {
    run bash "$SCRIPT" "$FIXTURES/basic-artifacts.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"At least one retention policy"* ]]
}

@test "exits with error for invalid max-age value" {
    run bash "$SCRIPT" --max-age abc "$FIXTURES/basic-artifacts.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"positive integer"* ]]
}

@test "exits with error for unknown option" {
    run bash "$SCRIPT" --bogus "$FIXTURES/basic-artifacts.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- Max age policy tests ---

@test "max-age deletes artifacts older than threshold" {
    # Reference time 1700000000, max-age 3 days = cutoff at 1699741200
    # Artifacts older than 3 days: test-results-2 (5.8d), coverage-report (11.6d)
    # test-results-1 at 1699700000 is 3.47 days old, so also deleted
    run bash "$SCRIPT" --max-age 3 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: test-results-1"* ]]
    [[ "$output" == *"DELETE: test-results-2"* ]]
    [[ "$output" == *"DELETE: coverage-report"* ]]
    [[ "$output" == *"RETAIN: build-logs-1"* ]]
    [[ "$output" == *"RETAIN: build-logs-2"* ]]
}

@test "max-age retains all when none are old enough" {
    # max-age 30 days, all artifacts are < 12 days old
    run bash "$SCRIPT" --max-age 30 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 0"* ]]
    [[ "$output" == *"Artifacts to retain: 5"* ]]
}

@test "max-age summary shows correct counts" {
    run bash "$SCRIPT" --max-age 3 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 3"* ]]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
    [[ "$output" == *"Total artifacts: 5"* ]]
}

@test "max-age summary shows correct space reclaimed" {
    # Deleted: test-results-1 (524288) + test-results-2 (3145728) + coverage-report (5242880) = 8912896
    run bash "$SCRIPT" --max-age 3 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Space reclaimed: 8.50MB"* ]]
}

# --- Keep-latest-N policy tests ---

@test "keep-latest-1 retains only newest per workflow" {
    run bash "$SCRIPT" --keep-latest 1 --reference-time 1700000000 "$FIXTURES/keep-latest-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RETAIN: artifact-a1"* ]]
    [[ "$output" == *"DELETE: artifact-a2"* ]]
    [[ "$output" == *"DELETE: artifact-a3"* ]]
    [[ "$output" == *"RETAIN: artifact-b1"* ]]
    [[ "$output" == *"DELETE: artifact-b2"* ]]
}

@test "keep-latest-2 retains two newest per workflow" {
    run bash "$SCRIPT" --keep-latest 2 --reference-time 1700000000 "$FIXTURES/keep-latest-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RETAIN: artifact-a1"* ]]
    [[ "$output" == *"RETAIN: artifact-a2"* ]]
    [[ "$output" == *"DELETE: artifact-a3"* ]]
    [[ "$output" == *"RETAIN: artifact-b1"* ]]
    [[ "$output" == *"RETAIN: artifact-b2"* ]]
}

@test "keep-latest summary shows correct counts" {
    run bash "$SCRIPT" --keep-latest 1 --reference-time 1700000000 "$FIXTURES/keep-latest-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 3"* ]]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
}

# --- Max total size policy tests ---

@test "max-total-size deletes oldest to fit under limit" {
    # Total: 15000, limit: 10000 -> need to remove 5000+
    # Oldest first: item-oldest (5000) -> total 10000, done
    run bash "$SCRIPT" --max-total-size 10000 --reference-time 1700000000 "$FIXTURES/size-limit-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: item-oldest"* ]]
    [[ "$output" == *"RETAIN: item-newest"* ]]
    [[ "$output" == *"RETAIN: item-new"* ]]
    [[ "$output" == *"RETAIN: item-mid"* ]]
    [[ "$output" == *"RETAIN: item-old"* ]]
}

@test "max-total-size deletes multiple oldest when needed" {
    # Total: 15000, limit: 6000 -> need to remove 9000+
    # Delete oldest (5000) -> 10000, still over
    # Delete next oldest (4000) -> 6000, at limit
    run bash "$SCRIPT" --max-total-size 6000 --reference-time 1700000000 "$FIXTURES/size-limit-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: item-oldest"* ]]
    [[ "$output" == *"DELETE: item-old"* ]]
    [[ "$output" == *"RETAIN: item-newest"* ]]
    [[ "$output" == *"RETAIN: item-new"* ]]
    [[ "$output" == *"RETAIN: item-mid"* ]]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
    [[ "$output" == *"Artifacts to retain: 3"* ]]
}

@test "max-total-size retains all when already under limit" {
    run bash "$SCRIPT" --max-total-size 20000 --reference-time 1700000000 "$FIXTURES/size-limit-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 0"* ]]
    [[ "$output" == *"Artifacts to retain: 5"* ]]
}

# --- Combined policy tests ---

@test "max-age and keep-latest combine correctly" {
    # max-age 3 removes test-results-1, test-results-2, coverage-report
    # keep-latest 1 on remaining: build-logs-1 kept, build-logs-2 deleted
    run bash "$SCRIPT" --max-age 3 --keep-latest 1 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RETAIN: build-logs-1"* ]]
    [[ "$output" == *"DELETE: build-logs-2"* ]]
    [[ "$output" == *"DELETE: test-results-1"* ]]
    [[ "$output" == *"DELETE: test-results-2"* ]]
    [[ "$output" == *"DELETE: coverage-report"* ]]
    [[ "$output" == *"Artifacts to delete: 4"* ]]
    [[ "$output" == *"Artifacts to retain: 1"* ]]
}

# --- Dry-run mode tests ---

@test "dry-run shows DRY RUN in output" {
    run bash "$SCRIPT" --dry-run --max-age 3 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "dry-run still generates full plan" {
    run bash "$SCRIPT" --dry-run --max-age 3 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifact Cleanup Plan"* ]]
    [[ "$output" == *"DELETE:"* ]]
    [[ "$output" == *"RETAIN:"* ]]
    [[ "$output" == *"Summary"* ]]
}

# --- Output format tests ---

@test "output contains plan header" {
    run bash "$SCRIPT" --max-age 30 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Artifact Cleanup Plan ==="* ]]
}

@test "output contains section headers" {
    run bash "$SCRIPT" --max-age 30 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to DELETE"* ]]
    [[ "$output" == *"Artifacts to RETAIN"* ]]
    [[ "$output" == *"Summary"* ]]
}

@test "size formatting shows KB for kilobyte range" {
    # test-results-1 is 524288 bytes = 512KB
    run bash "$SCRIPT" --max-age 1 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"512.00KB"* ]]
}

@test "size formatting shows MB for megabyte range" {
    # build-logs-1 is 1048576 bytes = 1.00MB
    run bash "$SCRIPT" --max-age 30 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.00MB"* ]]
}

@test "execute mode shows EXECUTE in output" {
    run bash "$SCRIPT" --max-age 30 --reference-time 1700000000 "$FIXTURES/basic-artifacts.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: EXECUTE"* ]]
}
