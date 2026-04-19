#!/usr/bin/env bats

# Test file for artifact cleanup script
# Uses red/green TDD: failing test first, then implementation

setup() {
  # Create a temporary directory for test artifacts
  export TMPDIR="${BATS_TEST_TMPDIR}"
  export TEST_DATA="${TMPDIR}/test_data.json"

  # Load the script being tested
  source "${BATS_TEST_DIRNAME}/artifact-cleanup.sh"
}

# Test 1: Parse artifact JSON and validate structure
@test "parse_artifacts should read JSON with artifact metadata" {
  # RED: This test will fail until we implement parse_artifacts

  cat > "${TEST_DATA}" << 'EOF'
[
  {
    "name": "artifact-1",
    "size": 1000,
    "created": "2026-01-01T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "artifact-2",
    "size": 2000,
    "created": "2026-02-01T00:00:00Z",
    "workflow_run_id": "run-1"
  }
]
EOF

  # Should return count of artifacts
  result=$(parse_artifacts "${TEST_DATA}")
  [[ "$result" -eq 2 ]]
}

# Test 2: Calculate age of artifacts
@test "calculate_age should return days since creation date" {
  # RED: This test will fail until we implement calculate_age

  # Mock today as 2026-04-19 (from context)
  reference_date="2026-04-19"

  # Artifact created 10 days ago
  created_date="2026-04-09"

  age=$(calculate_age "$created_date" "$reference_date")
  [[ "$age" -eq 10 ]]
}

# Test 3: Identify artifacts exceeding max age
@test "filter_by_age should identify old artifacts" {
  # RED: This test will fail until we implement filter_by_age

  cat > "${TEST_DATA}" << 'EOF'
[
  {
    "name": "artifact-old",
    "size": 1000,
    "created": "2026-01-01T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "artifact-new",
    "size": 1000,
    "created": "2026-04-15T00:00:00Z",
    "workflow_run_id": "run-1"
  }
]
EOF

  # Max age: 30 days, reference date: 2026-04-19
  old_artifacts=$(filter_by_age "${TEST_DATA}" 30 "2026-04-19")
  # Should have 1 artifact exceeding max age
  [[ $(echo "$old_artifacts" | jq '. | length') -eq 1 ]]
  [[ $(echo "$old_artifacts" | jq -r '.[0].name') == "artifact-old" ]]
}

# Test 4: Dry-run mode should not actually delete anything
@test "cleanup_artifacts should support dry-run mode" {
  # RED: This test will fail until we implement cleanup_artifacts with dry-run

  cat > "${TEST_DATA}" << 'EOF'
[
  {
    "name": "artifact-1",
    "size": 1000,
    "created": "2026-01-01T00:00:00Z",
    "workflow_run_id": "run-1"
  }
]
EOF

  # Run in dry-run mode
  output=$(cleanup_artifacts "${TEST_DATA}" --max-age 30 --dry-run 2>&1)

  # Should mention dry-run in output
  [[ "$output" =~ "dry-run" || "$output" =~ "DRY_RUN" ]]
}

# Test 5: Generate summary with space calculations
@test "generate_summary should calculate total size" {
  # RED: This test will fail until we implement generate_summary

  cat > "${TEST_DATA}" << 'EOF'
{
  "artifacts_to_delete": [
    {"name": "a1", "size": 1000},
    {"name": "a2", "size": 2000}
  ],
  "artifacts_to_keep": [
    {"name": "a3", "size": 500}
  ]
}
EOF

  summary=$(generate_summary "${TEST_DATA}")

  # Should show total space to be reclaimed (3000 bytes)
  [[ "$summary" =~ "3000" || "$summary" =~ "3 KB" || "$summary" =~ "reclaim" ]]
}

# Test 6: Filter artifacts by total size
@test "filter_by_size should identify artifacts exceeding size limit" {
  # RED: This test will fail until we implement filter_by_size

  cat > "${TEST_DATA}" << 'EOF'
[
  {
    "name": "artifact-large",
    "size": 5368709120,
    "created": "2026-04-15T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "artifact-small",
    "size": 536870912,
    "created": "2026-04-15T00:00:00Z",
    "workflow_run_id": "run-1"
  }
]
EOF

  # Max size: 2048 MB (2147483648 bytes)
  large_artifacts=$(filter_by_size "${TEST_DATA}" 2147483648)
  [[ $(echo "$large_artifacts" | jq '. | length') -eq 1 ]]
  [[ $(echo "$large_artifacts" | jq -r '.[0].name') == "artifact-large" ]]
}

# Test 7: Keep latest N artifacts per workflow
@test "filter_by_latest should keep only newest N artifacts per workflow" {
  # RED: This test will fail until we implement filter_by_latest

  cat > "${TEST_DATA}" << 'EOF'
[
  {
    "name": "artifact-1",
    "size": 1000,
    "created": "2026-04-10T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "artifact-2",
    "size": 1000,
    "created": "2026-04-15T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "artifact-3",
    "size": 1000,
    "created": "2026-04-17T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "artifact-4",
    "size": 1000,
    "created": "2026-04-18T00:00:00Z",
    "workflow_run_id": "run-2"
  },
  {
    "name": "artifact-5",
    "size": 1000,
    "created": "2026-04-12T00:00:00Z",
    "workflow_run_id": "run-2"
  }
]
EOF

  # Keep latest 2 per workflow
  old_artifacts=$(filter_by_latest "${TEST_DATA}" 2)
  # run-1 has 3 artifacts, keep 2 (artifact-3 and artifact-2), delete 1
  # run-2 has 2 artifacts, keep 2 (artifact-4 and artifact-5), delete 0
  # Total to delete: 1
  [[ $(echo "$old_artifacts" | jq '. | length') -eq 1 ]]
  [[ $(echo "$old_artifacts" | jq -r '.[0].name') == "artifact-1" ]]
}

# Test 8: Combine multiple filters
@test "apply_all_policies should apply all retention filters" {
  # RED: This test will fail until we implement apply_all_policies

  cat > "${TEST_DATA}" << 'EOF'
[
  {
    "name": "old-large",
    "size": 5368709120,
    "created": "2026-01-01T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "recent-small",
    "size": 536870912,
    "created": "2026-04-15T00:00:00Z",
    "workflow_run_id": "run-1"
  },
  {
    "name": "very-old",
    "size": 1000,
    "created": "2025-12-01T00:00:00Z",
    "workflow_run_id": "run-2"
  }
]
EOF

  # Apply policies: max-age 60, max-size 2048 MB, keep-latest 1
  plan=$(apply_all_policies "${TEST_DATA}" 60 2147483648 1 "2026-04-19")

  # Should identify artifacts for deletion
  local to_delete
  to_delete=$(echo "$plan" | jq '.artifacts_to_delete | length')
  [[ $to_delete -gt 0 ]]
}

# Test 9: Handle empty input gracefully
@test "cleanup_artifacts should handle empty artifact list" {
  # RED: This test will fail until we handle empty arrays

  cat > "${TEST_DATA}" << 'EOF'
[]
EOF

  result=$(cleanup_artifacts "${TEST_DATA}" --max-age 30 --dry-run 2>/dev/null)
  # Should produce valid JSON even with empty input
  echo "$result" | jq . > /dev/null
  # Should have empty deletion list
  [[ $(echo "$result" | jq '.artifacts_to_delete | length') -eq 0 ]]
}

# Test 10: Error handling for missing file
@test "cleanup_artifacts should error on missing input file" {
  # RED: This test will fail until we properly validate

  # This should return non-zero exit code
  run cleanup_artifacts "/nonexistent/file.json" --max-age 30
  [[ $status -ne 0 ]]
}
