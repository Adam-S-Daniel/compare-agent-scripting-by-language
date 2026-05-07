#!/usr/bin/env bats
# Dependency License Checker — bats test suite
#
# TDD approach: tests written before implementation, minimum code added to pass each one.
# Unit tests (1–11) call the script directly for rapid red/green cycles.
# The GitHub Actions workflow also runs these tests inside the container via act.
# Workflow structure tests (12–15) verify the workflow YAML.
# Act integration tests (16–17) run the full workflow via `act push --rm`; they are
# automatically skipped when bats is already executing inside a container.

SCRIPT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"

# ============================================================
# TDD ITERATION 1: Script existence
# ============================================================

@test "1. license-checker.sh exists and is executable" {
  [ -f "${SCRIPT_DIR}/license-checker.sh" ]
  [ -x "${SCRIPT_DIR}/license-checker.sh" ]
}

# ============================================================
# TDD ITERATION 2: Argument validation
# ============================================================

@test "2. exits with error when --manifest is missing" {
  run "${SCRIPT_DIR}/license-checker.sh" --config "${FIXTURES}/license-config.json"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--manifest is required" ]]
}

@test "3. exits with error when --config is missing" {
  run "${SCRIPT_DIR}/license-checker.sh" --manifest "${FIXTURES}/all-approved-package.json"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--config is required" ]]
}

@test "4. exits with error when manifest file does not exist" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "/nonexistent/path.json" \
    --config   "${FIXTURES}/license-config.json"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ============================================================
# TDD ITERATION 3: Parse package.json
# ============================================================

@test "5. parses package.json and lists all dependency names" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/all-approved-package.json" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"express"* ]]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"axios"* ]]
}

# ============================================================
# TDD ITERATION 4: License status — approved
# ============================================================

@test "6. reports 'approved' status for MIT-licensed packages" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/all-approved-package.json" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"approved"* ]]
  [[ "$output" == *"Approved: 3"* ]]
  [[ "$output" == *"Denied:   0"* ]]
}

# ============================================================
# TDD ITERATION 5: License status — denied
# ============================================================

@test "7. reports 'denied' status for GPL-licensed packages in strict mode" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest       "${FIXTURES}/has-denied-package.json" \
    --config         "${FIXTURES}/license-config.json" \
    --mock-db        "${FIXTURES}/license-mock-db.json" \
    --fail-on-denied
  [ "$status" -eq 1 ]
  [[ "$output" == *"denied"* ]]
  [[ "$output" == *"Denied:   1"* ]]
}

@test "8. includes 'denied' in report but exits 0 without --fail-on-denied" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/has-denied-package.json" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"denied"* ]]
  [[ "$output" == *"Denied:   1"* ]]
}

# ============================================================
# TDD ITERATION 6: License status — unknown
# ============================================================

@test "9. reports 'unknown' for packages absent from the mock database" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/has-unknown-package.json" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown"* ]]
  [[ "$output" == *"Unknown:  1"* ]]
}

# ============================================================
# TDD ITERATION 7: Parse requirements.txt
# ============================================================

@test "10. parses requirements.txt and outputs Python package names" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/requirements.txt" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"requests"* ]]
  [[ "$output" == *"flask"* ]]
  [[ "$output" == *"numpy"* ]]
  [[ "$output" == *"django"* ]]
}

# ============================================================
# TDD ITERATION 8: Report structure + mixed manifest
# ============================================================

@test "11. report includes summary section with correct totals" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/all-approved-package.json" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== Summary ==="* ]]
  [[ "$output" == *"Total:    3"* ]]
}

@test "12. mixed manifest shows approved, denied, and unknown entries" {
  run "${SCRIPT_DIR}/license-checker.sh" \
    --manifest "${FIXTURES}/mixed-package.json" \
    --config   "${FIXTURES}/license-config.json" \
    --mock-db  "${FIXTURES}/license-mock-db.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"approved"* ]]
  [[ "$output" == *"denied"* ]]
  [[ "$output" == *"unknown"* ]]
  [[ "$output" == *"Approved: 1"* ]]
  [[ "$output" == *"Denied:   1"* ]]
  [[ "$output" == *"Unknown:  1"* ]]
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================

@test "13. GitHub Actions workflow file exists" {
  [ -f "${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml" ]
}

@test "14. workflow passes actionlint" {
  run actionlint "${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
  [ "$status" -eq 0 ]
}

@test "15. workflow has push and workflow_dispatch triggers" {
  local wf="${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
  run grep -q "push:" "$wf"
  [ "$status" -eq 0 ]
  run grep -q "workflow_dispatch" "$wf"
  [ "$status" -eq 0 ]
}

@test "16. workflow references license-checker.sh" {
  local wf="${SCRIPT_DIR}/.github/workflows/dependency-license-checker.yml"
  run grep -q "license-checker.sh" "$wf"
  [ "$status" -eq 0 ]
}

# ============================================================
# ACT INTEGRATION TESTS
# Run `act push --rm` for two scenarios and assert on exact output.
# Skipped automatically when running inside a container (no Docker-in-Docker).
# ============================================================

ACT_RESULT_FILE="${SCRIPT_DIR}/act-result.txt"

# Helper: copy project files into a fresh temp git repo and return the path
_setup_act_repo() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cp -r "${SCRIPT_DIR}/." "$tmpdir/"
  git -C "$tmpdir" init -q
  git -C "$tmpdir" config user.email "ci@test.local"
  git -C "$tmpdir" config user.name  "CI Test"
  git -C "$tmpdir" add -A
  git -C "$tmpdir" commit -q -m "ci: test commit"
  echo "$tmpdir"
}

@test "17. act: approved npm packages — all Approved, Job succeeded" {
  # Skip inside a container (act requires Docker, which isn't available nested)
  if [ -f "/.dockerenv" ]; then
    skip "inside container — nested act not available"
  fi

  local tmpdir
  tmpdir=$(_setup_act_repo)

  {
    echo ""
    echo "=== TEST CASE 1: npm all-approved packages ==="
  } >> "${ACT_RESULT_FILE}"

  local act_output
  act_output=$(cd "$tmpdir" && act push --rm --pull=false \
    --env "MANIFEST_FILE=fixtures/all-approved-package.json" 2>&1)
  local act_exit=$?

  echo "$act_output"   >> "${ACT_RESULT_FILE}"
  echo "Exit code: ${act_exit}" >> "${ACT_RESULT_FILE}"
  echo "=== END TEST CASE 1 ===" >> "${ACT_RESULT_FILE}"

  rm -rf "$tmpdir"

  [ "$act_exit" -eq 0 ]
  [[ "$act_output" == *"Job succeeded"* ]]
  [[ "$act_output" == *"Approved: 3"* ]]
  [[ "$act_output" == *"express"* ]]
  [[ "$act_output" == *"Denied:   0"* ]]
}

@test "18. act: requirements.txt — Python packages listed, Job succeeded" {
  if [ -f "/.dockerenv" ]; then
    skip "inside container — nested act not available"
  fi

  local tmpdir
  tmpdir=$(_setup_act_repo)

  {
    echo ""
    echo "=== TEST CASE 2: requirements.txt (Python deps) ==="
  } >> "${ACT_RESULT_FILE}"

  local act_output
  act_output=$(cd "$tmpdir" && act push --rm --pull=false \
    --env "MANIFEST_FILE=fixtures/requirements.txt" 2>&1)
  local act_exit=$?

  echo "$act_output"   >> "${ACT_RESULT_FILE}"
  echo "Exit code: ${act_exit}" >> "${ACT_RESULT_FILE}"
  echo "=== END TEST CASE 2 ===" >> "${ACT_RESULT_FILE}"

  rm -rf "$tmpdir"

  [ "$act_exit" -eq 0 ]
  [[ "$act_output" == *"Job succeeded"* ]]
  [[ "$act_output" == *"requests"* ]]
  [[ "$act_output" == *"flask"* ]]
  [[ "$act_output" == *"Approved:"* ]]
}
