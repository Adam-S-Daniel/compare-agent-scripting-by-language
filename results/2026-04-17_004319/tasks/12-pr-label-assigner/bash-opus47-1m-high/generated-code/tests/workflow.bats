#!/usr/bin/env bats

# End-to-end + structural tests for the GitHub Actions workflow.
#
# The act harness runs every test case through `act push --rm` against a
# temporary git repo seeded with this project + the test case's fixture data.
# Every act run's full stdout/stderr is appended to act-result.txt.
#
# We intentionally cap to 3 act runs (per task instructions), so we use one
# multi-fixture matrix-style approach: a single workflow + 3 different fixture
# sets committed to 3 distinct temp repos.

PROJECT_ROOT="${BATS_TEST_DIRNAME%/tests}"
ACT_RESULT_FILE="${PROJECT_ROOT}/act-result.txt"
WORKFLOW="${PROJECT_ROOT}/.github/workflows/pr-label-assigner.yml"

setup_file() {
  : > "$ACT_RESULT_FILE"
}

# --- structural / lint tests (no act) ---------------------------------------

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "actionlint passes on the workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "workflow declares push, pull_request and workflow_dispatch triggers" {
  run grep -E '^\s*(push|pull_request|workflow_dispatch):' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"push:"* ]]
  [[ "$output" == *"pull_request:"* ]]
  [[ "$output" == *"workflow_dispatch:"* ]]
}

@test "workflow uses actions/checkout@v4" {
  run grep -F 'actions/checkout@v4' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow references the script file (which exists)" {
  run grep -F 'pr-label-assigner.sh' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_ROOT/pr-label-assigner.sh" ]
}

@test "workflow declares restrictive permissions (contents: read)" {
  run grep -E 'contents:\s*read' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# --- act runs ---------------------------------------------------------------

# Helper: create a temp git repo populated with project files + a custom
# fixtures/files.txt + fixtures/labels.conf, then run `act push --rm`.
# Sets globals: $repo_dir, $act_log, $act_status.
run_act_case() {
  local case_name="$1"
  local files_content="$2"
  local labels_content="$3"

  repo_dir="$(mktemp -d)"
  # Copy required project files into the temp repo.
  cp -r "$PROJECT_ROOT/.github" "$repo_dir/"
  cp -r "$PROJECT_ROOT/tests"   "$repo_dir/"
  cp    "$PROJECT_ROOT/pr-label-assigner.sh" "$repo_dir/"
  cp    "$PROJECT_ROOT/.actrc" "$repo_dir/" 2>/dev/null || true
  mkdir -p "$repo_dir/fixtures"
  printf '%s' "$files_content"  > "$repo_dir/fixtures/files.txt"
  printf '%s' "$labels_content" > "$repo_dir/fixtures/labels.conf"

  # Init git repo (act needs it).
  (
    cd "$repo_dir"
    git init -q
    git config user.email "act@example.com"
    git config user.name  "act"
    git add -A
    git commit -q -m "fixture: $case_name"
  )

  act_log="$(mktemp)"
  (
    cd "$repo_dir"
    act push --rm
  ) >"$act_log" 2>&1
  act_status=$?

  {
    echo
    echo "=================================================================="
    echo "ACT CASE: $case_name"
    echo "exit status: $act_status"
    echo "fixtures/files.txt:"
    sed 's/^/    /' "$repo_dir/fixtures/files.txt"
    echo "fixtures/labels.conf:"
    sed 's/^/    /' "$repo_dir/fixtures/labels.conf"
    echo "------------------- act stdout/stderr -------------------"
    cat "$act_log"
    echo "------------------- end act output ----------------------"
  } >> "$ACT_RESULT_FILE"
}

# Extract the labels emitted between the LABELS BEGIN/END markers from $act_log.
extract_labels() {
  awk '
    /----- LABELS BEGIN -----/ { capture=1; next }
    /----- LABELS END -----/   { capture=0; next }
    capture { sub(/^.*\| /, ""); print }
  ' "$act_log"
}

# Common assertions for every act case.
assert_act_succeeded() {
  [ "$act_status" -eq 0 ]
  # Each job in the workflow should report success.
  grep -F 'Job succeeded' "$act_log"
}

@test "act case 1: docs+api+frontend+tests fixture" {
  files=$'docs/intro.md\nsrc/api/users.go\nsrc/web/app.tsx\nsrc/web/app.test.tsx\n'
  conf=$'docs/**:documentation\nsrc/api/**:api,backend\nsrc/web/**:frontend\n**/*.test.*:tests\n**/*.md:documentation\n'
  run_act_case "docs-api-frontend-tests" "$files" "$conf"

  assert_act_succeeded

  labels="$(extract_labels)"
  expected=$'api\nbackend\ndocumentation\nfrontend\ntests'
  [ "$labels" = "$expected" ]
}

@test "act case 2: only-docs fixture (single label, dedup across files)" {
  files=$'docs/a.md\ndocs/sub/b.md\nREADME.md\n'
  conf=$'docs/**:documentation\n**/*.md:documentation\n'
  run_act_case "only-docs" "$files" "$conf"

  assert_act_succeeded

  labels="$(extract_labels)"
  expected=$'documentation'
  [ "$labels" = "$expected" ]
}

@test "act case 3: no matching rules produces no labels" {
  files=$'src/main.c\ninclude/util.h\n'
  conf=$'docs/**:documentation\nsrc/api/**:api\n'
  run_act_case "no-matches" "$files" "$conf"

  assert_act_succeeded

  labels="$(extract_labels)"
  [ "$labels" = "" ]
}

@test "act-result.txt was written and contains all three cases" {
  [ -f "$ACT_RESULT_FILE" ]
  grep -F 'ACT CASE: docs-api-frontend-tests' "$ACT_RESULT_FILE"
  grep -F 'ACT CASE: only-docs'              "$ACT_RESULT_FILE"
  grep -F 'ACT CASE: no-matches'             "$ACT_RESULT_FILE"
}
