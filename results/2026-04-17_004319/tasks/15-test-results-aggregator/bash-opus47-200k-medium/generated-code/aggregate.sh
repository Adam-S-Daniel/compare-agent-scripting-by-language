#!/usr/bin/env bash
# aggregate.sh - aggregate test results from JUnit XML and JSON files,
# compute totals (passed/failed/skipped/duration), detect flaky tests,
# and emit a markdown summary suitable for a GitHub Actions job summary.
#
# Usage: aggregate.sh <results-dir>
#   <results-dir> must contain *.xml (JUnit) and/or *.json (custom) files.
# If GITHUB_STEP_SUMMARY is set, the summary is also appended to that file.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: aggregate.sh <results-dir>

Aggregates JUnit XML (*.xml) and JSON (*.json) test result files in the
given directory. Prints a markdown summary to stdout. If the environment
variable GITHUB_STEP_SUMMARY is set, the summary is also appended there.

JSON file shape:
  {"tests":[{"name":"suite.name","status":"passed|failed|skipped","duration":0.0}]}
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 2
fi

results_dir="$1"
if [[ ! -d "$results_dir" ]]; then
    echo "error: results directory not found: $results_dir" >&2
    exit 1
fi

# --- Parsing helpers ------------------------------------------------------
# Each parser appends one record per testcase to a temp file, columns:
#   <name>\t<status>\t<duration>
# status is: passed | failed | skipped

records="$(mktemp)"
trap 'rm -f "$records"' EXIT

# Parse a JUnit XML file via awk. Handles single- and multi-line testcase
# elements. classname + name are joined with a dot when classname is present.
parse_junit() {
    local file="$1"
    # Normalize: strip newlines so each <testcase ...>...</testcase> is one line,
    # then split testcase blocks onto their own lines.
    tr '\n' ' ' < "$file" \
        | sed -E 's#<testcase#\n<testcase#g' \
        | grep '^<testcase' \
        | while IFS= read -r line; do
            local name classname duration status full
            name=$(sed -nE 's#.* name="([^"]*)".*#\1#p' <<<"$line")
            classname=$(sed -nE 's#.* classname="([^"]*)".*#\1#p' <<<"$line")
            duration=$(sed -nE 's#.* time="([^"]*)".*#\1#p' <<<"$line")
            [[ -z "$duration" ]] && duration="0"
            if [[ -n "$classname" ]]; then
                full="${classname}.${name}"
            else
                full="$name"
            fi
            if grep -q '<failure' <<<"$line" || grep -q '<error' <<<"$line"; then
                status="failed"
            elif grep -q '<skipped' <<<"$line"; then
                status="skipped"
            else
                status="passed"
            fi
            printf '%s\t%s\t%s\n' "$full" "$status" "$duration" >> "$records"
        done
}

# Parse a JSON file using jq. Schema: {"tests":[{name,status,duration}]}.
parse_json() {
    local file="$1"
    jq -r '.tests[] | [.name, .status, (.duration|tostring)] | @tsv' "$file" >> "$records"
}

# --- Discover and parse files --------------------------------------------

shopt -s nullglob
xml_files=( "$results_dir"/*.xml )
json_files=( "$results_dir"/*.json )
shopt -u nullglob

for f in "${xml_files[@]}"; do
    parse_junit "$f"
done
for f in "${json_files[@]}"; do
    parse_json "$f"
done

# --- Aggregate totals -----------------------------------------------------

total=0; passed=0; failed=0; skipped=0
duration_total="0"

while IFS=$'\t' read -r _name status dur; do
    total=$((total + 1))
    case "$status" in
        passed)  passed=$((passed + 1)) ;;
        failed)  failed=$((failed + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
    esac
    duration_total=$(awk -v a="$duration_total" -v b="$dur" 'BEGIN{printf "%.6f", a+b}')
done < "$records"

duration_fmt=$(awk -v d="$duration_total" 'BEGIN{printf "%.2f", d}')

# --- Detect flaky tests ---------------------------------------------------
# A test is flaky if it appears with both "passed" and "failed" status across
# the parsed records (i.e., across multiple matrix runs).

flaky_list=$(
    awk -F'\t' '
        $2=="passed" { passed_seen[$1]=1 }
        $2=="failed" { failed_seen[$1]=1 }
        END {
            for (k in passed_seen) {
                if (k in failed_seen) print k
            }
        }
    ' "$records" | sort
)

# --- Render markdown ------------------------------------------------------

render_summary() {
    echo "# Test Results Summary"
    echo
    echo "- Total: $total"
    echo "- Passed: $passed"
    echo "- Failed: $failed"
    echo "- Skipped: $skipped"
    echo "- Duration: ${duration_fmt}s"
    echo
    echo "## Flaky tests"
    if [[ -z "$flaky_list" ]]; then
        echo
        echo "_None detected._"
    else
        echo
        while IFS= read -r t; do
            [[ -n "$t" ]] && echo "- $t"
        done <<< "$flaky_list"
    fi
}

summary="$(render_summary)"
printf '%s\n' "$summary"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$summary" >> "$GITHUB_STEP_SUMMARY"
fi
