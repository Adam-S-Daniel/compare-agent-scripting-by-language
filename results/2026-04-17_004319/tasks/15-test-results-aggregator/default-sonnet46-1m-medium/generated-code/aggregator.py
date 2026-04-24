#!/usr/bin/env python3
"""
Test Results Aggregator

Parses JUnit XML and JSON test result files from a directory, aggregates
results across multiple files (simulating a matrix build), identifies flaky
tests, and generates a GitHub Actions markdown job summary.

Usage:
    python aggregator.py <results_directory>

Output (stdout): Markdown summary + machine-readable HTML comment markers
  suitable for piping into $GITHUB_STEP_SUMMARY.
"""

import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class TestResult:
    name: str
    classname: str
    status: str          # "passed", "failed", or "skipped"
    duration: float
    message: Optional[str]
    source_file: str


@dataclass
class AggregatedResults:
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    duration: float = 0.0
    all_tests: list = field(default_factory=list)
    failed_tests: list = field(default_factory=list)
    flaky_tests: list = field(default_factory=list)


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_junit_xml(filepath: str) -> list[TestResult]:
    """
    Parse a JUnit XML file (supports both <testsuites> and bare <testsuite>).
    Returns a list of TestResult objects, one per <testcase>.
    Raises ValueError with a meaningful message on parse failure.
    """
    try:
        tree = ET.parse(filepath)
    except ET.ParseError as e:
        raise ValueError(f"Invalid XML in {filepath}: {e}") from e

    root = tree.getroot()
    results: list[TestResult] = []

    # Handle both <testsuites><testsuite>... and bare <testsuite>...
    if root.tag == "testsuites":
        testsuites = root.findall("testsuite")
    elif root.tag == "testsuite":
        testsuites = [root]
    else:
        raise ValueError(
            f"Unexpected root element <{root.tag}> in {filepath}; "
            "expected <testsuites> or <testsuite>"
        )

    for suite in testsuites:
        for tc in suite.findall("testcase"):
            name = tc.get("name", "unknown")
            classname = tc.get("classname", "")
            duration = float(tc.get("time", "0") or "0")

            failure = tc.find("failure")
            error = tc.find("error")
            skipped = tc.find("skipped")

            if skipped is not None:
                status = "skipped"
                message = skipped.get("message") or skipped.text or None
            elif failure is not None:
                status = "failed"
                message = failure.get("message") or (failure.text or "").strip() or None
            elif error is not None:
                status = "failed"
                message = error.get("message") or (error.text or "").strip() or None
            else:
                status = "passed"
                message = None

            results.append(
                TestResult(
                    name=name,
                    classname=classname,
                    status=status,
                    duration=duration,
                    message=message,
                    source_file=str(filepath),
                )
            )

    return results


def parse_json_results(filepath: str) -> list[TestResult]:
    """
    Parse a JSON test results file.

    Expected format:
        {
          "test_suite": "SuiteName",   // optional
          "tests": [
            {
              "name": "test_foo",
              "classname": "SuiteName",  // optional
              "status": "passed|failed|skipped",
              "duration": 0.123,
              "message": "optional error text"
            }
          ]
        }

    Raises ValueError with a meaningful message on parse failure.
    """
    try:
        with open(filepath) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {filepath}: {e}") from e

    if "tests" not in data:
        raise ValueError(
            f"JSON file {filepath} is missing required 'tests' array"
        )

    suite_name = data.get("test_suite", Path(filepath).stem)
    results: list[TestResult] = []

    for i, tc in enumerate(data["tests"]):
        name = tc.get("name", f"test_{i}")
        classname = tc.get("classname", suite_name)
        raw_status = tc.get("status", "passed").lower()

        # Normalize status to our three values
        if raw_status in ("passed", "pass", "success", "ok"):
            status = "passed"
        elif raw_status in ("failed", "fail", "failure", "error"):
            status = "failed"
        elif raw_status in ("skipped", "skip", "ignored", "pending"):
            status = "skipped"
        else:
            status = "failed"  # unknown → treat as failed (safe default)

        results.append(
            TestResult(
                name=name,
                classname=classname,
                status=status,
                duration=float(tc.get("duration", 0) or 0),
                message=tc.get("message"),
                source_file=str(filepath),
            )
        )

    return results


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def identify_flaky_tests(file_results: list[list[TestResult]]) -> list[str]:
    """
    Identify tests that passed in some files and failed in others.

    A test is considered flaky when:
    - It appears in at least two result files.
    - In at least one file its status is "passed".
    - In at least one file its status is "failed".

    Returns a sorted list of test names.
    """
    # Map test name → set of statuses seen across files
    statuses: dict[str, set[str]] = {}
    for file_tests in file_results:
        for t in file_tests:
            statuses.setdefault(t.name, set()).add(t.status)

    return sorted(
        name
        for name, seen in statuses.items()
        if "passed" in seen and "failed" in seen
    )


def aggregate_results(
    file_results: list[list[TestResult]],
    source_files: list[str],
) -> AggregatedResults:
    """Flatten all per-file results, count totals, and detect flaky tests."""
    all_tests = [t for file_tests in file_results for t in file_tests]

    agg = AggregatedResults()
    agg.all_tests = all_tests
    agg.total = len(all_tests)
    agg.passed = sum(1 for t in all_tests if t.status == "passed")
    agg.failed = sum(1 for t in all_tests if t.status == "failed")
    agg.skipped = sum(1 for t in all_tests if t.status == "skipped")
    agg.duration = round(sum(t.duration for t in all_tests), 3)
    agg.failed_tests = [t for t in all_tests if t.status == "failed"]
    agg.flaky_tests = identify_flaky_tests(file_results)

    return agg


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def generate_markdown(
    agg: AggregatedResults,
    source_files: list[str],
) -> str:
    """
    Generate a Markdown summary suitable for GitHub Actions $GITHUB_STEP_SUMMARY.

    Includes:
    - Overview table with totals
    - Flaky tests section
    - Failed tests section
    - Machine-readable HTML comment markers for test harness assertions
    """
    lines: list[str] = []

    lines.append("# Test Results Summary")
    lines.append("")
    lines.append(f"Aggregated from **{len(source_files)}** file(s) (matrix build simulation)")
    lines.append("")

    # Overview table
    lines.append("## Overview")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Total Tests | {agg.total} |")
    lines.append(f"| Passed | {agg.passed} |")
    lines.append(f"| Failed | {agg.failed} |")
    lines.append(f"| Skipped | {agg.skipped} |")
    lines.append(f"| Duration | {agg.duration:.3f}s |")
    lines.append("")

    # Flaky tests
    if agg.flaky_tests:
        lines.append(f"## Flaky Tests ({len(agg.flaky_tests)})")
        lines.append("")
        lines.append("Tests that passed in some runs and failed in others:")
        lines.append("")

        # Build per-test status distribution
        test_statuses: dict[str, list[str]] = {}
        for t in agg.all_tests:
            test_statuses.setdefault(t.name, []).append(t.status)

        lines.append("| Test | Suite | Runs |")
        lines.append("|------|-------|------|")
        for fname in agg.flaky_tests:
            suite = next(
                (t.classname for t in agg.all_tests if t.name == fname), ""
            )
            statuses = test_statuses.get(fname, [])
            passed_count = statuses.count("passed")
            failed_count = statuses.count("failed")
            lines.append(f"| `{fname}` | {suite} | passed:{passed_count}, failed:{failed_count} |")
        lines.append("")
    else:
        lines.append("## Flaky Tests")
        lines.append("")
        lines.append("*No flaky tests detected*")
        lines.append("")

    # Failed tests
    if agg.failed_tests:
        lines.append(f"## Failed Tests ({len(agg.failed_tests)})")
        lines.append("")
        lines.append("| Test | Suite | Message |")
        lines.append("|------|-------|---------|")
        for t in agg.failed_tests:
            msg = (t.message or "").replace("|", "\\|").replace("\n", " ").strip()
            msg = msg[:120] + "…" if len(msg) > 120 else msg
            lines.append(f"| `{t.name}` | {t.classname} | {msg} |")
        lines.append("")
    else:
        lines.append("## Failed Tests")
        lines.append("")
        lines.append("*No failed tests*")
        lines.append("")

    # Source files
    lines.append("## Source Files")
    lines.append("")
    for sf in source_files:
        lines.append(f"- `{Path(sf).name}`")
    lines.append("")

    # Machine-readable markers used by test_harness.py assertions.
    # These are valid HTML comments so they render invisibly in GitHub Markdown.
    flaky_str = ",".join(agg.flaky_tests) if agg.flaky_tests else "none"
    lines.append(
        f"<!-- AGGREGATE_RESULT: passed={agg.passed} failed={agg.failed} "
        f"skipped={agg.skipped} total={agg.total} duration={agg.duration:.3f} -->"
    )
    lines.append(f"<!-- FLAKY_RESULT: {flaky_str} -->")

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(results_dir: str) -> int:
    """
    Entry point: scan results_dir for .xml and .json files, parse and aggregate,
    print markdown summary to stdout.
    """
    path = Path(results_dir)
    if not path.is_dir():
        print(f"Error: '{results_dir}' is not a directory.", file=sys.stderr)
        return 1

    # Discover result files
    xml_files = sorted(path.glob("*.xml"))
    json_files = sorted(path.glob("*.json"))
    source_files = [str(f) for f in xml_files + json_files]

    if not source_files:
        # Graceful empty-directory case
        empty_agg = AggregatedResults()
        md = generate_markdown(empty_agg, [])
        print(md)
        return 0

    # Parse each file, collecting per-file results for flaky detection
    file_results: list[list[TestResult]] = []
    for f in xml_files:
        try:
            file_results.append(parse_junit_xml(str(f)))
        except ValueError as e:
            print(f"Warning: skipping {f.name}: {e}", file=sys.stderr)

    for f in json_files:
        try:
            file_results.append(parse_json_results(str(f)))
        except ValueError as e:
            print(f"Warning: skipping {f.name}: {e}", file=sys.stderr)

    if not file_results:
        print("Error: all result files failed to parse.", file=sys.stderr)
        return 1

    agg = aggregate_results(file_results, source_files)
    md = generate_markdown(agg, source_files)
    print(md)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <results_directory>", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
