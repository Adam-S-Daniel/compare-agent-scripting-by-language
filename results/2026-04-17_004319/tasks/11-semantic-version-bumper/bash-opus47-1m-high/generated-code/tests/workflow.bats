#!/usr/bin/env bats
# Workflow structure + end-to-end CI tests.
#
# These tests:
#   1. Validate the workflow YAML structurally and via actionlint.
#   2. Run the workflow itself through `act` for several fixture inputs and
#      assert on EXACT expected values in the output.
#
# Each `act push` invocation runs in a fresh temp git repo seeded with the
# project files + that case's fixture data. Output from every run is appended
# to ../act-result.txt.

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW="${PROJECT_ROOT}/.github/workflows/semantic-version-bumper.yml"
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

setup_file() {
  : > "${PROJECT_ROOT}/act-result.txt"
}

# --- structural / static checks -------------------------------------------

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "workflow references the bump script" {
  grep -q 'bump-version.sh' "$WORKFLOW"
  [ -f "${PROJECT_ROOT}/bump-version.sh" ]
}

@test "workflow references the unit-test file" {
  grep -q 'tests/bump.bats' "$WORKFLOW"
  [ -f "${PROJECT_ROOT}/tests/bump.bats" ]
}

@test "workflow declares expected triggers" {
  # push, pull_request, workflow_dispatch, schedule must all be present.
  grep -qE '^on:' "$WORKFLOW"
  grep -qE '^[[:space:]]+push:' "$WORKFLOW"
  grep -qE '^[[:space:]]+pull_request:' "$WORKFLOW"
  grep -qE '^[[:space:]]+workflow_dispatch:' "$WORKFLOW"
  grep -qE '^[[:space:]]+schedule:' "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
  grep -q 'actions/checkout@v4' "$WORKFLOW"
}

@test "workflow declares permissions" {
  grep -q '^permissions:' "$WORKFLOW"
}

@test "actionlint passes on the workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# --- helpers --------------------------------------------------------------

# Stage a temp directory containing everything the workflow needs to run
# under `act`. Echoes the path of the staged dir.
stage_repo() {
  local fixture="$1" version_seed="$2" fixture_kind="$3"
  local stage
  stage="$(mktemp -d)"

  # Project files the workflow needs.
  cp "${PROJECT_ROOT}/bump-version.sh" "$stage/"
  mkdir -p "$stage/.github/workflows" "$stage/tests"
  cp "$WORKFLOW" "$stage/.github/workflows/"
  cp "${PROJECT_ROOT}/tests/bump.bats" "$stage/tests/"
  cp "${PROJECT_ROOT}/.actrc" "$stage/" 2>/dev/null || true

  # Per-case data.
  cp "${PROJECT_ROOT}/fixtures/${fixture}" "$stage/commits.txt"

  if [[ "$fixture_kind" == "package" ]]; then
    cat > "$stage/package.json" <<JSON
{
  "name": "demo",
  "version": "${version_seed}"
}
JSON
  else
    printf '%s\n' "$version_seed" > "$stage/VERSION"
  fi

  # Init a git repo so `act push` has a SHA to work with.
  ( cd "$stage" \
    && git init -q \
    && git config user.email ci@example.com \
    && git config user.name ci \
    && git add -A \
    && git commit -q -m "seed" )

  printf '%s\n' "$stage"
}

# Run the workflow under act. Appends labelled output to act-result.txt.
run_act_case() {
  local label="$1" stage="$2"
  {
    printf '\n========== CASE: %s ==========\n' "$label"
    printf 'stage dir: %s\n' "$stage"
  } >> "$ACT_RESULT"

  # The workflow auto-detects VERSION vs package.json, so a plain `act push`
  # against the staged repo is enough.
  ( cd "$stage" && act push --rm ) \
    >> "$ACT_RESULT" 2>&1
}

# Extract the section of act-result.txt belonging to the most recent case
# matching $label. Used for per-case assertions.
case_section() {
  local label="$1"
  awk -v label="$label" '
    $0 ~ ("========== CASE: " label " ==========") { capture=1; next }
    /^========== CASE: / { capture=0 }
    capture { print }
  ' "$ACT_RESULT"
}

# --- end-to-end act runs --------------------------------------------------

@test "act run: feat commits bump 1.1.0 -> 1.2.0 (minor)" {
  local stage
  stage="$(stage_repo commits-feat.txt 1.1.0 plain)"
  run_act_case "feat-minor" "$stage"
  local section
  section="$(case_section feat-minor)"
  [[ "$section" == *"Job succeeded"* ]]
  [[ "$section" == *"Computed new version: 1.2.0"* ]]
  [[ "$section" == *"NEXT_VERSION=1.2.0"* ]]
  rm -rf "$stage"
}

@test "act run: fix-only commits bump 2.4.4 -> 2.4.5 (patch)" {
  local stage
  stage="$(stage_repo commits-fix.txt 2.4.4 plain)"
  run_act_case "fix-patch" "$stage"
  local section
  section="$(case_section fix-patch)"
  [[ "$section" == *"Job succeeded"* ]]
  [[ "$section" == *"Computed new version: 2.4.5"* ]]
  [[ "$section" == *"NEXT_VERSION=2.4.5"* ]]
  rm -rf "$stage"
}

@test "act run: breaking change in package.json bumps 0.9.4 -> 1.0.0 (major)" {
  local stage
  stage="$(stage_repo commits-breaking.txt 0.9.4 package)"
  run_act_case "breaking-major" "$stage"
  local section
  section="$(case_section breaking-major)"
  [[ "$section" == *"Job succeeded"* ]]
  [[ "$section" == *"Computed new version: 1.0.0"* ]]
  [[ "$section" == *"NEXT_VERSION=1.0.0"* ]]
  # Verify the package.json got the new version (printed by "Show files" step).
  [[ "$section" == *'"version": "1.0.0"'* ]]
  rm -rf "$stage"
}

@test "act-result.txt exists and contains all three case headers" {
  [ -f "$ACT_RESULT" ]
  grep -q 'CASE: feat-minor' "$ACT_RESULT"
  grep -q 'CASE: fix-patch' "$ACT_RESULT"
  grep -q 'CASE: breaking-major' "$ACT_RESULT"
}
