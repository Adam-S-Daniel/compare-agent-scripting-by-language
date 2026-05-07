#!/usr/bin/env python3
"""Test results aggregator for matrix CI builds.

Parses JUnit XML and JSON test result files, aggregates across multiple runs,
computes totals, identifies flaky tests, and generates a markdown summary.
"""

import json
import os
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field


@dataclass
class TestResult:
    suite: str
    name: str
    status: str  # "passed", "failed", "skipped"
    duration: float
    message: str = ""


@dataclass
class AggregatedResults:
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    duration: float = 0.0
    results: list = field(default_factory=list)
    flaky_tests: list = field(default_factory=list)


def parse_junit_xml(filepath):
    """Parse a JUnit XML file and return a list of TestResult objects."""
    try:
        tree = ET.parse(filepath)
    except ET.ParseError as e:
        print(f"Error parsing XML file {filepath}: {e}", file=sys.stderr)
        return []

    root = tree.getroot()
    results = []

    # Handle both <testsuites><testsuite>... and bare <testsuite>...
    suites = root.findall(".//testsuite")
    if root.tag == "testsuite" and not suites:
        suites = [root]

    for suite in suites:
        suite_name = suite.get("name", "unknown")
        for tc in suite.findall("testcase"):
            name = tc.get("name", "unknown")
            duration = float(tc.get("time", "0"))

            if tc.find("failure") is not None:
                status = "failed"
                msg = tc.find("failure").get("message", "")
            elif tc.find("skipped") is not None:
                status = "skipped"
                msg = tc.find("skipped").get("message", "")
            elif tc.find("error") is not None:
                status = "failed"
                msg = tc.find("error").get("message", "")
            else:
                status = "passed"
                msg = ""

            results.append(TestResult(
                suite=suite_name, name=name,
                status=status, duration=duration, message=msg
            ))

    return results


def parse_json(filepath):
    """Parse a JSON test result file and return a list of TestResult objects."""
    try:
        with open(filepath) as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"Error parsing JSON file {filepath}: {e}", file=sys.stderr)
        return []

    suite_name = data.get("suite", "unknown")
    results = []

    for test in data.get("tests", []):
        results.append(TestResult(
            suite=suite_name,
            name=test.get("name", "unknown"),
            status=test.get("status", "unknown"),
            duration=float(test.get("duration", 0)),
            message=test.get("message", "")
        ))

    return results


def discover_files(directory):
    """Find all .xml and .json test result files in a directory."""
    if not os.path.isdir(directory):
        print(f"Error: '{directory}' is not a valid directory", file=sys.stderr)
        return []

    files = []
    for fname in sorted(os.listdir(directory)):
        fpath = os.path.join(directory, fname)
        if not os.path.isfile(fpath):
            continue
        if fname.endswith(".xml") or fname.endswith(".json"):
            files.append(fpath)
    return files


def find_flaky_tests(all_results):
    """Identify tests that passed in some runs and failed in others.

    Groups by (suite, test_name) and checks if both passed and failed statuses
    exist for the same test across different runs.
    """
    # Track statuses per unique test identity
    test_statuses = defaultdict(set)
    for r in all_results:
        key = f"{r.suite}.{r.name}"
        if r.status in ("passed", "failed"):
            test_statuses[key].add(r.status)

    flaky = sorted(
        key for key, statuses in test_statuses.items()
        if "passed" in statuses and "failed" in statuses
    )
    return flaky


def aggregate(directory):
    """Parse all test files in directory and compute aggregated results."""
    files = discover_files(directory)
    if not files:
        print(f"No test result files found in '{directory}'", file=sys.stderr)
        return AggregatedResults()

    all_results = []
    total_duration = 0.0

    for fpath in files:
        if fpath.endswith(".xml"):
            results = parse_junit_xml(fpath)
            # Use suite-level time from XML for duration
            try:
                tree = ET.parse(fpath)
                for suite in tree.findall(".//testsuite"):
                    total_duration += float(suite.get("time", "0"))
            except Exception:
                total_duration += sum(r.duration for r in results)
        else:
            results = parse_json(fpath)
            total_duration += sum(r.duration for r in results)

        all_results.extend(results)

    passed = sum(1 for r in all_results if r.status == "passed")
    failed = sum(1 for r in all_results if r.status == "failed")
    skipped = sum(1 for r in all_results if r.status == "skipped")
    total = len(all_results)
    flaky = find_flaky_tests(all_results)

    return AggregatedResults(
        total=total, passed=passed, failed=failed, skipped=skipped,
        duration=round(total_duration, 1), results=all_results,
        flaky_tests=flaky
    )


def generate_markdown(agg):
    """Generate a markdown summary of aggregated test results."""
    lines = []
    lines.append("# Test Results Summary")
    lines.append("")

    pass_rate = (agg.passed / agg.total * 100) if agg.total > 0 else 0.0

    lines.append("## Totals")
    lines.append("")
    lines.append(f"| Metric | Value |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Total Tests | {agg.total} |")
    lines.append(f"| Passed | {agg.passed} |")
    lines.append(f"| Failed | {agg.failed} |")
    lines.append(f"| Skipped | {agg.skipped} |")
    lines.append(f"| Pass Rate | {pass_rate:.1f}% |")
    lines.append(f"| Duration | {agg.duration}s |")
    lines.append("")

    lines.append("## Flaky Tests")
    lines.append("")
    if agg.flaky_tests:
        lines.append("Tests that passed in some runs and failed in others:")
        lines.append("")
        for t in agg.flaky_tests:
            lines.append(f"- `{t}`")
    else:
        lines.append("No flaky tests detected.")
    lines.append("")

    if agg.failed > 0:
        lines.append("## Failed Tests")
        lines.append("")
        seen = set()
        for r in agg.results:
            if r.status == "failed":
                key = f"{r.suite}.{r.name}"
                if key not in seen:
                    seen.add(key)
                    msg = f": {r.message}" if r.message else ""
                    lines.append(f"- `{key}`{msg}")
        lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: aggregator.py <directory>", file=sys.stderr)
        sys.exit(1)

    directory = sys.argv[1]
    agg = aggregate(directory)

    # Structured output for test harness parsing
    print(f"TOTAL_TESTS: {agg.total}")
    print(f"TOTAL_PASSED: {agg.passed}")
    print(f"TOTAL_FAILED: {agg.failed}")
    print(f"TOTAL_SKIPPED: {agg.skipped}")
    print(f"TOTAL_DURATION: {agg.duration}")
    if agg.flaky_tests:
        print(f"FLAKY_TESTS: {', '.join(agg.flaky_tests)}")
    else:
        print("FLAKY_TESTS: none")
    print("")

    # Markdown summary
    md = generate_markdown(agg)
    print(md)

    # Write to GITHUB_STEP_SUMMARY if available
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a") as f:
            f.write(md)

    # Exit with failure if any tests failed
    if agg.failed > 0:
        sys.exit(0)  # Don't fail the workflow; report is informational


if __name__ == "__main__":
    main()
