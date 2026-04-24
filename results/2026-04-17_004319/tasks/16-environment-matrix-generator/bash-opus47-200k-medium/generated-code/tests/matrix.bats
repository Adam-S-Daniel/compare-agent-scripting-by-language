#!/usr/bin/env bats
# Tests for environment-matrix-generator — every case runs through the
# GitHub Actions pipeline via act. Config fixtures are written to the repo
# root; the workflow picks them up and invokes generate-matrix.sh.

setup_file() {
    ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export ROOT
    ACT_LOG="${ROOT}/act-result.txt"
    export ACT_LOG
    : >"${ACT_LOG}"
    WORK="$(mktemp -d)"
    export WORK

    cp -r "${ROOT}/.github"            "${WORK}/"
    cp    "${ROOT}/generate-matrix.sh" "${WORK}/"
    cp    "${ROOT}/.actrc"             "${WORK}/"
    chmod +x "${WORK}/generate-matrix.sh"

    cd "${WORK}"
    git init -q
    git config user.email test@test
    git config user.name  test
    git add -A
    git commit -q -m init
}

teardown_file() {
    rm -rf "${WORK}"
}

# Run one act invocation with the given fixture written to matrix-config.json.
# Captures output to a variable and appends to act-result.txt.
run_case() {
    local name="$1" config="$2"
    printf '%s' "${config}" >"${WORK}/matrix-config.json"
    (cd "${WORK}" && git add -A && git commit -q -m "case ${name}" --allow-empty)

    {
        echo "===== CASE: ${name} ====="
        (cd "${WORK}" && act push --rm 2>&1)
        echo
        echo "===== END ${name} ====="
        echo
    } | tee -a "${ACT_LOG}" >"${WORK}/last-output.txt"
}

@test "actionlint passes cleanly" {
    run actionlint "${ROOT}/.github/workflows/environment-matrix-generator.yml"
    [ "$status" -eq 0 ]
}

@test "workflow YAML has required structure" {
    local yml="${ROOT}/.github/workflows/environment-matrix-generator.yml"
    run grep -E '^on:' "$yml";                   [ "$status" -eq 0 ]
    run grep -E '  push:' "$yml";                [ "$status" -eq 0 ]
    run grep -E '  workflow_dispatch:' "$yml";   [ "$status" -eq 0 ]
    run grep -E 'generate-matrix.sh' "$yml";     [ "$status" -eq 0 ]
    run grep -E 'permissions:' "$yml";           [ "$status" -eq 0 ]
}

@test "referenced script exists and is executable" {
    [ -x "${ROOT}/generate-matrix.sh" ]
}

@test "shellcheck passes" {
    run shellcheck "${ROOT}/generate-matrix.sh"
    [ "$status" -eq 0 ]
}

@test "bash -n syntax validation" {
    run bash -n "${ROOT}/generate-matrix.sh"
    [ "$status" -eq 0 ]
}

# ----- single act run covering many cases via a multi-case fixture -----

@test "act runs all matrix cases successfully" {
    local cfg
    cfg=$(cat <<'JSON'
{
  "cases": [
    {
      "name": "simple-2x2",
      "config": {
        "axes": {"os": ["linux","macos"], "node": ["18","20"]},
        "fail-fast": false
      },
      "expect": {"count": 4, "fail-fast": false}
    },
    {
      "name": "with-exclude",
      "config": {
        "axes": {"os": ["linux","macos"], "node": ["18","20"]},
        "exclude": [{"os":"macos","node":"18"}]
      },
      "expect": {"count": 3}
    },
    {
      "name": "with-include",
      "config": {
        "axes": {"os": ["linux"], "node": ["18","20"]},
        "include": [{"os":"windows","node":"22","extra":"x"}]
      },
      "expect": {"count": 3, "has-extra": true}
    },
    {
      "name": "max-parallel-and-failfast",
      "config": {
        "axes": {"os":["linux","macos","windows"]},
        "max-parallel": 2,
        "fail-fast": true
      },
      "expect": {"count": 3, "max-parallel": 2, "fail-fast": true}
    },
    {
      "name": "three-axes",
      "config": {
        "axes": {
          "os": ["linux","macos"],
          "node": ["18","20"],
          "flag": ["debug","release"]
        }
      },
      "expect": {"count": 8}
    },
    {
      "name": "exceeds-max-size",
      "config": {
        "axes": {"os":["a","b","c"], "v":["1","2","3"]},
        "max-size": 5
      },
      "expect": {"error": "exceeds max-size"}
    }
  ]
}
JSON
)
    run_case "all" "$cfg"

    run cat "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    # Every job succeeded
    run grep -c "Job succeeded" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    # act exit code captured by workflow (we assert on content below)
    run grep -F "CASE-OK simple-2x2 count=4" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    run grep -F "CASE-OK with-exclude count=3" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    run grep -F "CASE-OK with-include count=3 extra=yes" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    run grep -F "CASE-OK max-parallel-and-failfast count=3 max-parallel=2 fail-fast=true" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    run grep -F "CASE-OK three-axes count=8" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    run grep -F "CASE-OK exceeds-max-size error" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]

    # Workflow must have exited 0
    run grep -F "ALL-CASES-PASSED" "${WORK}/last-output.txt"
    [ "$status" -eq 0 ]
}
