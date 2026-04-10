#!/usr/bin/env bats
# Tests for artifact-cleanup.sh
# Uses --now to inject a fixed epoch for reproducible results.
# Fixed "now" = 2026-04-10T00:00:00 UTC = epoch 1775952000

SCRIPT="./artifact-cleanup.sh"
# 2026-04-10T00:00:00 UTC
NOW_EPOCH=1775952000

# ── Error handling tests ─────────────────────────────────────────────────────

@test "exits with error when no --input given" {
    run bash "$SCRIPT" --max-age-days 30
    [ "$status" -ne 0 ]
    [[ "$output" == *"--input is required"* ]]
}

@test "exits with error when input file does not exist" {
    run bash "$SCRIPT" --input nonexistent.csv --max-age-days 30
    [ "$status" -ne 0 ]
    [[ "$output" == *"Input file not found"* ]]
}

@test "exits with error when no retention policy given" {
    run bash "$SCRIPT" --input fixtures/basic.csv
    [ "$status" -ne 0 ]
    [[ "$output" == *"At least one retention policy is required"* ]]
}

@test "exits with error for unknown option" {
    run bash "$SCRIPT" --input fixtures/basic.csv --bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "shows help with -h flag" {
    run bash "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# ── Max age policy tests ─────────────────────────────────────────────────────

@test "max-age-days: deletes artifacts older than threshold" {
    # With now=2026-04-10 and max-age=30 days, cutoff is ~2026-03-11
    # old-artifact (2025-01-01) and very-old-artifact (2024-06-15) should be deleted
    # recent-artifact (2026-04-05) should be kept
    run bash "$SCRIPT" --input fixtures/max-age.csv --max-age-days 30 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: old-artifact"* ]]
    [[ "$output" == *"DELETE: very-old-artifact"* ]]
    [[ "$output" == *"KEEP:   recent-artifact"* ]]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
    [[ "$output" == *"Artifacts to retain: 1"* ]]
    [[ "$output" == *"Space reclaimed:    7000000 bytes"* ]]
    [[ "$output" == *"Space retained:     3000000 bytes"* ]]
}

@test "max-age-days: keeps all when none are old enough" {
    # max-age=9999 days — nothing is that old
    run bash "$SCRIPT" --input fixtures/max-age.csv --max-age-days 9999 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 0"* ]]
    [[ "$output" == *"Artifacts to retain: 3"* ]]
}

# ── Keep-latest-N per workflow tests ─────────────────────────────────────────

@test "keep-latest-n: keeps only N newest per workflow" {
    # wf-100 has 4 builds; keep latest 2 → delete build-v1 (Jan) and build-v2 (Feb)
    # wf-200 has 2 tests; keep latest 2 → keep both
    run bash "$SCRIPT" --input fixtures/keep-latest.csv --keep-latest-n 2 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: build-v1"* ]]
    [[ "$output" == *"DELETE: build-v2"* ]]
    [[ "$output" == *"KEEP:   build-v3"* ]]
    [[ "$output" == *"KEEP:   build-v4"* ]]
    [[ "$output" == *"KEEP:   test-v1"* ]]
    [[ "$output" == *"KEEP:   test-v2"* ]]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
    [[ "$output" == *"Artifacts to retain: 4"* ]]
    [[ "$output" == *"Space reclaimed:    2000000 bytes"* ]]
}

@test "keep-latest-n: keep 1 per workflow" {
    run bash "$SCRIPT" --input fixtures/keep-latest.csv --keep-latest-n 1 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    # wf-100: keep build-v4 (newest), delete v1,v2,v3
    # wf-200: keep test-v2 (newest), delete test-v1
    [[ "$output" == *"DELETE: build-v1"* ]]
    [[ "$output" == *"DELETE: build-v2"* ]]
    [[ "$output" == *"DELETE: build-v3"* ]]
    [[ "$output" == *"KEEP:   build-v4"* ]]
    [[ "$output" == *"DELETE: test-v1"* ]]
    [[ "$output" == *"KEEP:   test-v2"* ]]
    [[ "$output" == *"Artifacts to delete: 4"* ]]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
}

# ── Max total size policy tests ──────────────────────────────────────────────

@test "max-total-size: deletes oldest first to fit budget" {
    # Artifacts: small(1M,Jan) medium(3M,Feb) large(5M,Mar) tiny(500K,Apr)
    # Total = 9.5M. Budget = 6M. Need to reclaim 3.5M.
    # Delete oldest first: small(1M) → 8.5M still over; medium(3M) → 5.5M ≤ 6M. Done.
    run bash "$SCRIPT" --input fixtures/max-size.csv --max-total-size-bytes 6000000 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: small-artifact"* ]]
    [[ "$output" == *"DELETE: medium-artifact"* ]]
    [[ "$output" == *"KEEP:   large-artifact"* ]]
    [[ "$output" == *"KEEP:   tiny-artifact"* ]]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
    [[ "$output" == *"Space reclaimed:    4000000 bytes"* ]]
    [[ "$output" == *"Space retained:     5500000 bytes"* ]]
}

@test "max-total-size: keeps all when within budget" {
    run bash "$SCRIPT" --input fixtures/max-size.csv --max-total-size-bytes 99999999 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 0"* ]]
    [[ "$output" == *"Artifacts to retain: 4"* ]]
}

# ── Combined policy tests ────────────────────────────────────────────────────

@test "combined policies: max-age and keep-latest-n together" {
    # now=2026-04-10, max-age=180 days → cutoff ~2025-10-12
    # old-build-1 (2025-06-01) → too old → DELETE
    # old-build-2 (2025-09-01) → too old → DELETE
    # old-test-1 (2025-07-01) → too old → DELETE
    # Remaining: recent-build-1, recent-build-2, recent-test-1, recent-test-2
    # keep-latest-1 per workflow:
    #   wf-100: keep recent-build-2 (Apr), delete recent-build-1 (Mar)
    #   wf-200: keep recent-test-2 (Apr), delete recent-test-1 (Mar)
    run bash "$SCRIPT" --input fixtures/combined-policies.csv --max-age-days 180 --keep-latest-n 1 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: old-build-1"* ]]
    [[ "$output" == *"DELETE: old-build-2"* ]]
    [[ "$output" == *"DELETE: old-test-1"* ]]
    [[ "$output" == *"DELETE: recent-build-1"* ]]
    [[ "$output" == *"DELETE: recent-test-1"* ]]
    [[ "$output" == *"KEEP:   recent-build-2"* ]]
    [[ "$output" == *"KEEP:   recent-test-2"* ]]
    [[ "$output" == *"Artifacts to delete: 5"* ]]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
}

# ── Dry-run mode tests ──────────────────────────────────────────────────────

@test "dry-run mode is shown by default" {
    run bash "$SCRIPT" --input fixtures/basic.csv --max-age-days 30 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "execute mode is shown when --execute is used" {
    run bash "$SCRIPT" --input fixtures/basic.csv --max-age-days 30 --execute --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode: EXECUTE"* ]]
}

# ── Summary output format tests ─────────────────────────────────────────────

@test "output contains expected section headers" {
    run bash "$SCRIPT" --input fixtures/basic.csv --max-age-days 30 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ARTIFACT CLEANUP PLAN"* ]]
    [[ "$output" == *"ARTIFACTS TO DELETE"* ]]
    [[ "$output" == *"ARTIFACTS TO RETAIN"* ]]
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Total artifacts:"* ]]
    [[ "$output" == *"Space reclaimed:"* ]]
}

@test "basic fixture: max-age-days 30 produces correct summary" {
    # now=2026-04-10, max-age=30 → cutoff ~2026-03-11
    # DELETE: build-artifact-1 (Jan 1), build-artifact-2 (Feb 15), test-results-1 (Jan 10)
    # KEEP: build-artifact-3 (Mar 20), test-results-2 (Mar 25), deploy-log-1 (Apr 1)
    run bash "$SCRIPT" --input fixtures/basic.csv --max-age-days 30 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total artifacts:    6"* ]]
    [[ "$output" == *"Artifacts to delete: 3"* ]]
    [[ "$output" == *"Artifacts to retain: 3"* ]]
    [[ "$output" == *"Space reclaimed:    3300000 bytes"* ]]
    [[ "$output" == *"Space retained:     1050000 bytes"* ]]
}
