"""
Test Results Aggregator

Parses JUnit XML and JSON test result files, aggregates results across multiple
files (simulating a matrix build), detects flaky tests, and generates a
markdown summary suitable for GitHub Actions job summaries.

TDD approach: this file was written test-by-test after each test was written
and confirmed failing.
"""
from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Data classes (plain value objects - no logic)
# ---------------------------------------------------------------------------

@dataclass
class TestResult:
    """Represents a single test case result."""
    name: str
    classname: str
    passed: bool
    skipped: bool
    duration: float
    failure_message: str = ""


@dataclass
class TestSuiteResult:
    """Represents the aggregated results of one test suite (one file)."""
    suite_name: str
    total: int
    passed: int
    failed: int
    skipped: int
    duration: float
    test_cases: list[TestResult] = field(default_factory=list)


# ---------------------------------------------------------------------------
# TDD Cycle 1: JUnit XML parsing
# ---------------------------------------------------------------------------

def _parse_testsuite_element(elem: ET.Element) -> TestSuiteResult:
    """Parse a single <testsuite> XML element into a TestSuiteResult."""
    name = elem.get("name", "Unknown")
    duration = float(elem.get("time", "0") or "0")

    test_cases: list[TestResult] = []
    passed = 0
    failed = 0
    skipped = 0

    for tc in elem.findall("testcase"):
        tc_name = tc.get("name", "unknown")
        tc_class = tc.get("classname", "")
        tc_time = float(tc.get("time", "0") or "0")

        failure_elem = tc.find("failure")
        error_elem = tc.find("error")
        skipped_elem = tc.find("skipped")

        if skipped_elem is not None:
            # Skipped tests: count as skipped (not failed, not passed)
            test_cases.append(TestResult(
                name=tc_name, classname=tc_class,
                passed=True, skipped=True,
                duration=tc_time,
            ))
            skipped += 1
        elif failure_elem is not None or error_elem is not None:
            # Both <failure> and <error> count as failures
            msg_elem = failure_elem if failure_elem is not None else error_elem
            msg = msg_elem.get("message", "")
            test_cases.append(TestResult(
                name=tc_name, classname=tc_class,
                passed=False, skipped=False,
                duration=tc_time, failure_message=msg,
            ))
            failed += 1
        else:
            test_cases.append(TestResult(
                name=tc_name, classname=tc_class,
                passed=True, skipped=False,
                duration=tc_time,
            ))
            passed += 1

    total = passed + failed + skipped
    return TestSuiteResult(
        suite_name=name,
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
        test_cases=test_cases,
    )


def parse_junit_xml(content: str) -> TestSuiteResult:
    """
    Parse JUnit XML content (string) into a TestSuiteResult.

    Handles both <testsuite> (single) and <testsuites> (multiple) root elements.
    When multiple suites are present, results are merged into one TestSuiteResult.

    Raises ValueError on parse errors with a meaningful message.
    """
    try:
        root = ET.fromstring(content)
    except ET.ParseError as exc:
        raise ValueError(f"Failed to parse JUnit XML: {exc}") from exc

    if root.tag == "testsuites":
        # Merge multiple <testsuite> children into one result
        suites = [_parse_testsuite_element(child)
                  for child in root.findall("testsuite")]
        if not suites:
            return TestSuiteResult(suite_name="Unknown", total=0,
                                   passed=0, failed=0, skipped=0, duration=0.0)
        # Merge: take first suite name, sum everything else
        all_cases = []
        for s in suites:
            all_cases.extend(s.test_cases)
        return TestSuiteResult(
            suite_name=suites[0].suite_name,
            total=sum(s.total for s in suites),
            passed=sum(s.passed for s in suites),
            failed=sum(s.failed for s in suites),
            skipped=sum(s.skipped for s in suites),
            duration=sum(s.duration for s in suites),
            test_cases=all_cases,
        )
    elif root.tag == "testsuite":
        return _parse_testsuite_element(root)
    else:
        raise ValueError(
            f"Failed to parse JUnit XML: unexpected root element <{root.tag}>"
        )


# ---------------------------------------------------------------------------
# TDD Cycle 2: JSON test result parsing
# ---------------------------------------------------------------------------

def parse_json_results(content: str) -> TestSuiteResult:
    """
    Parse JSON test result content into a TestSuiteResult.

    Expected format:
        {
            "suite": "SuiteName",   # optional
            "tests": [
                {"name": "...", "status": "passed|failed|skipped",
                 "duration": 0.0, "error": "..."}  # error is optional
            ]
        }

    Raises ValueError on parse errors with a meaningful message.
    """
    try:
        data = json.loads(content)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse JSON results: {exc}") from exc

    suite_name = data.get("suite", "UnnamedSuite")
    raw_tests = data.get("tests", [])

    test_cases: list[TestResult] = []
    passed = 0
    failed = 0
    skipped = 0
    total_duration = 0.0

    for t in raw_tests:
        name = t.get("name", "unknown")
        classname = t.get("classname", "")
        status = t.get("status", "passed").lower()
        duration = float(t.get("duration", 0))
        error_msg = t.get("error", "")

        total_duration += duration

        if status == "skipped":
            test_cases.append(TestResult(
                name=name, classname=classname,
                passed=True, skipped=True,
                duration=duration,
            ))
            skipped += 1
        elif status == "failed":
            test_cases.append(TestResult(
                name=name, classname=classname,
                passed=False, skipped=False,
                duration=duration,
                failure_message=error_msg,
            ))
            failed += 1
        else:  # "passed" or anything else
            test_cases.append(TestResult(
                name=name, classname=classname,
                passed=True, skipped=False,
                duration=duration,
            ))
            passed += 1

    return TestSuiteResult(
        suite_name=suite_name,
        total=passed + failed + skipped,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=total_duration,
        test_cases=test_cases,
    )


# ---------------------------------------------------------------------------
# TDD Cycle 3: Aggregating multiple suite results
# ---------------------------------------------------------------------------

def aggregate_results(suites: list[TestSuiteResult]) -> dict[str, Any]:
    """
    Aggregate a list of TestSuiteResult objects into a summary dict.

    Returns:
        {
            "total": int,
            "passed": int,
            "failed": int,
            "skipped": int,
            "duration": float,
            "suites": [{"name": str, "total": int, "passed": int,
                         "failed": int, "skipped": int, "duration": float}],
        }
    """
    if not suites:
        return {
            "total": 0, "passed": 0, "failed": 0, "skipped": 0,
            "duration": 0.0, "suites": [],
        }

    suite_breakdowns = [
        {
            "name": s.suite_name,
            "total": s.total,
            "passed": s.passed,
            "failed": s.failed,
            "skipped": s.skipped,
            "duration": s.duration,
        }
        for s in suites
    ]

    return {
        "total": sum(s.total for s in suites),
        "passed": sum(s.passed for s in suites),
        "failed": sum(s.failed for s in suites),
        "skipped": sum(s.skipped for s in suites),
        "duration": sum(s.duration for s in suites),
        "suites": suite_breakdowns,
    }


# ---------------------------------------------------------------------------
# TDD Cycle 4: Flaky test detection
# ---------------------------------------------------------------------------

def detect_flaky_tests(
    runs: list[list[TestResult]],
) -> list[dict[str, Any]]:
    """
    Detect flaky tests: tests that passed in some runs and failed in others.

    Args:
        runs: A list of runs, where each run is a list of TestResult objects.
              Each run represents one execution of the test suite (e.g. one
              matrix job).

    Returns:
        List of dicts: [{"name": str, "classname": str,
                          "pass_count": int, "fail_count": int}]
        Only tests that both passed AND failed appear in the output.
        Consistently failing or consistently passing tests are not flaky.
    """
    if len(runs) < 2:
        # Need at least two runs to detect flakiness
        return []

    # Build a map: (name, classname) -> {"pass": count, "fail": count}
    test_stats: dict[tuple[str, str], dict[str, int]] = {}
    test_meta: dict[tuple[str, str], dict[str, str]] = {}

    for run in runs:
        for result in run:
            key = (result.name, result.classname)
            if key not in test_stats:
                test_stats[key] = {"pass": 0, "fail": 0}
                test_meta[key] = {"name": result.name, "classname": result.classname}
            # Skipped tests are not counted as pass or fail for flakiness
            if not result.skipped:
                if result.passed:
                    test_stats[key]["pass"] += 1
                else:
                    test_stats[key]["fail"] += 1

    flaky = []
    for key, stats in test_stats.items():
        if stats["pass"] > 0 and stats["fail"] > 0:
            flaky.append({
                "name": test_meta[key]["name"],
                "classname": test_meta[key]["classname"],
                "pass_count": stats["pass"],
                "fail_count": stats["fail"],
            })

    return sorted(flaky, key=lambda x: x["name"])


# ---------------------------------------------------------------------------
# TDD Cycle 5: Markdown summary generation
# ---------------------------------------------------------------------------

def generate_markdown_summary(aggregated: dict[str, Any]) -> str:
    """
    Generate a GitHub Actions-compatible Markdown summary from aggregated results.

    Args:
        aggregated: Output from aggregate_results(), plus an optional
                    "flaky_tests" key (list from detect_flaky_tests()).

    Returns:
        A Markdown string suitable for $GITHUB_STEP_SUMMARY.
    """
    total = aggregated["total"]
    passed = aggregated["passed"]
    failed = aggregated["failed"]
    skipped = aggregated["skipped"]
    duration = aggregated["duration"]
    suites = aggregated.get("suites", [])
    flaky_tests = aggregated.get("flaky_tests", [])

    overall_icon = "✅" if failed == 0 else "❌"
    overall_status = "PASSED" if failed == 0 else "FAILED"

    lines = [
        "# Test Results",
        "",
        f"{overall_icon} **Overall Status: {overall_status}**",
        "",
        "## Summary",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Total Tests | {total} |",
        f"| ✅ Passed | {passed} |",
        f"| ❌ Failed | {failed} |",
        f"| ⏭️ Skipped | {skipped} |",
        f"| ⏱️ Duration | {duration:.2f}s |",
        "",
    ]

    if suites:
        lines += [
            "## Suite Breakdown",
            "",
            "| Suite | Total | ✅ Passed | ❌ Failed | ⏭️ Skipped | ⏱️ Duration |",
            "|-------|-------|----------|----------|----------|----------|",
        ]
        for s in suites:
            status_icon = "✅" if s["failed"] == 0 else "❌"
            lines.append(
                f"| {status_icon} {s['name']} | {s['total']} | {s['passed']} | "
                f"{s['failed']} | {s['skipped']} | {s['duration']:.2f}s |"
            )
        lines.append("")

    if flaky_tests:
        lines += [
            "## ⚠️ Flaky Tests Detected",
            "",
            f"The following {len(flaky_tests)} test(s) produced inconsistent results "
            "across matrix runs:",
            "",
            "| Test | Class | Passes | Failures |",
            "|------|-------|--------|----------|",
        ]
        for ft in flaky_tests:
            lines.append(
                f"| `{ft['name']}` | `{ft['classname']}` | "
                f"{ft['pass_count']} | {ft['fail_count']} |"
            )
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _load_file(path: Path) -> TestSuiteResult:
    """Load a test result file (auto-detects XML vs JSON by extension)."""
    content = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()
    if suffix == ".xml":
        return parse_junit_xml(content)
    elif suffix == ".json":
        return parse_json_results(content)
    else:
        # Try XML first, then JSON
        try:
            return parse_junit_xml(content)
        except ValueError:
            return parse_json_results(content)


def main(args: list[str] | None = None) -> int:
    """
    CLI entry point.

    Usage:
        python aggregator.py [--output-file OUT] FILE [FILE ...]

    Each FILE is a JUnit XML or JSON test result file. When multiple files are
    provided they are treated as separate matrix runs for flaky test detection.
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Aggregate test results from JUnit XML / JSON files"
    )
    parser.add_argument("files", nargs="*", metavar="FILE",
                        help="Test result files (JUnit XML or JSON)")
    parser.add_argument("--output-file", metavar="OUT", default=None,
                        help="Write markdown summary to file instead of stdout")
    parser.add_argument("--glob", metavar="PATTERN", default=None,
                        help="Glob pattern to find result files (e.g. 'results/**/*.xml')")

    parsed = parser.parse_args(args)

    file_paths: list[Path] = []

    if parsed.glob:
        import glob as glob_module
        file_paths += [Path(p) for p in glob_module.glob(parsed.glob, recursive=True)]

    for f in parsed.files:
        file_paths.append(Path(f))

    if not file_paths:
        # Default: look for common patterns
        for pattern in ["**/*.xml", "**/*.json"]:
            import glob as glob_module
            file_paths += [Path(p) for p in glob_module.glob(pattern, recursive=True)
                           if "fixture" not in p]

    if not file_paths:
        print("ERROR: No test result files found.", file=sys.stderr)
        return 1

    suites: list[TestSuiteResult] = []
    all_run_cases: list[list[TestResult]] = []
    errors: list[str] = []

    for path in sorted(file_paths):
        try:
            result = _load_file(path)
            suites.append(result)
            all_run_cases.append(result.test_cases)
            print(f"Loaded: {path} ({result.total} tests, "
                  f"{result.passed} passed, {result.failed} failed)",
                  file=sys.stderr)
        except (ValueError, OSError) as exc:
            errors.append(f"ERROR loading {path}: {exc}")
            print(errors[-1], file=sys.stderr)

    aggregated = aggregate_results(suites)
    flaky = detect_flaky_tests(all_run_cases)
    aggregated["flaky_tests"] = flaky

    markdown = generate_markdown_summary(aggregated)

    if parsed.output_file:
        Path(parsed.output_file).write_text(markdown, encoding="utf-8")
        print(f"Summary written to {parsed.output_file}", file=sys.stderr)
    else:
        print(markdown)

    # Exit code: 0 = all good, 1 = errors during loading
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
