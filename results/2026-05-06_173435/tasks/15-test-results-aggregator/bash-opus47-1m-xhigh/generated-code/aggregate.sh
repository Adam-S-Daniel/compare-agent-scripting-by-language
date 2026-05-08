#!/usr/bin/env bash
# aggregate.sh — parse JUnit XML / JSON test result files and produce a
# GitHub-Actions-friendly markdown summary. Designed for matrix-build CI
# where each shard emits one or more result files; this script aggregates
# them, identifies flaky tests (passed in some shards, failed in others),
# and renders totals + flaky list as markdown.
#
# Subcommands:
#   parse-junit FILE     — emit canonical lines (<class>::<name>|status|dur)
#   parse-json FILE      — same canonical line format from a JSON results file
#   parse FILE           — autodetect JUnit XML or JSON
#   summary FILE [...]   — aggregate all input files; print markdown summary
#
# Exit codes: 0 success, 1 user error (bad args / missing file), 2 parse error.

set -euo pipefail

die() {
    printf 'aggregate.sh: %s\n' "$*" >&2
    exit 1
}

# parse-junit: read a JUnit XML file and print one canonical line per
# <testcase>. We rely on grep/sed because xmllint isn't always present
# in stripped-down CI containers, and JUnit XML output is regular enough
# that line-oriented extraction is reliable for the shapes the major
# runners (pytest, jest, go test, gradle, etc.) emit.
parse_junit() {
    local file=$1
    [ -f "$file" ] || die "parse-junit: file not found: $file"

    # Flatten the XML so each <testcase ...> opens on its own line and
    # children of a non-self-closing testcase remain on the same logical
    # block until </testcase>. We read the whole file into a variable, then
    # split on `<testcase` boundaries so we can inspect each block.
    local xml
    xml=$(tr -d '\r' <"$file")

    # Replace newlines with a sentinel so we can use regex across what was
    # originally multi-line content. Then split into one block per testcase.
    local flat
    flat=$(printf '%s' "$xml" | tr '\n' '\001')

    # Split on `<testcase` — the first chunk is everything before the first
    # testcase (testsuite header etc.) and we discard it.
    local -a blocks=()
    local IFS=
    # shellcheck disable=SC2207  # word splitting on a literal sentinel is intentional
    IFS=$'\002' read -r -d '' -a blocks < <(printf '%s' "$flat" | sed 's|<testcase|\x02&|g' && printf '\0') || true

    local block name classname duration status
    for block in "${blocks[@]}"; do
        [[ "$block" == *"<testcase"* ]] || continue

        # Extract attributes from the testcase opening tag. The opening
        # tag runs from `<testcase` to either `/>` (self-closing) or `>`.
        local opening
        opening=$(printf '%s' "$block" | sed -n 's|.*\(<testcase[^>]*[/]\?>\).*|\1|p')
        [ -n "$opening" ] || continue

        name=$(extract_attr "$opening" name)
        classname=$(extract_attr "$opening" classname)
        duration=$(extract_attr "$opening" time)
        [ -n "$duration" ] || duration="0"

        # Determine status. A self-closing testcase is unconditionally
        # passed. Otherwise inspect children for failure / error / skipped.
        if [[ "$opening" == */\> ]]; then
            status=passed
        elif [[ "$block" == *"<failure"* ]]; then
            status=failed
        elif [[ "$block" == *"<error"* ]]; then
            status=failed
        elif [[ "$block" == *"<skipped"* ]]; then
            status=skipped
        else
            status=passed
        fi

        # Build the qualified test id. Some emitters omit classname; fall
        # back to the bare name in that case so downstream dedup still works.
        local id
        if [ -n "$classname" ]; then
            id="${classname}::${name}"
        else
            id="$name"
        fi
        printf '%s|%s|%s\n' "$id" "$status" "$duration"
    done
}

# extract_attr OPENING_TAG ATTR_NAME — pull a single attribute value out
# of an XML opening tag. Handles both single- and double-quoted values.
extract_attr() {
    local tag=$1 attr=$2
    # Try double quotes first, then single quotes.
    local val
    val=$(printf '%s' "$tag" | sed -n "s|.* ${attr}=\"\\([^\"]*\\)\".*|\\1|p")
    if [ -z "$val" ]; then
        val=$(printf '%s' "$tag" | sed -n "s|.* ${attr}='\\([^']*\\)'.*|\\1|p")
    fi
    printf '%s' "$val"
}

# parse-json: read a JSON results file with shape
#   { "tests": [ {"name":..., "classname":..., "status":..., "duration":...} ] }
# and print canonical lines. We use jq for robustness — jq is small and
# universally available in CI images.
parse_json() {
    local file=$1
    [ -f "$file" ] || die "parse-json: file not found: $file"
    command -v jq >/dev/null 2>&1 || die "parse-json: jq is required"

    # The status field in JSON is normalized to passed/failed/skipped. We
    # accept common synonyms (pass/fail/skip, ok/error, success/failure).
    jq -r '
        .tests[] | [
            ((.classname // "") + (if .classname then "::" else "" end) + .name),
            (.status
                | ascii_downcase
                | if . == "pass" or . == "ok" or . == "success" then "passed"
                  elif . == "fail" or . == "error" or . == "failure" then "failed"
                  elif . == "skip" or . == "ignored" or . == "pending" then "skipped"
                  else . end),
            ((.duration // 0) | tostring)
        ] | join("|")
    ' "$file"
}

# parse: dispatch to parse_junit or parse_json based on file extension or
# leading byte. JSON files start with `{` or `[`; XML starts with `<`.
parse_any() {
    local file=$1
    [ -f "$file" ] || die "parse: file not found: $file"
    case "$file" in
        *.xml) parse_junit "$file"; return ;;
        *.json) parse_json "$file"; return ;;
    esac
    local first
    first=$(head -c 1 "$file" | tr -d '[:space:]')
    case "$first" in
        '<') parse_junit "$file" ;;
        '{'|'[') parse_json "$file" ;;
        *) die "parse: cannot detect format for $file" ;;
    esac
}

# summary: aggregate all input files into totals + flaky tests, render
# markdown to stdout. Computes:
#   - total runs (passed/failed/skipped)
#   - total duration (sum of per-test durations)
#   - flaky tests (tests that have at least one passed and one failed run)
#   - per-file breakdown (one row per input file)
summary() {
    [ "$#" -ge 1 ] || die "summary: at least one input file required"

    # Per-file aggregates (parallel arrays keyed by index).
    local -a file_names=() file_pass=() file_fail=() file_skip=() file_dur=()
    # Per-test result map: id -> space-separated list of statuses across runs.
    declare -A test_statuses=()

    local total_pass=0 total_fail=0 total_skip=0
    local total_dur="0"

    local f
    for f in "$@"; do
        [ -f "$f" ] || die "summary: file not found: $f"

        local fp=0 ff=0 fs=0 fd="0"
        # Read parsed canonical lines. We tolerate empty results files.
        while IFS='|' read -r id status dur; do
            [ -n "$id" ] || continue
            case "$status" in
                passed)  fp=$((fp + 1)); total_pass=$((total_pass + 1)) ;;
                failed)  ff=$((ff + 1)); total_fail=$((total_fail + 1)) ;;
                skipped) fs=$((fs + 1)); total_skip=$((total_skip + 1)) ;;
                *)       die "summary: unknown status '$status' for $id in $f" ;;
            esac
            fd=$(awk -v a="$fd" -v b="$dur" 'BEGIN { printf "%.3f", a + b }')

            # Append status to this test's history. Subsequent tests with
            # the same id from other files reveal flakiness.
            local prev=${test_statuses[$id]:-}
            if [ -n "$prev" ]; then
                test_statuses[$id]="$prev $status"
            else
                test_statuses[$id]="$status"
            fi
        done < <(parse_any "$f")

        file_names+=("$f")
        file_pass+=("$fp")
        file_fail+=("$ff")
        file_skip+=("$fs")
        file_dur+=("$fd")
        total_dur=$(awk -v a="$total_dur" -v b="$fd" 'BEGIN { printf "%.3f", a + b }')
    done

    # Identify flaky tests: those whose status set contains both
    # passed and failed across the parsed files.
    local -a flaky=()
    local id statuses
    for id in "${!test_statuses[@]}"; do
        statuses=${test_statuses[$id]}
        if [[ "$statuses" == *"passed"* ]] && [[ "$statuses" == *"failed"* ]]; then
            flaky+=("$id")
        fi
    done
    # Stable order for deterministic output.
    if [ "${#flaky[@]}" -gt 0 ]; then
        IFS=$'\n' read -r -d '' -a flaky < <(printf '%s\n' "${flaky[@]}" | sort && printf '\0') || true
    fi

    render_markdown \
        "$total_pass" "$total_fail" "$total_skip" "$total_dur" \
        "${#flaky[@]}" \
        "${#file_names[@]}" \
        flaky file_names file_pass file_fail file_skip file_dur
}

# render_markdown takes scalars + array names and writes the GH-Actions
# job-summary-shaped markdown. Using nameref args (declare -n) keeps the
# caller readable instead of stuffing arrays into a global.
render_markdown() {
    local total_pass=$1 total_fail=$2 total_skip=$3 total_dur=$4
    local flaky_count=$5 file_count=$6
    local -n _flaky=$7
    local -n _names=$8
    local -n _pass=$9
    local -n _fail=${10}
    local -n _skip=${11}
    local -n _dur=${12}

    local total=$((total_pass + total_fail + total_skip))
    local status_emoji status_word
    if [ "$total_fail" -gt 0 ]; then
        status_word="FAILED"
        status_emoji=":x:"
    elif [ "$flaky_count" -gt 0 ]; then
        status_word="FLAKY"
        status_emoji=":warning:"
    else
        status_word="PASSED"
        status_emoji=":white_check_mark:"
    fi

    printf '# Test Results Summary %s\n\n' "$status_emoji"
    printf '**Status:** %s\n\n' "$status_word"
    printf '## Totals\n\n'
    printf '| Metric | Value |\n| --- | --- |\n'
    printf '| Total tests | %d |\n' "$total"
    printf '| Passed | %d |\n' "$total_pass"
    printf '| Failed | %d |\n' "$total_fail"
    printf '| Skipped | %d |\n' "$total_skip"
    printf '| Flaky | %d |\n' "$flaky_count"
    printf '| Duration (s) | %s |\n' "$total_dur"
    printf '| Files aggregated | %d |\n\n' "$file_count"

    printf '## Per-file breakdown\n\n'
    printf '| File | Passed | Failed | Skipped | Duration (s) |\n'
    printf '| --- | --- | --- | --- | --- |\n'
    local i
    for i in $(seq 0 $((file_count - 1))); do
        printf '| %s | %d | %d | %d | %s |\n' \
            "$(basename "${_names[$i]}")" \
            "${_pass[$i]}" "${_fail[$i]}" "${_skip[$i]}" "${_dur[$i]}"
    done
    printf '\n'

    printf '## Flaky tests\n\n'
    if [ "$flaky_count" -eq 0 ]; then
        printf '_No flaky tests detected._\n'
    else
        printf '| Test |\n| --- |\n'
        local t
        for t in "${_flaky[@]}"; do
            # shellcheck disable=SC2016  # backticks are intentional markdown, not a subshell
            printf '| `%s` |\n' "$t"
        done
    fi
}

main() {
    [ "$#" -ge 1 ] || die "usage: $0 {parse-junit|parse-json|parse|summary} ARGS..."
    local cmd=$1
    shift
    case "$cmd" in
        parse-junit) parse_junit "$@" ;;
        parse-json)  parse_json "$@" ;;
        parse)       parse_any "$@" ;;
        summary)     summary "$@" ;;
        -h|--help)
            cat <<'EOF'
Usage: aggregate.sh SUBCOMMAND ARGS

Subcommands:
  parse-junit FILE             Emit canonical lines for a JUnit XML file.
  parse-json FILE              Emit canonical lines for a JSON results file.
  parse FILE                   Autodetect format and emit canonical lines.
  summary FILE [FILE ...]      Aggregate inputs and print markdown summary.

Canonical line format:
  <classname>::<name>|<passed|failed|skipped>|<duration_seconds>
EOF
            ;;
        *) die "unknown subcommand: $cmd" ;;
    esac
}

# Only run main when invoked as a script (allow `source aggregate.sh`
# from tests if we ever want unit-level access to functions).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
