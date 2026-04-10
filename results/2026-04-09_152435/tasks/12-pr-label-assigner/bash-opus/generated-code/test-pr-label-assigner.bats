#!/usr/bin/env bats
# Test suite for PR Label Assigner
# All tests run through GitHub Actions via `act push`
#
# TDD approach: each test validates a specific behavior of the label assigner
# by running the full CI pipeline through act and checking exact output values.

WORK_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT="$WORK_DIR/act-result.txt"

# ============================================================
# Workflow structure tests (no act needed)
# ============================================================

@test "workflow YAML exists at .github/workflows/pr-label-assigner.yml" {
  [ -f "$WORK_DIR/.github/workflows/pr-label-assigner.yml" ]
}

@test "workflow has correct trigger events" {
  grep -q "push:" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
  grep -q "pull_request:" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
  grep -q "workflow_dispatch:" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
}

@test "workflow has jobs defined" {
  grep -q "jobs:" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
  grep -q "assign-labels:" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
}

@test "workflow uses actions/checkout@v4" {
  grep -q "actions/checkout@v4" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
}

@test "workflow references pr-label-assigner.sh" {
  grep -q "pr-label-assigner.sh" "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
}

@test "pr-label-assigner.sh exists and is executable" {
  [ -f "$WORK_DIR/pr-label-assigner.sh" ]
  [ -x "$WORK_DIR/pr-label-assigner.sh" ]
}

@test "pr-label-assigner.sh has correct shebang" {
  head -1 "$WORK_DIR/pr-label-assigner.sh" | grep -q '#!/usr/bin/env bash'
}

@test "pr-label-assigner.sh passes shellcheck" {
  shellcheck "$WORK_DIR/pr-label-assigner.sh"
}

@test "pr-label-assigner.sh passes bash -n syntax check" {
  bash -n "$WORK_DIR/pr-label-assigner.sh"
}

@test "actionlint passes on workflow file" {
  actionlint "$WORK_DIR/.github/workflows/pr-label-assigner.yml"
}

# ============================================================
# Act-based integration tests
# ============================================================

@test "act push runs successfully and produces correct output" {
  # Create temp directory for an isolated git repo
  local tmpdir
  tmpdir="$(mktemp -d)"

  # Initialize git repo with project files
  cd "$tmpdir"
  git init -b main
  git config user.email "test@test.com"
  git config user.name "Test"

  # Copy project files
  cp "$WORK_DIR/pr-label-assigner.sh" "$tmpdir/"
  chmod +x "$tmpdir/pr-label-assigner.sh"
  mkdir -p "$tmpdir/.github/workflows"
  cp "$WORK_DIR/.github/workflows/pr-label-assigner.yml" "$tmpdir/.github/workflows/"

  # Copy .actrc if it exists
  if [ -f "$WORK_DIR/.actrc" ]; then
    cp "$WORK_DIR/.actrc" "$tmpdir/"
  fi

  # Create initial commit
  git add -A
  git commit -m "initial commit"

  # Run act (--pull=false to use local image without trying to pull)
  local act_output
  act_output="$(act push --rm --pull=false 2>&1)" || true
  local act_exit=$?

  # Save output
  echo "========== ACT RUN ==========" > "$ACT_RESULT"
  echo "$act_output" >> "$ACT_RESULT"
  echo "========== END ACT RUN ==========" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  cd "$WORK_DIR"
  rm -rf "$tmpdir"

  # --- Assertions ---

  # 1. Act should succeed
  echo "ACT EXIT CODE: $act_exit"
  [ "$act_exit" -eq 0 ]

  # 2. Job should succeed
  echo "$act_output" | grep -qi "Job succeeded"

  # 3. Test 1: Basic glob matching - should produce documentation, api, tests, core
  echo "$act_output" | grep -q "documentation"
  echo "$act_output" | grep -q "api"
  echo "$act_output" | grep -q "tests"
  echo "$act_output" | grep -q "core"

  # 4. Test 2: Priority and max-labels (max 2) - should produce typescript, api only
  #    The *.ts pattern matches both files, src/api/** matches routes.ts, src/** matches both
  #    With max 2, we get typescript and api
  echo "$act_output" | grep -q "typescript"

  # 5. Test 3: Single file multiple rules - app.test.js matches both *.test.js and src/**
  echo "$act_output" | grep -q "tests"
  echo "$act_output" | grep -q "core"

  # 6. Test 4: No matches - should show no labels matched
  echo "$act_output" | grep -q "(no labels matched)"

  # 7. Test 5: Deep nested paths
  echo "$act_output" | grep -q "frontend"
  echo "$act_output" | grep -q "testing"
  echo "$act_output" | grep -q "styles"

  # 8. Test 6: Error handling
  echo "$act_output" | grep -q "OK: exited with error"
  echo "$act_output" | grep -q "Config file not found"

  # 9. All tests completed marker
  echo "$act_output" | grep -q "All tests completed"
}

@test "act-result.txt exists and contains expected content" {
  [ -f "$ACT_RESULT" ]
  grep -q "ACT RUN" "$ACT_RESULT"
  grep -q "All tests completed" "$ACT_RESULT"
}
