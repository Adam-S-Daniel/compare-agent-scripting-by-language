#!/usr/bin/env bats
# TDD tests for artifact_cleanup.sh
# Red/green cycle: each test written before the implementation that makes it pass.
# Reference date 2026-04-20 is fixed for deterministic age calculations.

SCRIPT="${BATS_TEST_DIRNAME}/../artifact_cleanup.sh"
REF_DATE="2026-04-20"

setup() {
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# --- RED 1: argument validation ---

@test "exits with error when --artifacts is missing" {
  run bash "$SCRIPT" --policy /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"--artifacts is required"* ]]
}

@test "exits with error when --policy is missing" {
  run bash "$SCRIPT" --artifacts /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"--policy is required"* ]]
}

@test "exits with error when artifacts file does not exist" {
  echo '{}' > "$TMP_DIR/policy.json"
  run bash "$SCRIPT" --artifacts /nonexistent/file.json --policy "$TMP_DIR/policy.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# --- RED 2: max_age_days policy ---
# Fixture: 4 artifacts; artifact-alpha (109 days old) and artifact-beta (78 days old)
# exceed max_age_days=30 and must be deleted.
# space reclaimed = 1048576 + 2097152 = 3145728 bytes

@test "max_age policy deletes artifacts older than threshold" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[
  {"name": "artifact-alpha", "size": 1048576, "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "run-001"},
  {"name": "artifact-beta",  "size": 2097152, "created_at": "2026-02-01T00:00:00Z", "workflow_run_id": "run-001"},
  {"name": "artifact-gamma", "size": 524288,  "created_at": "2026-04-10T00:00:00Z", "workflow_run_id": "run-002"},
  {"name": "artifact-delta", "size": 262144,  "created_at": "2026-04-15T00:00:00Z", "workflow_run_id": "run-002"}
]
EOF
  echo '{"max_age_days": 30}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE: artifact-alpha"* ]]
  [[ "$output" == *"DELETE: artifact-beta"* ]]
  [[ "$output" == *"KEEP"* ]]
  [[ "$output" == *"delete_count=2"* ]]
  [[ "$output" == *"retain_count=2"* ]]
  [[ "$output" == *"space_reclaimed_bytes=3145728"* ]]
}

@test "max_age policy keeps artifacts within threshold" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[
  {"name": "fresh-artifact", "size": 500000, "created_at": "2026-04-18T00:00:00Z", "workflow_run_id": "run-x"}
]
EOF
  echo '{"max_age_days": 30}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"delete_count=0"* ]]
  [[ "$output" == *"retain_count=1"* ]]
}

# --- RED 3: max_total_size_bytes policy ---
# Fixture: 4 artifacts totaling 1050000 bytes > 1000000 limit.
# Delete oldest (artifact-size-a, 400000 bytes) to get under limit.

@test "max_total_size policy deletes oldest artifacts to fit budget" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[
  {"name": "artifact-size-a", "size": 400000, "created_at": "2026-04-01T00:00:00Z", "workflow_run_id": "run-size"},
  {"name": "artifact-size-b", "size": 300000, "created_at": "2026-04-05T00:00:00Z", "workflow_run_id": "run-size"},
  {"name": "artifact-size-c", "size": 200000, "created_at": "2026-04-18T00:00:00Z", "workflow_run_id": "run-size"},
  {"name": "artifact-size-d", "size": 150000, "created_at": "2026-04-19T00:00:00Z", "workflow_run_id": "run-size"}
]
EOF
  echo '{"max_total_size_bytes": 1000000}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE: artifact-size-a"* ]]
  [[ "$output" == *"delete_count=1"* ]]
  [[ "$output" == *"retain_count=3"* ]]
  [[ "$output" == *"space_reclaimed_bytes=400000"* ]]
}

@test "max_total_size policy no-op when already under limit" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[
  {"name": "small-a", "size": 100000, "created_at": "2026-04-10T00:00:00Z", "workflow_run_id": "run-s"},
  {"name": "small-b", "size": 100000, "created_at": "2026-04-15T00:00:00Z", "workflow_run_id": "run-s"}
]
EOF
  echo '{"max_total_size_bytes": 1000000}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"delete_count=0"* ]]
}

# --- RED 4: keep_latest_n per workflow ---
# Fixture: 2 workflows x 3 artifacts each; keep_latest_n=2 deletes oldest from each workflow.

@test "keep_latest_n keeps newest N artifacts per workflow run" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[
  {"name": "alpha-1", "size": 100000, "created_at": "2026-04-01T00:00:00Z", "workflow_run_id": "wf-alpha"},
  {"name": "alpha-2", "size": 100000, "created_at": "2026-04-10T00:00:00Z", "workflow_run_id": "wf-alpha"},
  {"name": "alpha-3", "size": 100000, "created_at": "2026-04-18T00:00:00Z", "workflow_run_id": "wf-alpha"},
  {"name": "beta-1",  "size": 150000, "created_at": "2026-04-02T00:00:00Z", "workflow_run_id": "wf-beta"},
  {"name": "beta-2",  "size": 150000, "created_at": "2026-04-11T00:00:00Z", "workflow_run_id": "wf-beta"},
  {"name": "beta-3",  "size": 150000, "created_at": "2026-04-19T00:00:00Z", "workflow_run_id": "wf-beta"}
]
EOF
  echo '{"keep_latest_n": 2}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE: alpha-1"* ]]
  [[ "$output" == *"DELETE: beta-1"* ]]
  [[ "$output" == *"delete_count=2"* ]]
  [[ "$output" == *"retain_count=4"* ]]
}

# --- RED 5: dry-run mode ---

@test "dry_run mode shows DRY RUN header in output" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[{"name": "old-art", "size": 1000000, "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "run-x"}]
EOF
  echo '{"max_age_days": 30}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "non-dry-run mode shows LIVE RUN header in output" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[{"name": "old-art", "size": 1000000, "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "run-x"}]
EOF
  echo '{"max_age_days": 30}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"LIVE RUN"* ]]
}

# --- RED 6: combined policies ---
# max_age removes combined-a (109 days old).
# keep_latest_n=2 for wf-x removes combined-b (3rd newest after combined-a gone).
# Result: 2 deleted, 3 retained.

@test "combined max_age and keep_latest_n policies applied correctly" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[
  {"name": "combined-a", "size": 300000, "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "wf-x"},
  {"name": "combined-b", "size": 100000, "created_at": "2026-04-05T00:00:00Z", "workflow_run_id": "wf-x"},
  {"name": "combined-c", "size": 80000,  "created_at": "2026-04-15T00:00:00Z", "workflow_run_id": "wf-x"},
  {"name": "combined-d", "size": 60000,  "created_at": "2026-04-18T00:00:00Z", "workflow_run_id": "wf-x"},
  {"name": "combined-e", "size": 50000,  "created_at": "2026-04-10T00:00:00Z", "workflow_run_id": "wf-y"}
]
EOF
  echo '{"max_age_days": 30, "keep_latest_n": 2}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE: combined-a"* ]]
  [[ "$output" == *"DELETE: combined-b"* ]]
  [[ "$output" == *"delete_count=2"* ]]
  [[ "$output" == *"retain_count=3"* ]]
}

# --- RED 7: summary fields ---

@test "summary contains all required fields" {
  cat > "$TMP_DIR/artifacts.json" << 'EOF'
[{"name": "art-1", "size": 500000, "created_at": "2026-04-10T00:00:00Z", "workflow_run_id": "r1"}]
EOF
  echo '{}' > "$TMP_DIR/policy.json"

  run bash "$SCRIPT" --artifacts "$TMP_DIR/artifacts.json" --policy "$TMP_DIR/policy.json" \
    --reference-date "$REF_DATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"total_artifacts="* ]]
  [[ "$output" == *"delete_count="* ]]
  [[ "$output" == *"retain_count="* ]]
  [[ "$output" == *"space_reclaimed_bytes="* ]]
  [[ "$output" == *"space_retained_bytes="* ]]
}

# --- RED 8: workflow structure tests ---

@test "workflow file exists at expected path" {
  [ -f "${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml" ]
}

@test "workflow file references artifact_cleanup.sh script" {
  local wf="${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
  [[ "$(cat "$wf")" == *"artifact_cleanup.sh"* ]]
}

@test "workflow file contains push trigger" {
  local wf="${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
  [[ "$(cat "$wf")" == *"push"* ]]
}

@test "workflow file contains workflow_dispatch trigger" {
  local wf="${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
  [[ "$(cat "$wf")" == *"workflow_dispatch"* ]]
}

@test "actionlint passes on workflow file" {
  run actionlint "${BATS_TEST_DIRNAME}/../.github/workflows/artifact-cleanup-script.yml"
  [ "$status" -eq 0 ]
}
