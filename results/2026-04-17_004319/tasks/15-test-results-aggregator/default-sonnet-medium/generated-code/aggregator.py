#!/usr/bin/env python3
"""Test results aggregator.

Parses JUnit XML and JSON test result files, aggregates across multiple
files (simulating a matrix build), identifies flaky tests (same test
passing in some runs and failing in others), and generates a markdown
summary suitable for a GitHub Actions job summary.
"""

import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class TestResult:
    name: str
    suite: str
    status: str       # passed | failed | skipped | error
    duration: float
    message: Optional[str] = None
    source_file: str = ""


@dataclass
class AggregatedResults:
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    errors: int = 0
    duration: float = 0.0
    # flaky_tests: test_name -> {"passed": int, "failed": int}
    flaky_tests: dict = field(default_factory=dict)
    all_results: list = field(default_factory=list)


def parse_junit_xml(filepath: str) -> list[TestResult]:
    """Parse a JUnit XML file and return TestResult objects.

    Accepts both <testsuites> (standard) and bare <testsuite> root elements.
    """
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
    except ET.ParseError as e:
        raise ValueError(f"Invalid XML in {filepath}: {e}")

    if root.tag == "testsuites":
        suites = root.findall("testsuite")
    elif root.tag == "testsuite":
        suites = [root]
    else:
        raise ValueError(
            f"Unexpected root element '{root.tag}' in {filepath}; "
            "expected <testsuites> or <testsuite>"
        )

    results = []
    for suite in suites:
        suite_name = suite.get("name", "unknown")
        for tc in suite.findall("testcase"):
            name = tc.get("name", "unknown")
            duration = float(tc.get("time", 0) or 0)

            failure = tc.find("failure")
            error = tc.find("error")
            skipped = tc.find("skipped")

            if failure is not None:
                status = "failed"
                message = failure.get("message") or failure.text
            elif error is not None:
                status = "error"
                message = error.get("message") or error.text
            elif skipped is not None:
                status = "skipped"
                message = skipped.get("message") or skipped.text
            else:
                status = "passed"
                message = None

            results.append(TestResult(
                name=name,
                suite=suite_name,
                status=status,
                duration=duration,
                message=message,
                source_file=filepath,
            ))

    return results


def parse_json_results(filepath: str) -> list[TestResult]:
    """Parse a JSON test results file.

    Expected format:
      {"suite": "name", "tests": [{"name": ..., "status": ..., "duration": ...}]}
    """
    try:
        with open(filepath) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {filepath}: {e}")

    suite_name = data.get("suite", Path(filepath).stem)
    results = []

    for test in data.get("tests", []):
        name = test.get("name", "unknown")
        raw_status = test.get("status", "unknown")
        duration = float(test.get("duration", 0) or 0)
        message = test.get("message")

        # Normalise alternate status spellings
        status_map = {
            "pass": "passed", "passing": "passed", "ok": "passed",
            "fail": "failed", "failing": "failed",
            "skip": "skipped", "pending": "skipped",
        }
        status = status_map.get(raw_status, raw_status)

        results.append(TestResult(
            name=name,
            suite=suite_name,
            status=status,
            duration=duration,
            message=message,
            source_file=filepath,
        ))

    return results


def parse_file(filepath: str) -> list[TestResult]:
    """Dispatch to the correct parser based on file extension."""
    path = Path(filepath)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {filepath}")

    ext = path.suffix.lower()
    if ext == ".xml":
        return parse_junit_xml(filepath)
    elif ext == ".json":
        return parse_json_results(filepath)
    else:
        raise ValueError(
            f"Unsupported file format: {ext}. Supported formats: .xml (JUnit), .json"
        )


def aggregate_results(all_run_results: list[list[TestResult]]) -> AggregatedResults:
    """Aggregate test results across runs and detect flaky tests.

    A flaky test is one that both passed and failed across different runs.
    """
    agg = AggregatedResults()
    test_statuses: dict[str, list[str]] = defaultdict(list)

    for run in all_run_results:
        for result in run:
            agg.total += 1
            agg.duration += result.duration
            agg.all_results.append(result)

            if result.status == "passed":
                agg.passed += 1
            elif result.status == "failed":
                agg.failed += 1
            elif result.status == "skipped":
                agg.skipped += 1
            elif result.status == "error":
                agg.errors += 1

            # Only passed/failed results count for flakiness
            if result.status in ("passed", "failed"):
                test_statuses[result.name].append(result.status)

    for name, statuses in test_statuses.items():
        p = statuses.count("passed")
        f = statuses.count("failed")
        if p > 0 and f > 0:
            agg.flaky_tests[name] = {"passed": p, "failed": f}

    return agg


def generate_markdown_summary(
    agg: AggregatedResults,
    file_sources: list[str],
) -> str:
    """Render aggregated results as a GitHub Actions job summary (Markdown)."""
    lines: list[str] = []

    lines.append("## Test Results Summary")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Total Tests | {agg.total} |")
    lines.append(f"| Passed | {agg.passed} |")
    lines.append(f"| Failed | {agg.failed} |")
    lines.append(f"| Skipped | {agg.skipped} |")
    if agg.errors > 0:
        lines.append(f"| Errors | {agg.errors} |")
    lines.append(f"| Duration | {agg.duration:.2f}s |")
    lines.append("")

    if agg.failed == 0 and agg.errors == 0:
        lines.append(":white_check_mark: All tests passed")
    else:
        lines.append(f":x: {agg.failed + agg.errors} test(s) failed")
    lines.append("")

    if agg.flaky_tests:
        lines.append("### Flaky Tests")
        lines.append("")
        lines.append("| Test Name | Passed Runs | Failed Runs |")
        lines.append("|-----------|-------------|-------------|")
        for name, counts in sorted(agg.flaky_tests.items()):
            lines.append(f"| {name} | {counts['passed']} | {counts['failed']} |")
        lines.append("")

    if file_sources:
        lines.append("### Files Processed")
        lines.append("")
        for src in file_sources:
            lines.append(f"- `{src}`")
        lines.append("")

    return "\n".join(lines)


def main(files: list[str]) -> None:
    """CLI entry point: aggregate test files and print a markdown summary."""
    if not files:
        print("Usage: aggregator.py <file1> [file2] ...", file=sys.stderr)
        sys.exit(1)

    all_results: list[list[TestResult]] = []
    had_error = False

    for filepath in files:
        try:
            results = parse_file(filepath)
            all_results.append(results)
        except (FileNotFoundError, ValueError) as e:
            print(f"Error: {e}", file=sys.stderr)
            had_error = True

    if had_error and not all_results:
        sys.exit(1)

    agg = aggregate_results(all_results)
    summary = generate_markdown_summary(agg, files)
    print(summary)


if __name__ == "__main__":
    main(sys.argv[1:])
