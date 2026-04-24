#!/usr/bin/env bash
# run-act-tests.sh - Drives the dependency-license-checker workflow through
# `act` with multiple fixture manifests and asserts exact expected output.
#
# For each case: stage a temp git repo containing the project + that case's
# manifest content, run `act push --rm`, append the captured output to
# act-result.txt (with clear delimiters), then assert:
#   * act exited 0 for the workflow run itself
#   * each job reports "Job succeeded"
#   * the captured output contains the exact expected substring(s)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_FILE="${PROJECT_DIR}/act-result.txt"
: > "$RESULT_FILE"

# Copy the project minus ephemeral artifacts into a fresh temp git repo so
# `act push` treats the workspace as a clean commit.
setup_case_repo() {
  local casedir="$1" manifest_content="$2"
  mkdir -p "$casedir"
  # Copy the working tree, excluding .git and the result file itself.
  tar -C "$PROJECT_DIR" \
      --exclude='./.git' \
      --exclude='./act-result.txt' \
      --exclude='./act.out' \
      -cf - . | tar -C "$casedir" -xf -
  printf '%s' "$manifest_content" > "$casedir/fixtures/sample-manifest.txt"
  (
    cd "$casedir"
    git init -q -b main
    git config user.email test@example.com
    git config user.name test
    git add -A
    git commit -qm "test: seed fixtures"
  )
}

fail() {
  echo "ASSERTION FAILED: $*" >&2
  exit 1
}

run_case() {
  local name="$1" manifest_content="$2"
  shift 2
  local expected=("$@")

  local casedir
  casedir="$(mktemp -d)"
  trap 'rm -rf "$casedir"' RETURN
  setup_case_repo "$casedir" "$manifest_content"

  {
    echo ""
    echo "================================================================"
    echo "TEST CASE: $name"
    echo "MANIFEST:"
    echo "$manifest_content"
    echo "----------------------------------------------------------------"
  } >> "$RESULT_FILE"

  local case_out="$casedir/act.out"
  set +e
  ( cd "$casedir" && act push --rm --pull=false ) >"$case_out" 2>&1
  local rc=$?
  set -e
  {
    cat "$case_out"
    echo ""
    echo "ACT_EXIT_CODE: $rc"
    echo "================================================================"
  } >> "$RESULT_FILE"

  [[ $rc -eq 0 ]] || fail "[$name] act exited with $rc"

  # Assert each job succeeded.
  grep -q "Job succeeded" "$case_out" \
    || fail "[$name] no 'Job succeeded' lines in output"
  local jobs_ok
  jobs_ok="$(grep -c "Job succeeded" "$case_out" || true)"
  (( jobs_ok >= 2 )) || fail "[$name] expected >=2 successful jobs, got $jobs_ok"

  for pat in "${expected[@]}"; do
    grep -qF "$pat" "$case_out" \
      || fail "[$name] expected substring not found: $pat"
  done

  echo "PASS: $name"
}

# ----- Test cases -----

# Case 1: all-approved manifest -> compliance-check emits APPROVED entries
# and a Total: 2 / Approved: 2 summary.
run_case "all-approved" \
"lodash==4.17.21
express==4.18.0
" \
  "lodash@4.17.21: MIT - APPROVED" \
  "express@4.18.0: MIT - APPROVED" \
  "Total: 2" \
  "Approved: 2" \
  "Denied: 0" \
  "Unknown: 0" \
  "License check exit code: 0"

# Case 2: denied license -> DENIED entry, nonzero internal exit
run_case "contains-denied" \
"lodash==4.17.21
badpkg==1.0.0
" \
  "lodash@4.17.21: MIT - APPROVED" \
  "badpkg@1.0.0: GPL-3.0 - DENIED" \
  "Total: 2" \
  "Approved: 1" \
  "Denied: 1" \
  "License check exit code: 1"

# Case 3: unknown license -> UNKNOWN entry
run_case "contains-unknown" \
"mystery==9.9.9
apache-tool==1.5.0
" \
  "mystery@9.9.9: UNKNOWN - UNKNOWN" \
  "apache-tool@1.5.0: Apache-2.0 - APPROVED" \
  "Total: 2" \
  "Approved: 1" \
  "Unknown: 1" \
  "License check exit code: 1"

echo ""
echo "All act test cases passed. Output saved to $RESULT_FILE"
