#!/usr/bin/env bats

# Tests for artifact-cleanup.sh
# TDD approach: tests define expected behavior before implementation exists.
# Red phase: these tests are written before the script exists and will fail initially.

# Resolve paths relative to this test file
SCRIPT="$BATS_TEST_DIRNAME/../artifact-cleanup.sh"
FIXTURES_DIR="$BATS_TEST_DIRNAME/fixtures"
WORKFLOW_FILE="$BATS_TEST_DIRNAME/../.github/workflows/artifact-cleanup-script.yml"

# ── Existence checks ─────────────────────────────────────────────────────────

@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# ── Error handling ────────────────────────────────────────────────────────────

@test "returns non-zero exit when no artifacts file provided" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "returns non-zero exit for nonexistent artifacts file" {
    run "$SCRIPT" /nonexistent/path/artifacts.json
    [ "$status" -ne 0 ]
}

# ── Max-age policy ────────────────────────────────────────────────────────────
# Fixture: 3 artifacts; 2 created in 2020 (clearly >30 days old), 1 in 2099 (always new)
# Expected: 2 deleted, 1 retained, 6291456 bytes reclaimed (5242880 + 1048576)

@test "max-age policy marks 2 of 3 artifacts for deletion" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
}

@test "max-age policy retains 1 artifact" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to retain: 1"* ]]
}

@test "max-age policy shows space reclaimed of 6291456 bytes" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Space reclaimed: 6291456 bytes"* ]]
}

@test "max-age deletion list includes old-artifact-a" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: old-artifact-a"* ]]
}

@test "max-age deletion list includes old-artifact-b" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: old-artifact-b"* ]]
}

@test "max-age deletion does not include new-artifact-c" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" != *"DELETE: new-artifact-c"* ]]
}

# ── Keep-latest-N policy ──────────────────────────────────────────────────────
# Fixture: 6 artifacts; 3 per workflow; keep-latest-n=2 → delete 1 oldest per workflow
# Expected: 2 deleted (wf1-artifact-old + wf2-artifact-old), 4 retained

@test "keep-latest-n=2 marks 2 of 6 artifacts for deletion" {
    run "$SCRIPT" --keep-latest-n 2 "$FIXTURES_DIR/keep-latest-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
}

@test "keep-latest-n=2 retains 4 of 6 artifacts" {
    run "$SCRIPT" --keep-latest-n 2 "$FIXTURES_DIR/keep-latest-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to retain: 4"* ]]
}

@test "keep-latest-n=2 deletes oldest artifact in workflow-1" {
    run "$SCRIPT" --keep-latest-n 2 "$FIXTURES_DIR/keep-latest-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: wf1-artifact-old"* ]]
}

@test "keep-latest-n=2 deletes oldest artifact in workflow-2" {
    run "$SCRIPT" --keep-latest-n 2 "$FIXTURES_DIR/keep-latest-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: wf2-artifact-old"* ]]
}

# ── Max-total-size policy ─────────────────────────────────────────────────────
# Fixture: 4 artifacts × 20 MiB = 80 MiB total; limit = 50 MiB (52428800 bytes)
# Delete oldest first: delete a (→60 MiB, still over), delete b (→40 MiB, under limit)
# Expected: 2 deleted, 2 retained, 41943040 bytes reclaimed

@test "max-total-size deletes 2 oldest artifacts to get under 52428800 bytes" {
    run "$SCRIPT" --max-total-size-bytes 52428800 "$FIXTURES_DIR/max-size-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
}

@test "max-total-size retains 2 artifacts" {
    run "$SCRIPT" --max-total-size-bytes 52428800 "$FIXTURES_DIR/max-size-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
}

@test "max-total-size reclaims 41943040 bytes" {
    run "$SCRIPT" --max-total-size-bytes 52428800 "$FIXTURES_DIR/max-size-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Space reclaimed: 41943040 bytes"* ]]
}

@test "max-total-size deletes size-artifact-a (oldest)" {
    run "$SCRIPT" --max-total-size-bytes 52428800 "$FIXTURES_DIR/max-size-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE: size-artifact-a"* ]]
}

# ── Dry-run mode ──────────────────────────────────────────────────────────────

@test "dry-run mode includes DRY RUN notice in output" {
    run "$SCRIPT" --dry-run --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "dry-run mode still shows the deletion plan with 2 artifacts" {
    run "$SCRIPT" --dry-run --max-age-days 30 "$FIXTURES_DIR/max-age-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 2"* ]]
}

# ── No-deletion case ──────────────────────────────────────────────────────────
# Fixture: 2 artifacts with 2099 creation dates; all within policy
# Expected: 0 deleted, 2 retained, 0 bytes reclaimed

@test "no deletions when all artifacts are within max-age policy" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/no-delete-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to delete: 0"* ]]
}

@test "all 2 artifacts retained when none match deletion policy" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/no-delete-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifacts to retain: 2"* ]]
}

@test "space reclaimed is 0 bytes when no artifacts deleted" {
    run "$SCRIPT" --max-age-days 30 "$FIXTURES_DIR/no-delete-artifacts.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Space reclaimed: 0 bytes"* ]]
}

# ── Workflow structure tests ──────────────────────────────────────────────────

@test "workflow file exists at .github/workflows/artifact-cleanup-script.yml" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "workflow references artifact-cleanup.sh script" {
    grep -q "artifact-cleanup.sh" "$WORKFLOW_FILE"
}

@test "workflow has push trigger" {
    grep -q "push:" "$WORKFLOW_FILE"
}

@test "actionlint passes on workflow file" {
    run actionlint "$WORKFLOW_FILE"
    [ "$status" -eq 0 ]
}
