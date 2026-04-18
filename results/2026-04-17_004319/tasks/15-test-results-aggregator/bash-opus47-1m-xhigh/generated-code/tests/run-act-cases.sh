#!/usr/bin/env bash
#
# End-to-end driver: run the GitHub Actions workflow locally via `act` for
# every test case in tests/cases/*, saving all output (delimited by case) to
# act-result.txt in the project root. This is the "expensive" half of the
# harness; tests/harness.bats validates the captured output without
# re-invoking act.
#
# Usage:
#   tests/run-act-cases.sh            # run all cases
#   tests/run-act-cases.sh case1 ...  # run only the listed cases

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACT_RESULT="${PROJECT_ROOT}/act-result.txt"

# Prepare a throwaway git repo that mirrors the project with one case's
# fixtures overlaid into results/. Echoes the repo path.
prepare_repo() {
  local case_dir="$1"
  local tmp
  tmp="$(mktemp -d)"

  tar -C "$PROJECT_ROOT" \
      --exclude='./.git' \
      --exclude='./act-result.txt' \
      --exclude='./results' \
      -cf - . \
    | tar -C "$tmp" -xf -

  mkdir -p "$tmp/results"
  cp "$case_dir"/* "$tmp/results/"

  (
    cd "$tmp"
    git init -q
    git config user.email "harness@example.com"
    git config user.name  "harness"
    git add -A
    git commit -q -m "harness: case fixture"
  )
  echo "$tmp"
}

# Run act for one case and append the captured output (including a
# structured exit marker) to act-result.txt.
run_case() {
  local case_name="$1"
  local case_dir="${PROJECT_ROOT}/tests/cases/${case_name}"
  if [[ ! -d "$case_dir" ]]; then
    echo "run-act-cases: no such case: $case_name" >&2
    return 2
  fi

  local repo rc=0
  repo="$(prepare_repo "$case_dir")"

  {
    echo "================================================================"
    echo "CASE: ${case_name}"
    echo "REPO: ${repo}"
    echo "================================================================"
  } >>"$ACT_RESULT"

  (cd "$repo" && act push --rm 2>&1) >>"$ACT_RESULT" || rc=$?

  {
    echo "----------------------------------------------------------------"
    echo "ACT_EXIT: $rc"
    echo "END CASE: ${case_name}"
    echo "================================================================"
    echo
  } >>"$ACT_RESULT"

  rm -rf "$repo"
  return "$rc"
}

main() {
  : >"$ACT_RESULT"   # truncate on each full run
  local cases=("$@")
  if [[ ${#cases[@]} -eq 0 ]]; then
    local d
    for d in "${PROJECT_ROOT}/tests/cases"/*/; do
      cases+=("$(basename "$d")")
    done
  fi
  local overall=0
  local c
  for c in "${cases[@]}"; do
    echo "=== running act for ${c} ==="
    if ! run_case "$c"; then
      echo "act failed for ${c} (exit $?)" >&2
      overall=1
    fi
  done
  return "$overall"
}

main "$@"
