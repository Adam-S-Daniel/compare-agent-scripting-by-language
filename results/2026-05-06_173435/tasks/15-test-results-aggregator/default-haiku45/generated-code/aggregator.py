"""Test results aggregator - parses multiple formats and generates summaries."""
import xml.etree.ElementTree as ET
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Any


def parse_junit_xml(filepath: str) -> Dict[str, Any]:
    """Parse a JUnit XML test results file.

    Returns a dict with keys: passed, failed, skipped, total, duration, tests
    """
    tree = ET.parse(filepath)
    root = tree.getroot()

    tests = []
    passed = 0
    failed = 0
    skipped = 0
    total_duration = 0.0

    for testsuite in root.findall(".//testsuite"):
        suite_time = float(testsuite.get("time", 0.0))

        for testcase in testsuite.findall("testcase"):
            test_name = testcase.get("name")
            classname = testcase.get("classname")
            duration = float(testcase.get("time", 0.0))

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
                "name": test_name,
                "classname": classname,
                "status": status,
                "duration": duration,
            })

        # Prefer testsuite's reported time; fall back to sum of test times
        if suite_time > 0:
            total_duration += suite_time
        else:
            total_duration += sum(float(tc.get("time", 0.0))
                                 for tc in testsuite.findall("testcase"))

    total = passed + failed + skipped

    return {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": total,
        "duration": total_duration,
        "tests": tests,
    }


def parse_json_results(filepath: str) -> Dict[str, Any]:
    """Parse a JSON test results file.

    Expected format:
    {
        "results": [
            {"name": "test_name", "status": "passed|failed|skipped", "duration": 1.0},
            ...
        ],
        "summary": {
            "total": N,
            "passed": N,
            "failed": N,
            "skipped": N,
            "duration": N.N
        }
    }
    """
    with open(filepath, "r") as f:
        data = json.load(f)

    tests = data.get("results", [])
    summary = data.get("summary", {})

    return {
        "passed": summary.get("passed", 0),
        "failed": summary.get("failed", 0),
        "skipped": summary.get("skipped", 0),
        "total": summary.get("total", 0),
        "duration": summary.get("duration", 0.0),
        "tests": tests,
    }


def aggregate_results(result_files: List[str]) -> Dict[str, Any]:
    """Aggregate test results from multiple files.

    Simulates a matrix build by combining results from different test runs.
    """
    total_passed = 0
    total_failed = 0
    total_skipped = 0
    total_duration = 0.0
    all_tests = []

    for filepath in result_files:
        if filepath.endswith(".xml"):
            result = parse_junit_xml(filepath)
        elif filepath.endswith(".json"):
            result = parse_json_results(filepath)
        else:
            raise ValueError(f"Unsupported file format: {filepath}")

        total_passed += result["passed"]
        total_failed += result["failed"]
        total_skipped += result["skipped"]
        total_duration += result["duration"]
        all_tests.extend(result["tests"])

    total_tests = total_passed + total_failed + total_skipped

    return {
        "total_passed": total_passed,
        "total_failed": total_failed,
        "total_skipped": total_skipped,
        "total_tests": total_tests,
        "total_duration": total_duration,
        "tests": all_tests,
    }


def find_flaky_tests(result_files: List[str]) -> Dict[str, Dict[str, int]]:
    """Identify flaky tests (passed in some runs, failed in others).

    Returns dict of {test_name: {passed_count: N, failed_count: N}}
    """
    test_results = defaultdict(lambda: {"passed_count": 0, "failed_count": 0})

    for filepath in result_files:
        if filepath.endswith(".xml"):
            result = parse_junit_xml(filepath)
        elif filepath.endswith(".json"):
            result = parse_json_results(filepath)
        else:
            continue

        for test in result["tests"]:
            test_name = test["name"]
            status = test["status"]

            if status == "passed":
                test_results[test_name]["passed_count"] += 1
            elif status == "failed":
                test_results[test_name]["failed_count"] += 1

    # Find tests that both passed and failed
    flaky = {
        name: counts
        for name, counts in test_results.items()
        if counts["passed_count"] > 0 and counts["failed_count"] > 0
    }

    return flaky


def generate_markdown_summary(result_files: List[str]) -> str:
    """Generate a markdown summary suitable for GitHub Actions job summary."""
    aggregated = aggregate_results(result_files)
    flaky = find_flaky_tests(result_files)

    lines = [
        "# Test Results Summary",
        "",
        "## Overall Statistics",
        f"✅ Passed: {aggregated['total_passed']}",
        f"❌ Failed: {aggregated['total_failed']}",
        f"⏭️ Skipped: {aggregated['total_skipped']}",
        f"Total Tests: {aggregated['total_tests']}",
        f"Duration: {aggregated['total_duration']:.2f}s",
        "",
    ]

    if aggregated["total_failed"] > 0:
        lines.append("## Failed Tests")
        for test in aggregated["tests"]:
            if test["status"] == "failed":
                lines.append(f"- `{test['name']}` ({test.get('classname', 'N/A')})")
        lines.append("")

    if flaky:
        lines.append("## Flaky Tests")
        for test_name in sorted(flaky.keys()):
            counts = flaky[test_name]
            lines.append(
                f"- `{test_name}` - Passed: {counts['passed_count']}, "
                f"Failed: {counts['failed_count']}"
            )
        lines.append("")

    return "\n".join(lines)
