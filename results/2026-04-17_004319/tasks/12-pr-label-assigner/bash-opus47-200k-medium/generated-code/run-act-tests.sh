#!/usr/bin/env bash
# run-act-tests.sh
#
# End-to-end test harness. For each declared test case we:
#   1. copy the project into a clean temp git repo
#   2. overwrite fixtures/{rules.conf,files.txt} with case fixtures
#   3. commit and run `act push --rm`
#   4. append the full output to act-result.txt (delimited)
#   5. assert act exited 0, the workflow reports "Job succeeded",
#      and the expected LABELS_RESULT line is present verbatim

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="$HERE/act-result.txt"
: > "$RESULT_FILE"

pass=0
fail=0

run_case() {
  local name=$1 rules=$2 files=$3 expected=$4

  printf '\n========================================\n' | tee -a "$RESULT_FILE"
  printf 'CASE: %s\n' "$name"                          | tee -a "$RESULT_FILE"
  printf '========================================\n'  | tee -a "$RESULT_FILE"

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  # Copy project files (exclude .git and any previous act artefacts).
  rsync -a --exclude='.git' --exclude='act-result.txt' "$HERE/" "$tmp/"

  # Override fixtures for this case.
  printf '%s\n' "$rules" > "$tmp/fixtures/rules.conf"
  printf '%s\n' "$files" > "$tmp/fixtures/files.txt"

  (
    cd "$tmp" || exit 1
    git init -q -b main
    git config user.email "ci@example.com"
    git config user.name "ci"
    git add .
    git commit -q -m "case: $name"
  )

  local out status
  out=$(cd "$tmp" && act push --rm --pull=false 2>&1)
  status=$?

  printf '%s\n' "$out" >> "$RESULT_FILE"
  printf '[exit=%d]\n' "$status" >> "$RESULT_FILE"

  local ok=1
  if [[ $status -ne 0 ]]; then
    echo "FAIL [$name]: act exited $status"; ok=0
  fi
  if ! grep -q 'Job succeeded' <<<"$out"; then
    echo "FAIL [$name]: no 'Job succeeded' line in act output"; ok=0
  fi
  if ! grep -qF "LABELS_RESULT=$expected" <<<"$out"; then
    echo "FAIL [$name]: expected LABELS_RESULT=$expected not found in output"
    ok=0
  fi
  if (( ok )); then
    echo "PASS [$name]"
    ((pass++))
  else
    ((fail++))
  fi
}

# ---- Test cases ----

# Case 1: docs only. Expect single "documentation" label.
run_case "docs-only" \
  "docs/**|documentation|90" \
  "docs/readme.md
docs/guide/advanced.md" \
  "documentation"

# Case 2: conflict with priority. api(10) should come before tests(50).
run_case "api-and-tests-with-priority" \
  "src/api/**|api|10
**/*.test.*|tests|50" \
  "src/api/users.go
src/api/users.test.go" \
  "api,tests"

# Case 3: three labels with mixed priorities.
run_case "all-three-priority-sorted" \
  "src/api/**|api|10
**/*.test.*|tests|50
docs/**|documentation|90" \
  "src/api/users.go
src/api/users.test.go
docs/guide.md
README.md" \
  "api,tests,documentation"

echo
echo "====== summary ======"
echo "pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
