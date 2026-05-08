#!/usr/bin/env bats
# End-to-end / pipeline tests:
#   - YAML structure assertions
#   - actionlint
#   - run the workflow with `act push --rm` for each fixture case and assert
#     on EXACT expected counts/substrings.
#
# All act output is appended to <project>/act-result.txt (delimited by case).

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
  export WORKFLOW="$REPO_ROOT/.github/workflows/secret-rotation-validator.yml"
  export ACT_RESULT="$REPO_ROOT/act-result.txt"
  : > "$ACT_RESULT"   # truncate at the start of the run
}

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORKFLOW="$REPO_ROOT/.github/workflows/secret-rotation-validator.yml"
  ACT_RESULT="$REPO_ROOT/act-result.txt"
}

# ---------- structure / static checks (fast, no docker) ----------------------

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "actionlint passes on workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
  run grep -F "uses: actions/checkout@v4" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request, schedule, workflow_dispatch triggers" {
  grep -qE '^[[:space:]]*push:'              "$WORKFLOW"
  grep -qE '^[[:space:]]*pull_request:'      "$WORKFLOW"
  grep -qE '^[[:space:]]*schedule:'          "$WORKFLOW"
  grep -qE '^[[:space:]]*workflow_dispatch:' "$WORKFLOW"
}

@test "workflow declares contents:read permission" {
  grep -qE 'contents:[[:space:]]*read' "$WORKFLOW"
}

@test "workflow references the validator script" {
  grep -q 'validate-rotation.sh' "$WORKFLOW"
  [ -x "$REPO_ROOT/validate-rotation.sh" ]
}

# ---------- helpers ----------------------------------------------------------

# Build an isolated git repo containing the project plus per-case fixture data,
# run `act push --rm` inside it, append the captured stdout/stderr to the
# project-root act-result.txt, and store the exit status in $ACT_STATUS.
run_act_case() {
  local case_name="$1" fixture="$2" warning_days="$3" now_date="$4"

  local work
  work="$(mktemp -d)"

  # Copy minimal project surface needed by the workflow.
  cp "$REPO_ROOT/validate-rotation.sh" "$work/"
  chmod +x "$work/validate-rotation.sh"
  mkdir -p "$work/.github/workflows"
  cp "$WORKFLOW" "$work/.github/workflows/"
  cp "$REPO_ROOT/.actrc" "$work/.actrc"

  # Per-case fixture + override env.
  cp "$REPO_ROOT/fixtures/$fixture" "$work/secrets.json"
  cat > "$work/test-params.env" <<EOF
WARNING_DAYS=$warning_days
NOW_DATE=$now_date
CONFIG_FILE=secrets.json
EOF

  # Initialize a git repo (act needs a real repo for `push`).
  (
    cd "$work"
    git init -q -b main
    git -c user.email=ci@example.com -c user.name=ci add -A
    git -c user.email=ci@example.com -c user.name=ci commit -q -m "case: $case_name"
  )

  {
    echo
    echo "============================================================"
    echo "ACT CASE: $case_name (fixture=$fixture warning_days=$warning_days now=$now_date)"
    echo "============================================================"
  } >> "$ACT_RESULT"

  # Run act and capture combined output. Don't fail the bats test here — the
  # caller asserts on $ACT_STATUS explicitly so we get a meaningful diagnostic.
  set +e
  ( cd "$work" && act push --rm --pull=false ) >> "$ACT_RESULT" 2>&1
  ACT_STATUS=$?
  set -e
  export ACT_STATUS

  rm -rf "$work"
}

# Slice out just the most recent case's section of act-result.txt.
last_case_output() {
  awk '/^ACT CASE: /{buf=""} {buf = buf $0 "\n"} END{printf "%s", buf}' "$ACT_RESULT"
}

# ---------- act-driven fixture cases -----------------------------------------

@test "act case: mixed.json -> expired=2 warning=1 ok=1, expected names present" {
  run_act_case "mixed-2026-05-07-w14" "mixed.json" "14" "2026-05-07"
  [ "$ACT_STATUS" -eq 0 ]
  out="$(last_case_output)"

  # Every job must succeed.
  echo "$out" | grep -q "Job succeeded"

  # Validator output appears via `tee`.
  echo "$out" | grep -q "# Secret Rotation Report"
  echo "$out" | grep -q "## Expired"
  echo "$out" | grep -q "## Warning"
  echo "$out" | grep -q "## OK"

  # Exact expected secret names per status.
  echo "$out" | grep -q "OLD_API_KEY"
  echo "$out" | grep -q "ANCIENT_TOKEN"
  echo "$out" | grep -q "SOON_TOKEN"
  echo "$out" | grep -q "FRESH_KEY"

  # Exact summary counts (mathematically derived from fixture).
  echo "$out" | grep -q "ROTATION_SUMMARY expired=2 warning=1 ok=1"
}

@test "act case: all-ok.json -> expired=0 warning=0 ok=2" {
  run_act_case "all-ok-2026-05-07-w14" "all-ok.json" "14" "2026-05-07"
  [ "$ACT_STATUS" -eq 0 ]
  out="$(last_case_output)"

  echo "$out" | grep -q "Job succeeded"
  echo "$out" | grep -q "WEB_SESSION_KEY"
  echo "$out" | grep -q "DB_PASSWORD"
  echo "$out" | grep -q "ROTATION_SUMMARY expired=0 warning=0 ok=2"
}
