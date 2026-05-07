#!/usr/bin/env bash
# aggregate.sh - Test Results Aggregator
#
# Parses JUnit XML and JSON test result files, aggregates across multiple
# files (simulating a matrix build), computes totals, identifies flaky tests
# (passed in some runs, failed in others), and generates a markdown summary.
#
# Usage: aggregate.sh <path>
#   <path> can be a directory (processes *.xml and *.json) or a single file.

set -euo pipefail

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
  echo "Usage: $(basename "$0") <path>" >&2
  echo "  <path>  Directory containing .xml/.json test results, or a single file." >&2
  exit 1
}

# ── XML parser via Python3 ───────────────────────────────────────────────────
# Outputs TSV lines: <test_id>\t<status>\t<duration>
# status is one of: passed | failed | skipped
parse_junit_xml() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import xml.etree.ElementTree as ET, sys

tree = ET.parse(sys.argv[1])
root = tree.getroot()

# Handle both <testsuites> root and bare <testsuite> root
suites = root.findall('testsuite') if root.tag == 'testsuites' else [root]

for suite in suites:
    for tc in suite.findall('testcase'):
        classname = tc.get('classname', '')
        name = tc.get('name', '')
        # Build unique test id: classname::name or just name
        test_id = f"{classname}::{name}" if classname else name
        duration = tc.get('time', '0') or '0'
        if tc.find('failure') is not None or tc.find('error') is not None:
            status = 'failed'
        elif tc.find('skipped') is not None:
            status = 'skipped'
        else:
            status = 'passed'
        print(f"{test_id}\t{status}\t{duration}")
PYEOF
}

# ── JSON parser via jq ────────────────────────────────────────────────────────
# Expects: { "results": [{ "name": str, "status": str, "duration": float }] }
parse_json_results() {
  local file="$1"
  jq -r '.results[] | "\(.name)\t\(.status)\t\(.duration)"' "$file"
}

# ── Determine parser for a file ───────────────────────────────────────────────
parse_file() {
  local file="$1"
  case "$file" in
    *.xml)  parse_junit_xml "$file" ;;
    *.json) parse_json_results "$file" ;;
    *)
      echo "Error: unsupported file type: $file" >&2
      return 1
      ;;
  esac
}

# ── Collect all result files from a path ─────────────────────────────────────
collect_files() {
  local path="$1"
  if [ -d "$path" ]; then
    find "$path" -maxdepth 1 \( -name '*.xml' -o -name '*.json' \) | sort
  elif [ -f "$path" ]; then
    echo "$path"
  else
    echo "Error: path not found: $path" >&2
    return 1
  fi
}

# ── Main aggregation logic ─────────────────────────────────────────────────
main() {
  if [ $# -eq 0 ]; then
    echo "Error: no path provided." >&2
    usage
  fi

  local path="$1"

  # Collect files
  local files
  files=$(collect_files "$path") || exit 1

  if [ -z "$files" ]; then
    echo "Error: no .xml or .json files found in $path" >&2
    exit 1
  fi

  # Per-test tracking: associative arrays keyed by test_id
  # pass_count[id] = number of runs where it passed
  # fail_count[id] = number of runs where it failed
  declare -A pass_count
  declare -A fail_count
  declare -A skip_count
  declare -A fail_file

  local total=0 passed=0 failed=0 skipped=0
  local total_duration=0

  # Process each file
  while IFS= read -r file; do
    local parsed
    parsed=$(parse_file "$file") || continue

    while IFS=$'\t' read -r test_id status duration; do
      [ -z "$test_id" ] && continue
      total=$(( total + 1 ))
      # Accumulate duration with awk for float addition
      total_duration=$(awk "BEGIN { printf \"%.2f\", $total_duration + $duration }")

      case "$status" in
        passed)
          passed=$(( passed + 1 ))
          pass_count[$test_id]=$(( ${pass_count[$test_id]:-0} + 1 ))
          ;;
        failed)
          failed=$(( failed + 1 ))
          fail_count[$test_id]=$(( ${fail_count[$test_id]:-0} + 1 ))
          fail_file[$test_id]="$file"
          ;;
        skipped)
          skipped=$(( skipped + 1 ))
          skip_count[$test_id]=$(( ${skip_count[$test_id]:-0} + 1 ))
          ;;
      esac
    done <<< "$parsed"
  done <<< "$files"

  # ── Find flaky tests: appeared in both pass_count and fail_count ───────────
  local flaky_tests=()
  for test_id in "${!pass_count[@]}"; do
    if [ "${fail_count[$test_id]:-0}" -gt 0 ]; then
      flaky_tests+=("$test_id")
    fi
  done

  # ── Find consistently failing tests (failed but never passed) ─────────────
  local failing_tests=()
  for test_id in "${!fail_count[@]}"; do
    if [ "${pass_count[$test_id]:-0}" -eq 0 ]; then
      failing_tests+=("$test_id")
    fi
  done

  # ── Emit machine-readable summary lines for workflow assertions ───────────
  echo "TOTAL:${total} PASSED:${passed} FAILED:${failed} SKIPPED:${skipped}"
  for ft in "${flaky_tests[@]}"; do
    echo "FLAKY:${ft}"
  done

  # ── Generate markdown summary ─────────────────────────────────────────────
  echo ""
  echo "# Test Results Summary"
  echo ""
  echo "## Totals"
  echo ""
  echo "| Tests | Passed | Failed | Skipped | Duration |"
  echo "|-------|--------|--------|---------|----------|"
  echo "| ${total} | ${passed} | ${failed} | ${skipped} | ${total_duration}s |"
  echo ""

  # Flaky section
  echo "## Flaky Tests"
  echo ""
  if [ ${#flaky_tests[@]} -eq 0 ]; then
    echo "_No flaky tests detected._"
  else
    echo "| Test | Passed Runs | Failed Runs |"
    echo "|------|-------------|-------------|"
    for ft in "${flaky_tests[@]}"; do
      echo "| \`${ft}\` | ${pass_count[$ft]} | ${fail_count[$ft]} |"
    done
  fi
  echo ""

  # Failed section
  echo "## Failed Tests"
  echo ""
  if [ ${#failing_tests[@]} -eq 0 ] && [ ${#flaky_tests[@]} -eq 0 ]; then
    echo "_No failing tests._"
  else
    echo "| Test | Last Seen In |"
    echo "|------|-------------|"
    for ft in "${failing_tests[@]}"; do
      echo "| \`${ft}\` | ${fail_file[$ft]:-unknown} |"
    done
    for ft in "${flaky_tests[@]}"; do
      echo "| \`${ft}\` _(flaky)_ | ${fail_file[$ft]:-unknown} |"
    done
  fi
}

main "$@"
