#!/usr/bin/env bats
# All tests run through the GitHub Actions workflow via act.
# Each test case:
#   1. copies the project into a fresh temp git repo + its fixture data,
#   2. runs `act push --rm` with --env overrides for this case's parameters,
#   3. appends the full act output to act-result.txt (delimited per case),
#   4. asserts act exit code 0 and "Job succeeded" appears in the output,
#   5. parses the JSON output block to assert exact expected counts.

PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
ACT_RESULT_FILE="${PROJECT_ROOT}/act-result.txt"

setup_file() {
    : > "${ACT_RESULT_FILE}"
}

# Runs a single act case in an isolated temp git repo and appends to act-result.
# Usage: run_act_case <case_name> <config_file> <warning_days> <today>
#                    <expected_exit> <expected_expired> <expected_warning> <expected_ok>
run_act_case() {
    local name="$1" config="$2" warn="$3" today="$4"
    local exp_exit="$5" exp_expired="$6" exp_warning="$7" exp_ok="$8"

    local workdir
    workdir="$(mktemp -d)"
    # Copy project (minus .git and act-result.txt) into temp dir.
    cp -r "${PROJECT_ROOT}/validate-secrets.sh" \
          "${PROJECT_ROOT}/fixtures" \
          "${PROJECT_ROOT}/.github" \
          "${PROJECT_ROOT}/.actrc" \
          "${workdir}/"
    (
        cd "${workdir}"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test"
        git add -A
        git commit -q -m "test fixture"
    )

    local out_file rc
    out_file="$(mktemp)"
    set +e
    (
        cd "${workdir}"
        act push --rm --pull=false \
            --env "CONFIG_FILE=${config}" \
            --env "WARNING_DAYS=${warn}" \
            --env "TODAY=${today}" \
            --env "FORMAT=markdown" \
            --env "EXPECTED_EXIT=${exp_exit}" \
            --env "EXPECTED_EXPIRED=${exp_expired}" \
            --env "EXPECTED_WARNING=${exp_warning}" \
            --env "EXPECTED_OK=${exp_ok}"
    ) >"${out_file}" 2>&1
    rc=$?
    set -e

    {
        echo "========== BEGIN CASE: ${name} =========="
        echo "config=${config} warning_days=${warn} today=${today}"
        echo "expected: exit=${exp_exit} expired=${exp_expired} warning=${exp_warning} ok=${exp_ok}"
        echo "act exit code: ${rc}"
        cat "${out_file}"
        echo "========== END CASE: ${name} =========="
        echo
    } >> "${ACT_RESULT_FILE}"

    # Export for assertions.
    ACT_RC="${rc}"
    ACT_OUT="$(cat "${out_file}")"
    rm -f "${out_file}"
    rm -rf "${workdir}"
}

@test "workflow structure: file exists and references script" {
    [[ -f "${PROJECT_ROOT}/.github/workflows/secret-rotation-validator.yml" ]]
    grep -q 'validate-secrets.sh' "${PROJECT_ROOT}/.github/workflows/secret-rotation-validator.yml"
    grep -q 'actions/checkout@v4' "${PROJECT_ROOT}/.github/workflows/secret-rotation-validator.yml"
    grep -q 'on:' "${PROJECT_ROOT}/.github/workflows/secret-rotation-validator.yml"
}

@test "actionlint passes on workflow" {
    run actionlint "${PROJECT_ROOT}/.github/workflows/secret-rotation-validator.yml"
    [ "$status" -eq 0 ]
}

@test "case 1: mixed.json with warn=14 -> 1 expired, 0 warning, 2 ok, exit 1" {
    run_act_case "mixed_warn14" "fixtures/mixed.json" "14" "2026-04-17" "1" "1" "0" "2"
    echo "act rc=${ACT_RC}"
    [ "${ACT_RC}" -eq 0 ]
    [[ "${ACT_OUT}" == *"Job succeeded"* ]]
    [[ "${ACT_OUT}" == *"All assertions passed."* ]]
    [[ "${ACT_OUT}" == *'"expired": 1'* ]]
    [[ "${ACT_OUT}" == *'"warning": 0'* ]]
    [[ "${ACT_OUT}" == *'"ok": 2'* ]]
    [[ "${ACT_OUT}" == *"DB_PASSWORD"* ]]
}

@test "case 2: all-ok.json with warn=14 -> 0 expired, 0 warning, 2 ok, exit 0" {
    run_act_case "all_ok" "fixtures/all-ok.json" "14" "2026-04-17" "0" "0" "0" "2"
    echo "act rc=${ACT_RC}"
    [ "${ACT_RC}" -eq 0 ]
    [[ "${ACT_OUT}" == *"Job succeeded"* ]]
    [[ "${ACT_OUT}" == *"All assertions passed."* ]]
    [[ "${ACT_OUT}" == *'"expired": 0'* ]]
    [[ "${ACT_OUT}" == *'"ok": 2'* ]]
    [[ "${ACT_OUT}" == *"CERT_KEY"* ]]
}

@test "case 3: warning-only.json with warn=30 -> 0 expired, 2 warning, 0 ok, exit 0" {
    run_act_case "warning_only" "fixtures/warning-only.json" "30" "2026-04-17" "0" "0" "2" "0"
    echo "act rc=${ACT_RC}"
    [ "${ACT_RC}" -eq 0 ]
    [[ "${ACT_OUT}" == *"Job succeeded"* ]]
    [[ "${ACT_OUT}" == *"All assertions passed."* ]]
    [[ "${ACT_OUT}" == *'"expired": 0'* ]]
    [[ "${ACT_OUT}" == *'"warning": 2'* ]]
    [[ "${ACT_OUT}" == *"OAUTH_CLIENT_SECRET"* ]]
}
