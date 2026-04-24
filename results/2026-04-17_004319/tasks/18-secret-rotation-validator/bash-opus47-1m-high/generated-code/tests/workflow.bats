#!/usr/bin/env bats
# Workflow tests: validate the GH Actions workflow structure AND run it
# end-to-end through act for several fixture inputs. All test execution
# happens through the pipeline — we never invoke the script directly here.

setup_file() {
    ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export ROOT
    export WORKFLOW="${ROOT}/.github/workflows/secret-rotation-validator.yml"
    export ACT_RESULT="${ROOT}/act-result.txt"
    : > "${ACT_RESULT}"   # truncate so we capture only this run's output
}

# ---------------- workflow structure tests ----------------------------------

@test "workflow file exists" {
    [ -f "${WORKFLOW}" ]
}

@test "actionlint passes on the workflow" {
    run actionlint "${WORKFLOW}"
    [ "${status}" -eq 0 ]
}

@test "workflow has all expected triggers" {
    # push, pull_request, schedule, workflow_dispatch
    run grep -E '^  (push|pull_request|schedule|workflow_dispatch):' "${WORKFLOW}"
    [ "${status}" -eq 0 ]
    # 4 distinct trigger keys
    [ "$(echo "${output}" | wc -l)" -eq 4 ]
}

@test "workflow defines validate job that runs on ubuntu-latest" {
    grep -q '^  validate:' "${WORKFLOW}"
    grep -q 'runs-on: ubuntu-latest' "${WORKFLOW}"
}

@test "workflow uses actions/checkout@v4" {
    grep -q 'uses: actions/checkout@v4' "${WORKFLOW}"
}

@test "workflow references the validator script" {
    grep -q 'secret-rotation-validator.sh' "${WORKFLOW}"
    [ -x "${ROOT}/secret-rotation-validator.sh" ]
}

@test "workflow declares contents:read permission" {
    grep -q 'contents: read' "${WORKFLOW}"
}

# ---------------- act end-to-end tests --------------------------------------
# Each test:
#   1. Builds an isolated git repo containing project files + the case fixture
#   2. Runs `act push --rm` from there
#   3. Appends output (with a delimiter) to act-result.txt
#   4. Asserts exit 0 and exact expected substrings

run_act_case() {
    local case_name="$1" fixture_src="$2" warning_days="$3" today="$4"

    local sandbox
    sandbox="$(mktemp -d)"

    # Copy project files (script, workflow, fixtures dir for the named fixture)
    cp "${ROOT}/secret-rotation-validator.sh" "${sandbox}/"
    cp "${ROOT}/.actrc" "${sandbox}/"
    mkdir -p "${sandbox}/.github/workflows" "${sandbox}/fixtures"
    cp "${WORKFLOW}" "${sandbox}/.github/workflows/"
    cp "${fixture_src}" "${sandbox}/fixtures/case.json"

    (
        cd "${sandbox}"
        git init -q
        git config user.email "ci@test"
        git config user.name "ci"
        git add .
        git commit -q -m "case ${case_name}"
    )

    {
        echo
        echo "===== CASE: ${case_name} (fixture=${fixture_src##*/}, warning=${warning_days}, today=${today}) ====="
    } >> "${ACT_RESULT}"

    # Run act with workflow_dispatch inputs piped via env-overriding push
    # Note: we use `push` event since it's what the harness requires.
    # The workflow's env defaults will pick up these env vars when not set
    # via inputs, so we override via --env.
    run bash -c "cd '${sandbox}' && act push --rm \
        --env FIXTURE='fixtures/case.json' \
        --env WARNING_DAYS='${warning_days}' \
        --env TODAY='${today}' 2>&1"

    echo "${output}" >> "${ACT_RESULT}"
    echo "----- exit=${status} -----" >> "${ACT_RESULT}"

    rm -rf "${sandbox}"

    # Expose for assertions
    ACT_OUTPUT="${output}"
    ACT_STATUS="${status}"
}

@test "act case 1: sample fixture - mixed expired/warning/ok" {
    run_act_case "sample-mixed" "${ROOT}/fixtures/sample.json" 14 "2026-04-19"
    [ "${ACT_STATUS}" -eq 0 ]
    # Job succeeded marker
    [[ "${ACT_OUTPUT}" == *"Job succeeded"* ]]
    # Status derived from --strict run is 'expired' (api-token rotated 2025-01-01)
    [[ "${ACT_OUTPUT}" == *"Status: expired"* ]]
    # Markdown headings present
    [[ "${ACT_OUTPUT}" == *"## Expired"* ]]
    [[ "${ACT_OUTPUT}" == *"## Warning"* ]]
    [[ "${ACT_OUTPUT}" == *"## OK"* ]]
    # Specific secret names in output
    [[ "${ACT_OUTPUT}" == *"api-token"* ]]
    [[ "${ACT_OUTPUT}" == *"db-password"* ]]
    [[ "${ACT_OUTPUT}" == *"session-key"* ]]
    [[ "${ACT_OUTPUT}" == *"web-api"* ]]
}

@test "act case 2: all-ok fixture - no warnings or expiries" {
    run_act_case "all-ok" "${ROOT}/fixtures/all-ok.json" 14 "2026-04-19"
    [ "${ACT_STATUS}" -eq 0 ]
    [[ "${ACT_OUTPUT}" == *"Job succeeded"* ]]
    [[ "${ACT_OUTPUT}" == *"Status: ok"* ]]
    # The Expired and Warning sections should be empty
    [[ "${ACT_OUTPUT}" == *"kms-root"* ]]
    [[ "${ACT_OUTPUT}" == *"tls-cert"* ]]
}

@test "act case 3: all-expired fixture - status=expired" {
    run_act_case "all-expired" "${ROOT}/fixtures/all-expired.json" 14 "2026-04-19"
    [ "${ACT_STATUS}" -eq 0 ]
    [[ "${ACT_OUTPUT}" == *"Job succeeded"* ]]
    [[ "${ACT_OUTPUT}" == *"Status: expired"* ]]
    [[ "${ACT_OUTPUT}" == *"legacy-pat"* ]]
}

@test "act-result.txt artifact exists and is non-empty" {
    [ -s "${ACT_RESULT}" ]
    grep -q '===== CASE: sample-mixed' "${ACT_RESULT}"
    grep -q '===== CASE: all-ok' "${ACT_RESULT}"
    grep -q '===== CASE: all-expired' "${ACT_RESULT}"
}
