#!/usr/bin/env bash
# Test Results Aggregator
#
# Parses JUnit XML and JSON test result files, aggregates results across
# multiple files (simulating a matrix CI build), computes totals, identifies
# flaky tests (passed in some runs, failed in others), and generates a
# markdown summary suitable for GitHub Actions job summaries.
#
# Usage: aggregate.sh <file1> [file2] ...
# Supported formats: JUnit XML (.xml), JSON (.json)

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: aggregate.sh <file1> [file2] ...

Parse test result files and generate a markdown summary.

Supported formats:
  *.xml   JUnit XML (testsuites/testsuite/testcase elements)
  *.json  JSON ({suite, results: [{name, status, duration}]})

Example:
  aggregate.sh results-*.xml results-*.json
EOF
    exit 1
}

[[ $# -eq 0 ]] && usage

# Temp directory for intermediate per-test data
tmp_dir=$(mktemp -d)
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

# All parsed results land here: STATUS<TAB>NAME<TAB>DURATION
all_results="$tmp_dir/all_results.tsv"
touch "$all_results"

# parse_junit FILE
# Emits STATUS<TAB>NAME<TAB>DURATION for each testcase in a JUnit XML file.
# Uses python3's standard library xml.etree for reliable XML parsing.
parse_junit() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

try:
    tree = ET.parse(sys.argv[1])
except ET.ParseError as exc:
    print(f"ERROR: Cannot parse XML '{sys.argv[1]}': {exc}", file=sys.stderr)
    sys.exit(1)

root = tree.getroot()
# Support both <testsuites> wrapper and bare <testsuite> as root
suites = root.findall("testsuite") if root.tag == "testsuites" else [root]

for suite in suites:
    for tc in suite.findall("testcase"):
        name     = tc.get("name", "unknown")
        duration = tc.get("time", "0") or "0"
        if tc.find("failure") is not None or tc.find("error") is not None:
            status = "failed"
        elif tc.find("skipped") is not None:
            status = "skipped"
        else:
            status = "passed"
        print(f"{status}\t{name}\t{duration}")
PYEOF
}

# parse_json FILE
# Emits STATUS<TAB>NAME<TAB>DURATION for each result in a JSON file.
# Expected schema: {"suite":"...", "results":[{"name":"...","status":"...","duration":0.0}]}
parse_json() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, json

try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
except (json.JSONDecodeError, OSError) as exc:
    print(f"ERROR: Cannot parse JSON '{sys.argv[1]}': {exc}", file=sys.stderr)
    sys.exit(1)

for r in data.get("results", []):
    name     = r.get("name", "unknown")
    status   = r.get("status", "unknown")
    duration = r.get("duration", 0)
    print(f"{status}\t{name}\t{duration}")
PYEOF
}

# Process each input file, routing to the appropriate parser by extension
for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        exit 1
    fi
    case "$file" in
        *.xml)
            if ! parse_junit "$file" >> "$all_results"; then
                echo "ERROR: Failed to parse XML file: $file" >&2
                exit 1
            fi
            ;;
        *.json)
            if ! parse_json "$file" >> "$all_results"; then
                echo "ERROR: Failed to parse JSON file: $file" >&2
                exit 1
            fi
            ;;
        *)
            echo "ERROR: Unsupported file format (expected .xml or .json): $file" >&2
            exit 1
            ;;
    esac
done

# Compute totals, detect flaky tests, and generate markdown — all in one
# python3 pass over the collected TSV for reliable float arithmetic.
python3 - "$all_results" <<'PYEOF'
import sys, os
from collections import defaultdict

# name -> list of statuses across all runs
results: dict[str, list[str]] = defaultdict(list)
total_passed  = 0
total_failed  = 0
total_skipped = 0
total_duration = 0.0

with open(sys.argv[1]) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        status, name, dur_str = parts[0], parts[1], parts[2]
        try:
            duration = float(dur_str)
        except ValueError:
            duration = 0.0
        results[name].append(status)
        total_duration += duration
        if status == "passed":
            total_passed  += 1
        elif status == "failed":
            total_failed  += 1
        elif status == "skipped":
            total_skipped += 1

total_tests = total_passed + total_failed + total_skipped

# Flaky = appeared as both passed and failed across different files
flaky = sorted(
    name for name, statuses in results.items()
    if "passed" in statuses and "failed" in statuses
)

# --- Markdown output ---
lines = [
    "## Test Results Summary",
    "",
    "| Metric | Value |",
    "|--------|-------|",
    f"| Total Tests | {total_tests} |",
    f"| ✅ Passed | {total_passed} |",
    f"| ❌ Failed | {total_failed} |",
    f"| ⏭️ Skipped | {total_skipped} |",
    f"| ⏱️ Duration | {total_duration:.2f}s |",
    "",
]

if flaky:
    lines += [
        "### ⚠️ Flaky Tests",
        "",
        *[f"- `{name}`" for name in flaky],
        "",
    ]
else:
    lines += ["### ✅ No Flaky Tests Detected", ""]

summary = "\n".join(lines)
print(summary)

# Machine-readable line for CI assertions (greppable from act output)
flaky_str = ",".join(flaky) if flaky else "none"
print(
    f"AGGREGATE_RESULT: "
    f"passed={total_passed} "
    f"failed={total_failed} "
    f"skipped={total_skipped} "
    f"duration={total_duration:.2f}s "
    f"flaky={flaky_str}"
)

# Write markdown to GitHub Actions step summary when running in CI
step_summary = os.environ.get("GITHUB_STEP_SUMMARY", "")
if step_summary:
    with open(step_summary, "a") as sf:
        sf.write(summary + "\n")
PYEOF
