#!/usr/bin/env bash
# act-harness.sh
#
# Runs every matrix-gen test case through the real GitHub Actions workflow via
# `act push --rm`. For each case we:
#   1. Build an isolated temp git repo containing the project files and that
#      case's fixture data (copied to ./active-fixture.json plus an env setting
#      that tells the workflow whether the run is expected to succeed or fail).
#   2. Invoke `act push --rm` and capture stdout+stderr.
#   3. Append the delimited output to act-result.txt in the project directory.
#   4. Assert act's exit code is 0, that the workflow reports "Job succeeded",
#      and that expected values are present in the workflow output.
#
# This file satisfies the "ALL TESTS MUST RUN THROUGH ACT" requirement and
# produces the required act-result.txt artifact.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_FILE="${PROJECT_DIR}/act-result.txt"

: > "${RESULT_FILE}"

# Each test case: name | fixture_file | expected_mode | grep_assertion
# grep_assertion is a pattern that must appear in the workflow output once the
# success criterion is confirmed (e.g. a JSON substring or error phrase).
TEST_CASES=(
  "basic-multi-dim|basic-multi-dim.json|success|\"ubuntu-latest\""
  "with-include|with-include.json|success|\"include\":"
  "with-limits|with-limits.json|success|\"max-parallel\": 4"
  "too-big|too-big.json|fail|exceeds max-matrix-size"
)

# expected_extra checks per case: these are grep -F patterns that must all
# appear somewhere in the captured act output for the case. Using a parallel
# array keeps the case definition simple while still enforcing exact values.
declare -A EXPECTED_PATTERNS=(
  ["basic-multi-dim"]='"os":
"ubuntu-latest"
"windows-latest"
"node":
"feature":
"fail-fast": true
===RESULT===ok===
Job succeeded'
  ["with-include"]='"include":
"windows-latest"
"21"
===RESULT===ok===
Job succeeded'
  ["with-limits"]='"max-parallel": 4
"fail-fast": false
===RESULT===ok===
Job succeeded'
  ["too-big"]='matrix size 27 exceeds max-matrix-size 10
===RESULT===ok===
Job succeeded'
)

# run_one builds a throwaway repo, copies the project + fixture into it, runs
# act, captures the output, and appends the delimited result to act-result.txt.
# Returns 0 iff the case passed all assertions.
run_one() {
  local name="$1" fixture="$2" expected_mode="$3"
  local tmpdir
  tmpdir="$(mktemp -d)"
  # Clean up the temp repo on return (success or failure) to keep CI tidy.
  trap 'rm -rf "${tmpdir}"' RETURN

  echo "================================================================"
  echo "[harness] Case: ${name}  fixture=${fixture}  expect=${expected_mode}"
  echo "================================================================"

  # Copy only the pieces the workflow needs; avoids pulling in node_modules or
  # the harness's own temp artifacts.
  mkdir -p "${tmpdir}/.github/workflows" "${tmpdir}/fixtures"
  cp "${PROJECT_DIR}/matrix-gen.sh" "${tmpdir}/"
  cp "${PROJECT_DIR}/.github/workflows/environment-matrix-generator.yml" \
    "${tmpdir}/.github/workflows/"
  cp "${PROJECT_DIR}/fixtures/"*.json "${tmpdir}/fixtures/"
  cp "${PROJECT_DIR}/.actrc" "${tmpdir}/" 2>/dev/null || true
  cp "${PROJECT_DIR}/fixtures/${fixture}" "${tmpdir}/active-fixture.json"

  # The workflow reads expected-mode.txt to decide whether the script is
  # expected to succeed or to emit a validation failure.
  printf '%s\n' "${expected_mode}" > "${tmpdir}/expected-mode.txt"

  (
    cd "${tmpdir}" || exit 1
    git init -q
    git -c user.email=harness@example.com -c user.name=harness add .
    git -c user.email=harness@example.com -c user.name=harness \
      commit -q -m "harness: ${name}"
  )

  local output
  local rc
  # --pull=false: the .actrc pins a locally-built image (act-ubuntu-pwsh:latest).
  # Without this flag act tries to pull it from a registry and fails.
  output="$(cd "${tmpdir}" && act push --rm --pull=false 2>&1)"
  rc=$?

  {
    echo
    echo "=================================================================="
    echo "=== CASE: ${name} (fixture=${fixture}, expect=${expected_mode}) ==="
    echo "=================================================================="
    echo "${output}"
    echo "=== END CASE: ${name} (act exit=${rc}) ==="
  } >> "${RESULT_FILE}"

  if [[ "${rc}" -ne 0 ]]; then
    echo "[harness] FAIL ${name}: act exited ${rc}"
    return 1
  fi

  # Workflow must report the job succeeded for every case (workflow absorbs
  # script failures on negative cases and still reports success at the job level).
  if ! grep -q "Job succeeded" <<<"${output}"; then
    echo "[harness] FAIL ${name}: no 'Job succeeded' marker"
    return 1
  fi

  # Check every required substring (grep -F = fixed strings, no regex).
  local patterns="${EXPECTED_PATTERNS[${name}]}"
  local missing=0
  while IFS= read -r pat; do
    [[ -z "${pat}" ]] && continue
    if ! grep -F -q -- "${pat}" <<<"${output}"; then
      echo "[harness] FAIL ${name}: missing expected substring: ${pat}"
      missing=1
    fi
  done <<<"${patterns}"

  if [[ "${missing}" -ne 0 ]]; then
    return 1
  fi

  echo "[harness] PASS ${name}"
  return 0
}

fails=0
passed=0
for case_line in "${TEST_CASES[@]}"; do
  IFS='|' read -r name fixture mode _pattern <<<"${case_line}"
  if run_one "${name}" "${fixture}" "${mode}"; then
    passed=$((passed + 1))
  else
    fails=$((fails + 1))
  fi
done

echo
echo "================================================================"
echo "[harness] Summary: ${passed} passed, ${fails} failed"
echo "[harness] Full act output saved to: ${RESULT_FILE}"
echo "================================================================"

exit "${fails}"
