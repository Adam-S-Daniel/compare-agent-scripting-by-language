#!/usr/bin/env bash
# aggregate.sh — Test Results Aggregator
#
# Parses test result files in multiple formats (JUnit XML, JSON),
# aggregates results across files (simulating a matrix build),
# identifies flaky tests (passed in some runs, failed in others),
# and generates a markdown summary for GitHub Actions job summaries.
#
# Usage:  ./aggregate.sh <directory>
#   <directory>  Directory containing .xml (JUnit) and/or .json result files
#   Output:      Markdown summary on stdout

set -euo pipefail

# generate_summary <dir>
# Delegates all parsing, aggregation, and markdown rendering to Python3.
# Python3 is used for reliable XML/JSON parsing and float arithmetic;
# bash handles argument validation and orchestration.
generate_summary() {
    local dir="$1"

    # Pass the directory via environment variable so the heredoc can remain
    # single-quoted (no unintended shell expansion inside Python source).
    DIR="$dir" python3 << 'PYEOF'
import json
import xml.etree.ElementTree as ET
import os
import glob
import sys
from collections import defaultdict

dir_path = os.environ["DIR"]
runs = []

# Process XML files first (sorted), then JSON files (sorted).
# Sorting ensures deterministic run numbering across identical inputs.
xml_files = sorted(glob.glob(os.path.join(dir_path, "*.xml")))
json_files = sorted(glob.glob(os.path.join(dir_path, "*.json")))

for filepath in xml_files + json_files:
    filename = os.path.basename(filepath)

    # ── JUnit XML ──────────────────────────────────────────────────────────
    if filepath.endswith(".xml"):
        try:
            tree = ET.parse(filepath)
            root = tree.getroot()
            # Support both <testsuites> wrapper and bare <testsuite> root.
            suites = (
                root.findall("testsuite")
                if root.tag == "testsuites"
                else [root]
            )

            for suite in suites:
                test_cases = []
                for tc in suite.findall("testcase"):
                    name = tc.get("name", "unknown")
                    if tc.find("failure") is not None or tc.find("error") is not None:
                        status = "failed"
                    elif tc.find("skipped") is not None:
                        status = "skipped"
                    else:
                        status = "passed"
                    test_cases.append({"name": name, "status": status})

                total = int(suite.get("tests", len(test_cases)))
                failures = int(suite.get("failures", 0)) + int(suite.get("errors", 0))
                skipped_count = int(suite.get("skipped", 0))
                passed_count = total - failures - skipped_count

                runs.append({
                    "suite": suite.get("name", filename),
                    "total": total,
                    "passed": passed_count,
                    "failed": failures,
                    "skipped": skipped_count,
                    "duration": float(suite.get("time", 0.0)),
                    "test_cases": test_cases,
                })
        except ET.ParseError as e:
            print(f"Error: failed to parse XML file '{filename}': {e}", file=sys.stderr)
            sys.exit(1)

    # ── JSON ───────────────────────────────────────────────────────────────
    elif filepath.endswith(".json"):
        try:
            with open(filepath) as f:
                data = json.load(f)
            tc_list = data.get("tests", [])
            runs.append({
                "suite": data.get("suite", filename),
                "total": len(tc_list),
                "passed": sum(1 for t in tc_list if t.get("status") == "passed"),
                "failed": sum(1 for t in tc_list if t.get("status") == "failed"),
                "skipped": sum(1 for t in tc_list if t.get("status") == "skipped"),
                "duration": float(data.get("duration", 0.0)),
                "test_cases": tc_list,
            })
        except (json.JSONDecodeError, KeyError) as e:
            print(f"Error: failed to parse JSON file '{filename}': {e}", file=sys.stderr)
            sys.exit(1)

if not runs:
    print("Error: no test result files found in directory", file=sys.stderr)
    sys.exit(1)

# ── Aggregate totals ───────────────────────────────────────────────────────
total_tests    = sum(r["total"]    for r in runs)
total_passed   = sum(r["passed"]   for r in runs)
total_failed   = sum(r["failed"]   for r in runs)
total_skipped  = sum(r["skipped"]  for r in runs)
total_duration = sum(r["duration"] for r in runs)

# ── Flaky test detection ───────────────────────────────────────────────────
# A test is flaky when it both passed and failed across different runs.
pass_in = defaultdict(list)
fail_in = defaultdict(list)
for run in runs:
    for tc in run["test_cases"]:
        s = tc.get("status", "unknown")
        if s == "passed":
            pass_in[tc["name"]].append(run["suite"])
        elif s == "failed":
            fail_in[tc["name"]].append(run["suite"])

flaky = []
for name in sorted(set(pass_in.keys()) & set(fail_in.keys())):
    flaky.append({
        "name": name,
        "passed_in": ", ".join(pass_in[name]),
        "failed_in": ", ".join(fail_in[name]),
    })

# ── Markdown output ────────────────────────────────────────────────────────
print("# Test Results Summary")
print("")
print("## Overview")
print("| Metric | Value |")
print("|--------|-------|")
print(f"| Total Tests | {total_tests} |")
print(f"| Passed | {total_passed} |")
print(f"| Failed | {total_failed} |")
print(f"| Skipped | {total_skipped} |")
print(f"| Total Duration | {total_duration:.2f}s |")
print("")
print("## Results by Run")
print("| Run | Suite | Tests | Passed | Failed | Skipped | Duration |")
print("|-----|-------|-------|--------|--------|---------|----------|")
for i, run in enumerate(runs, 1):
    print(
        f"| {i} | {run['suite']} | {run['total']} "
        f"| {run['passed']} | {run['failed']} | {run['skipped']} "
        f"| {run['duration']:.2f}s |"
    )
print("")
print("## Flaky Tests")
if flaky:
    print("| Test | Passed In | Failed In |")
    print("|------|-----------|-----------|")
    for f in flaky:
        print(f"| {f['name']} | {f['passed_in']} | {f['failed_in']} |")
else:
    print("")
    print("No flaky tests detected.")
PYEOF
}

# ── Entry point ────────────────────────────────────────────────────────────
main() {
    if [ $# -lt 1 ]; then
        echo "Error: Usage: $(basename "$0") <directory>" >&2
        exit 1
    fi

    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist" >&2
        exit 1
    fi

    generate_summary "$dir"
}

main "$@"
