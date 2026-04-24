#!/usr/bin/env bash
# Test harness: runs the GitHub Actions workflow under `act` for a series of
# test cases. Each case sets up a temp git repo containing the project plus
# that case's fixture files, runs `act push --rm`, appends the output to
# act-result.txt, and asserts on exit code, "Job succeeded", and the exact
# expected label list.
#
# Limited to 3 act runs (the number of test cases) per task instructions.
set -u

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="$PROJECT_DIR/act-result.txt"
: > "$RESULT_FILE"

PASSED=0
FAILED=0
CASE_NUM=0

# run_case <name> <rules_json_inline> <files_inline> <expected_labels_csv>
run_case() {
  local name="$1"
  local rules="$2"
  local files="$3"
  local expected="$4"

  CASE_NUM=$((CASE_NUM + 1))
  echo "===== CASE $CASE_NUM: $name =====" | tee -a "$RESULT_FILE"

  local tmp
  tmp="$(mktemp -d)"
  # Copy project files needed by the workflow.
  cp -r "$PROJECT_DIR/.github" "$tmp/"
  [ -f "$PROJECT_DIR/.actrc" ] && cp "$PROJECT_DIR/.actrc" "$tmp/"
  cp -r "$PROJECT_DIR/tests" "$tmp/"
  cp "$PROJECT_DIR/label_assigner.py" "$tmp/"
  mkdir -p "$tmp/fixtures"
  printf '%s' "$rules" > "$tmp/fixtures/rules.json"
  printf '%s' "$files" > "$tmp/fixtures/changed_files.txt"

  ( cd "$tmp" && git init -q && git add -A && \
    git -c user.email=t@t -c user.name=t commit -q -m init )

  local out
  out="$(cd "$tmp" && act push --rm --pull=false --container-architecture linux/amd64 2>&1)"
  local rc=$?
  echo "$out" >> "$RESULT_FILE"
  echo "----- act exit code: $rc -----" >> "$RESULT_FILE"

  # Extract labels printed between the BEGIN/END markers.
  local labels
  labels="$(echo "$out" | awk '/BEGIN LABELS/{flag=1;next} /END LABELS/{flag=0} flag' \
            | sed -E 's/^[^|]*\|[[:space:]]*//' | sed -E 's/\r$//' \
            | grep -v '^$' | paste -sd, -)"

  echo "extracted labels: '$labels'  expected: '$expected'" | tee -a "$RESULT_FILE"

  local ok=1
  if [ "$rc" -ne 0 ]; then echo "FAIL: act exit $rc" | tee -a "$RESULT_FILE"; ok=0; fi
  if ! echo "$out" | grep -q "Job succeeded"; then
    echo "FAIL: no 'Job succeeded' in output" | tee -a "$RESULT_FILE"; ok=0
  fi
  if [ "$labels" != "$expected" ]; then
    echo "FAIL: label mismatch" | tee -a "$RESULT_FILE"; ok=0
  fi

  if [ "$ok" -eq 1 ]; then
    echo "PASS: case $CASE_NUM" | tee -a "$RESULT_FILE"
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
  rm -rf "$tmp"
}

# Case 1: docs-only changes -> single label
run_case "docs-only" \
  '{"rules":[{"pattern":"docs/**","label":"documentation","priority":1},{"pattern":"src/**","label":"source","priority":2}]}' \
  $'docs/a.md\ndocs/sub/b.md\n' \
  "documentation"

# Case 2: mixed change set, exercises priority order + multi-label
run_case "mixed-priority" \
  '{"rules":[{"pattern":"docs/**","label":"documentation","priority":1},{"pattern":"src/api/**","label":"api","priority":2},{"pattern":"src/**","label":"source","priority":3},{"pattern":"**/*.test.*","label":"tests","priority":4}]}' \
  $'docs/intro.md\nsrc/api/v1/users.py\nsrc/api/v1/users.test.py\nsrc/db/conn.py\n' \
  "documentation,api,source,tests"

# Case 3: no rule matches -> empty label set
run_case "no-matches" \
  '{"rules":[{"pattern":"docs/**","label":"documentation","priority":1}]}' \
  $'src/a.py\nsrc/b.py\n' \
  ""

echo ""
echo "===== SUMMARY: $PASSED passed, $FAILED failed =====" | tee -a "$RESULT_FILE"
[ "$FAILED" -eq 0 ]
