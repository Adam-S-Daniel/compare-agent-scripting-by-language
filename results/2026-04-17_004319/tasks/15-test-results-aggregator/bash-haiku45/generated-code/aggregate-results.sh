#!/usr/bin/env bash
# Test results aggregator: parses JUnit XML and JSON test results,
# aggregates across multiple files, detects flaky tests, and generates markdown summaries.
set -euo pipefail

parse_junit_xml() {
  local xml_file="$1"
  [ -f "$xml_file" ] || return 1

  # Extract test counts and duration from XML
  local tests failed skipped passed duration
  tests=$(grep -oP 'tests="\K[0-9]+' "$xml_file" | head -1)
  failed=$(grep -oP 'failures="\K[0-9]+' "$xml_file" | head -1)
  skipped=$(grep -oP 'skipped="\K[0-9]+' "$xml_file" | head -1)
  duration=$(grep -oP 'time="\K[0-9.]+' "$xml_file" | head -1)

  # Defaults
  tests=${tests:-0}
  failed=${failed:-0}
  skipped=${skipped:-0}
  duration=${duration:-0}
  passed=$((tests - failed - skipped))

  # Output as JSON
  printf '{"passed":%d,"failed":%d,"skipped":%d,"total":%d,"duration":%.2f}\n' \
    "$passed" "$failed" "$skipped" "$tests" "${duration%.*}.${duration#*.}"
}

parse_json_results() {
  local json_file="$1"
  [ -f "$json_file" ] || return 1

  # Extract counts from JSON
  local passed failed skipped
  passed=$(jq -r '.passed // 0' "$json_file")
  failed=$(jq -r '.failed // 0' "$json_file")
  skipped=$(jq -r '.skipped // 0' "$json_file")

  printf '{"passed":%d,"failed":%d,"skipped":%d}\n' "$passed" "$failed" "$skipped"
}

aggregate_junit_files() {
  [ $# -gt 0 ] || { echo '{"error":"No files provided"}'; return 1; }

  local total_passed=0 total_failed=0 total_skipped=0
  local file

  for file in "$@"; do
    local result
    result=$(parse_junit_xml "$file") || continue

    local p f s
    p=$(echo "$result" | jq -r '.passed')
    f=$(echo "$result" | jq -r '.failed')
    s=$(echo "$result" | jq -r '.skipped')

    total_passed=$((total_passed + p))
    total_failed=$((total_failed + f))
    total_skipped=$((total_skipped + s))
  done

  printf '{"total_passed":%d,"total_failed":%d,"total_skipped":%d}\n' "$total_passed" "$total_failed" "$total_skipped"
}

detect_flaky_tests() {
  [ $# -ge 2 ] || { echo '{}'; return 1; }

  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" RETURN

  # Collect test results across all files
  local file
  for file in "$@"; do
    # Normalize: convert to single line, then split testcases
    tr '\n' ' ' < "$file" | \
      sed 's/<testcase/\n<testcase/g' | \
      grep -E '<testcase' | \
      while read -r line; do
        # Extract test name (first name attribute after <testcase tag)
        local name
        name=$(echo "$line" | sed -E 's/.*<testcase\s+name="([^"]+)".*/\1/')

        # Check if failure tag exists in this test block
        local status="passed"
        echo "$line" | grep -q '<failure' && status="failed"

        echo "$name:$status"
      done
  done | sort > "$tmpfile"

  # Find tests with inconsistent results (flaky)
  awk -F: '{status[$1][$2]++} END {
    for (test in status) {
      count = 0
      for (s in status[test]) count++
      if (count > 1) {
        print test
      }
    }
  }' "$tmpfile"
}

generate_markdown_summary() {
  local total_passed=0 total_failed=0 total_skipped=0 total_duration=0

  # Parse key=value arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      total_passed=*) total_passed="${1#*=}" ;;
      total_failed=*) total_failed="${1#*=}" ;;
      total_skipped=*) total_skipped="${1#*=}" ;;
      total_duration=*) total_duration="${1#*=}" ;;
    esac
    shift
  done

  cat <<EOF
# Test Results Summary

## Summary Statistics

- **Passed**: $total_passed
- **Failed**: $total_failed
- **Skipped**: $total_skipped
- **Duration**: ${total_duration}s

EOF
}

main() {
  local output_file=""
  local files=()

  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output)
        output_file="$2"
        shift 2
        ;;
      -h|--help)
        cat <<HELP
Usage: $0 [OPTIONS] <result-file...>

Parse test result files (JUnit XML or JSON) and generate aggregated report.

OPTIONS:
  -o, --output FILE   Write summary to FILE (default: stdout)
  -h, --help          Show this help message

EXAMPLES:
  $0 results/*.xml
  $0 -o summary.md run1-results.json run2-results.json
HELP
        return 0
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done

  [ ${#files[@]} -gt 0 ] || { echo "Error: No result files provided" >&2; return 1; }

  # Aggregate results
  local total_passed=0 total_failed=0 total_skipped=0 total_duration=0
  local file

  for file in "${files[@]}"; do
    [ -f "$file" ] || { echo "Error: File not found: $file" >&2; continue; }

    local result
    if [[ "$file" == *.xml ]]; then
      result=$(parse_junit_xml "$file") || continue
    elif [[ "$file" == *.json ]]; then
      result=$(parse_json_results "$file") || continue
    else
      echo "Error: Unsupported file format: $file" >&2
      continue
    fi

    local p f s d
    p=$(echo "$result" | jq -r '.passed // 0')
    f=$(echo "$result" | jq -r '.failed // 0')
    s=$(echo "$result" | jq -r '.skipped // 0')
    d=$(echo "$result" | jq -r '.duration // 0')

    total_passed=$((total_passed + p))
    total_failed=$((total_failed + f))
    total_skipped=$((total_skipped + s))
    total_duration=$(echo "$total_duration + $d" | bc -l)
  done

  # Detect flaky tests if multiple files
  local flaky_tests=""
  if [ ${#files[@]} -gt 1 ]; then
    flaky_tests=$(detect_flaky_tests "${files[@]}")
  fi

  # Generate summary
  local summary
  summary=$(generate_markdown_summary \
    total_passed="$total_passed" \
    total_failed="$total_failed" \
    total_skipped="$total_skipped" \
    total_duration="$total_duration")

  # Add flaky tests section if any found
  if [ -n "$flaky_tests" ]; then
    summary+=$'\n## Flaky Tests\n\n'
    summary+="The following tests passed in some runs but failed in others:\n\n"
    echo "$flaky_tests" | while read -r test; do
      summary+="- \`$test\`\n"
    done
  fi

  # Output result
  if [ -n "$output_file" ]; then
    echo -e "$summary" > "$output_file"
  else
    echo -e "$summary"
  fi
}

# Allow sourcing for tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
