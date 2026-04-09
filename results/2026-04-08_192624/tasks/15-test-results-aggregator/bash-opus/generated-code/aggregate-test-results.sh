#!/usr/bin/env bash
# aggregate-test-results.sh
#
# Parses test result files in JUnit XML and JSON formats, aggregates results
# across multiple files (simulating a matrix build), computes totals
# (passed, failed, skipped, duration), identifies flaky tests, and generates
# a markdown summary suitable for a GitHub Actions job summary.
#
# Usage:
#   ./aggregate-test-results.sh [--output FILE] <result-file> [result-file ...]
#
# Supported formats:
#   - JUnit XML (.xml)
#   - JSON (.json) with testSuites[].tests[] structure
#
# Output: Markdown summary written to stdout (or --output FILE).

set -euo pipefail

# --- Globals for aggregated data ---
# We accumulate test outcomes in a temp file with lines:
#   <classname>.<testname> <status> <duration>
# where status is one of: passed, failed, skipped
RESULTS_FILE=""
OUTPUT_FILE=""

# --- Helpers ---

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  echo "Usage: $0 [--output FILE] <result-file> [result-file ...]" >&2
  exit 1
}

# cleanup temp files on exit
cleanup() {
  if [[ -n "${RESULTS_FILE}" && -f "${RESULTS_FILE}" ]]; then
    rm -f "${RESULTS_FILE}"
  fi
}
trap cleanup EXIT

# --- JUnit XML Parser ---
# Parses JUnit XML without xmllint/xmlstarlet using grep/sed/awk.
# Extracts each <testcase> and determines pass/fail/skip from child elements.
parse_junit_xml() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    die "File not found: $file"
  fi

  # Read entire file content
  local content
  content=$(cat "$file")

  # Extract testcase blocks - each on possibly multiple lines.
  # We join lines first to make parsing easier, then split on testcase tags.
  local joined
  joined=$(echo "$content" | tr '\n' ' ' | sed 's/  */ /g')

  # Split on </testcase> to get individual testcase blocks.
  # Replace </testcase> with a newline delimiter, then process each line.
  local testcases
  testcases=$(echo "$joined" | sed 's|</testcase>|\n|g; s|/>|\n|g' \
    | grep '<testcase ' || true)

  if [[ -z "$testcases" ]]; then
    echo "WARNING: No testcases found in $file" >&2
    return
  fi

  while IFS= read -r tc; do
    # Isolate just the <testcase ...> opening tag for attribute extraction
    local tag
    tag=$(echo "$tc" | grep -oE '<testcase [^>]*' | head -1)

    # Extract name attribute from the testcase tag
    local name
    name=$(echo "$tag" | sed -n 's/.* name="\([^"]*\)".*/\1/p')
    [[ -z "$name" ]] && name=$(echo "$tag" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

    # Extract classname attribute
    local classname
    classname=$(echo "$tag" | sed -n 's/.*classname="\([^"]*\)".*/\1/p')

    # Extract time attribute
    local duration
    duration=$(echo "$tag" | sed -n 's/.*time="\([^"]*\)".*/\1/p')
    duration="${duration:-0.00}"

    # Determine status by checking for child elements
    local status="passed"
    if echo "$tc" | grep -q '<failure'; then
      status="failed"
    elif echo "$tc" | grep -q '<skipped'; then
      status="skipped"
    elif echo "$tc" | grep -q '<error'; then
      status="failed"
    fi

    # Build a unique test identifier
    local test_id="${classname}.${name}"

    echo "${test_id} ${status} ${duration}" >> "${RESULTS_FILE}"
  done <<< "$testcases"
}

# --- JSON Parser ---
# Parses JSON test results using jq.
parse_json() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    die "File not found: $file"
  fi

  if ! command -v jq &>/dev/null; then
    die "jq is required for JSON parsing but not found"
  fi

  # Extract test records from the JSON structure
  local records
  records=$(jq -r '.testSuites[].tests[] | "\(.classname).\(.name) \(.status) \(.duration)"' "$file") || die "Failed to parse JSON: $file"

  if [[ -z "$records" ]]; then
    echo "WARNING: No tests found in $file" >&2
    return
  fi

  echo "$records" >> "${RESULTS_FILE}"
}

# --- Aggregation ---
# Reads the accumulated results file and computes totals + flaky detection.
aggregate_results() {
  if [[ ! -s "${RESULTS_FILE}" ]]; then
    die "No test results to aggregate"
  fi

  # Total counts across all runs
  local total_passed total_failed total_skipped total_duration
  total_passed=$(awk '$2 == "passed"' "${RESULTS_FILE}" | wc -l)
  total_failed=$(awk '$2 == "failed"' "${RESULTS_FILE}" | wc -l)
  total_skipped=$(awk '$2 == "skipped"' "${RESULTS_FILE}" | wc -l)
  total_duration=$(awk '{ sum += $3 } END { printf "%.2f", sum }' "${RESULTS_FILE}")

  local total_tests=$((total_passed + total_failed + total_skipped))

  # --- Flaky test detection ---
  # A test is flaky if it has BOTH passed and failed outcomes across runs.
  # We find test_ids that appear with different statuses (excluding skipped).
  local flaky_tests
  flaky_tests=$(awk '$2 != "skipped" { print $1, $2 }' "${RESULTS_FILE}" \
    | sort -u \
    | awk '{ count[$1]++ } END { for (t in count) if (count[t] > 1) print t }' \
    | sort)

  # --- Failed tests (consistently failed = failed in all non-skip runs) ---
  local failed_tests
  failed_tests=$(awk '$2 == "failed"' "${RESULTS_FILE}" \
    | awk '{ print $1 }' \
    | sort -u)

  # --- Generate markdown ---
  generate_markdown "$total_tests" "$total_passed" "$total_failed" "$total_skipped" \
    "$total_duration" "$flaky_tests" "$failed_tests"
}

# --- Markdown Generation ---
generate_markdown() {
  local total_tests="$1"
  local total_passed="$2"
  local total_failed="$3"
  local total_skipped="$4"
  local total_duration="$5"
  local flaky_tests="$6"
  local failed_tests="$7"

  # Determine overall status icon
  local status_icon="✅"
  if [[ "$total_failed" -gt 0 ]]; then
    status_icon="❌"
  fi

  local md=""
  md+="# ${status_icon} Test Results Summary\n"
  md+="\n"
  md+="## Totals\n"
  md+="\n"
  md+="| Metric | Count |\n"
  md+="| --- | --- |\n"
  md+="| Total Tests | ${total_tests} |\n"
  md+="| Passed | ${total_passed} |\n"
  md+="| Failed | ${total_failed} |\n"
  md+="| Skipped | ${total_skipped} |\n"
  md+="| Duration | ${total_duration}s |\n"
  md+="\n"

  # Failed tests section
  if [[ -n "$failed_tests" ]]; then
    md+="## Failed Tests\n"
    md+="\n"
    while IFS= read -r test_name; do
      [[ -z "$test_name" ]] && continue
      md+="- \`${test_name}\`\n"
    done <<< "$failed_tests"
    md+="\n"
  fi

  # Flaky tests section
  if [[ -n "$flaky_tests" ]]; then
    md+="## Flaky Tests\n"
    md+="\n"
    md+="These tests had inconsistent results across runs:\n"
    md+="\n"
    while IFS= read -r test_name; do
      [[ -z "$test_name" ]] && continue
      md+="- \`${test_name}\`\n"
    done <<< "$flaky_tests"
    md+="\n"
  fi

  # Output the markdown
  if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%b' "$md" > "$OUTPUT_FILE"
    echo "Summary written to: $OUTPUT_FILE" >&2
  else
    printf '%b' "$md"
  fi
}

# --- Main ---
main() {
  local files=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output)
        [[ $# -lt 2 ]] && die "--output requires a filename argument"
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --help|-h)
        usage
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    die "No input files specified. Use --help for usage."
  fi

  # Create temp file for accumulating results
  RESULTS_FILE=$(mktemp)

  # Parse each input file based on extension
  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      die "File not found: $file"
    fi

    case "$file" in
      *.xml)
        parse_junit_xml "$file"
        ;;
      *.json)
        parse_json "$file"
        ;;
      *)
        die "Unsupported file format: $file (expected .xml or .json)"
        ;;
    esac
  done

  # Aggregate and generate summary
  aggregate_results
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
