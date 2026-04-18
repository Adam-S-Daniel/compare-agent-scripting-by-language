#!/usr/bin/env bash
# Test-results aggregator.
#
# Subcommands:
#   parse_junit <file>          -> records: name<TAB>status<TAB>duration
#   parse_json  <file>          -> records: name<TAB>status<TAB>duration
#   aggregate   <file>...       -> key=value totals + flaky=<names>
#   summary     <file>...       -> Markdown summary (for GH Actions job summary)
#
# Record format keeps things pipeline-friendly for awk/sort/uniq.
# Flaky == same test name observed with both "passed" and "failed" across runs.

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

usage() {
    cat >&2 <<'EOF'
Usage: aggregate.sh <command> [args...]
Commands:
  parse_junit <file>
  parse_json  <file>
  aggregate   <file>...
  summary     <file>...
EOF
    exit 2
}

# Detect format by extension; JUnit XMLs end in .xml, JSON in .json.
detect_format() {
    case "$1" in
        *.xml) echo junit ;;
        *.json) echo json ;;
        *) die "cannot detect format for $1 (expected .xml or .json)" ;;
    esac
}

# parse_junit: extract each <testcase> and classify by child element.
# Uses a small awk state machine rather than an XML parser — sufficient for
# the JUnit subset produced by pytest, jest --reporters, surefire, etc.
parse_junit() {
    local file="$1"
    [[ -f "$file" ]] || die "file not found: $file"
    awk '
        function extract(attr, s,   re, m) {
            # Leading space ensures we do not match classname when asked for name.
            re = "[[:space:]]" attr "=\"[^\"]*\""
            if (match(s, re)) {
                m = substr(s, RSTART, RLENGTH)
                sub("[[:space:]]*" attr "=\"", "", m)
                sub(/"$/, "", m)
                return m
            }
            return ""
        }
        /<testcase/ { in_tc = 1; line = "" }
        in_tc {
            # Accumulate only inside the current testcase so attributes and
            # child elements (<failure>, <skipped>) are all visible together.
            line = line " " $0
        }
        in_tc && (/\/>/ || /<\/testcase>/) {
            name = extract("name", line)
            dur  = extract("time", line)
            status = "passed"
            if (line ~ /<failure/ || line ~ /<error/) status = "failed"
            else if (line ~ /<skipped/) status = "skipped"
            printf "%s\t%s\t%s\n", name, status, dur
            in_tc = 0; line = ""
        }
    ' "$file"
}

# parse_json: relies on jq. Standard shape: {"tests":[{name,status,duration}]}
parse_json() {
    local file="$1"
    [[ -f "$file" ]] || die "file not found: $file"
    command -v jq >/dev/null || die "jq required for JSON parsing"
    jq -r '.tests[] | [.name, .status, (.duration|tostring)] | @tsv' "$file"
}

# parse_any: dispatch on format.
parse_any() {
    local fmt
    fmt="$(detect_format "$1")"
    case "$fmt" in
        junit) parse_junit "$1" ;;
        json)  parse_json  "$1" ;;
    esac
}

# aggregate: consume all files, emit totals and flaky list.
aggregate() {
    [[ $# -ge 1 ]] || die "aggregate needs at least one file"
    local tmp
    tmp="$(mktemp)"
    for f in "$@"; do
        parse_any "$f" >> "$tmp"
    done

    awk -F'\t' '
        {
            total++
            status[$2]++
            dur += ($3 + 0)
            # Track statuses observed per test name for flaky detection.
            seen[$1] = seen[$1] "," $2
        }
        END {
            printf "total=%d\n", total
            printf "passed=%d\n",  status["passed"]  + 0
            printf "failed=%d\n",  status["failed"]  + 0
            printf "skipped=%d\n", status["skipped"] + 0
            printf "duration=%.3f\n", dur
            flaky = ""
            for (n in seen) {
                if (seen[n] ~ /,passed/ && seen[n] ~ /,failed/) {
                    flaky = (flaky ? flaky "," : "") n
                }
            }
            printf "flaky=%s\n", flaky
        }
    ' "$tmp"
    rm -f "$tmp"
}

# summary: render GitHub-flavored markdown report.
summary() {
    [[ $# -ge 1 ]] || die "summary needs at least one file"
    local agg
    agg="$(aggregate "$@")"

    # Extract aggregate values.
    local total passed failed skipped duration flaky
    total=$(awk -F= '/^total=/{print $2}' <<<"$agg")
    passed=$(awk -F= '/^passed=/{print $2}' <<<"$agg")
    failed=$(awk -F= '/^failed=/{print $2}' <<<"$agg")
    skipped=$(awk -F= '/^skipped=/{print $2}' <<<"$agg")
    duration=$(awk -F= '/^duration=/{print $2}' <<<"$agg")
    flaky=$(awk -F= '/^flaky=/{sub(/^flaky=/,""); print}' <<<"$agg")

    local status_emoji="Passing"
    [[ "$failed" -gt 0 ]] && status_emoji="Failing"

    cat <<EOF
# Test Results Summary

**Overall status:** $status_emoji

| Metric | Value |
|--------|-------|
| Total | $total |
| Passed | $passed |
| Failed | $failed |
| Skipped | $skipped |
| Duration (s) | $duration |
| Runs aggregated | $# |

## Flaky Tests

EOF

    if [[ -z "$flaky" ]]; then
        echo "No flaky tests detected."
    else
        echo "| Test | Reason |"
        echo "|------|--------|"
        # shellcheck disable=SC2001  # need sed for the pipeline
        echo "$flaky" | tr ',' '\n' | while read -r name; do
            [[ -z "$name" ]] && continue
            echo "| $name | passed in some runs, failed in others |"
        done
    fi
}

main() {
    [[ $# -ge 1 ]] || usage
    local cmd="$1"; shift
    case "$cmd" in
        parse_junit) parse_junit "$@" ;;
        parse_json)  parse_json  "$@" ;;
        aggregate)   aggregate   "$@" ;;
        summary)     summary     "$@" ;;
        -h|--help)   usage ;;
        *) echo "Usage: unknown command: $cmd" >&2; exit 2 ;;
    esac
}

main "$@"
