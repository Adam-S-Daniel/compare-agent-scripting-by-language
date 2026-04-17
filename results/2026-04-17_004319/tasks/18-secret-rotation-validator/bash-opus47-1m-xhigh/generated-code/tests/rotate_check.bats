#!/usr/bin/env bats
# Test suite for the secret-rotation-validator.
#
# Per the task requirements, EVERY test case is executed through the GitHub
# Actions workflow via `act`. We therefore do not invoke the script directly
# here; instead we:
#   1. Validate the workflow's YAML structure and actionlint cleanliness.
#   2. Launch `act push --rm` (at most twice — markdown and JSON modes),
#      capturing each run's output into act-result.txt.
#   3. Parse that captured act output to assert exact expected values
#      produced by the workflow's invocation of rotate-check.sh.

# --- test-run state files (shared across tests via global paths) ------------

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/secret-rotation-validator.yml"
SCRIPT_FILE="$ROOT_DIR/rotate-check.sh"
ACT_RESULT="$ROOT_DIR/act-result.txt"
ACT_MARKDOWN_SECTION="$ROOT_DIR/.act-markdown.out"
ACT_JSON_SECTION="$ROOT_DIR/.act-json.out"

# Helper: reconstruct the literal stdout+stderr of the workflow steps by
# stripping act's `[Workflow/Job]   | ` prefix from every captured line.
# This lets us inspect the tool output (markdown or JSON) exactly as it
# would appear outside the act log framing.
strip_act_prefix() {
  # Matches lines like: `[xxx/yyy]   | some content`
  # and emits just `some content`.
  sed -E 's#^\[[^]]+\][[:space:]]+\|[[:space:]]?##'
}

# Extract the JSON block emitted by the JSON-mode workflow run. The script's
# JSON output is wrapped in <<<JSON-REPORT-BEGIN>>> / <<<JSON-REPORT-END>>>
# markers by the workflow, which are easy to grep across arbitrary act log
# framing.
extract_json_report() {
  awk '
    /<<<JSON-REPORT-BEGIN>>>/ { f=1; next }
    /<<<JSON-REPORT-END>>>/   { f=0; next }
    f { print }
  ' | strip_act_prefix
}

# Helper: setup a fresh temp git repo containing the project files and a
# fixture pointer, then run `act push --rm` there.  Output is captured
# to the caller-provided destination file.
run_act_with_fixture() {
  local fixture_rel="$1"      # path (relative to project) of fixture to use
  local output_format="$2"    # markdown | json
  local dest_file="$3"        # where to store act's full output

  local workdir
  workdir="$(mktemp -d)"
  # Copy project sources into the temp repo.
  cp -r "$ROOT_DIR/rotate-check.sh" "$workdir/"
  cp -r "$ROOT_DIR/.github" "$workdir/"
  cp -r "$ROOT_DIR/fixtures" "$workdir/"
  cp "$ROOT_DIR/.actrc" "$workdir/.actrc"

  # Write a tiny config file pointing at the chosen fixture so the workflow
  # reads a stable, known path.  This is the only piece of per-case data.
  printf 'FIXTURE=%s\nFORMAT=%s\nTODAY=2026-04-17\nWARNING_DAYS=14\n' \
    "$fixture_rel" "$output_format" > "$workdir/rotation.env"

  (
    cd "$workdir"
    git init -q
    git add -A
    git -c user.email=ci@example.com -c user.name=ci commit -q -m 'init'
    # Intentionally do NOT use --quiet: we rely on act's "Job succeeded"
    # status line to verify the job state.
    set +e
    act push --rm >"$dest_file" 2>&1
    local rc=$?
    set -e
    echo "__ACT_EXIT__=$rc" >>"$dest_file"
  )
}

# ---------------------------------------------------------------------------
# Workflow structure tests (no act invocation needed — fast).
# ---------------------------------------------------------------------------

@test "workflow file exists at expected path" {
  [ -f "$WORKFLOW_FILE" ]
}

@test "script file exists and is executable" {
  [ -x "$SCRIPT_FILE" ]
}

@test "workflow references rotate-check.sh" {
  grep -q 'rotate-check.sh' "$WORKFLOW_FILE"
}

@test "workflow triggers include push, pull_request, workflow_dispatch, schedule" {
  grep -q 'push:' "$WORKFLOW_FILE"
  grep -q 'pull_request:' "$WORKFLOW_FILE"
  grep -q 'workflow_dispatch:' "$WORKFLOW_FILE"
  grep -q 'schedule:' "$WORKFLOW_FILE"
}

@test "workflow declares explicit contents: read permission" {
  grep -qE 'contents:[[:space:]]+read' "$WORKFLOW_FILE"
}

@test "workflow uses actions/checkout@v4" {
  grep -q 'actions/checkout@v4' "$WORKFLOW_FILE"
}

@test "actionlint passes on the workflow" {
  run actionlint "$WORKFLOW_FILE"
  [ "$status" -eq 0 ]
}

@test "script passes shellcheck" {
  run shellcheck "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# act integration tests.
#
# We keep the two act runs isolated (one markdown, one JSON) and cache their
# output to per-run section files so downstream assertion tests don't need
# to re-invoke act.  act-result.txt is the full, delimited record of both
# runs as required by the task spec.
# ---------------------------------------------------------------------------

@test "act run 1 of 2 (markdown, mixed fixture) — job succeeds" {
  # Reset shared artifact before first act run.
  : >"$ACT_RESULT"

  run_act_with_fixture "fixtures/mixed.json" "markdown" "$ACT_MARKDOWN_SECTION"
  {
    echo "===== CASE: markdown, fixture=mixed.json ====="
    cat "$ACT_MARKDOWN_SECTION"
    echo
  } >>"$ACT_RESULT"

  grep -q '__ACT_EXIT__=0' "$ACT_MARKDOWN_SECTION"
  grep -q 'Job succeeded' "$ACT_MARKDOWN_SECTION"
}

@test "markdown output contains expected header and summary counts" {
  # Strip the act log prefix first so the markdown body is inspected verbatim.
  local body
  body=$(strip_act_prefix < "$ACT_MARKDOWN_SECTION")
  echo "$body" | grep -qF '# Secret Rotation Report'
  echo "$body" | grep -qF 'Generated: 2026-04-17'
  echo "$body" | grep -qF -- '- Expired: 2'
  echo "$body" | grep -qF -- '- Warning: 1'
  echo "$body" | grep -qF -- '- OK: 1'
}

@test "markdown output lists db-password as expired with exact days_overdue 381" {
  local body
  body=$(strip_act_prefix < "$ACT_MARKDOWN_SECTION")
  echo "$body" | grep -qF '| db-password | 2025-01-01 | 90 | 381 | postgres, analytics |'
}

@test "markdown output lists api-token as expired with exact days_overdue 6" {
  local body
  body=$(strip_act_prefix < "$ACT_MARKDOWN_SECTION")
  echo "$body" | grep -qF '| api-token | 2026-01-01 | 100 | 6 | api-gateway |'
}

@test "markdown output lists jwt-secret as warning with exact days_until_expiry 8" {
  local body
  body=$(strip_act_prefix < "$ACT_MARKDOWN_SECTION")
  echo "$body" | grep -qF '| jwt-secret | 2026-01-25 | 90 | 8 | auth-service |'
}

@test "markdown output lists oauth-key as ok with exact days_until_expiry 74" {
  local body
  body=$(strip_act_prefix < "$ACT_MARKDOWN_SECTION")
  echo "$body" | grep -qF '| oauth-key | 2026-04-01 | 90 | 74 | oauth-provider |'
}

@test "markdown output has the three urgency sections in correct order" {
  local body exp_line warn_line ok_line
  body=$(strip_act_prefix < "$ACT_MARKDOWN_SECTION")
  exp_line=$(echo "$body" | grep -n '## Expired' | head -1 | cut -d: -f1)
  warn_line=$(echo "$body" | grep -n '## Warning' | head -1 | cut -d: -f1)
  ok_line=$(echo "$body" | grep -n '## OK' | head -1 | cut -d: -f1)
  [ -n "$exp_line" ] && [ -n "$warn_line" ] && [ -n "$ok_line" ]
  [ "$exp_line" -lt "$warn_line" ]
  [ "$warn_line" -lt "$ok_line" ]
}

@test "act run 2 of 2 (JSON, mixed fixture) — job succeeds" {
  run_act_with_fixture "fixtures/mixed.json" "json" "$ACT_JSON_SECTION"
  {
    echo "===== CASE: json, fixture=mixed.json ====="
    cat "$ACT_JSON_SECTION"
    echo
  } >>"$ACT_RESULT"

  grep -q '__ACT_EXIT__=0' "$ACT_JSON_SECTION"
  grep -q 'Job succeeded' "$ACT_JSON_SECTION"
}

@test "JSON output parses cleanly and has expected top-level keys" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ -n "$json" ]
  echo "$json" | jq -e 'has("generated") and has("warning_window_days") and has("summary") and has("expired") and has("warning") and has("ok")' >/dev/null
}

@test "JSON summary contains exact urgency counts" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ "$(echo "$json" | jq -r '.summary.expired')" = "2" ]
  [ "$(echo "$json" | jq -r '.summary.warning')" = "1" ]
  [ "$(echo "$json" | jq -r '.summary.ok')" = "1" ]
}

@test "JSON expired list contains db-password with exact days_overdue 381" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ "$(echo "$json" | jq -r '.expired[] | select(.name=="db-password") | .days_overdue')" = "381" ]
}

@test "JSON expired list contains api-token with exact days_overdue 6" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ "$(echo "$json" | jq -r '.expired[] | select(.name=="api-token") | .days_overdue')" = "6" ]
}

@test "JSON warning list contains jwt-secret with exact days_until_expiry 8" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ "$(echo "$json" | jq -r '.warning[] | select(.name=="jwt-secret") | .days_until_expiry')" = "8" ]
}

@test "JSON ok list contains oauth-key with exact days_until_expiry 74" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ "$(echo "$json" | jq -r '.ok[] | select(.name=="oauth-key") | .days_until_expiry')" = "74" ]
}

@test "JSON required_by is a JSON array (list), not a string" {
  local json
  json=$(extract_json_report < "$ACT_JSON_SECTION")
  [ "$(echo "$json" | jq -r '.expired[] | select(.name=="db-password") | .required_by | type')" = "array" ]
  [ "$(echo "$json" | jq -r '.expired[] | select(.name=="db-password") | .required_by | length')" = "2" ]
}

@test "act-result.txt exists and contains both case delimiters" {
  [ -f "$ACT_RESULT" ]
  grep -q '===== CASE: markdown' "$ACT_RESULT"
  grep -q '===== CASE: json' "$ACT_RESULT"
}
