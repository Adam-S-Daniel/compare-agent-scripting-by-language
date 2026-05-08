#!/usr/bin/env python3
"""
Test Results Aggregator

Parses JUnit XML and JSON test result files from a matrix build,
aggregates totals, identifies flaky tests, and generates a
GitHub Actions job summary in Markdown format.
"""

from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class TestCase:
    name: str
    classname: str
    status: str        # "passed", "failed", "skipped", "error"
    duration: float
    message: str = ""
    run_name: str = ""


@dataclass
class RunResult:
    run_name: str
    tests: list[TestCase]
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    errors: int = 0
    duration: float = 0.0


@dataclass
class AggregatedResults:
    runs: list[RunResult]
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    errors: int = 0
    duration: float = 0.0
    flaky_tests: list[str] = field(default_factory=list)
    consistently_failing: list[str] = field(default_factory=list)
    consistently_passing: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_junit_xml(filepath: str | Path, run_name: str = "") -> RunResult:
    """Parse a JUnit XML file and return a RunResult.

    Handles both <testsuites> and bare <testsuite> root elements.
    Raises FileNotFoundError if the file does not exist.
    """
    p = Path(filepath)
    if not p.exists():
        raise FileNotFoundError(f"Test result file not found: {filepath}")

    try:
        tree = ET.parse(p)
    except ET.ParseError as exc:
        raise ValueError(f"Invalid XML in {filepath}: {exc}") from exc

    root = tree.getroot()
    name = run_name or p.stem

    tests: list[TestCase] = []

    # Collect all <testcase> elements regardless of nesting depth
    for tc_elem in root.iter("testcase"):
        tc_name = tc_elem.get("name", "")
        classname = tc_elem.get("classname", "")
        duration = float(tc_elem.get("time", "0") or "0")

        failure = tc_elem.find("failure")
        error = tc_elem.find("error")
        skipped = tc_elem.find("skipped")

        if failure is not None:
            status = "failed"
            # Prefer text content (full traceback) over message attribute (short label)
            message = (failure.text or "").strip() or failure.get("message", "")
        elif error is not None:
            status = "error"
            message = (error.text or "").strip() or error.get("message", "")
        elif skipped is not None:
            status = "skipped"
            message = skipped.get("message", "") or ""
        else:
            status = "passed"
            message = ""

        tests.append(TestCase(
            name=tc_name,
            classname=classname,
            status=status,
            duration=duration,
            message=message,
            run_name=name,
        ))

    # Compute totals from the parsed test cases (more reliable than XML attrs)
    total = len(tests)
    passed = sum(1 for t in tests if t.status == "passed")
    failed = sum(1 for t in tests if t.status == "failed")
    skipped = sum(1 for t in tests if t.status == "skipped")
    errors = sum(1 for t in tests if t.status == "error")

    # Sum duration from the outermost element (testsuite or testsuites)
    duration = float(root.get("time", "0") or "0")
    if duration == 0.0:
        duration = sum(t.duration for t in tests)

    return RunResult(
        run_name=name,
        tests=tests,
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        errors=errors,
        duration=duration,
    )


def parse_json_results(filepath: str | Path, run_name: str = "") -> RunResult:
    """Parse a JSON test results file and return a RunResult.

    Expected JSON schema:
      {
        "run_name": "optional-name",
        "tests": [
          {"name": "...", "classname": "...", "status": "passed|failed|skipped",
           "duration": 0.5, "message": "optional failure message"}
        ]
      }

    Raises FileNotFoundError if the file does not exist.
    Raises ValueError if the JSON is malformed or missing required fields.
    """
    p = Path(filepath)
    if not p.exists():
        raise FileNotFoundError(f"Test result file not found: {filepath}")

    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {filepath}: {exc}") from exc

    if not isinstance(data, dict):
        raise ValueError(f"Expected a JSON object at top level in {filepath}")

    name = run_name or data.get("run_name", "") or p.stem
    raw_tests = data.get("tests", [])

    tests: list[TestCase] = []
    for item in raw_tests:
        tests.append(TestCase(
            name=item.get("name", ""),
            classname=item.get("classname", ""),
            status=item.get("status", "passed"),
            duration=float(item.get("duration", 0)),
            message=item.get("message", ""),
            run_name=name,
        ))

    total = len(tests)
    passed = sum(1 for t in tests if t.status == "passed")
    failed = sum(1 for t in tests if t.status == "failed")
    skipped = sum(1 for t in tests if t.status == "skipped")
    errors = sum(1 for t in tests if t.status == "error")
    duration = sum(t.duration for t in tests)

    return RunResult(
        run_name=name,
        tests=tests,
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        errors=errors,
        duration=duration,
    )


# ---------------------------------------------------------------------------
# Aggregation and flaky detection
# ---------------------------------------------------------------------------

def aggregate_results(runs: list[RunResult]) -> AggregatedResults:
    """Aggregate multiple RunResults.

    Flaky detection: a test is flaky when it appears in at least two runs
    and its status is "passed" in at least one and "failed" in at least one.
    Consistently failing: appears in at least one run and only ever fails.
    """
    if not runs:
        return AggregatedResults(runs=[], total=0)

    all_tests: list[TestCase] = []
    for run in runs:
        all_tests.extend(run.tests)

    total = sum(r.total for r in runs)
    passed = sum(r.passed for r in runs)
    failed = sum(r.failed for r in runs)
    skipped = sum(r.skipped for r in runs)
    errors = sum(r.errors for r in runs)
    duration = sum(r.duration for r in runs)

    # Group test cases by their canonical key "classname::name"
    by_key: dict[str, list[str]] = {}
    for tc in all_tests:
        key = f"{tc.classname}::{tc.name}"
        by_key.setdefault(key, []).append(tc.status)

    flaky: list[str] = []
    consistently_failing: list[str] = []
    consistently_passing: list[str] = []

    for key, statuses in by_key.items():
        has_pass = any(s == "passed" for s in statuses)
        has_fail = any(s == "failed" for s in statuses)

        if has_pass and has_fail:
            flaky.append(key)
        elif has_fail and not has_pass:
            consistently_failing.append(key)
        elif has_pass and not has_fail:
            consistently_passing.append(key)

    return AggregatedResults(
        runs=runs,
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        errors=errors,
        duration=duration,
        flaky_tests=sorted(flaky),
        consistently_failing=sorted(consistently_failing),
        consistently_passing=sorted(consistently_passing),
    )


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def generate_markdown(results: AggregatedResults) -> str:
    """Generate a GitHub Actions job summary in Markdown format."""
    lines: list[str] = []

    lines.append("## Test Results Summary")
    lines.append("")

    # Summary table
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Total Tests | {results.total} |")
    lines.append(f"| Passed | {results.passed} |")
    lines.append(f"| Failed | {results.failed} |")
    lines.append(f"| Skipped | {results.skipped} |")
    lines.append(f"| Duration | {results.duration:.2f}s |")
    lines.append("")

    # Per-run breakdown
    if results.runs:
        lines.append("### Per-Run Breakdown")
        lines.append("")
        lines.append("| Run | Tests | Passed | Failed | Skipped | Duration |")
        lines.append("|-----|-------|--------|--------|---------|----------|")
        for run in results.runs:
            lines.append(
                f"| {run.run_name} | {run.total} | {run.passed} | "
                f"{run.failed} | {run.skipped} | {run.duration:.2f}s |"
            )
        lines.append("")

    # Flaky tests
    if results.flaky_tests:
        lines.append("### Flaky Tests (passed in some runs, failed in others)")
        lines.append("")
        for t in results.flaky_tests:
            lines.append(f"- `{t}`")
        lines.append("")

    # Consistently failing
    if results.consistently_failing:
        lines.append("### Consistently Failing Tests")
        lines.append("")
        for t in results.consistently_failing:
            lines.append(f"- `{t}`")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    """Main entry point. Usage: aggregator.py [file1 file2 ...]

    Accepts JUnit XML (.xml) and JSON (.json) files.
    Prints the markdown summary to stdout and writes it to
    $GITHUB_STEP_SUMMARY if the env var is set.
    """
    import os

    args = argv if argv is not None else sys.argv[1:]

    if not args:
        print("Usage: aggregator.py <result-file1> [result-file2 ...]", file=sys.stderr)
        print("Supported formats: JUnit XML (.xml), JSON (.json)", file=sys.stderr)
        return 1

    runs: list[RunResult] = []
    errors: list[str] = []

    for filepath in args:
        p = Path(filepath)
        try:
            if p.suffix.lower() == ".xml":
                runs.append(parse_junit_xml(p))
            elif p.suffix.lower() == ".json":
                runs.append(parse_json_results(p))
            else:
                errors.append(f"Unknown format for {filepath} (expected .xml or .json)")
        except (FileNotFoundError, ValueError) as exc:
            errors.append(str(exc))

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        if not runs:
            return 1

    results = aggregate_results(runs)
    md = generate_markdown(results)
    print(md)

    # Write to GitHub Actions step summary if available
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(md)

    return 0 if results.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
