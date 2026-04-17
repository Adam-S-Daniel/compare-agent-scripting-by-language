#!/usr/bin/env bash
# Act-based end-to-end harness.
#
# For each test case:
#   1. Build a temp git repo containing project files + the case's fixture as
#      input.tsv and a config.env that overrides the workflow's policy env vars.
#   2. Run `act push --rm` inside that repo.
#   3. Capture output, assert exit 0, assert exact expected plan summary values,
#      and assert every job shows "Job succeeded".
#   4. Append the full output to act-result.txt in the original directory.
#
# Also runs workflow structure checks and actionlint.
#
# Stops at the first failure to keep the output readable.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "${HERE}"

RESULT_FILE="${HERE}/act-result.txt"
: > "${RESULT_FILE}"   # truncate

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

section() {
  printf '\n========== %s ==========\n' "$*" | tee -a "${RESULT_FILE}"
}

# ---------- workflow structure tests ----------

section "Structure: file exists"
WF=".github/workflows/artifact-cleanup-script.yml"
[[ -f "${WF}" ]] || fail "workflow file missing"
echo "ok: ${WF}" | tee -a "${RESULT_FILE}"

section "Structure: references cleanup.sh and test/cleanup.bats"
grep -q 'cleanup.sh' "${WF}" || fail "workflow does not reference cleanup.sh"
grep -q 'test/cleanup.bats' "${WF}" || fail "workflow does not reference test/cleanup.bats"
[[ -f cleanup.sh ]] || fail "cleanup.sh missing"
[[ -f test/cleanup.bats ]] || fail "test/cleanup.bats missing"
echo "ok: referenced files exist" | tee -a "${RESULT_FILE}"

section "Structure: triggers, jobs, permissions"
# Lightweight structural checks via grep — enough to catch regressions without
# pulling in a YAML parser.
for tok in 'push:' 'pull_request:' 'schedule:' 'workflow_dispatch:' \
           'permissions:' 'contents: read' \
           'lint:' 'test:' 'plan:' 'needs: lint' 'needs: test'; do
  grep -q "${tok}" "${WF}" || fail "workflow missing expected token: ${tok}"
done
echo "ok: triggers/jobs/permissions present" | tee -a "${RESULT_FILE}"

section "Structure: actionlint"
actionlint "${WF}" 2>&1 | tee -a "${RESULT_FILE}"
# actionlint exits 0 when clean
echo "ok: actionlint exit 0" | tee -a "${RESULT_FILE}"

# ---------- act test cases ----------
#
# Each case: name | fixture tsv | policy env overrides | expected retained |
#            expected deleted | expected reclaimed bytes

run_act_case() {
  local case_name="$1" fixture="$2" overrides="$3" \
        want_retained="$4" want_deleted="$5" want_reclaimed="$6"

  section "ACT CASE: ${case_name}"

  local tmp
  tmp="$(mktemp -d)"
  # Copy project files we need inside the temp repo.
  cp -r "${HERE}/cleanup.sh" "${HERE}/test" "${HERE}/.github" "${HERE}/.actrc" "${tmp}/"
  # Put the case's fixture at the path the workflow reads.
  cp "${HERE}/test/fixtures/${fixture}" "${tmp}/input.tsv"
  # Drop the per-case overrides file (sourced into $GITHUB_ENV by the workflow).
  printf '%s\n' "${overrides}" > "${tmp}/config.env"

  (
    cd "${tmp}"
    git init -q
    git -c user.email=ci@example.com -c user.name=ci add -A
    git -c user.email=ci@example.com -c user.name=ci commit -q -m "case ${case_name}"
  )

  local out
  # --rm cleans up containers; --container-architecture keeps WSL happy.
  if ! out="$(cd "${tmp}" && act push --rm --pull=false --container-architecture linux/amd64 2>&1)"; then
    echo "${out}" | tee -a "${RESULT_FILE}"
    rm -rf "${tmp}"
    fail "act exited non-zero for case ${case_name}"
  fi

  echo "${out}" | tee -a "${RESULT_FILE}"
  rm -rf "${tmp}"

  # Assertions against the plan summary.
  local want_r="Artifacts retained: ${want_retained}"
  local want_d="Artifacts deleted: ${want_deleted}"
  local want_s="Space reclaimed: ${want_reclaimed} bytes"
  [[ "${out}" == *"${want_r}"* ]] || fail "${case_name}: expected '${want_r}'"
  [[ "${out}" == *"${want_d}"* ]] || fail "${case_name}: expected '${want_d}'"
  [[ "${out}" == *"${want_s}"* ]] || fail "${case_name}: expected '${want_s}'"

  # Assert every job reported success. Act prints "Job succeeded" per job.
  local succ_count
  succ_count="$(printf '%s\n' "${out}" | grep -c 'Job succeeded' || true)"
  (( succ_count >= 3 )) || fail "${case_name}: expected >=3 'Job succeeded' lines, saw ${succ_count}"

  echo "ok: ${case_name} (retained=${want_retained} deleted=${want_deleted} reclaimed=${want_reclaimed})" | tee -a "${RESULT_FILE}"
}

# Case 1: max-age policy on aged.tsv (3 rows; 1 ancient > 30 days).
run_act_case "max-age-30d" \
  "aged.tsv" \
  "MAX_AGE_DAYS=30" \
  2 1 1000

# Case 2: keep-latest on per-workflow.tsv (6 rows across 2 workflows; keep 2 each).
run_act_case "keep-latest-2" \
  "per-workflow.tsv" \
  "KEEP_LATEST=2" \
  4 2 200

# Case 3: combined max-age + keep-latest on combined.tsv (5 rows).
run_act_case "combined" \
  "combined.tsv" \
  $'MAX_AGE_DAYS=30\nKEEP_LATEST=1' \
  2 3 1500

section "DONE"
echo "All act test cases passed." | tee -a "${RESULT_FILE}"
