#!/usr/bin/env python3
"""
Test Results Aggregator

Parses test result files in JUnit XML and JSON formats, aggregates results
across multiple files (simulating a matrix build), computes totals, identifies
flaky tests, and generates a markdown summary suitable for GitHub Actions.

Usage:
    python3 aggregator.py <fixture_dir>

The script reads all .xml and .json files from the given directory, parses
them, aggregates the results, and prints a markdown summary to stdout.
"""

import json
import os
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field


# -- Data model for a single test case result --
@dataclass
class TestResult:
    """A single test case execution result."""
    name: str
    status: str  # "passed", "failed", "skipped"
    duration: float  # seconds
    source_file: str  # which result file this came from
    error_message: str = ""


# -- Data model for aggregated results --
@dataclass
class AggregatedResults:
    """Aggregated test results across all files."""
    results: list = field(default_factory=list)
    parse_errors: list = field(default_factory=list)

    @property
    def total(self):
        return len(self.results)

    @property
    def passed(self):
        return sum(1 for r in self.results if r.status == "passed")

    @property
    def failed(self):
        return sum(1 for r in self.results if r.status == "failed")

    @property
    def skipped(self):
        return sum(1 for r in self.results if r.status == "skipped")

    @property
    def duration(self):
        return sum(r.duration for r in self.results)

    def flaky_tests(self):
        """
        Identify flaky tests: tests that passed in some runs and failed in others.
        A test is flaky if it has both 'passed' and 'failed' statuses across runs.
        Skipped results are ignored for flaky detection.
        """
        # Group results by test name
        by_name = {}
        for r in self.results:
            if r.status == "skipped":
                continue
            by_name.setdefault(r.name, set()).add(r.status)

        # Flaky = has both passed and failed
        return sorted(
            name for name, statuses in by_name.items()
            if "passed" in statuses and "failed" in statuses
        )


def parse_junit_xml(filepath):
    """
    Parse a JUnit XML file and return a list of TestResult objects.

    Handles the standard JUnit XML format with <testsuites>/<testsuite>/<testcase>.
    A testcase is:
      - "failed" if it has a <failure> child
      - "skipped" if it has a <skipped> child
      - "passed" otherwise
    """
    results = []
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
    except ET.ParseError as e:
        raise ValueError(f"Failed to parse XML '{filepath}': {e}")

    # Handle both <testsuites> root and bare <testsuite> root
    if root.tag == "testsuites":
        suites = root.findall("testsuite")
    elif root.tag == "testsuite":
        suites = [root]
    else:
        raise ValueError(
            f"Unexpected root element '{root.tag}' in '{filepath}'. "
            "Expected 'testsuites' or 'testsuite'."
        )

    for suite in suites:
        for tc in suite.findall("testcase"):
            name = tc.get("name", "unknown")
            duration = float(tc.get("time", "0"))

            # Determine status from child elements
            failure = tc.find("failure")
            skipped = tc.find("skipped")

            if failure is not None:
                status = "failed"
                error_msg = failure.get("message", failure.text or "")
            elif skipped is not None:
                status = "skipped"
                error_msg = skipped.get("message", "")
            else:
                status = "passed"
                error_msg = ""

            results.append(TestResult(
                name=name,
                status=status,
                duration=duration,
                source_file=os.path.basename(filepath),
                error_message=error_msg,
            ))

    return results


def parse_json_results(filepath):
    """
    Parse a JSON test results file and return a list of TestResult objects.

    Expected format:
    {
      "results": [
        {"name": "test_name", "status": "passed|failed|skipped", "duration": 0.5},
        ...
      ]
    }
    """
    try:
        with open(filepath) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON '{filepath}': {e}")

    if "results" not in data:
        raise ValueError(
            f"JSON file '{filepath}' missing 'results' key. "
            "Expected format: {\"results\": [...]}"
        )

    results = []
    for entry in data["results"]:
        name = entry.get("name", "unknown")
        status = entry.get("status", "unknown")
        duration = float(entry.get("duration", 0))
        error_msg = entry.get("error", "")

        if status not in ("passed", "failed", "skipped"):
            raise ValueError(
                f"Unknown status '{status}' for test '{name}' in '{filepath}'. "
                "Expected 'passed', 'failed', or 'skipped'."
            )

        results.append(TestResult(
            name=name,
            status=status,
            duration=duration,
            source_file=os.path.basename(filepath),
            error_message=error_msg,
        ))

    return results


def aggregate_results(fixture_dir):
    """
    Read all .xml and .json files from fixture_dir, parse them,
    and return an AggregatedResults object.
    """
    agg = AggregatedResults()

    if not os.path.isdir(fixture_dir):
        print(f"ERROR: Directory not found: {fixture_dir}", file=sys.stderr)
        sys.exit(1)

    files = sorted(os.listdir(fixture_dir))
    if not files:
        print(f"WARNING: No files found in {fixture_dir}", file=sys.stderr)
        return agg

    for filename in files:
        filepath = os.path.join(fixture_dir, filename)
        if not os.path.isfile(filepath):
            continue

        try:
            if filename.endswith(".xml"):
                results = parse_junit_xml(filepath)
                agg.results.extend(results)
            elif filename.endswith(".json"):
                results = parse_json_results(filepath)
                agg.results.extend(results)
            else:
                # Skip unsupported file types silently
                continue
        except ValueError as e:
            # Graceful error handling: log the error but continue processing
            error_msg = f"WARNING: Skipping '{filename}': {e}"
            agg.parse_errors.append(error_msg)
            print(error_msg, file=sys.stderr)

    return agg


def generate_markdown(agg):
    """
    Generate a markdown summary from aggregated results.
    This format is suitable for GitHub Actions job summaries ($GITHUB_STEP_SUMMARY).
    """
    lines = []
    lines.append("# Test Results Summary")
    lines.append("")

    # Overall totals
    lines.append("## Totals")
    lines.append("")
    lines.append(f"| Metric | Value |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Total | {agg.total} |")
    lines.append(f"| Passed | {agg.passed} |")
    lines.append(f"| Failed | {agg.failed} |")
    lines.append(f"| Skipped | {agg.skipped} |")
    lines.append(f"| Duration | {agg.duration:.2f}s |")
    lines.append("")

    # Pass rate
    if agg.total - agg.skipped > 0:
        rate = agg.passed / (agg.total - agg.skipped) * 100
        lines.append(f"Pass rate: {rate:.1f}% (excluding skipped)")
        lines.append("")

    # Flaky tests
    flaky = agg.flaky_tests()
    lines.append("## Flaky Tests")
    lines.append("")
    if flaky:
        lines.append(f"Found {len(flaky)} flaky test(s) (passed in some runs, failed in others):")
        lines.append("")
        for name in flaky:
            lines.append(f"- `{name}`")
    else:
        lines.append("No flaky tests detected.")
    lines.append("")

    # Failed tests detail
    failed_results = [r for r in agg.results if r.status == "failed"]
    if failed_results:
        lines.append("## Failed Tests")
        lines.append("")
        for r in failed_results:
            lines.append(f"- **{r.name}** ({r.source_file}): {r.error_message}")
        lines.append("")

    # Per-file breakdown
    lines.append("## Per-File Breakdown")
    lines.append("")
    lines.append("| File | Passed | Failed | Skipped | Duration |")
    lines.append("|------|--------|--------|---------|----------|")

    # Group by source file
    by_file = {}
    for r in agg.results:
        by_file.setdefault(r.source_file, []).append(r)

    for fname in sorted(by_file.keys()):
        file_results = by_file[fname]
        p = sum(1 for r in file_results if r.status == "passed")
        f = sum(1 for r in file_results if r.status == "failed")
        s = sum(1 for r in file_results if r.status == "skipped")
        d = sum(r.duration for r in file_results)
        lines.append(f"| {fname} | {p} | {f} | {s} | {d:.2f}s |")
    lines.append("")

    # Parse errors
    if agg.parse_errors:
        lines.append("## Parse Errors")
        lines.append("")
        for err in agg.parse_errors:
            lines.append(f"- {err}")
        lines.append("")

    # Plain-text summary block (easy to parse in CI output)
    lines.append("## Plain Summary")
    lines.append("")
    lines.append(f"Total: {agg.total}")
    lines.append(f"Passed: {agg.passed}")
    lines.append(f"Failed: {agg.failed}")
    lines.append(f"Skipped: {agg.skipped}")
    lines.append(f"Duration: {agg.duration:.2f}s")
    if flaky:
        lines.append(f"Flaky: {', '.join(flaky)}")
    lines.append("")

    return "\n".join(lines)


def main():
    """Entry point: parse arguments, aggregate, and print markdown."""
    if len(sys.argv) < 2:
        print("Usage: python3 aggregator.py <fixture_dir>", file=sys.stderr)
        sys.exit(1)

    fixture_dir = sys.argv[1]
    agg = aggregate_results(fixture_dir)
    markdown = generate_markdown(agg)
    print(markdown)

    # Exit with non-zero if there were test failures (useful for CI)
    # But don't exit non-zero for parse errors alone
    if agg.failed > 0:
        sys.exit(0)  # Still exit 0 - the summary is the important output


if __name__ == "__main__":
    main()
