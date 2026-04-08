# Test Results Aggregator
#
# Parses JUnit XML and JSON test result files, aggregates across matrix builds,
# detects flaky tests, and generates a GitHub Actions job summary in Markdown.
#
# Design:
#   TestCase        - single test result (name, classname, status, duration, message)
#   RunResult       - all test cases from one matrix run (identified by run_id)
#   AggregateSummary - rolled-up totals + flaky test map + failure details
#   FlakyTest       - a test that passed in some runs and failed in others
#
# Public API:
#   parse_junit_xml(xml_content: str) -> list[TestCase]
#   parse_json_results(json_content: str) -> list[TestCase]
#   load_results_from_file(path: str, run_id: str) -> RunResult
#   aggregate_results(runs: list[RunResult]) -> AggregateSummary
#   generate_markdown_summary(summary: AggregateSummary) -> str

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from xml.etree import ElementTree


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class TestCase:
    """Single test result from one run."""
    name: str
    classname: str
    status: str          # "passed" | "failed" | "skipped" | "error"
    duration: float
    message: Optional[str] = None


@dataclass
class RunResult:
    """All test cases from a single matrix run."""
    run_id: str
    cases: list[TestCase] = field(default_factory=list)


@dataclass
class FlakyTest:
    """A test that produced mixed results across runs."""
    key: str             # "<classname>::<name>" — unique identity
    classname: str
    name: str
    passed_runs: list[str] = field(default_factory=list)
    failed_runs: list[str] = field(default_factory=list)


@dataclass
class AggregateSummary:
    """Rolled-up statistics across all runs."""
    total_passed: int
    total_failed: int
    total_skipped: int
    total_tests: int
    total_duration: float
    run_count: int
    flaky_tests: dict[str, FlakyTest]             # key -> FlakyTest
    failed_test_details: list[tuple]              # (run_id, classname, name, message)


# ---------------------------------------------------------------------------
# JUnit XML parser
# ---------------------------------------------------------------------------

def parse_junit_xml(xml_content: str) -> list[TestCase]:
    """Parse JUnit XML content and return a list of TestCase objects.

    Handles both <testsuites> (multiple suites) and <testsuite> root elements.
    A <testcase> without a <failure>, <error>, or <skipped> child is "passed".
    """
    try:
        root = ElementTree.fromstring(xml_content)
    except ElementTree.ParseError as exc:
        raise ValueError(f"Invalid JUnit XML: {exc}") from exc

    # Collect all <testcase> elements regardless of nesting depth
    if root.tag == "testsuites":
        testcase_elements = root.findall(".//testcase")
    elif root.tag == "testsuite":
        testcase_elements = root.findall(".//testcase")
    else:
        raise ValueError(
            f"Unexpected root element <{root.tag}>; expected <testsuites> or <testsuite>"
        )

    cases = []
    for tc in testcase_elements:
        name = tc.get("name", "")
        classname = tc.get("classname", "")
        duration = float(tc.get("time", 0) or 0)

        # Determine status from child elements
        failure = tc.find("failure")
        error = tc.find("error")
        skipped = tc.find("skipped")

        if failure is not None:
            status = "failed"
            message = failure.get("message") or (failure.text or "").strip()
        elif error is not None:
            status = "error"
            message = error.get("message") or (error.text or "").strip()
        elif skipped is not None:
            status = "skipped"
            message = skipped.get("message") or (skipped.text or "").strip() or None
        else:
            status = "passed"
            message = None

        cases.append(TestCase(name=name, classname=classname, status=status,
                               duration=duration, message=message or None))
    return cases


# ---------------------------------------------------------------------------
# JSON results parser
# ---------------------------------------------------------------------------

def parse_json_results(json_content: str) -> list[TestCase]:
    """Parse JSON test result content and return a list of TestCase objects.

    Expected schema:
    {
      "suite": "<optional suite name>",
      "tests": [
        {
          "name": "<test name>",
          "classname": "<class or module name>",
          "status": "passed" | "failed" | "skipped",
          "duration": <float seconds>,
          "message": "<optional failure/skip message>"
        },
        ...
      ]
    }
    """
    try:
        data = json.loads(json_content)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON test results: {exc}") from exc

    if "tests" not in data:
        raise ValueError("JSON test results must contain a 'tests' array")

    cases = []
    for i, t in enumerate(data["tests"]):
        name = t.get("name", f"test_{i}")
        classname = t.get("classname", "")
        status = t.get("status", "passed").lower()
        duration = float(t.get("duration", 0))
        message = t.get("message") or None

        if status not in ("passed", "failed", "skipped", "error"):
            raise ValueError(
                f"Unknown status '{status}' for test '{name}'; "
                "expected passed, failed, skipped, or error"
            )

        cases.append(TestCase(name=name, classname=classname, status=status,
                               duration=duration, message=message))
    return cases


# ---------------------------------------------------------------------------
# File loader — dispatches to the right parser based on extension
# ---------------------------------------------------------------------------

def load_results_from_file(path: str, run_id: str) -> RunResult:
    """Load test results from a file on disk.

    Dispatches to parse_junit_xml for .xml files and parse_json_results for
    .json files.  Raises ValueError for unsupported extensions.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Test result file not found: {path}")

    suffix = p.suffix.lower()
    content = p.read_text(encoding="utf-8")

    if suffix == ".xml":
        cases = parse_junit_xml(content)
    elif suffix == ".json":
        cases = parse_json_results(content)
    else:
        raise ValueError(
            f"Unsupported file format '{suffix}' for '{path}'; "
            "expected .xml (JUnit) or .json"
        )

    return RunResult(run_id=run_id, cases=cases)


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def aggregate_results(runs: list[RunResult]) -> AggregateSummary:
    """Aggregate test results from multiple runs.

    Computes totals (passed, failed, skipped, duration) and identifies flaky
    tests — those that passed in at least one run and failed in at least one
    other run.

    A test is keyed by "<classname>::<name>" so the same test appearing in
    multiple runs can be correlated.
    """
    total_passed = 0
    total_failed = 0
    total_skipped = 0
    total_duration = 0.0

    # per-test tracking: key -> {"passed": [run_ids], "failed": [run_ids]}
    per_test: dict[str, dict[str, list[str]]] = {}
    failed_details: list[tuple] = []

    for run in runs:
        for tc in run.cases:
            key = f"{tc.classname}::{tc.name}"

            if tc.status == "passed":
                total_passed += 1
            elif tc.status in ("failed", "error"):
                total_failed += 1
                failed_details.append((run.run_id, tc.classname, tc.name, tc.message or ""))
            elif tc.status == "skipped":
                total_skipped += 1

            total_duration += tc.duration

            if key not in per_test:
                per_test[key] = {"passed": [], "failed": [], "meta": (tc.classname, tc.name)}

            if tc.status == "passed":
                per_test[key]["passed"].append(run.run_id)
            elif tc.status in ("failed", "error"):
                per_test[key]["failed"].append(run.run_id)

    # A test is flaky if it appeared in both passed and failed buckets
    flaky: dict[str, FlakyTest] = {}
    for key, data in per_test.items():
        if data["passed"] and data["failed"]:
            classname, name = data["meta"]
            flaky[key] = FlakyTest(
                key=key,
                classname=classname,
                name=name,
                passed_runs=data["passed"],
                failed_runs=data["failed"],
            )

    return AggregateSummary(
        total_passed=total_passed,
        total_failed=total_failed,
        total_skipped=total_skipped,
        total_tests=total_passed + total_failed + total_skipped,
        total_duration=total_duration,
        run_count=len(runs),
        flaky_tests=flaky,
        failed_test_details=failed_details,
    )


# ---------------------------------------------------------------------------
# Markdown summary generator
# ---------------------------------------------------------------------------

def generate_markdown_summary(summary: AggregateSummary) -> str:
    """Generate a Markdown job summary suitable for GitHub Actions.

    Sections:
      1. Overall stats table (passed / failed / skipped / total / duration / runs)
      2. Flaky tests table (if any)
      3. Failure details table (if any)
    """
    lines: list[str] = []

    # ---- Heading ----
    lines.append("# Test Results Summary\n")

    # ---- Overall statistics ----
    pass_rate = (
        f"{summary.total_passed / summary.total_tests * 100:.1f}%"
        if summary.total_tests > 0
        else "N/A"
    )
    status_icon = ":white_check_mark:" if summary.total_failed == 0 else ":x:"

    lines.append(f"{status_icon} **{summary.total_passed} passed** | "
                 f":x: **{summary.total_failed} failed** | "
                 f":zzz: **{summary.total_skipped} skipped** | "
                 f"**{summary.total_tests} total**\n")

    lines.append("## Overview\n")
    lines.append("| Metric | Value |")
    lines.append("| --- | --- |")
    lines.append(f"| Total Tests | {summary.total_tests} |")
    lines.append(f"| Passed | {summary.total_passed} |")
    lines.append(f"| Failed | {summary.total_failed} |")
    lines.append(f"| Skipped | {summary.total_skipped} |")
    lines.append(f"| Pass Rate | {pass_rate} |")
    lines.append(f"| Total Duration | {summary.total_duration:.3f}s |")
    lines.append(f"| Matrix Runs | {summary.run_count} |")
    lines.append("")

    # ---- Flaky tests ----
    if summary.flaky_tests:
        lines.append(f"## :warning: Flaky Tests ({len(summary.flaky_tests)})\n")
        lines.append("These tests passed in some runs and failed in others:\n")
        lines.append("| Test | Class | Passed In | Failed In |")
        lines.append("| --- | --- | --- | --- |")
        for ft in sorted(summary.flaky_tests.values(), key=lambda x: x.key):
            passed = ", ".join(ft.passed_runs)
            failed = ", ".join(ft.failed_runs)
            lines.append(f"| `{ft.name}` | `{ft.classname}` | {passed} | {failed} |")
        lines.append("")
    else:
        lines.append("## Flaky Tests\n")
        lines.append("No flaky tests detected.\n")

    # ---- Failure details ----
    if summary.failed_test_details:
        lines.append(f"## :x: Failures ({len(summary.failed_test_details)})\n")
        lines.append("| Run | Class | Test | Message |")
        lines.append("| --- | --- | --- | --- |")
        for run_id, classname, name, message in summary.failed_test_details:
            # Escape pipe characters in messages to avoid breaking Markdown tables
            safe_msg = (message or "").replace("|", "\\|")
            lines.append(f"| {run_id} | `{classname}` | `{name}` | {safe_msg} |")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    import glob as _glob

    if len(sys.argv) < 2:
        print("Usage: python aggregator.py <result-file-or-glob> [...]", file=sys.stderr)
        sys.exit(1)

    runs: list[RunResult] = []
    for pattern in sys.argv[1:]:
        for filepath in sorted(_glob.glob(pattern)):
            run_id = Path(filepath).stem
            try:
                run = load_results_from_file(filepath, run_id=run_id)
                runs.append(run)
                print(f"Loaded {len(run.cases)} tests from {filepath} (run: {run_id})")
            except (ValueError, FileNotFoundError) as exc:
                print(f"Error loading {filepath}: {exc}", file=sys.stderr)

    if not runs:
        print("No result files loaded.", file=sys.stderr)
        sys.exit(1)

    summary = aggregate_results(runs)
    md = generate_markdown_summary(summary)
    print(md)
