#!/usr/bin/env bash
#
# run-act-tests.sh
#
# End-to-end test harness: builds a temp git repo containing this project's
# files plus the bundled fixture cases, runs `act push --rm` to execute the
# pr-label-assigner workflow, captures the output to act-result.txt, and
# asserts that every fixture case produced its known-good label set.
#
# We intentionally run `act` once with all fixture cases present because the
# workflow already iterates over each case directory in its final step. That
# keeps us under the 3-run cap while still exercising every case end-to-end
# inside the GitHub Actions environment.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="${HERE}/act-result.txt"
: > "$RESULT_FILE"

log() { printf '[harness] %s\n' "$*"; }

cleanup() {
  if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

WORK="$(mktemp -d)"
log "staging temp git repo at $WORK"

# Copy only the files needed for the workflow run.
cp -R \
  "${HERE}/.actrc" \
  "${HERE}/.github" \
  "${HERE}/pr-label-assigner.sh" \
  "${HERE}/tests" \
  "${HERE}/fixtures" \
  "$WORK/"

(
  cd "$WORK"
  git init -q -b main
  git -c user.email=t@t -c user.name=t add -A
  git -c user.email=t@t -c user.name=t commit -q -m "fixtures"
)

log "running act push --rm (single invocation, all fixture cases)"
ACT_LOG="$(mktemp)"
set +e
( cd "$WORK" && act push --rm --pull=false ) >"$ACT_LOG" 2>&1
ACT_STATUS=$?
set -e

{
  printf '===== act invocation (status=%s) =====\n' "$ACT_STATUS"
  cat "$ACT_LOG"
  printf '\n===== end act invocation =====\n'
} >> "$RESULT_FILE"

if [ "$ACT_STATUS" -ne 0 ]; then
  log "FAIL: act exited with status $ACT_STATUS"
  cat "$ACT_LOG" >&2
  exit 1
fi

# Every job line should report success.
if ! grep -q "Job succeeded" "$ACT_LOG"; then
  log "FAIL: expected 'Job succeeded' marker missing from act output"
  exit 1
fi

# extract_labels <case-name> -> prints LABEL: lines (without the prefix)
extract_labels() {
  local case_name="$1"
  awk -v c="$case_name" '
    $0 ~ "=== CASE: " c " ===" { inblock = 1; next }
    inblock && $0 ~ "=== END: " c " ===" { inblock = 0 }
    inblock { print }
  ' "$ACT_LOG" \
    | sed -n 's/.*LABEL: //p'
}

assert_case() {
  local name="$1"
  shift
  local expected
  expected="$(printf '%s\n' "$@")"
  local actual
  actual="$(extract_labels "$name")"
  if [ "$expected" = "$actual" ]; then
    log "PASS: case=$name labels match"
  else
    log "FAIL: case=$name"
    log "  expected:"
    printf '%s\n' "$expected" | sed 's/^/    /' >&2
    log "  actual:"
    printf '%s\n' "$actual" | sed 's/^/    /' >&2
    exit 1
  fi
}

# ---- Expected outcomes (exact, case by case) ----
# docs-only: only docs/** matches; rules:
#   10:docs/** -> documentation, 20:src/api/** -> api, 5:**/*.test.* -> tests
# Files: docs/intro.md, docs/guide/quickstart.md, README.md
# README.md doesn't match any rule.
assert_case "docs-only" "documentation"

# api-and-tests:
#   30:src/api/** -> api      (matches src/api/users.go, src/api/users.test.go)
#   20:**/*.test.* -> tests   (matches src/api/users.test.go)
#   10:src/** -> source       (matches all three files)
#   5:docs/** -> documentation (no match)
# Sorted by descending priority: api(30), tests(20), source(10)
assert_case "api-and-tests" "api" "tests" "source"

# no-match: zero rules match, so empty label set.
assert_case "no-match"

log "all fixture cases passed"
log "act output preserved in $RESULT_FILE"
