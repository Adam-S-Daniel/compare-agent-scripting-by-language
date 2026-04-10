#!/usr/bin/env bats
# Tests for artifact_cleanup.sh
# Using red/green TDD: tests were written before implementation.
#
# Artifact data format (CSV):
#   name,size_bytes,created_epoch,workflow_run_id
#
# Retention policies (env vars):
#   MAX_AGE_DAYS     - delete artifacts older than N days
#   MAX_TOTAL_SIZE_B - delete if total size exceeds this (bytes)
#   KEEP_LATEST_N    - keep only N most recent per workflow_run_id
#   DRY_RUN          - if "true", only print plan, don't delete

SCRIPT="$BATS_TEST_DIRNAME/../artifact_cleanup.sh"

# Reference epoch for "today" in tests — fixed so tests are deterministic.
# 2026-04-10 00:00:00 UTC = 1744243200
FIXED_NOW=1744243200

# Helper: create a temp fixture file with given content
make_fixture() {
  local tmpfile
  tmpfile="$(mktemp)"
  printf '%s\n' "$@" > "$tmpfile"
  echo "$tmpfile"
}

# ─── Group 1: Script structure ────────────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script has correct shebang" {
  head -1 "$SCRIPT" | grep -q '^#!/usr/bin/env bash$'
}

@test "script passes bash -n syntax check" {
  bash -n "$SCRIPT"
}

# ─── Group 2: Input parsing ───────────────────────────────────────────────────

@test "script exits 1 with error when no artifact file given" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "script exits 1 when artifact file does not exist" {
  run "$SCRIPT" /nonexistent/path.csv
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "script exits 0 with empty artifact file" {
  local tmpfile
  tmpfile="$(mktemp)"
  printf '' > "$tmpfile"
  run "$SCRIPT" "$tmpfile"
  rm -f "$tmpfile"
  [ "$status" -eq 0 ]
}

# ─── Group 3: Max-age policy ──────────────────────────────────────────────────

@test "max-age policy: artifact older than threshold is marked for deletion" {
  # 40 days ago (older than 30-day limit)
  local old_epoch=$(( FIXED_NOW - 40 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "old-artifact,1048576,${old_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE"* ]]
  [[ "$output" == *"old-artifact"* ]]
}

@test "max-age policy: artifact within threshold is retained" {
  # 10 days ago (within 30-day limit)
  local recent_epoch=$(( FIXED_NOW - 10 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "recent-artifact,1048576,${recent_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEEP"* ]]
  [[ "$output" == *"recent-artifact"* ]]
}

@test "max-age policy: exactly at threshold age is retained" {
  # Exactly 30 days ago — boundary: retain
  local boundary_epoch=$(( FIXED_NOW - 30 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "boundary-artifact,1048576,${boundary_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEEP"* ]]
}

# ─── Group 4: Keep-latest-N policy ───────────────────────────────────────────

@test "keep-latest-N: keeps newest N artifacts per workflow, deletes rest" {
  # 3 artifacts for run-001, keep only 2 newest
  local t1=$(( FIXED_NOW - 5 * 86400 ))   # newest
  local t2=$(( FIXED_NOW - 10 * 86400 ))  # middle
  local t3=$(( FIXED_NOW - 15 * 86400 ))  # oldest — should be deleted
  local fixture
  fixture="$(make_fixture \
    "artifact-a,500000,${t1},run-001" \
    "artifact-b,500000,${t2},run-001" \
    "artifact-c,500000,${t3},run-001")"

  run env NOW="$FIXED_NOW" KEEP_LATEST_N=2 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"artifact-a"*"KEEP"* ]] || [[ "$output" == *"KEEP"*"artifact-a"* ]]
  [[ "$output" == *"artifact-b"*"KEEP"* ]] || [[ "$output" == *"KEEP"*"artifact-b"* ]]
  [[ "$output" == *"artifact-c"*"DELETE"* ]] || [[ "$output" == *"DELETE"*"artifact-c"* ]]
}

@test "keep-latest-N: different workflows are handled independently" {
  local t1=$(( FIXED_NOW - 5 * 86400 ))
  local t2=$(( FIXED_NOW - 10 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "w1-art-a,500000,${t1},run-001" \
    "w1-art-b,500000,${t2},run-001" \
    "w2-art-a,500000,${t1},run-002" \
    "w2-art-b,500000,${t2},run-002")"

  run env NOW="$FIXED_NOW" KEEP_LATEST_N=1 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  # Newest of each workflow kept, older deleted
  [[ "$output" == *"w1-art-a"*"KEEP"* ]] || [[ "$output" == *"KEEP"*"w1-art-a"* ]]
  [[ "$output" == *"w1-art-b"*"DELETE"* ]] || [[ "$output" == *"DELETE"*"w1-art-b"* ]]
  [[ "$output" == *"w2-art-a"*"KEEP"* ]] || [[ "$output" == *"KEEP"*"w2-art-a"* ]]
  [[ "$output" == *"w2-art-b"*"DELETE"* ]] || [[ "$output" == *"DELETE"*"w2-art-b"* ]]
}

# ─── Group 5: Max-total-size policy ──────────────────────────────────────────

@test "max-total-size: deletes oldest artifacts when total exceeds limit" {
  # 3 x 1 MB = 3 MB total; limit is 2 MB — oldest should be deleted
  local t1=$(( FIXED_NOW - 1 * 86400 ))   # newest
  local t2=$(( FIXED_NOW - 5 * 86400 ))   # middle
  local t3=$(( FIXED_NOW - 10 * 86400 ))  # oldest — should go first
  local fixture
  fixture="$(make_fixture \
    "size-art-a,1048576,${t1},run-001" \
    "size-art-b,1048576,${t2},run-001" \
    "size-art-c,1048576,${t3},run-001")"

  run env NOW="$FIXED_NOW" MAX_TOTAL_SIZE_B=2097152 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"size-art-c"*"DELETE"* ]] || [[ "$output" == *"DELETE"*"size-art-c"* ]]
}

@test "max-total-size: retains all when total is within limit" {
  local t1=$(( FIXED_NOW - 1 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "small-art,512000,${t1},run-001")"

  run env NOW="$FIXED_NOW" MAX_TOTAL_SIZE_B=2097152 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEEP"* ]]
  [[ "$output" != *"DELETE"* ]]
}

# ─── Group 6: Summary output ─────────────────────────────────────────────────

@test "summary shows total space reclaimed" {
  local old_epoch=$(( FIXED_NOW - 40 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "doomed-artifact,2097152,${old_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  # Summary must mention bytes reclaimed
  [[ "$output" == *"reclaimed"* ]] || [[ "$output" == *"Reclaimed"* ]]
}

@test "summary counts retained vs deleted artifacts" {
  local old_epoch=$(( FIXED_NOW - 40 * 86400 ))
  local recent_epoch=$(( FIXED_NOW - 5 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "old-art,1048576,${old_epoch},run-001" \
    "new-art,1048576,${recent_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"retained: 1"* ]] || [[ "$output" == *"Retained: 1"* ]]
  [[ "$output" == *"deleted: 1"* ]] || [[ "$output" == *"Deleted: 1"* ]]
}

# ─── Group 7: Dry-run mode ────────────────────────────────────────────────────

@test "dry-run mode: outputs deletion plan but marks as dry-run" {
  local old_epoch=$(( FIXED_NOW - 40 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "old-art,1048576,${old_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 DRY_RUN=true "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"dry run"* ]] || [[ "$output" == *"dry-run"* ]]
  [[ "$output" == *"DELETE"* ]]  # plan still shown
}

@test "dry-run mode: exit code 0 even with artifacts to delete" {
  local old_epoch=$(( FIXED_NOW - 40 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "old-art,1048576,${old_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 DRY_RUN=true "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
}

# ─── Group 8: Combined policies ───────────────────────────────────────────────

@test "combined policies: all three policies applied together" {
  # 4 artifacts for run-001
  local t1=$(( FIXED_NOW - 2 * 86400 ))   # recent, small — keep
  local t2=$(( FIXED_NOW - 5 * 86400 ))   # recent, small — keep (N=2 per workflow)
  local t3=$(( FIXED_NOW - 20 * 86400 ))  # recent but 3rd-oldest for run-001 — deleted by keep-N
  local t_old=$(( FIXED_NOW - 60 * 86400 )) # too old — deleted by max-age
  local fixture
  fixture="$(make_fixture \
    "art-new1,500000,${t1},run-001" \
    "art-new2,500000,${t2},run-001" \
    "art-mid,500000,${t3},run-001" \
    "art-old,500000,${t_old},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 KEEP_LATEST_N=2 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"art-old"*"DELETE"* ]] || [[ "$output" == *"DELETE"*"art-old"* ]]
  [[ "$output" == *"art-mid"*"DELETE"* ]] || [[ "$output" == *"DELETE"*"art-mid"* ]]
  [[ "$output" == *"art-new1"*"KEEP"* ]] || [[ "$output" == *"KEEP"*"art-new1"* ]]
  [[ "$output" == *"art-new2"*"KEEP"* ]] || [[ "$output" == *"KEEP"*"art-new2"* ]]
}

@test "exact space reclaimed: 2MB artifact deleted reports 2097152 bytes" {
  local old_epoch=$(( FIXED_NOW - 40 * 86400 ))
  local fixture
  fixture="$(make_fixture \
    "big-art,2097152,${old_epoch},run-001")"

  run env NOW="$FIXED_NOW" MAX_AGE_DAYS=30 "$SCRIPT" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2097152"* ]]
}

# ─── Group 9: Workflow structure validation ───────────────────────────────────

WORKFLOW=".github/workflows/artifact-cleanup-script.yml"

@test "workflow file exists" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  [ -f "$wf" ]
}

@test "workflow references artifact_cleanup.sh correctly" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  grep -q "artifact_cleanup.sh" "$wf"
}

@test "workflow has push trigger" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  grep -q "push" "$wf"
}

@test "workflow has workflow_dispatch trigger" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  grep -q "workflow_dispatch" "$wf"
}

@test "workflow uses actions/checkout@v4" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  grep -q "actions/checkout@v4" "$wf"
}

@test "workflow has a lint job" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  grep -q "lint" "$wf"
}

@test "workflow has a test job" {
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  grep -q "test" "$wf"
}

@test "actionlint passes on workflow file" {
  # Skip gracefully when actionlint is not installed in the current environment
  # (e.g., inside the act Docker container when actionlint was not pre-installed).
  # The lint job in the workflow validates this independently.
  if ! command -v actionlint &>/dev/null; then
    skip "actionlint not found in PATH"
  fi
  local wf="$BATS_TEST_DIRNAME/../${WORKFLOW}"
  run actionlint "$wf"
  [ "$status" -eq 0 ]
}
