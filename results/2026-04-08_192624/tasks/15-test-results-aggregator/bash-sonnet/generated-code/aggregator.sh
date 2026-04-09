#!/usr/bin/env bash
# aggregator.sh — Parse JUnit XML and JSON test results, aggregate across
# multiple files (matrix builds), identify flaky tests, and generate a
# markdown summary suitable for GitHub Actions job summaries.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage: aggregator.sh [OPTIONS] FILE [FILE ...]

Parse JUnit XML and JSON test result files and produce an aggregated summary.

Options:
  --markdown   Emit a Markdown table summary (GitHub Actions job summary format)
  --flaky      Enable flaky test detection (tests that pass in some runs, fail in others)
  --help       Show this help message

Supported formats:
  *.xml   JUnit XML (testsuite element)
  *.json  JSON object with "tests" array (status: passed/failed/skipped)

Output (default):
  passed=N failed=N skipped=N duration=N.Ns
EOF
  exit 1
}

# ---------------------------------------------------------------------------
# Helper: die with error message
# ---------------------------------------------------------------------------
die() {
  echo "Error: $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Parse a JUnit XML file.
# Outputs lines: "name=<test> status=<passed|failed|skipped> duration=<s>"
# ---------------------------------------------------------------------------
parse_junit_xml() {
  local file="$1"
  # Use grep + sed to extract testcase elements without requiring xmllint.
  # Each <testcase .../> or <testcase ...>...</testcase> is processed.
  local in_case=0
  local tc_name="" tc_time="" tc_status="passed"
  while IFS= read -r line; do
    # Start of a testcase
    if [[ "$line" =~ \<testcase ]]; then
      in_case=1
      tc_status="passed"
      # Extract name attribute
      if [[ "$line" =~ name=\"([^\"]+)\" ]]; then
        tc_name="${BASH_REMATCH[1]}"
      fi
      # Extract time attribute
      if [[ "$line" =~ time=\"([^\"]+)\" ]]; then
        tc_time="${BASH_REMATCH[1]}"
      else
        tc_time="0"
      fi
    fi
    # Detect failure/error inside a testcase block
    if [[ $in_case -eq 1 ]]; then
      if [[ "$line" =~ \<failure || "$line" =~ \<error ]]; then
        tc_status="failed"
      fi
      if [[ "$line" =~ \<skipped ]]; then
        tc_status="skipped"
      fi
    fi
    # End of testcase: self-closing or closing tag
    local self_close close_tag
    self_close=0; close_tag=0
    [[ "$line" =~ /\>$ ]] && self_close=1
    [[ "$line" =~ \</testcase\> ]] && close_tag=1
    if [[ $in_case -eq 1 && ( $self_close -eq 1 || $close_tag -eq 1 ) ]]; then
      echo "name=$tc_name status=$tc_status duration=$tc_time"
      in_case=0
      tc_name=""
      tc_time=""
      tc_status="passed"
    fi
  done < "$file"
}

# ---------------------------------------------------------------------------
# Parse a JSON test result file.
# Expects: {"tests": [{"name":"...","status":"...","duration":N}, ...]}
# Outputs same format as parse_junit_xml.
# Requires: python3 (available on virtually all CI runners)
# ---------------------------------------------------------------------------
parse_json() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for t in data.get("tests", []):
    name = t.get("name", "unknown")
    status = t.get("status", "unknown")
    dur = t.get("duration", 0)
    print(f"name={name} status={status} duration={dur}")
PYEOF
}

# ---------------------------------------------------------------------------
# Parse a single file (auto-detect format)
# ---------------------------------------------------------------------------
parse_file() {
  local file="$1"
  [[ -f "$file" ]] || die "File not found: $file"
  case "$file" in
    *.xml)  parse_junit_xml "$file" ;;
    *.json) parse_json "$file" ;;
    *)      die "Unsupported file format: $file (expected .xml or .json)" ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
MARKDOWN=0
FLAKY=0
FILES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown) MARKDOWN=1; shift ;;
    --flaky)    FLAKY=1;    shift ;;
    --help)     usage ;;
    --*)        die "Unknown option: $1" ;;
    *)          FILES+=("$1"); shift ;;
  esac
done

[[ ${#FILES[@]} -eq 0 ]] && usage

# Validate all files before processing (errors in process substitution are subshells)
for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || die "File not found: $file"
  case "$file" in
    *.xml|*.json) ;;
    *) die "Unsupported file format: $file (expected .xml or .json)" ;;
  esac
done

# Accumulate totals
total_passed=0
total_failed=0
total_skipped=0
total_duration=0

# For flaky detection: track per-test pass/fail counts across files
declare -A test_pass_count
declare -A test_fail_count

for file in "${FILES[@]}"; do
  while IFS= read -r record; do
    # Parse record fields: name=... status=... duration=...
    name="${record#*name=}";    name="${name%% *}"
    status="${record#*status=}"; status="${status%% *}"
    dur="${record#*duration=}";  dur="${dur%% *}"

    case "$status" in
      passed)  total_passed=$((total_passed + 1))  ;;
      failed)  total_failed=$((total_failed + 1))  ;;
      skipped) total_skipped=$((total_skipped + 1)) ;;
    esac

    # Accumulate duration (uses python3 for float arithmetic)
    total_duration=$(python3 -c "print($total_duration + $dur)")

    # Track per-test results for flaky detection
    if [[ $FLAKY -eq 1 ]]; then
      if [[ "$status" == "passed" ]]; then
        test_pass_count["$name"]=$(( ${test_pass_count["$name"]:-0} + 1 )) || true
      elif [[ "$status" == "failed" ]]; then
        test_fail_count["$name"]=$(( ${test_fail_count["$name"]:-0} + 1 )) || true
      fi
    fi
  done < <(parse_file "$file")
done

# Round duration to 1 decimal
total_duration=$(python3 -c "print(round($total_duration, 1))")

# ---------------------------------------------------------------------------
# Identify flaky tests (appeared both passing and failing across files)
# ---------------------------------------------------------------------------
flaky_tests=()
if [[ $FLAKY -eq 1 ]]; then
  for tname in "${!test_pass_count[@]}"; do
    if [[ ${test_fail_count["$tname"]:-0} -gt 0 && ${test_pass_count["$tname"]:-0} -gt 0 ]]; then
      flaky_tests+=("$tname")
    fi
  done
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ $MARKDOWN -eq 1 ]]; then
  echo "## Test Results"
  echo ""
  echo "| Metric | Value |"
  echo "| ------ | ----- |"
  echo "| Passed | $total_passed |"
  echo "| Failed | $total_failed |"
  echo "| Skipped | $total_skipped |"
  echo "| Duration | ${total_duration}s |"
  if [[ $FLAKY -eq 1 && ${#flaky_tests[@]} -gt 0 ]]; then
    echo ""
    echo "### Flaky Tests"
    echo ""
    for ft in "${flaky_tests[@]}"; do
      echo "- $ft"
    done
  fi
else
  echo "passed=$total_passed failed=$total_failed skipped=$total_skipped duration=${total_duration}s"
  if [[ $FLAKY -eq 1 ]]; then
    if [[ ${#flaky_tests[@]} -gt 0 ]]; then
      echo "flaky=${#flaky_tests[@]}"
      for ft in "${flaky_tests[@]}"; do
        echo "flaky_test=$ft"
      done
    else
      echo "flaky=0"
    fi
  fi
fi
