#!/usr/bin/env bats
# Workflow structure + end-to-end (act) tests.
#
# All test cases run through the GitHub Actions pipeline via `act`. Output is
# appended to act-result.txt with clear delimiters per case.

setup_file() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT
  export WORKFLOW="$ROOT/.github/workflows/environment-matrix-generator.yml"
  export ACT_LOG="$ROOT/act-result.txt"
  : > "$ACT_LOG"   # truncate at the start of the run
}

@test "workflow YAML parses and has expected structure" {
  run python3 -c "
import yaml,sys
d=yaml.safe_load(open('$WORKFLOW'))
assert 'push' in d[True] and 'pull_request' in d[True] and 'workflow_dispatch' in d[True], d[True]
assert 'generate' in d['jobs']
steps=[s.get('uses') or s.get('name') for s in d['jobs']['generate']['steps']]
assert any('actions/checkout' in (s or '') for s in steps), steps
assert d['permissions']['contents']=='read'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]]
}

@test "workflow references existing script" {
  run grep -q 'generate-matrix.sh' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ -f "$ROOT/generate-matrix.sh" ]
}

@test "actionlint passes on workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# --- act integration: one push run per fixture -------------------------------
# Each case stages a temp repo containing the project files with a different
# fixture promoted to fixtures/default.json (the workflow's default config).
# We assert exit=0, "Job succeeded", and exact expected values in the output.

run_act_case() {
  local name="$1" fixture="$2"
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$ROOT"/. "$tmp/"
  rm -rf "$tmp/.git" "$tmp/act-result.txt"
  cp "$ROOT/fixtures/$fixture" "$tmp/fixtures/default.json"
  (
    cd "$tmp"
    git init -q
    git config user.email t@t
    git config user.name t
    git add -A
    git commit -q -m init
    act push --rm --pull=false --workflows .github/workflows/environment-matrix-generator.yml 2>&1
  ) > "$tmp/out.txt"
  local rc=$?
  {
    echo "===== CASE: $name (fixture=$fixture) rc=$rc ====="
    cat "$tmp/out.txt"
    echo "===== END: $name ====="
  } >> "$ACT_LOG"
  echo "$tmp"
  return $rc
}

@test "act: default fixture produces count=4" {
  run run_act_case "default" "default.json"
  [ "$status" -eq 0 ]
  tmp="${lines[-1]}"
  grep -q 'Job succeeded' "$tmp/out.txt"
  grep -q 'MATRIX_COUNT=4' "$tmp/out.txt"
  grep -q 'Matrix combinations: 4' "$tmp/out.txt"
}

@test "act: simple fixture produces count=2" {
  run run_act_case "simple" "simple.json"
  [ "$status" -eq 0 ]
  tmp="${lines[-1]}"
  grep -q 'Job succeeded' "$tmp/out.txt"
  grep -q 'MATRIX_COUNT=2' "$tmp/out.txt"
  grep -q '"lang": "go"' "$tmp/out.txt"
  grep -q '"lang": "rust"' "$tmp/out.txt"
}

@test "act-result.txt exists and contains both cases" {
  [ -f "$ACT_LOG" ]
  grep -q 'CASE: default' "$ACT_LOG"
  grep -q 'CASE: simple' "$ACT_LOG"
}
