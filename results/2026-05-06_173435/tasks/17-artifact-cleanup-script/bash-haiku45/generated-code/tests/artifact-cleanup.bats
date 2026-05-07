#!/usr/bin/env bats

# Artifact cleanup script tests using bats framework
# Tests cover: parsing, retention policies, dry-run mode, summary generation

setup() {
  # Create a temporary directory for test data
  TEST_TMPDIR="$(mktemp -d)" || exit 1

  # Find script relative to test file directory
  SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SCRIPT="${SCRIPT_DIR}/artifact-cleanup.sh"

  # Create mock artifact CSV file for testing
  MOCK_CSV="${TEST_TMPDIR}/artifacts.csv"
}

teardown() {
  # Clean up temporary test directory
  rm -rf "${TEST_TMPDIR}"
}

# Test 1: Script exists and is executable
@test "script exists and is executable" {
  [ -f "${SCRIPT}" ]
  [ -x "${SCRIPT}" ]
}

# Test 2: Script fails gracefully with no input
@test "script fails with missing input file" {
  run "${SCRIPT}" --input /nonexistent/file.csv --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"Error"* ]]
}

# Test 3: Parse simple artifact CSV with headers
@test "parses artifact CSV with correct format" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,1000,2026-05-01,run-1
artifact-2,2000,2026-05-02,run-2
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"artifact-1"* ]]
  [[ "$output" == *"artifact-2"* ]]
}

# Test 4: Dry-run mode does not actually delete
@test "dry-run mode reports what would be deleted" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,1000,2026-04-20,run-1
artifact-2,2000,2026-05-05,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --max-age 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"dry run"* ]]
}

# Test 5: Apply max-age retention policy
@test "deletes artifacts older than max-age" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
old-artifact,1000,2026-04-20,run-1
new-artifact,2000,2026-05-05,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --max-age 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"old-artifact"* ]]
  [[ "$output" == *"delete"* ]] || [[ "$output" == *"Delete"* ]]
}

# Test 6: Apply max-total-size retention policy
@test "keeps only latest artifacts when total size exceeds limit" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,3000,2026-05-01,run-1
artifact-2,3000,2026-05-02,run-1
artifact-3,3000,2026-05-03,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --max-total-size 5000
  [ "$status" -eq 0 ]
  [[ "$output" == *"artifact"* ]]
  [[ "$output" == *"delete"* ]] || [[ "$output" == *"Delete"* ]]
}

# Test 7: Apply keep-latest-N retention policy
@test "keeps only latest N artifacts per workflow" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,1000,2026-05-01,run-1
artifact-2,1000,2026-05-02,run-1
artifact-3,1000,2026-05-03,run-1
artifact-4,1000,2026-05-04,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --keep-latest 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"artifact-1"* ]] || [[ "$output" == *"artifact-2"* ]]
  [[ "$output" == *"delete"* ]] || [[ "$output" == *"Delete"* ]]
}

# Test 8: Summary includes total space reclaimed
@test "summary includes total space reclaimed" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,5000,2026-04-20,run-1
artifact-2,3000,2026-05-05,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --max-age 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"space"* ]] || [[ "$output" == *"Space"* ]] || [[ "$output" == *"reclaimed"* ]] || [[ "$output" == *"total"* ]]
}

# Test 9: Summary shows artifacts retained vs deleted
@test "summary shows count of artifacts retained and deleted" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,1000,2026-04-20,run-1
artifact-2,1000,2026-05-05,run-1
artifact-3,1000,2026-05-05,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --max-age 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"delete"* ]] || [[ "$output" == *"Delete"* ]]
  [[ "$output" == *"retain"* ]] || [[ "$output" == *"Retain"* ]] || [[ "$output" == *"keep"* ]]
}

# Test 10: Multiple retention policies combine correctly (all must be satisfied)
@test "multiple policies are combined (AND logic)" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
artifact-1,1000,2026-04-20,run-1
artifact-2,1000,2026-04-25,run-1
artifact-3,1000,2026-05-04,run-1
artifact-4,1000,2026-05-05,run-1
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run --max-age 10 --keep-latest 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"artifact"* ]]
}

# Test 11: Help message
@test "displays help message with --help flag" {
  run "${SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

# Test 12: Handle empty CSV gracefully
@test "handles empty artifact list" {
  cat > "${MOCK_CSV}" << 'EOF'
name,size_bytes,creation_date,workflow_run_id
EOF

  run "${SCRIPT}" --input "${MOCK_CSV}" --dry-run
  [ "$status" -eq 0 ]
}
