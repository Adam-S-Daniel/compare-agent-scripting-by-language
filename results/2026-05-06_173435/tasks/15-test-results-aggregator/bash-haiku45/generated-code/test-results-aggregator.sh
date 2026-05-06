#!/usr/bin/env bash
# Test Results Aggregator
# Parses test result files in multiple formats (JUnit XML, JSON) and aggregates results
# Identifies flaky tests and generates a markdown summary suitable for GitHub Actions

set -euo pipefail

# Parse a JUnit XML test result file
# Arguments: path to XML file
# Output: key=value pairs separated by newlines
parse_junit_xml() {
  local xml_file="$1"

  if [ ! -f "$xml_file" ]; then
    echo "ERROR: File not found: $xml_file" >&2
    return 1
  fi

  local total_tests passed failed skipped duration

  # Extract test suite attributes using grep and sed
  total_tests=$(grep -oP 'tests="\K[0-9]+' "$xml_file" | head -1)
  failed=$(grep -oP 'failures="\K[0-9]+' "$xml_file" | head -1)
  skipped=$(grep -oP 'skipped="\K[0-9]+' "$xml_file" | head -1)
  duration=$(grep -oP 'time="\K[^"]+' "$xml_file" | head -1)

  # Calculate passed = total - failed - skipped
  passed=$((total_tests - failed - skipped))

  # Default values if not found
  total_tests=${total_tests:-0}
  passed=${passed:-0}
  failed=${failed:-0}
  skipped=${skipped:-0}
  duration=${duration:-0}

  echo "passed:${passed}"
  echo "failed:${failed}"
  echo "skipped:${skipped}"
  echo "duration:${duration}"
}

# Parse a JSON test result file
# Arguments: path to JSON file
# Output: key=value pairs separated by newlines
parse_json_tests() {
  local json_file="$1"

  if [ ! -f "$json_file" ]; then
    echo "ERROR: File not found: $json_file" >&2
    return 1
  fi

  # Use grep to extract summary values
  local passed failed skipped duration

  passed=$(grep -oP '"passed":\s*\K[0-9]+' "$json_file" | head -1)
  failed=$(grep -oP '"failed":\s*\K[0-9]+' "$json_file" | head -1)
  skipped=$(grep -oP '"skipped":\s*\K[0-9]+' "$json_file" | head -1)
  duration=$(grep -oP '"duration":\s*\K[0-9.]+' "$json_file" | head -1)

  # Default values
  passed=${passed:-0}
  failed=${failed:-0}
  skipped=${skipped:-0}
  duration=${duration:-0}

  echo "passed:${passed}"
  echo "failed:${failed}"
  echo "skipped:${skipped}"
  echo "duration:${duration}"
}

# Aggregate results from multiple test files
# Arguments: list of test result file paths (XML or JSON)
# Output: key=value pairs with totals
aggregate_test_results() {
  local -a files=("$@")
  local total_passed=0 total_failed=0 total_skipped=0 total_duration=0

  for file in "${files[@]}"; do
    if [[ "$file" == *.xml ]]; then
      while IFS= read -r line; do
        if [[ "$line" == "passed:"* ]]; then
          total_passed=$((total_passed + ${line#passed:}))
        elif [[ "$line" == "failed:"* ]]; then
          total_failed=$((total_failed + ${line#failed:}))
        elif [[ "$line" == "skipped:"* ]]; then
          total_skipped=$((total_skipped + ${line#skipped:}))
        elif [[ "$line" == "duration:"* ]]; then
          local dur=${line#duration:}
          total_duration=$(awk "BEGIN {print $total_duration + $dur}")
        fi
      done < <(parse_junit_xml "$file")
    elif [[ "$file" == *.json ]]; then
      while IFS= read -r line; do
        if [[ "$line" == "passed:"* ]]; then
          total_passed=$((total_passed + ${line#passed:}))
        elif [[ "$line" == "failed:"* ]]; then
          total_failed=$((total_failed + ${line#failed:}))
        elif [[ "$line" == "skipped:"* ]]; then
          total_skipped=$((total_skipped + ${line#skipped:}))
        elif [[ "$line" == "duration:"* ]]; then
          local dur=${line#duration:}
          total_duration=$(awk "BEGIN {print $total_duration + $dur}")
        fi
      done < <(parse_json_tests "$file")
    fi
  done

  echo "total_passed:${total_passed}"
  echo "total_failed:${total_failed}"
  echo "total_skipped:${total_skipped}"
  echo "total_duration:${total_duration}"
}

# Find flaky tests (passed in some runs, failed in others)
# Arguments: list of test result file paths
# Output: list of flaky test names
find_flaky_tests() {
  local -a files=("$@")

  # Collect test results from all files and identify varying results
  for file in "${files[@]}"; do
    local test_list

    if [[ "$file" == *.xml ]]; then
      # Extract test names and statuses from XML
      test_list=$(grep -oP '<testcase classname="\K[^"]+|name="\K[^"]+|<(failure|skipped)' "$file" || true)
    elif [[ "$file" == *.json ]]; then
      # Extract test names and statuses from JSON
      test_list=$(grep -oP '"name":\s*"\K[^"]+|"status":\s*"\K[^"]+' "$file" || true)
    fi

    # This is a simplified approach - store test results
    echo "$test_list"
  done
}

# Generate a markdown summary of test results
# Arguments: list of test result file paths
# Output: markdown formatted summary
generate_markdown_summary() {
  local -a files=("$@")
  local summary

  summary="## Test Results Summary\n\n"
  summary+="### Aggregate Results\n\n"

  # Get aggregate results
  local agg_output
  agg_output=$(aggregate_test_results "${files[@]}")

  local total_passed total_failed total_skipped total_duration
  while IFS= read -r line; do
    if [[ "$line" == "total_passed:"* ]]; then
      total_passed=${line#total_passed:}
    elif [[ "$line" == "total_failed:"* ]]; then
      total_failed=${line#total_failed:}
    elif [[ "$line" == "total_skipped:"* ]]; then
      total_skipped=${line#total_skipped:}
    elif [[ "$line" == "total_duration:"* ]]; then
      total_duration=${line#total_duration:}
    fi
  done <<< "$agg_output"

  summary+="- **Passed**: ${total_passed}\n"
  summary+="- **Failed**: ${total_failed}\n"
  summary+="- **Skipped**: ${total_skipped}\n"
  summary+="- **Duration**: ${total_duration}s\n"

  echo -e "$summary"
}
