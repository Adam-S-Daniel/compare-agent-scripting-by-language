#!/usr/bin/env bats
#
# End-to-end tests: every case runs the GitHub Actions workflow under `act`
# in an isolated temp git repo. We assert on EXACT expected substrings of
# the workflow log, not generic "the workflow ran" signals.
#
# Two cases are deliberately enough to exercise both manifest formats and
# both verdict outcomes (COMPLIANT / NON_COMPLIANT) while staying inside
# the project-wide budget on `act push` invocations.

load test_helper

setup_file() {
    # Wipe the artifact at the start of the run so each `bats` invocation
    # produces a fresh act-result.txt rather than appending forever.
    : > "${ACT_RESULT_FILE}"
}

# ---------------------------------------------------------------------------
# Case 1 — package.json with mixed approved/denied/unknown deps.
# Expected: act exits 0 (we configured the workflow to never fail), the
# job succeeds, and the log contains every dependency line plus the
# NON_COMPLIANT verdict.
# ---------------------------------------------------------------------------
@test "act case 1: package.json with mixed licenses → NON_COMPLIANT, all deps reported" {
    local repo
    repo=$(make_test_repo)

    # The workflow reads ./manifest. For the npm case we just copy the
    # fixture there verbatim — the script auto-detects JSON.
    cp "${PROJECT_ROOT}/fixtures/package.json" "${repo}/manifest"

    local output rc
    output=$(run_act_push "${repo}") && rc=0 || rc=$?
    record_case "package.json mixed → NON_COMPLIANT" "${rc}" "${output}"

    rm -rf "${repo}"

    # 1. act itself must exit 0.
    [ "$rc" -eq 0 ]

    # 2. Job succeeded marker — act prints "Job succeeded" at the end of a
    # successful job. We require it explicitly.
    grep -q 'Job succeeded' <<< "${output}"

    # 3. Header + total.
    grep -q 'Dependency License Compliance Report' <<< "${output}"
    grep -q 'Total dependencies: 5' <<< "${output}"

    # 4. Each dep + license + status — exact lines.
    grep -qF 'express@4.18.2 - MIT - APPROVED'        <<< "${output}"
    grep -qF 'lodash@4.17.21 - MIT - APPROVED'        <<< "${output}"
    grep -qF 'copyleft-pkg@1.0.0 - GPL-3.0 - DENIED'  <<< "${output}"
    grep -qF 'mystery-pkg@0.0.1 - <unknown> - UNKNOWN' <<< "${output}"
    grep -qF 'react@18.2.0 - MIT - APPROVED'          <<< "${output}"

    # 5. Summary counts must match exactly.
    grep -qF 'Summary: 3 approved, 1 denied, 1 unknown' <<< "${output}"

    # 6. Script-level status line and workflow verdict line.
    grep -qF 'Status: NON_COMPLIANT' <<< "${output}"
    grep -qF 'VERDICT: NON_COMPLIANT' <<< "${output}"
    grep -qF 'license-check exit code: 1' <<< "${output}"
}

# ---------------------------------------------------------------------------
# Case 2 — requirements.txt with all-approved deps.
# Expected: act exits 0, the job succeeds, every dep is APPROVED, and the
# verdict is COMPLIANT.
# ---------------------------------------------------------------------------
@test "act case 2: clean requirements.txt → COMPLIANT, all deps approved" {
    local repo
    repo=$(make_test_repo)

    cp "${PROJECT_ROOT}/fixtures/requirements-clean.txt" "${repo}/manifest"

    local output rc
    output=$(run_act_push "${repo}") && rc=0 || rc=$?
    record_case "requirements.txt clean → COMPLIANT" "${rc}" "${output}"

    rm -rf "${repo}"

    [ "$rc" -eq 0 ]
    grep -q 'Job succeeded' <<< "${output}"

    grep -q 'Dependency License Compliance Report' <<< "${output}"
    grep -q 'Total dependencies: 4' <<< "${output}"

    grep -qF 'requests@2.31.0 - Apache-2.0 - APPROVED' <<< "${output}"
    grep -qF 'flask@2.3.3 - BSD-3-Clause - APPROVED'   <<< "${output}"
    grep -qF 'numpy@1.24.0 - BSD-3-Clause - APPROVED'  <<< "${output}"
    grep -qF 'pandas@2.0.3 - BSD-3-Clause - APPROVED'  <<< "${output}"

    grep -qF 'Summary: 4 approved, 0 denied, 0 unknown' <<< "${output}"
    grep -qF 'Status: COMPLIANT' <<< "${output}"
    grep -qF 'VERDICT: COMPLIANT' <<< "${output}"
    grep -qF 'license-check exit code: 0' <<< "${output}"
}

# Sanity: after both cases ran, the artifact must exist and contain both
# delimited blocks.
@test "act-result.txt artifact contains both case blocks" {
    [ -s "${ACT_RESULT_FILE}" ]
    grep -q 'CASE: package.json mixed'        "${ACT_RESULT_FILE}"
    grep -q 'CASE: requirements.txt clean'    "${ACT_RESULT_FILE}"
}
