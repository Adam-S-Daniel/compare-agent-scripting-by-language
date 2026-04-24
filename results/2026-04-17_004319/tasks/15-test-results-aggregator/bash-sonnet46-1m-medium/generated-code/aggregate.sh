#!/usr/bin/env bash
# aggregate.sh - Test Results Aggregator
#
# Parses JUnit XML and JSON test result files from matrix CI builds,
# aggregates totals (passed/failed/skipped/duration), identifies flaky
# tests (same test name passes in some files but fails in others), and
# generates a GitHub Actions-compatible markdown job summary.
#
# Usage:
#   ./aggregate.sh [file1 file2 ...] [-o output_file]
#   ./aggregate.sh [directory]       [-o output_file]
#
# Options:
#   -o FILE   Write markdown to FILE (default: test-summary.md)
#   -h        Show this help
#
# Supported formats: JUnit XML (.xml), custom JSON (.json)
# JSON schema: {"suite":"name","tests":[{"name":"...","status":"pass|fail|skip","duration":N}]}

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Parsing: each parser outputs "suite|name|status|duration" lines
# ──────────────────────────────────────────────────────────────────────

# Parse a JUnit XML file using Python's built-in xml.etree
# Handles both <testsuite> root and <testsuites> wrapper root.
parse_junit_xml() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import xml.etree.ElementTree as ET
import sys

file = sys.argv[1]
try:
    tree = ET.parse(file)
    root = tree.getroot()
except Exception as e:
    print(f"ERROR: cannot parse XML {file}: {e}", file=sys.stderr)
    sys.exit(1)

if root.tag == 'testsuites':
    suites = root.findall('testsuite')
elif root.tag == 'testsuite':
    suites = [root]
else:
    print(f"ERROR: unexpected root element <{root.tag}> in {file}", file=sys.stderr)
    sys.exit(1)

for suite in suites:
    suite_name = (suite.get('name') or 'Unknown').replace('|', '_')
    for tc in suite.findall('testcase'):
        name     = (tc.get('name') or 'Unknown').replace('|', '_')
        duration = tc.get('time') or '0'
        if tc.find('failure') is not None or tc.find('error') is not None:
            status = 'fail'
        elif tc.find('skipped') is not None:
            status = 'skip'
        else:
            status = 'pass'
        print(f"{suite_name}|{name}|{status}|{duration}")
PYEOF
}

# Parse a custom JSON test result file using jq.
# Expected schema: {"suite":"...", "tests":[{"name":"...","status":"...","duration":N}]}
parse_json() {
    local file="$1"
    jq -r '.suite as $suite |
           .tests[] |
           [($suite       | gsub("\\|"; "_")),
            (.name        | gsub("\\|"; "_")),
            .status,
            (.duration | tostring)] |
           join("|")' "$file" 2>/dev/null || {
        echo "ERROR: cannot parse JSON file: $file" >&2
        exit 1
    }
}

# ──────────────────────────────────────────────────────────────────────
# Aggregation helpers (operate on "filepath|suite|name|status|duration")
# ──────────────────────────────────────────────────────────────────────

# Compute summary totals; prints "total passed failed skipped duration"
aggregate_totals() {
    awk -F'|' '
    {
        total++
        s = $4
        if      (s == "pass") passed++
        else if (s == "fail") failed++
        else if (s == "skip") skipped++
        total_dur += $5 + 0
    }
    END { printf "%d %d %d %d %.3f\n",
          total, passed+0, failed+0, skipped+0, total_dur }'
}

# Emit the name of every test that both passed and failed across files.
# A test is flaky when it appears as "pass" in at least one file AND
# "fail" in at least one other file (regardless of classname/suite).
detect_flaky() {
    awk -F'|' '
    {
        name   = $3
        status = $4
        if (status == "pass") has_pass[name] = 1
        if (status == "fail") has_fail[name] = 1
    }
    END {
        for (n in has_pass)
            if (n in has_fail) print n
    }'
}

# ──────────────────────────────────────────────────────────────────────
# Markdown generation
# ──────────────────────────────────────────────────────────────────────

# Write a markdown summary to OUTPUT_FILE and cat it to stdout.
generate_markdown() {
    local parsed="$1"   # multi-line string: filepath|suite|name|status|duration
    local outfile="$2"

    local totals total passed failed skipped duration
    totals=$(printf '%s\n' "$parsed" | aggregate_totals)
    read -r total passed failed skipped duration <<< "$totals"

    # Flaky detection; sort for deterministic output
    local flaky_raw flaky_count=0
    flaky_raw=$(printf '%s\n' "$parsed" | detect_flaky | sort)
    if [[ -n "$flaky_raw" ]]; then
        flaky_count=$(printf '%s\n' "$flaky_raw" | wc -l | tr -d ' ')
    fi

    # Failed test details: filepath|suite|name for every fail entry
    local failed_details
    failed_details=$(printf '%s\n' "$parsed" | awk -F'|' '$4 == "fail" {print $1 "|" $2 "|" $3}')

    {
        echo "## Test Results Summary"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        printf "| **Total Tests** | %d |\n"  "$total"
        printf "| **Passed** | %d |\n"       "$passed"
        printf "| **Failed** | %d |\n"       "$failed"
        printf "| **Skipped** | %d |\n"      "$skipped"
        printf "| **Duration** | %.2fs |\n"  "$duration"
        echo ""

        if [[ "$failed" -gt 0 ]]; then
            echo "## Failed Tests"
            echo ""
            echo "| File | Suite | Test |"
            echo "|------|-------|------|"
            while IFS='|' read -r fp suite name; do
                printf "| \`%s\` | %s | %s |\n" "$(basename "$fp")" "$suite" "$name"
            done <<< "$failed_details"
            echo ""
        fi

        if [[ "$flaky_count" -gt 0 ]]; then
            printf "## Flaky Tests (%d)\n\n" "$flaky_count"
            echo "Tests that passed in some runs but failed in others:"
            echo ""
            while IFS= read -r t; do
                echo "- $t"
            done <<< "$flaky_raw"
        else
            echo "## Flaky Tests"
            echo ""
            echo "No flaky tests detected."
        fi
    } > "$outfile"

    cat "$outfile"
}

# ──────────────────────────────────────────────────────────────────────
# File collection and dispatch
# ──────────────────────────────────────────────────────────────────────

# Parse all supplied files; outputs "filepath|suite|name|status|duration" lines.
parse_files() {
    local -a files=("$@")
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "WARNING: file not found, skipping: $file" >&2
            continue
        fi
        local rows=""
        case "$file" in
            *.xml)  rows=$(parse_junit_xml "$file") ;;
            *.json) rows=$(parse_json      "$file") ;;
            *)
                echo "WARNING: unsupported file type, skipping: $file" >&2
                continue
                ;;
        esac
        # Prefix each row with the originating filepath for flaky tracking
        while IFS= read -r row; do
            printf '%s|%s\n' "$file" "$row"
        done <<< "$rows"
    done
}

# ──────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────

main() {
    local output_file="test-summary.md"
    local -a input_files=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o)
                output_file="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [file1 file2 ... | directory] [-o output_file]"
                exit 0
                ;;
            *)
                if [[ -d "$1" ]]; then
                    while IFS= read -r f; do
                        input_files+=("$f")
                    done < <(find "$1" -maxdepth 1 -type f \( -name "*.xml" -o -name "*.json" \) | sort)
                else
                    input_files+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ ${#input_files[@]} -eq 0 ]]; then
        echo "ERROR: no input files specified." >&2
        echo "Usage: $0 [file1 file2 ... | directory] [-o output_file]" >&2
        exit 1
    fi

    echo "Parsing ${#input_files[@]} test result file(s)..." >&2

    local parsed
    parsed=$(parse_files "${input_files[@]}")

    if [[ -z "$parsed" ]]; then
        echo "ERROR: no test results found in the supplied files." >&2
        exit 1
    fi

    generate_markdown "$parsed" "$output_file" >&2 || true
    # Re-emit the markdown to stdout so callers (workflow, bats) can capture it
    cat "$output_file"
    echo "Summary written to: $output_file" >&2
}

# Guard: only run main when executed directly, not when sourced by tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
