#!/usr/bin/env bats
# Secret Rotation Validator — bats test suite
# TDD: tests are written first; implementation follows in secret-rotation-validator.sh

# Path helpers
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/secret-rotation-validator.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
WORKFLOW="$SCRIPT_DIR/.github/workflows/secret-rotation-validator.yml"

# ============================================================
# RED phase 1 — script exists and is executable
# ============================================================
@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ============================================================
# RED phase 2 — script prints usage on --help
# ============================================================
@test "script shows usage on --help" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# ============================================================
# RED phase 3 — error handling: missing config file
# ============================================================
@test "errors with non-zero exit on missing config file" {
  run "$SCRIPT" /nonexistent/path.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error:"* ]]
}

# ============================================================
# RED phase 4 — markdown output: all-ok fixture
# Expected: both secrets appear under ok, none in expired/warning
# ============================================================
@test "all-ok fixture: markdown shows two ok secrets" {
  run "$SCRIPT" --date 2026-05-08 "$FIXTURES/all-ok.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"API_KEY"* ]]
  [[ "$output" == *"DB_PASS"* ]]
  # OK section should have 2 entries
  [[ "$output" == *"OK (2)"* ]]
}

# ============================================================
# RED phase 5 — markdown output: mixed fixture
# EXPIRED_SECRET, WARNING_SECRET, OK_SECRET must be classified correctly
# ============================================================
@test "mixed fixture: markdown identifies expired secret" {
  run "$SCRIPT" --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"EXPIRED_SECRET"* ]]
}

@test "mixed fixture: markdown identifies warning secret" {
  run "$SCRIPT" --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING_SECRET"* ]]
}

@test "mixed fixture: markdown identifies ok secret" {
  run "$SCRIPT" --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK_SECRET"* ]]
}

# ============================================================
# RED phase 6 — JSON output format
# ============================================================
@test "mixed fixture: JSON output contains expired entry" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  # Must be valid JSON
  echo "$output" | jq . >/dev/null 2>&1
  # Must have EXPIRED_SECRET in expired array
  result=$(echo "$output" | jq -r '.expired[0].name')
  [ "$result" = "EXPIRED_SECRET" ]
}

@test "mixed fixture: JSON output contains warning entry" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.warning[0].name')
  [ "$result" = "WARNING_SECRET" ]
}

@test "mixed fixture: JSON output contains ok entry" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.ok[0].name')
  [ "$result" = "OK_SECRET" ]
}

# ============================================================
# RED phase 7 — JSON output includes exact calculated fields
# EXPIRED_SECRET: expires=2026-01-30, days_overdue=97
# WARNING_SECRET: expires=2026-05-14, days_until_expiry=6
# OK_SECRET: expires=2026-05-30, days_until_expiry=22
# ============================================================
@test "JSON output: expired entry has correct expiry date" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.expired[0].expires')
  [ "$result" = "2026-01-30" ]
}

@test "JSON output: expired entry has correct days_overdue" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.expired[0].days_overdue')
  [ "$result" = "98" ]
}

@test "JSON output: warning entry has correct days_until_expiry" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.warning[0].days_until_expiry')
  [ "$result" = "6" ]
}

@test "JSON output: ok entry has correct days_until_expiry" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.ok[0].days_until_expiry')
  [ "$result" = "22" ]
}

# ============================================================
# RED phase 8 — configurable warning window
# ============================================================
@test "warning-days 30 promotes ok to warning" {
  # With --warning-days 30, OK_SECRET (22 days until expiry) becomes warning
  run "$SCRIPT" --format json --date 2026-05-08 --warning-days 30 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  # OK_SECRET should now be in warning, not ok
  warning_names=$(echo "$output" | jq -r '[.warning[].name] | join(",")')
  [[ "$warning_names" == *"OK_SECRET"* ]]
}

# ============================================================
# RED phase 9 — empty config
# ============================================================
@test "empty config produces empty report gracefully" {
  run "$SCRIPT" "$FIXTURES/empty.json"
  [ "$status" -eq 0 ]
  # Should not error out
}

# ============================================================
# RED phase 10 — required_by field included in output
# ============================================================
@test "JSON output: required_by field is present" {
  run "$SCRIPT" --format json --date 2026-05-08 "$FIXTURES/mixed.json"
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.expired[0].required_by | length')
  [ "$result" -ge 1 ]
}

# ============================================================
# WORKFLOW STRUCTURE TESTS (static — no act needed)
# ============================================================
@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "workflow has push trigger" {
  run grep -q "push:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow has schedule trigger" {
  run grep -q "schedule:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow references script file that exists" {
  # Workflow must reference secret-rotation-validator.sh
  run grep -q "secret-rotation-validator.sh" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ -f "$SCRIPT_DIR/secret-rotation-validator.sh" ]
}

@test "workflow references fixture files that exist" {
  run grep -q "fixtures/mixed.json" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ -f "$FIXTURES/mixed.json" ]
}

@test "actionlint passes on workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ============================================================
# ACT INTEGRATION TEST
# Runs all scenarios through the GitHub Actions workflow via act.
# Saves full output to act-result.txt in the workspace root.
# Asserts exact expected values from workflow output.
# ============================================================
@test "act: workflow executes all scenarios and job succeeds" {
  # Use a temp dir so we have a clean git repo for act
  local tmpdir
  tmpdir=$(mktemp -d)

  # Copy project files (excluding the .git dir and act-result.txt)
  rsync -a --exclude='.git' --exclude='act-result.txt' \
    "$SCRIPT_DIR/" "$tmpdir/"

  # Initialize a git repo (act needs one)
  cd "$tmpdir"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git add -A
  git commit -q -m "test: run secret rotation validator"

  # Run act — single invocation covers all test scenarios in the workflow
  # --pull=false: use local Docker image without attempting a registry pull
  run act push --rm --pull=false \
    -W .github/workflows/secret-rotation-validator.yml \
    2>&1

  # Capture output to act-result.txt in workspace root
  {
    echo "=== ACT RUN: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "$output"
    echo "=== END ACT RUN ==="
  } >> "$SCRIPT_DIR/act-result.txt"

  # Primary assertion: workflow must succeed
  [ "$status" -eq 0 ]

  # Job succeeded marker from act
  [[ "$output" == *"Job succeeded"* ]]

  # Exact value assertions from workflow step output
  # All-ok scenario: both secrets appear as ok
  [[ "$output" == *"API_KEY"* ]]
  [[ "$output" == *"DB_PASS"* ]]

  # Mixed scenario: correct urgency classification
  [[ "$output" == *"EXPIRED_SECRET"* ]]
  [[ "$output" == *"WARNING_SECRET"* ]]
  [[ "$output" == *"OK_SECRET"* ]]

  # JSON scenario: exact field values echoed by workflow step
  [[ "$output" == *"expires=2026-01-30"* ]]
  [[ "$output" == *"days_overdue=98"* ]]
  [[ "$output" == *"days_until=6"* ]]
  [[ "$output" == *"days_until=22"* ]]

  cd "$SCRIPT_DIR"
  rm -rf "$tmpdir"
}
