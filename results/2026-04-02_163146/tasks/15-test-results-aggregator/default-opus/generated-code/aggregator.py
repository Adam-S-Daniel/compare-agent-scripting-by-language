"""
Test Results Aggregator

Parses test result files in JUnit XML and JSON formats, aggregates results
across multiple matrix build runs, computes totals, detects flaky tests,
and generates a Markdown summary for GitHub Actions job summaries.

Architecture:
  - TestCaseResult: dataclass representing one test case outcome from one run
  - parse_junit_xml(path) -> list[TestCaseResult]: parse JUnit XML format
  - parse_json(path) -> list[TestCaseResult]: parse JSON format
  - parse_file(path) -> list[TestCaseResult]: auto-detect format by extension
  - aggregate(runs) -> AggregatedResults: merge results across runs
  - find_flaky_tests(runs) -> list[FlakyTest]: tests that pass in some runs, fail in others
  - generate_markdown(aggregated) -> str: GitHub Actions job summary
"""

from __future__ import annotations

import json
import os
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class TestCaseResult:
    """A single test case result from a single run."""
    name: str
    classname: str
    status: str          # "passed", "failed", "skipped"
    duration: float      # seconds
    message: str = ""    # failure/skip message
    run_name: str = ""   # which matrix run this came from


@dataclass
class FlakyTest:
    """A test that produced different outcomes across runs."""
    name: str
    classname: str
    passed_runs: list[str] = field(default_factory=list)
    failed_runs: list[str] = field(default_factory=list)


@dataclass
class AggregatedResults:
    """Totals and details across all runs."""
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    total_duration: float = 0.0
    runs: int = 0
    flaky_tests: list[FlakyTest] = field(default_factory=list)
    failures: list[TestCaseResult] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

class ParseError(Exception):
    """Raised when a test result file cannot be parsed."""
    pass


def parse_junit_xml(path: str) -> list[TestCaseResult]:
    """Parse a JUnit XML file into TestCaseResult objects.

    Handles the standard JUnit XML schema:
      <testsuites> -> <testsuite> -> <testcase>
    Each <testcase> may contain <failure>, <error>, or <skipped> children.
    """
    if not os.path.isfile(path):
        raise ParseError(f"File not found: {path}")

    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        raise ParseError(f"Malformed XML in {path}: {exc}") from exc

    root = tree.getroot()
    # Derive run name from the testsuites 'name' attribute or filename
    run_name = root.get("name", os.path.basename(path))

    results: list[TestCaseResult] = []

    # Support both <testsuites><testsuite>... and bare <testsuite>
    if root.tag == "testsuites":
        suites = root.findall("testsuite")
    elif root.tag == "testsuite":
        suites = [root]
    else:
        raise ParseError(f"Unexpected root element <{root.tag}> in {path}")

    for suite in suites:
        for tc in suite.findall("testcase"):
            name = tc.get("name", "unknown")
            classname = tc.get("classname", suite.get("name", ""))
            duration = float(tc.get("time", "0"))

            # Determine status from child elements
            failure = tc.find("failure")
            error = tc.find("error")
            skipped = tc.find("skipped")

            if failure is not None:
                status = "failed"
                message = failure.get("message", failure.text or "")
            elif error is not None:
                status = "failed"
                message = error.get("message", error.text or "")
            elif skipped is not None:
                status = "skipped"
                message = skipped.get("message", "")
            else:
                status = "passed"
                message = ""

            results.append(TestCaseResult(
                name=name,
                classname=classname,
                status=status,
                duration=duration,
                message=message,
                run_name=run_name,
            ))

    return results


def parse_json(path: str) -> list[TestCaseResult]:
    """Parse a JSON test results file into TestCaseResult objects.

    Expected schema:
    {
      "name": "Run N",
      "suites": [
        {
          "name": "suite_name",
          "tests": [
            { "name": "...", "classname": "...", "duration": N, "status": "...", "message": "..." }
          ]
        }
      ]
    }
    """
    if not os.path.isfile(path):
        raise ParseError(f"File not found: {path}")

    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise ParseError(f"Malformed JSON in {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ParseError(f"Expected JSON object at top level in {path}")

    run_name = data.get("name", os.path.basename(path))
    results: list[TestCaseResult] = []

    for suite in data.get("suites", []):
        for test in suite.get("tests", []):
            results.append(TestCaseResult(
                name=test.get("name", "unknown"),
                classname=test.get("classname", suite.get("name", "")),
                status=test.get("status", "passed"),
                duration=float(test.get("duration", 0)),
                message=test.get("message", ""),
                run_name=run_name,
            ))

    return results


def parse_file(path: str) -> list[TestCaseResult]:
    """Auto-detect format by file extension and parse accordingly."""
    ext = os.path.splitext(path)[1].lower()
    if ext == ".xml":
        return parse_junit_xml(path)
    elif ext == ".json":
        return parse_json(path)
    else:
        raise ParseError(f"Unsupported file format '{ext}' for {path}")


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def find_flaky_tests(runs: list[list[TestCaseResult]]) -> list[FlakyTest]:
    """Identify tests that passed in some runs but failed in others.

    A test is flaky if it has at least one 'passed' and at least one 'failed'
    outcome across the provided runs. Skipped-only tests are not flaky.
    """
    # Key: (classname, name) -> {run_name: status}
    outcomes: dict[tuple[str, str], dict[str, str]] = {}

    for run in runs:
        for tc in run:
            key = (tc.classname, tc.name)
            if key not in outcomes:
                outcomes[key] = {}
            outcomes[key][tc.run_name] = tc.status

    flaky: list[FlakyTest] = []
    for (classname, name), run_statuses in sorted(outcomes.items()):
        passed_runs = [r for r, s in run_statuses.items() if s == "passed"]
        failed_runs = [r for r, s in run_statuses.items() if s == "failed"]
        if passed_runs and failed_runs:
            flaky.append(FlakyTest(
                name=name,
                classname=classname,
                passed_runs=passed_runs,
                failed_runs=failed_runs,
            ))

    return flaky


def aggregate(runs: list[list[TestCaseResult]]) -> AggregatedResults:
    """Aggregate test results across multiple runs into totals.

    Each run contributes its own counts; flaky detection spans all runs.
    """
    result = AggregatedResults(runs=len(runs))

    for run in runs:
        for tc in run:
            result.total += 1
            result.total_duration += tc.duration
            if tc.status == "passed":
                result.passed += 1
            elif tc.status == "failed":
                result.failed += 1
                result.failures.append(tc)
            elif tc.status == "skipped":
                result.skipped += 1

    result.flaky_tests = find_flaky_tests(runs)
    return result


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def generate_markdown(agg: AggregatedResults) -> str:
    """Generate a GitHub Actions job summary in Markdown.

    Includes: overview table, failure details, flaky test warnings.
    """
    lines: list[str] = []

    # Header
    lines.append("# Test Results Summary")
    lines.append("")

    # Status badge
    if agg.failed > 0:
        lines.append("> **Status:** :red_circle: Some tests failed")
    elif agg.flaky_tests:
        lines.append("> **Status:** :warning: All tests passed but flaky tests detected")
    else:
        lines.append("> **Status:** :green_circle: All tests passed")
    lines.append("")

    # Overview table
    lines.append("## Overview")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| **Total tests** | {agg.total} |")
    lines.append(f"| **Passed** | {agg.passed} |")
    lines.append(f"| **Failed** | {agg.failed} |")
    lines.append(f"| **Skipped** | {agg.skipped} |")
    lines.append(f"| **Duration** | {agg.total_duration:.2f}s |")
    lines.append(f"| **Runs** | {agg.runs} |")
    lines.append("")

    # Failures section
    if agg.failures:
        lines.append("## Failures")
        lines.append("")
        for tc in agg.failures:
            lines.append(f"### `{tc.classname}::{tc.name}` (run: {tc.run_name})")
            lines.append("")
            if tc.message:
                lines.append(f"```\n{tc.message}\n```")
                lines.append("")

    # Flaky tests section
    if agg.flaky_tests:
        lines.append("## Flaky Tests")
        lines.append("")
        lines.append("These tests produced different results across runs:")
        lines.append("")
        lines.append("| Test | Passed in | Failed in |")
        lines.append("|------|-----------|-----------|")
        for ft in agg.flaky_tests:
            passed = ", ".join(ft.passed_runs)
            failed = ", ".join(ft.failed_runs)
            lines.append(f"| `{ft.classname}::{ft.name}` | {passed} | {failed} |")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Parse all test result files passed as arguments and print a summary."""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python aggregator.py <file1.xml> <file2.json> ...", file=sys.stderr)
        sys.exit(1)

    runs: list[list[TestCaseResult]] = []
    errors: list[str] = []

    for path in sys.argv[1:]:
        try:
            results = parse_file(path)
            runs.append(results)
        except ParseError as exc:
            errors.append(str(exc))

    if errors:
        for err in errors:
            print(f"WARNING: {err}", file=sys.stderr)

    if not runs:
        print("ERROR: No valid test result files found.", file=sys.stderr)
        sys.exit(1)

    agg = aggregate(runs)
    print(generate_markdown(agg))


if __name__ == "__main__":
    main()
