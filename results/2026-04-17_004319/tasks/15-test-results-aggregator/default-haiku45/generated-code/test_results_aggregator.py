#!/usr/bin/env python3
"""
Test Results Aggregator: Parse and aggregate test results from multiple formats.

This script parses test result files in JUnit XML and JSON formats,
aggregates results across multiple files (simulating matrix builds),
computes statistics (passed, failed, skipped, duration),
identifies flaky tests (inconsistent results across runs),
and generates a markdown summary for GitHub Actions job summaries.
"""

import json
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import defaultdict


def parse_junit_xml(filepath: str) -> dict:
    """
    Parse a JUnit XML test result file.

    Returns a dict with keys:
    - passed: number of passed tests
    - failed: number of failed tests
    - skipped: number of skipped tests
    - total: total number of tests
    - duration: total execution time
    - tests: list of test case dicts
    """
    tree = ET.parse(filepath)
    root = tree.getroot()

    tests = []
    passed = 0
    failed = 0
    skipped = 0

    for testsuite in root.findall(".//testsuite"):
        for testcase in testsuite.findall("testcase"):
            name = testcase.get("name")
            classname = testcase.get("classname")
            duration = float(testcase.get("time", 0))

            if testcase.find("failure") is not None:
                status = "failed"
                failed += 1
            elif testcase.find("skipped") is not None:
                status = "skipped"
                skipped += 1
            else:
                status = "passed"
                passed += 1

            tests.append({
                "name": name,
                "classname": classname,
                "status": status,
                "duration": duration,
            })

    total = passed + failed + skipped
    duration = float(root.get("time", 0))

    return {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": total,
        "duration": duration,
        "tests": tests,
    }


def parse_json_results(filepath: str) -> dict:
    """
    Parse a JSON test result file.

    JSON format has a 'testsuites' array with suite objects containing:
    - name: suite name
    - tests: total test count
    - passed: passed count
    - failed: failed count
    - skipped: skipped count
    - duration: execution time
    - testcases: array of individual test case objects

    Returns a dict with the same structure as parse_junit_xml.
    """
    with open(filepath, "r") as f:
        data = json.load(f)

    tests = []
    passed = 0
    failed = 0
    skipped = 0
    total_duration = 0.0

    for suite in data.get("testsuites", []):
        total_duration += suite.get("duration", 0)

        for testcase in suite.get("testcases", []):
            name = testcase.get("name")
            classname = testcase.get("classname")
            status = testcase.get("status", "passed")
            duration = testcase.get("duration", 0)

            tests.append({
                "name": name,
                "classname": classname,
                "status": status,
                "duration": duration,
            })

            if status == "passed":
                passed += 1
            elif status == "failed":
                failed += 1
            elif status == "skipped":
                skipped += 1

    total = passed + failed + skipped

    return {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": total,
        "duration": total_duration,
        "tests": tests,
    }


def aggregate_results(filepaths: list) -> dict:
    """
    Aggregate results from multiple test result files.

    Returns a dict with keys:
    - total_passed: sum of passed tests
    - total_failed: sum of failed tests
    - total_skipped: sum of skipped tests
    - total_duration: sum of execution times
    - num_runs: number of files aggregated
    - all_tests: list of all tests across all files
    """
    total_passed = 0
    total_failed = 0
    total_skipped = 0
    total_duration = 0.0
    all_tests = []

    for filepath in filepaths:
        if filepath.endswith(".xml"):
            result = parse_junit_xml(filepath)
        elif filepath.endswith(".json"):
            result = parse_json_results(filepath)
        else:
            continue

        total_passed += result["passed"]
        total_failed += result["failed"]
        total_skipped += result["skipped"]
        total_duration += result["duration"]
        all_tests.extend(result["tests"])

    return {
        "total_passed": total_passed,
        "total_failed": total_failed,
        "total_skipped": total_skipped,
        "total_duration": total_duration,
        "num_runs": len(filepaths),
        "all_tests": all_tests,
    }


def find_flaky_tests(filepaths: list) -> dict:
    """
    Identify tests that are flaky (pass in some runs, fail in others).

    Returns a dict where keys are test names and values are:
    {
        "runs": [
            {"status": "passed|failed|skipped", "duration": float},
            ...
        ]
    }

    Only includes tests that have different statuses across runs.
    """
    test_results = defaultdict(list)

    for filepath in filepaths:
        if filepath.endswith(".xml"):
            result = parse_junit_xml(filepath)
        elif filepath.endswith(".json"):
            result = parse_json_results(filepath)
        else:
            continue

        for test in result["tests"]:
            key = f"{test['classname']}::{test['name']}"
            test_results[key].append({
                "status": test["status"],
                "duration": test["duration"],
            })

    flaky = {}
    for test_key, runs in test_results.items():
        statuses = {run["status"] for run in runs}
        if len(statuses) > 1:
            test_name = test_key.split("::")[-1]
            flaky[test_name] = {"runs": runs}

    return flaky


def generate_markdown_summary(aggregated: dict, flaky: dict) -> str:
    """
    Generate a markdown summary of test results.

    Returns a markdown string suitable for GitHub Actions job summary,
    including total counts, duration, and flaky test details.
    """
    lines = [
        "# Test Results Summary",
        "",
        "## Overall Statistics",
        "",
        f"| Metric | Count |",
        f"|--------|-------|",
        f"| Passed | {aggregated['total_passed']} |",
        f"| Failed | {aggregated['total_failed']} |",
        f"| Skipped | {aggregated['total_skipped']} |",
        f"| **Total** | **{aggregated['total_passed'] + aggregated['total_failed'] + aggregated['total_skipped']}** |",
        f"| Duration | {aggregated['total_duration']:.2f}s |",
        f"| Runs | {aggregated['num_runs']} |",
        "",
    ]

    if flaky:
        lines.extend([
            "## Flaky Tests",
            "",
            "The following tests show inconsistent results across runs:",
            "",
        ])
        for test_name, details in sorted(flaky.items()):
            statuses = [run["status"] for run in details["runs"]]
            lines.append(f"- **{test_name}**: {', '.join(statuses)}")
        lines.append("")
    else:
        lines.extend([
            "## Flaky Tests",
            "",
            "No flaky tests detected.",
            "",
        ])

    return "\n".join(lines)


def main():
    """Main entry point for command-line usage."""
    import sys
    if len(sys.argv) < 2:
        print("Usage: test_results_aggregator.py <result_file1> [result_file2] ...")
        sys.exit(1)

    files = sys.argv[1:]
    aggregated = aggregate_results(files)
    flaky = find_flaky_tests(files)
    summary = generate_markdown_summary(aggregated, flaky)
    print(summary)


if __name__ == "__main__":
    main()
