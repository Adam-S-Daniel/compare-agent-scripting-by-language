#!/usr/bin/env bats

# Drives the GitHub Actions workflow through `act` for three test
# fixtures, appends each run's output to act-result.txt, and asserts
# on the exact labels produced by the workflow.

PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
RESULT_FILE="${PROJECT_DIR}/act-result.txt"

setup_file() {
    : > "$RESULT_FILE"
}

# Build a temp git repo containing the project plus a case-specific
# fixture file, then run `act push --rm` inside it.
run_case() {
    local case_name="$1" fixture_content="$2"
    local tmp
    tmp="$(mktemp -d)"
    # Copy project files (excluding .git and any prior act-result.txt).
    tar -C "$PROJECT_DIR" --exclude=.git --exclude=act-result.txt -cf - . \
        | tar -C "$tmp" -xf -
    printf '%s' "$fixture_content" > "$tmp/tests/fixtures/changed-files.txt"
    (
        cd "$tmp"
        git init -q
        git config user.email ci@example.com
        git config user.name ci
        git add -A
        git commit -q -m "case $case_name"
        act push --rm 2>&1
    ) > "$tmp/out.log"
    local exit_code=$?
    {
        echo "===== CASE: $case_name ====="
        cat "$tmp/out.log"
        echo "===== END CASE: $case_name (exit=$exit_code) ====="
        echo
    } >> "$RESULT_FILE"
    CASE_LOG="$tmp/out.log"
    CASE_EXIT=$exit_code
}

# Extract the block between RESULT_LABELS_BEGIN / RESULT_LABELS_END
# lines emitted by the workflow, with the act step-prefix stripped.
extract_labels() {
    local log="$1"
    awk '
        /RESULT_LABELS_BEGIN/ { capture=1; next }
        /RESULT_LABELS_END/   { capture=0; next }
        capture { sub(/^.*\| /, ""); print }
    ' "$log"
}

@test "act: docs-only fixture yields documentation" {
    run_case "docs-only" "docs/readme.md
docs/guide.md
"
    [ "$CASE_EXIT" -eq 0 ]
    grep -q "Job succeeded" "$CASE_LOG"
    labels=$(extract_labels "$CASE_LOG")
    expected="documentation"
    [ "$(printf '%s' "$labels")" = "$expected" ]
}

@test "act: mixed fixture yields tests, api, documentation in priority order" {
    run_case "mixed" "docs/readme.md
src/api/handler.sh
src/api/foo.test.sh
"
    [ "$CASE_EXIT" -eq 0 ]
    grep -q "Job succeeded" "$CASE_LOG"
    labels=$(extract_labels "$CASE_LOG")
    expected="tests
api
documentation"
    [ "$labels" = "$expected" ]
}

@test "act: no-match fixture yields empty label set" {
    run_case "no-match" "random/other.bin
bin/tool.exe
"
    [ "$CASE_EXIT" -eq 0 ]
    grep -q "Job succeeded" "$CASE_LOG"
    labels=$(extract_labels "$CASE_LOG")
    [ -z "$labels" ]
}
