#!/usr/bin/env bash
#
# Shared helpers for the bats integration tests. Each integration test
# stands up a temporary git repo containing the project files plus the
# fixture under test, runs `act push --rm` against it, and writes the
# combined act output to <project_root>/act-result.txt.

# Absolute path to the project root (the directory containing tests/).
project_root() {
    cd "$BATS_TEST_DIRNAME/.." && pwd
}

# Append a delimited block of act output for the given test case to
# act-result.txt in the project root.
_append_act_result() {
    local fixture=$1 status=$2 body=$3
    local result_file
    result_file="$(project_root)/act-result.txt"
    {
        printf '\n'
        printf '%s\n' '==================================================================='
        printf 'TEST CASE: %s\n' "$fixture"
        printf 'TIMESTAMP: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '%s\n' '==================================================================='
        printf '%s\n' "$body"
        printf '%s\n' '-------------------------------------------------------------------'
        printf 'EXIT_CODE: %d\n' "$status"
        printf '%s\n' '==================================================================='
    } >> "$result_file"
}

# Build a temp git workspace seeded with the project files plus the named
# fixture, then run `act push --rm` and capture combined output.
#
# Sets globals consumed by the calling bats test:
#   output  - combined stdout/stderr from act
#   status  - act's exit code
run_fixture() {
    local fixture=$1
    local root
    root=$(project_root)

    local ws
    ws=$(mktemp -d "${TMPDIR:-/tmp}/srv-act-${fixture}.XXXXXX")

    cp "$root/secret-rotation-validator.sh" "$ws/"
    cp "$root/.actrc" "$ws/"
    mkdir -p "$ws/.github/workflows"
    cp "$root/.github/workflows/secret-rotation-validator.yml" \
       "$ws/.github/workflows/"

    mkdir -p "$ws/fixture"
    cp "$root/tests/fixtures/$fixture/secrets.txt" "$ws/fixture/"
    cp "$root/tests/fixtures/$fixture/params.env"  "$ws/fixture/"

    (
        cd "$ws"
        git init -q -b main
        git -c user.email=test@example.com -c user.name=test add -A
        git -c user.email=test@example.com -c user.name=test \
            commit -q -m "fixture: $fixture"
    ) >/dev/null

    # --pull=false is essential here: the .actrc points at the locally
    # built act-ubuntu-pwsh image, which has no registry to pull from.
    set +e
    output=$(cd "$ws" && act push --rm --pull=false 2>&1)
    status=$?
    set -e

    _append_act_result "$fixture" "$status" "$output"

    # Workspace is intentionally left in $TMPDIR for post-mortem debugging
    # if a test fails; mktemp paths are unique per run so they don't pile up.
    rm -rf "$ws"
}

# Assertion helpers that operate on the $output captured above.

assert_in_output() {
    local needle=$1
    if ! grep -qF -- "$needle" <<<"$output"; then
        printf 'expected in output: %s\n' "$needle" >&2
        printf -- '--- output begin ---\n%s\n--- output end ---\n' "$output" >&2
        return 1
    fi
}

refute_in_output() {
    local needle=$1
    if grep -qF -- "$needle" <<<"$output"; then
        printf 'unexpected in output: %s\n' "$needle" >&2
        return 1
    fi
}
