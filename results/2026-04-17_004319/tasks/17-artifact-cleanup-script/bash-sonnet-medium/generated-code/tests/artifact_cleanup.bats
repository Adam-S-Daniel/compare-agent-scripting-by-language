#!/usr/bin/env bats
# TDD tests for artifact-cleanup.sh
# Red/Green cycle: write failing test, implement minimum code, refactor

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/artifact-cleanup.sh"
FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"

setup() {
    mkdir -p "$FIXTURES_DIR"
    # Reference date for all tests: 2026-04-19 (today)
    export REFERENCE_DATE="2026-04-19"
}

teardown() {
    rm -f "$FIXTURES_DIR"/test_*.csv
}

# --- RED: Test 1: script exists and is executable ---
@test "script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

# --- RED: Test 2: script prints usage when called with --help ---
@test "script prints usage with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# --- RED: Test 3: script errors on missing artifacts file ---
@test "script errors on missing artifacts file" {
    run "$SCRIPT" --artifacts /nonexistent/path.csv
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

# --- RED: Test 4: script loads artifacts from CSV ---
@test "script loads artifacts from CSV" {
    cat > "$FIXTURES_DIR/test_basic.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
artifact-A,1048576,2026-04-15,run-001
artifact-B,2097152,2026-04-10,run-002
EOF
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_basic.csv" --dry-run \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"artifact-A"* ]] || [[ "$output" == *"artifact-B"* ]]
}

# --- RED: Test 5: max-age policy deletes old artifacts ---
@test "max-age policy marks old artifacts for deletion" {
    cat > "$FIXTURES_DIR/test_age.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
old-artifact,1048576,2026-03-01,run-001
new-artifact,2097152,2026-04-18,run-002
EOF
    # max-age-days=10: old-artifact is 49 days old, new-artifact is 1 day old
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_age.csv" --dry-run \
        --max-age-days 10 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"old-artifact"* ]]
    [[ "$output" == *"DELETE"* ]] || [[ "$output" == *"delete"* ]]
}

# --- RED: Test 6: max-age policy retains recent artifacts ---
@test "max-age policy retains recent artifacts" {
    cat > "$FIXTURES_DIR/test_age_retain.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
recent-artifact,1048576,2026-04-18,run-001
EOF
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_age_retain.csv" --dry-run \
        --max-age-days 10 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RETAIN"* ]] || [[ "$output" == *"retain"* ]] || \
        [[ "$output" == *"kept"* ]] || [[ "$output" == *"keep"* ]]
}

# --- RED: Test 7: max-total-size policy removes oldest when over limit ---
@test "max-total-size policy deletes oldest artifacts when over limit" {
    cat > "$FIXTURES_DIR/test_size.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
oldest-artifact,5242880,2026-04-01,run-001
middle-artifact,5242880,2026-04-10,run-002
newest-artifact,5242880,2026-04-18,run-003
EOF
    # 3 artifacts * 5MB = 15MB total; limit to 8MB: should delete oldest until under limit
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_size.csv" --dry-run \
        --max-total-size 8388608 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"oldest-artifact"* ]]
    [[ "$output" == *"DELETE"* ]] || [[ "$output" == *"delete"* ]]
}

# --- RED: Test 8: keep-latest-N policy keeps only N per workflow ---
@test "keep-latest-N policy retains only N artifacts per workflow" {
    cat > "$FIXTURES_DIR/test_latest.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
wf1-run1,1048576,2026-04-01,workflow-A
wf1-run2,1048576,2026-04-05,workflow-A
wf1-run3,1048576,2026-04-10,workflow-A
wf1-run4,1048576,2026-04-15,workflow-A
wf2-run1,1048576,2026-04-10,workflow-B
EOF
    # keep-latest-n=2 for workflow-A: should delete wf1-run1 and wf1-run2
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_latest.csv" --dry-run \
        --keep-latest-n 2 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"wf1-run1"* ]]
    [[ "$output" == *"DELETE"* ]] || [[ "$output" == *"delete"* ]]
}

# --- RED: Test 9: keep-latest-N retains the most recent artifacts ---
@test "keep-latest-N retains the most recent artifacts per workflow" {
    cat > "$FIXTURES_DIR/test_latest_retain.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
wf1-run3,1048576,2026-04-10,workflow-A
wf1-run4,1048576,2026-04-15,workflow-A
EOF
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_latest_retain.csv" --dry-run \
        --keep-latest-n 2 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # Both should be retained since we only have 2 and limit is 2
    [[ "$output" == *"wf1-run3"* ]]
    [[ "$output" == *"RETAIN"* ]] || [[ "$output" == *"retain"* ]] || \
        [[ "$output" == *"kept"* ]] || [[ "$output" == *"keep"* ]]
}

# --- RED: Test 10: summary shows correct counts and reclaimed space ---
@test "summary shows artifacts retained vs deleted and space reclaimed" {
    cat > "$FIXTURES_DIR/test_summary.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
old-1,10485760,2026-01-01,run-001
old-2,5242880,2026-01-15,run-002
new-1,2097152,2026-04-18,run-003
EOF
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_summary.csv" --dry-run \
        --max-age-days 30 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # old-1 and old-2 are >30 days old; new-1 is 1 day old
    [[ "$output" == *"deleted: 2"* ]] || [[ "$output" == *"Deleted: 2"* ]] || \
        [[ "$output" == *"2 artifact"* ]]
    [[ "$output" == *"retained: 1"* ]] || [[ "$output" == *"Retained: 1"* ]] || \
        [[ "$output" == *"1 artifact"* ]]
    # 10485760 + 5242880 = 15728640 bytes reclaimed
    [[ "$output" == *"15728640"* ]] || [[ "$output" == *"15.0 MB"* ]] || \
        [[ "$output" == *"15 MB"* ]]
}

# --- RED: Test 11: combined policies apply correctly ---
@test "multiple policies combine correctly" {
    cat > "$FIXTURES_DIR/test_combined.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
very-old,10485760,2026-01-01,workflow-X
old-dup1,5242880,2026-04-01,workflow-X
old-dup2,5242880,2026-04-05,workflow-X
recent,2097152,2026-04-18,workflow-X
EOF
    # max-age=30 days kills very-old; keep-latest-n=2 kills old-dup1
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_combined.csv" --dry-run \
        --max-age-days 30 --keep-latest-n 2 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"very-old"* ]]
    [[ "$output" == *"DELETE"* ]] || [[ "$output" == *"delete"* ]]
}

# --- RED: Test 12: non-dry-run outputs deletion commands ---
@test "non-dry-run mode outputs deletion commands" {
    cat > "$FIXTURES_DIR/test_nodryrun.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
old-artifact,1048576,2026-01-01,run-001
EOF
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_nodryrun.csv" \
        --max-age-days 10 --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    # Should output a gh artifact delete command or equivalent
    [[ "$output" == *"gh artifact"* ]] || [[ "$output" == *"delete"* ]] || \
        [[ "$output" == *"DELETE"* ]]
}

# --- RED: Test 13: empty CSV is handled gracefully ---
@test "empty artifacts CSV is handled gracefully" {
    cat > "$FIXTURES_DIR/test_empty.csv" <<'EOF'
name,size_bytes,created_date,workflow_run_id
EOF
    run "$SCRIPT" --artifacts "$FIXTURES_DIR/test_empty.csv" --dry-run \
        --reference-date "$REFERENCE_DATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0"* ]]
}
