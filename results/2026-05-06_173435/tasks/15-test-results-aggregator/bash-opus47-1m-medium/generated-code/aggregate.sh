#!/usr/bin/env bash
# Test results aggregator: parses JUnit XML and JSON test result files,
# aggregates totals, detects flaky tests, emits a markdown summary.
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 <results-dir> [output-file]

Parses every *.xml (JUnit) and *.json file in <results-dir>, aggregates
the results, identifies flaky tests (passed in some runs, failed in others)
and writes a markdown summary to stdout (or <output-file> if given).
EOF
}

# Extract test cases from a JUnit XML file as TSV: name<TAB>status<TAB>duration
parse_junit() {
    local file=$1
    # Normalize: put each tag on its own line so awk can scan reliably.
    sed -E 's/>[[:space:]]*</>\n</g' "$file" | awk '
        function extract(line, key,    m, v) {
            if (match(line, key "=\"[^\"]*\"")) {
                v = substr(line, RSTART, RLENGTH)
                sub(key "=\"", "", v); sub("\"$", "", v)
                return v
            }
            return ""
        }
        /<testcase[ >]/ {
            name = extract($0, "name")
            t = extract($0, "time")
            if (t == "") t = 0
            status = "passed"
            # self-closing: <testcase ... />
            if ($0 ~ /\/>[[:space:]]*$/) {
                printf "%s\t%s\t%s\n", name, status, t
                next
            }
            in_tc = 1; cur_name = name; cur_time = t; cur_status = "passed"
            next
        }
        in_tc && /<failure[ />]/ { cur_status = "failed" }
        in_tc && /<error[ />]/   { cur_status = "failed" }
        in_tc && /<skipped[ />]/ { cur_status = "skipped" }
        in_tc && /<\/testcase>/ {
            printf "%s\t%s\t%s\n", cur_name, cur_status, cur_time
            in_tc = 0
        }
    '
}

# Extract test cases from a JSON file as TSV: name<TAB>status<TAB>duration
# Expected schema: { "tests": [ { "name": "...", "status": "passed|failed|skipped", "duration": <number> }, ... ] }
parse_json() {
    local file=$1
    jq -r '.tests[] | [.name, .status, (.duration // 0)] | @tsv' "$file"
}

# Parse all files in a directory and emit unified TSV stream to stdout.
parse_all() {
    local dir=$1
    local f
    shopt -s nullglob
    for f in "$dir"/*.xml; do
        parse_junit "$f"
    done
    for f in "$dir"/*.json; do
        parse_json "$f"
    done
    shopt -u nullglob
}

# Build markdown summary from a TSV stream on stdin.
summarize() {
    awk -F'\t' '
        {
            name = $1; status = $2; dur = $3 + 0
            total++
            total_dur += dur
            if (status == "passed")  passed++
            else if (status == "failed")  failed++
            else if (status == "skipped") skipped++
            seen[name "/" status]++
            names[name] = 1
        }
        END {
            # Flaky = test name that appears with both passed and failed status
            n_flaky = 0
            for (n in names) {
                if (seen[n "/passed"] && seen[n "/failed"]) {
                    flaky[n_flaky++] = n
                }
            }
            print "# Test Results Summary"
            print ""
            print "| Metric | Count |"
            print "| --- | ---: |"
            printf "| Total    | %d |\n", total + 0
            printf "| Passed   | %d |\n", passed + 0
            printf "| Failed   | %d |\n", failed + 0
            printf "| Skipped  | %d |\n", skipped + 0
            printf "| Duration | %.3fs |\n", total_dur + 0
            print ""
            printf "## Flaky Tests (%d)\n\n", n_flaky
            if (n_flaky == 0) {
                print "_No flaky tests detected._"
            } else {
                # sort for stable output
                for (i = 0; i < n_flaky; i++) {
                    for (j = i + 1; j < n_flaky; j++) {
                        if (flaky[j] < flaky[i]) {
                            tmp = flaky[i]; flaky[i] = flaky[j]; flaky[j] = tmp
                        }
                    }
                }
                for (i = 0; i < n_flaky; i++) printf "- %s\n", flaky[i]
            }
            print ""
            if (failed + 0 > 0) {
                print "**Status:** :x: FAILED"
            } else {
                print "**Status:** :white_check_mark: PASSED"
            }
        }
    '
}

main() {
    if [[ $# -lt 1 ]]; then
        usage >&2
        exit 2
    fi
    local dir=$1
    local out=${2:-}
    if [[ ! -d $dir ]]; then
        echo "error: results directory not found: $dir" >&2
        exit 1
    fi
    if [[ -n $out ]]; then
        parse_all "$dir" | summarize > "$out"
    else
        parse_all "$dir" | summarize
    fi
}

# Allow sourcing for tests without running main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
