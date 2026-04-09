#!/usr/bin/env python3
"""
Test Results Aggregator

Parses test result files in JUnit XML and JSON formats, aggregates results
across multiple files (simulating a matrix build), computes totals, identifies
flaky tests, and generates a markdown summary for GitHub Actions job summaries.

TDD approach: Each function was developed by first writing a failing test case,
then implementing the minimum code to pass, then refactoring.
"""

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path


# --- Data models ---

@dataclass
class TestResult:
    """Represents a single test case result."""
    name: str
    classname: str
    status: str  # "passed", "failed", "skipped"
    duration: float
    message: str = ""

    @property
    def full_name(self):
        """Unique identifier for the test: classname::name."""
        return f"{self.classname}::{self.name}"


@dataclass
class AggregatedResults:
    """Holds aggregated results across all parsed files."""
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    duration: float = 0.0
    test_results: list = field(default_factory=list)
    files_parsed: int = 0
    flaky_tests: list = field(default_factory=list)
    failed_tests: list = field(default_factory=list)


# --- Parsers ---
# TDD Red: First wrote tests expecting parse_junit_xml to return TestResult objects.
# TDD Green: Implemented the minimal parser.
# TDD Refactor: Extracted common patterns into TestResult dataclass.

def parse_junit_xml(filepath):
    """
    Parse a JUnit XML file and return a list of TestResult objects.

    Handles the standard JUnit XML schema with <testsuites>/<testsuite>/<testcase>.
    A testcase with a <failure> child is 'failed', with <skipped> is 'skipped',
    otherwise 'passed'.
    """
    results = []
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"ERROR: Failed to parse XML file {filepath}: {e}", file=sys.stderr)
        return results
    except FileNotFoundError:
        print(f"ERROR: File not found: {filepath}", file=sys.stderr)
        return results

    # Handle both <testsuites> root and bare <testsuite> root
    if root.tag == "testsuites":
        suites = root.findall("testsuite")
    elif root.tag == "testsuite":
        suites = [root]
    else:
        print(f"ERROR: Unexpected root element '{root.tag}' in {filepath}", file=sys.stderr)
        return results

    for suite in suites:
        for testcase in suite.findall("testcase"):
            name = testcase.get("name", "unknown")
            classname = testcase.get("classname", suite.get("name", "unknown"))
            duration = float(testcase.get("time", "0"))

            # Determine status from child elements
            failure = testcase.find("failure")
            error = testcase.find("error")
            skipped = testcase.find("skipped")

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

            results.append(TestResult(
                name=name,
                classname=classname,
                status=status,
                duration=duration,
                message=message,
            ))

    return results


# TDD Red: Wrote tests expecting parse_json to handle the JSON test format.
# TDD Green: Implemented JSON parser.
# TDD Refactor: Unified return type with JUnit parser.

def parse_json(filepath):
    """
    Parse a JSON test results file and return a list of TestResult objects.

    Expected format:
    {
      "testSuites": [{
        "name": "suite_name",
        "tests": [{"name": "...", "classname": "...", "status": "...", "duration": ..., "message": "..."}]
      }]
    }
    """
    results = []
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: Failed to parse JSON file {filepath}: {e}", file=sys.stderr)
        return results
    except FileNotFoundError:
        print(f"ERROR: File not found: {filepath}", file=sys.stderr)
        return results

    for suite in data.get("testSuites", []):
        suite_name = suite.get("name", "unknown")
        for test in suite.get("tests", []):
            results.append(TestResult(
                name=test.get("name", "unknown"),
                classname=test.get("classname", suite_name),
                status=test.get("status", "passed"),
                duration=float(test.get("duration", 0)),
                message=test.get("message", ""),
            ))

    return results


def detect_format(filepath):
    """Auto-detect file format from extension."""
    ext = Path(filepath).suffix.lower()
    if ext == ".xml":
        return "junit"
    elif ext == ".json":
        return "json"
    return None


def parse_file(filepath):
    """Parse a test result file, auto-detecting the format."""
    fmt = detect_format(filepath)
    if fmt == "junit":
        return parse_junit_xml(filepath)
    elif fmt == "json":
        return parse_json(filepath)
    else:
        print(f"WARNING: Skipping unsupported file format: {filepath}", file=sys.stderr)
        return []


# --- Aggregation ---
# TDD Red: Wrote test expecting aggregate() to combine results from multiple files.
# TDD Green: Implemented counting logic.
# TDD Refactor: Added flaky detection.

def find_result_files(directory):
    """Recursively find all .xml and .json files in a directory."""
    result_files = []
    for root, _dirs, files in os.walk(directory):
        for f in sorted(files):
            if f.endswith(".xml") or f.endswith(".json"):
                result_files.append(os.path.join(root, f))
    return result_files


def detect_flaky_tests(all_results):
    """
    Identify flaky tests: tests that appeared in multiple runs with different outcomes.

    A test is flaky if it passed in at least one run AND failed in at least one run.
    Returns a list of flaky test full_names.
    """
    # Group results by test full_name
    test_outcomes = {}
    for result in all_results:
        key = result.full_name
        if key not in test_outcomes:
            test_outcomes[key] = set()
        test_outcomes[key].add(result.status)

    # Flaky = both "passed" and "failed" outcomes for the same test
    flaky = []
    for full_name, outcomes in sorted(test_outcomes.items()):
        if "passed" in outcomes and "failed" in outcomes:
            flaky.append(full_name)

    return flaky


def aggregate(directory):
    """
    Aggregate test results from all files in a directory.

    Returns an AggregatedResults object with totals, flaky detection, and per-test data.
    """
    files = find_result_files(directory)
    all_results = []

    for filepath in files:
        results = parse_file(filepath)
        all_results.extend(results)

    # Compute totals
    total = len(all_results)
    passed = sum(1 for r in all_results if r.status == "passed")
    failed = sum(1 for r in all_results if r.status == "failed")
    skipped = sum(1 for r in all_results if r.status == "skipped")
    duration = round(float(sum(r.duration for r in all_results)), 3)

    # Detect flaky tests
    flaky = detect_flaky_tests(all_results)

    # Collect failed test details
    failed_tests = [r for r in all_results if r.status == "failed"]

    return AggregatedResults(
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
        test_results=all_results,
        files_parsed=len(files),
        flaky_tests=flaky,
        failed_tests=failed_tests,
    )


# --- Markdown generation ---
# TDD Red: Wrote test expecting generate_markdown to produce specific output.
# TDD Green: Built the markdown template.
# TDD Refactor: Improved formatting and structure.

def generate_markdown(results):
    """
    Generate a GitHub Actions job summary in markdown format.

    Includes: overview table, failed test details, flaky test warnings.
    """
    lines = []
    lines.append("# Test Results Summary")
    lines.append("")

    # Status icon
    if results.failed > 0:
        lines.append("**Status: FAILED**")
    elif results.total == 0:
        lines.append("**Status: NO TESTS FOUND**")
    else:
        lines.append("**Status: PASSED**")
    lines.append("")

    # Overview table
    lines.append("## Overview")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Total Tests | {results.total} |")
    lines.append(f"| Passed | {results.passed} |")
    lines.append(f"| Failed | {results.failed} |")
    lines.append(f"| Skipped | {results.skipped} |")
    lines.append(f"| Duration | {results.duration}s |")
    lines.append(f"| Files Parsed | {results.files_parsed} |")
    lines.append("")

    # Failed tests section
    if results.failed_tests:
        lines.append("## Failed Tests")
        lines.append("")
        for t in results.failed_tests:
            lines.append(f"- **{t.full_name}**: {t.message}")
        lines.append("")

    # Flaky tests section
    if results.flaky_tests:
        lines.append("## Flaky Tests")
        lines.append("")
        lines.append("The following tests had inconsistent results across runs:")
        lines.append("")
        for name in results.flaky_tests:
            lines.append(f"- {name}")
        lines.append("")

    return "\n".join(lines)


# --- Main entry point ---

def main():
    parser = argparse.ArgumentParser(description="Aggregate test results from multiple formats")
    parser.add_argument("directory", help="Directory containing test result files")
    parser.add_argument("--output", "-o", help="Output file for markdown summary (default: stdout)")
    args = parser.parse_args()

    if not os.path.isdir(args.directory):
        print(f"ERROR: Directory not found: {args.directory}", file=sys.stderr)
        sys.exit(1)

    results = aggregate(args.directory)
    markdown = generate_markdown(results)

    # Print structured output for machine parsing (delimited section)
    print("=== AGGREGATED TOTALS ===")
    print(f"TOTAL={results.total}")
    print(f"PASSED={results.passed}")
    print(f"FAILED={results.failed}")
    print(f"SKIPPED={results.skipped}")
    print(f"DURATION={results.duration}")
    print(f"FILES_PARSED={results.files_parsed}")
    print(f"FLAKY_COUNT={len(results.flaky_tests)}")
    if results.flaky_tests:
        print(f"FLAKY_TESTS={','.join(results.flaky_tests)}")
    print("=== END TOTALS ===")
    print("")

    # Print markdown summary
    print(markdown)

    # Write to file if requested
    if args.output:
        with open(args.output, "w") as f:
            f.write(markdown)
        print(f"\nMarkdown summary written to: {args.output}", file=sys.stderr)

    # Write to GITHUB_STEP_SUMMARY if available
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a") as f:
            f.write(markdown)

    # Exit with failure if any tests failed
    if results.failed > 0:
        sys.exit(1)
    return 0


if __name__ == "__main__":
    main()
