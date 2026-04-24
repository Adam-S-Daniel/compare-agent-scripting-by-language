#!/usr/bin/env bats
# ci.bats — the primary test suite. Per benchmark rules, every matrix-generator
# test case is exercised through the real GitHub Actions workflow via `act`.
#
# Strategy: `setup_file` invokes `act push --rm --pull=false` exactly once per
# session, capturing the combined output of every fixture (emitted by the
# test-harness.sh step with per-case delimiters). Each @test then parses the
# saved log and asserts on exact expected values.

# Per-test helpers. Each @test runs in a fresh subshell so we recompute paths
# from BATS_TEST_DIRNAME (always provided) rather than relying on
# setup_file-exported variables, which don't always survive on older bats.
project_root() { cd "$BATS_TEST_DIRNAME/.." && pwd; }
act_log_path() { echo "$(project_root)/act-result.txt"; }
act_exit_path() { echo "$(project_root)/.act-exit-code"; }

extract_case() {
    # act prefixes each captured step-output line with `[job-name]   | `. We
    # strip that prefix, then apply the ===CASE:name=== / ===END:name===
    # delimiter logic against the raw content.
    local name="$1"
    awk -v name="$name" '
        match($0, /\][[:space:]]*\|[[:space:]]*/) {
            content = substr($0, RSTART + RLENGTH)
            if (content == "===CASE:" name "===") { capture = 1; next }
            if (content == "===END:"  name "===") { capture = 0; next }
            if (capture) print content
        }
    ' "$(act_log_path)"
}

case_exit_code() {
    extract_case "$1" | awk -F: '/^EXIT:/ { print $2 }'
}

case_json() {
    extract_case "$1" | awk '/^EXIT:/ { exit } { print }'
}

setup_file() {
    local root log exit_file
    root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    log="$root/act-result.txt"
    exit_file="$root/.act-exit-code"

    # Allow re-using a prior act log when iterating on the test suite itself
    # (set BATS_REUSE_ACT=1). Cuts iteration cost without changing behavior
    # in CI, where the env var is never set.
    if [[ "${BATS_REUSE_ACT:-}" == "1" && -s "$log" && -s "$exit_file" ]]; then
        return 0
    fi

    # Reset the artifacts so asserting on the file content is deterministic.
    : > "$log"
    : > "$exit_file"

    pushd "$root" >/dev/null

    # Use --pull=false so act uses the locally-built act-ubuntu-pwsh image
    # referenced by .actrc (and any other prebuilt images). Without this act
    # tries a docker pull and fails because the image is local-only.
    echo "bats: invoking act ..." | tee -a "$log"
    set +e
    act push --rm --pull=false 2>&1 | tee -a "$log"
    local rc=${PIPESTATUS[0]}
    set -e
    echo "bats: act exit code = $rc" | tee -a "$log"
    echo "$rc" > "$exit_file"

    popd >/dev/null
}

@test "act exited 0" {
    rc="$(cat "$(act_exit_path)")"
    [ "$rc" = "0" ]
}

@test "workflow jobs all succeeded" {
    # Our workflow has two jobs (generate-matrix and run-fixtures). Both
    # should print 'Job succeeded' in the act log.
    count=$(grep -c "Job succeeded" "$(act_log_path)" || true)
    [ "$count" -ge 2 ]
}

@test "act-result.txt artifact exists and is non-empty" {
    [ -s "$(act_log_path)" ]
}

@test "fixture basic: exit 0 and 4 include entries" {
    rc=$(case_exit_code basic)
    [ "$rc" = "0" ]
    json=$(case_json basic)
    count=$(echo "$json" | jq '.matrix.include | length')
    [ "$count" -eq 4 ]
    echo "$json" | jq -e '.matrix.include[] | select(.os=="ubuntu-latest" and .language_version=="3.10")'
    echo "$json" | jq -e '.matrix.include[] | select(.os=="ubuntu-latest" and .language_version=="3.11")'
    echo "$json" | jq -e '.matrix.include[] | select(.os=="windows-latest" and .language_version=="3.10")'
    echo "$json" | jq -e '.matrix.include[] | select(.os=="windows-latest" and .language_version=="3.11")'
}

@test "fixture with-exclude: windows+extra combination removed" {
    rc=$(case_exit_code with-exclude)
    [ "$rc" = "0" ]
    json=$(case_json with-exclude)
    count=$(echo "$json" | jq '.matrix.include | length')
    [ "$count" -eq 3 ]
    excluded=$(echo "$json" | jq '[.matrix.include[] | select(.os=="windows-latest" and .feature=="extra")] | length')
    [ "$excluded" -eq 0 ]
}

@test "fixture with-include: extra macOS entry appended verbatim" {
    rc=$(case_exit_code with-include)
    [ "$rc" = "0" ]
    json=$(case_json with-include)
    count=$(echo "$json" | jq '.matrix.include | length')
    [ "$count" -eq 2 ]
    echo "$json" | jq -e '.matrix.include[] | select(.os=="macos-latest" and .language_version=="3.11" and .experimental==true)'
}

@test "fixture parallel-fail-fast: max-parallel=4 and fail-fast=true" {
    rc=$(case_exit_code parallel-fail-fast)
    [ "$rc" = "0" ]
    json=$(case_json parallel-fail-fast)
    [ "$(echo "$json" | jq -r '."max-parallel"')" = "4" ]
    [ "$(echo "$json" | jq -r '."fail-fast"')" = "true" ]
}

@test "fixture with-features: 2*2*2=8 include entries" {
    rc=$(case_exit_code with-features)
    [ "$rc" = "0" ]
    json=$(case_json with-features)
    count=$(echo "$json" | jq '.matrix.include | length')
    [ "$count" -eq 8 ]
}

@test "fixture too-big: exits 3 with max_size error" {
    rc=$(case_exit_code too-big)
    [ "$rc" = "3" ]
    extract_case too-big | grep -q "exceeds max_size"
}

@test "fixture invalid: exits 2 with parse error" {
    rc=$(case_exit_code invalid)
    [ "$rc" = "2" ]
    extract_case invalid | grep -q "invalid JSON"
}

@test "fixture empty: exits 2 with axis requirement error" {
    rc=$(case_exit_code empty)
    [ "$rc" = "2" ]
    extract_case empty | grep -q "at least one axis"
}

@test "every expected case delimiter is present in the act log" {
    local log
    log="$(act_log_path)"
    for name in basic with-exclude with-include parallel-fail-fast with-features too-big invalid empty; do
        grep -q "===CASE:${name}===" "$log"
        grep -q "===END:${name}===" "$log"
    done
}
