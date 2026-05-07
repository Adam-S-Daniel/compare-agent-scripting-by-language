#!/usr/bin/env bats

# Workflow-level tests. We run the GitHub Actions workflow ONCE via `act push`,
# capture the entire output to act-result.txt, and then assert per-fixture
# outcomes by parsing the delimited blocks the workflow emits.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/semantic-version-bumper.yml"
PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

@test "workflow YAML exists" {
  [ -f "$WORKFLOW" ]
}

@test "actionlint passes (exit code 0)" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow declares expected triggers" {
  grep -qE '^on:' "$WORKFLOW"
  grep -q 'push:'             "$WORKFLOW"
  grep -q 'pull_request:'     "$WORKFLOW"
  grep -q 'workflow_dispatch' "$WORKFLOW"
}

@test "workflow checks out repo and references the script" {
  grep -q 'actions/checkout@v4' "$WORKFLOW"
  grep -q 'bump-version.sh'     "$WORKFLOW"
}

@test "workflow references files that exist on disk" {
  [ -f "${PROJECT_ROOT}/bump-version.sh" ]
  [ -f "${PROJECT_ROOT}/tests/bump-version.bats" ]
  [ -d "${PROJECT_ROOT}/fixtures/feat" ]
  [ -d "${PROJECT_ROOT}/fixtures/fix" ]
  [ -d "${PROJECT_ROOT}/fixtures/breaking" ]
  [ -d "${PROJECT_ROOT}/fixtures/pkgjson" ]
}

@test "act-result.txt exists from prior act run" {
  [ -f "$ACT_RESULT" ]
  [ -s "$ACT_RESULT" ]
}

@test "act run reported Job succeeded" {
  grep -q "Job succeeded" "$ACT_RESULT"
}

# Per-fixture assertions: the workflow emits "===== FIXTURE_BEGIN <name> ====="
# blocks. We grep within the corresponding span. Awk extracts the block.

extract_block() {
  awk -v name="$1" '
    $0 ~ ("FIXTURE_BEGIN " name) { capture=1 }
    capture { print }
    $0 ~ ("FIXTURE_END "   name) { capture=0 }
  ' "$ACT_RESULT"
}

@test "feat fixture (1.2.3) bumps to 1.3.0 in workflow output" {
  block="$(extract_block feat)"
  echo "$block" | grep -q "NEW_VERSION=1.3.0"
}

@test "fix fixture (1.2.3) bumps to 1.2.4 in workflow output" {
  block="$(extract_block fix)"
  echo "$block" | grep -q "NEW_VERSION=1.2.4"
}

@test "breaking fixture (1.2.3) bumps to 2.0.0 in workflow output" {
  block="$(extract_block breaking)"
  echo "$block" | grep -q "NEW_VERSION=2.0.0"
}

@test "pkgjson fixture (2.4.0) bumps to 2.5.0 in workflow output" {
  block="$(extract_block pkgjson)"
  echo "$block" | grep -q "NEW_VERSION=2.5.0"
  echo "$block" | grep -q '"version": "2.5.0"'
}

@test "changelog entries are emitted (Features / Fixes / BREAKING CHANGES)" {
  grep -q "### Features"          "$ACT_RESULT"
  grep -q "### Fixes"             "$ACT_RESULT"
  grep -q "### BREAKING CHANGES"  "$ACT_RESULT"
}
