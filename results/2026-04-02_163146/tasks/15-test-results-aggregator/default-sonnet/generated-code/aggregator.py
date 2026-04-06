"""
Test Results Aggregator — Implementation.

Parses JUnit XML and JSON test result files, aggregates results across
multiple files (matrix build simulation), detects flaky tests, and
generates a GitHub Actions-compatible markdown job summary.

Design:
  - TestResult       — one test case (name, status, duration, failure message)
  - TestSuiteResult  — one file's worth of results (list of TestResults + totals)
  - AggregatedResults — across all suites (totals + suite list)
  - detect_flaky_tests(agg) → dict[name → {passed, failed}]
  - generate_markdown_summary(agg, flaky) → str
"""

from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ─────────────────────────────────────────────
# DATA CLASSES
# ─────────────────────────────────────────────

@dataclass
class TestResult:
    """Represents a single test case result."""
    name: str
    status: str              # "passed", "failed", "skipped"
    duration: float          # seconds
    failure_message: Optional[str]
    classname: str
    suite: str               # name of the parent suite (for tracing)


@dataclass
class TestSuiteResult:
    """Represents all results from one test-result file."""
    name: str
    passed: int
    failed: int
    skipped: int
    duration: float
    tests: list[TestResult]
    source_file: str

    @property
    def total(self) -> int:
        return self.passed + self.failed + self.skipped


@dataclass
class AggregatedResults:
    """Totals aggregated across all suites in a matrix build."""
    suites: list[TestSuiteResult]
    total_passed: int
    total_failed: int
    total_skipped: int
    total_duration: float

    @property
    def total_tests(self) -> int:
        return self.total_passed + self.total_failed + self.total_skipped


# ─────────────────────────────────────────────
# 1. JUnit XML PARSER
# ─────────────────────────────────────────────

def parse_junit_xml(path: str) -> TestSuiteResult:
    """
    Parse a JUnit XML test result file.

    JUnit XML schema (simplified):
      <testsuites>               ← optional wrapper
        <testsuite name="..." tests="N" failures="N" skipped="N" time="N.N">
          <testcase name="..." classname="..." time="N.N">
            <failure message="...">...</failure>   ← present iff failed
            <skipped/>                              ← present iff skipped
          </testcase>
          ...
        </testsuite>
      </testsuites>

    Raises:
        FileNotFoundError: if the file doesn't exist.
        ValueError: if the file is not valid XML or missing expected structure.
    """
    file_path = Path(path)
    if not file_path.exists():
        raise FileNotFoundError(f"Test result file not found: {path}")

    try:
        tree = ET.parse(str(file_path))
    except ET.ParseError as exc:
        raise ValueError(f"Invalid XML in {path}: {exc}") from exc

    root = tree.getroot()

    # Handle both <testsuites><testsuite>...</testsuite></testsuites>
    # and bare <testsuite>...</testsuite>
    if root.tag == "testsuites":
        # Use the first testsuite element
        suite_elem = root.find("testsuite")
        if suite_elem is None:
            raise ValueError(f"Invalid XML in {path}: no <testsuite> element found")
    elif root.tag == "testsuite":
        suite_elem = root
    else:
        raise ValueError(
            f"Invalid XML in {path}: root element must be <testsuite> or <testsuites>, "
            f"got <{root.tag}>"
        )

    suite_name = suite_elem.get("name", "Unknown")
    duration = float(suite_elem.get("time", "0") or "0")

    tests: list[TestResult] = []
    passed = failed = skipped = 0

    for tc in suite_elem.findall("testcase"):
        tc_name = tc.get("name", "unknown")
        tc_class = tc.get("classname", "")
        tc_time = float(tc.get("time", "0") or "0")

        failure_elem = tc.find("failure")
        error_elem = tc.find("error")
        skipped_elem = tc.find("skipped")

        if skipped_elem is not None:
            status = "skipped"
            failure_message = None
            skipped += 1
        elif failure_elem is not None:
            status = "failed"
            # Prefer the message attribute; fall back to element text
            failure_message = (
                failure_elem.get("message")
                or (failure_elem.text or "").strip()
                or "Test failed"
            )
            failed += 1
        elif error_elem is not None:
            status = "failed"
            failure_message = (
                error_elem.get("message")
                or (error_elem.text or "").strip()
                or "Test error"
            )
            failed += 1
        else:
            status = "passed"
            failure_message = None
            passed += 1

        tests.append(TestResult(
            name=tc_name,
            status=status,
            duration=tc_time,
            failure_message=failure_message,
            classname=tc_class,
            suite=suite_name,
        ))

    return TestSuiteResult(
        name=suite_name,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
        tests=tests,
        source_file=str(file_path),
    )


# ─────────────────────────────────────────────
# 2. JSON PARSER
# ─────────────────────────────────────────────

def parse_json_results(path: str) -> TestSuiteResult:
    """
    Parse a JSON test result file.

    Expected schema:
    {
      "suite": "SuiteName",
      "duration": 3.14,
      "tests": [
        {
          "name": "test_foo",
          "status": "passed" | "failed" | "skipped",
          "duration": 0.5,
          "classname": "module.Class",      ← optional
          "failure_message": "..."           ← optional, present if failed
        },
        ...
      ]
    }

    Raises:
        FileNotFoundError: if the file doesn't exist.
        ValueError: if JSON is malformed or required keys are missing.
    """
    file_path = Path(path)
    if not file_path.exists():
        raise FileNotFoundError(f"Test result file not found: {path}")

    try:
        data = json.loads(file_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc

    # Validate required top-level keys
    if "suite" not in data or "tests" not in data:
        raise ValueError(
            f"Invalid JSON test result format in {path}: "
            "expected top-level 'suite' and 'tests' keys"
        )

    suite_name = data["suite"]
    duration = float(data.get("duration", 0))
    raw_tests = data["tests"]

    tests: list[TestResult] = []
    passed = failed = skipped = 0

    for item in raw_tests:
        name = item.get("name", "unknown")
        status = item.get("status", "unknown").lower()
        tc_duration = float(item.get("duration", 0))
        classname = item.get("classname", "")
        failure_message = item.get("failure_message")

        if status == "passed":
            passed += 1
        elif status == "failed":
            failed += 1
            if not failure_message:
                failure_message = "Test failed (no message provided)"
        elif status == "skipped":
            skipped += 1
        # Unknown statuses are treated as passed to avoid false failures

        tests.append(TestResult(
            name=name,
            status=status,
            duration=tc_duration,
            failure_message=failure_message,
            classname=classname,
            suite=suite_name,
        ))

    return TestSuiteResult(
        name=suite_name,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
        tests=tests,
        source_file=str(file_path),
    )


# ─────────────────────────────────────────────
# 3. AGGREGATION
# ─────────────────────────────────────────────

def aggregate_results(suites: list[TestSuiteResult]) -> AggregatedResults:
    """
    Aggregate results from multiple test suite files.

    Sums passed/failed/skipped/duration across all suites.
    Preserves the individual suite list for per-suite reporting.
    """
    total_passed = sum(s.passed for s in suites)
    total_failed = sum(s.failed for s in suites)
    total_skipped = sum(s.skipped for s in suites)
    total_duration = sum(s.duration for s in suites)

    return AggregatedResults(
        suites=list(suites),
        total_passed=total_passed,
        total_failed=total_failed,
        total_skipped=total_skipped,
        total_duration=total_duration,
    )


# ─────────────────────────────────────────────
# 4. FLAKY TEST DETECTION
# ─────────────────────────────────────────────

def detect_flaky_tests(
    agg: AggregatedResults,
) -> dict[str, dict[str, int]]:
    """
    Identify flaky tests — tests that both passed AND failed across suites.

    A test is "flaky" if it appears in more than one suite and has at least
    one "passed" result and at least one "failed" result.

    Returns:
        dict mapping test name → {"passed": N, "failed": M}
        Only tests that are genuinely flaky (mixed results) are included.
    """
    # Collect all (name → list of statuses) across suites
    status_map: dict[str, list[str]] = {}

    for suite in agg.suites:
        for test in suite.tests:
            if test.name not in status_map:
                status_map[test.name] = []
            status_map[test.name].append(test.status)

    flaky: dict[str, dict[str, int]] = {}

    for name, statuses in status_map.items():
        passed_count = statuses.count("passed")
        failed_count = statuses.count("failed")

        # Flaky = has both passing and failing runs
        if passed_count > 0 and failed_count > 0:
            flaky[name] = {"passed": passed_count, "failed": failed_count}

    return flaky


# ─────────────────────────────────────────────
# 5. MARKDOWN SUMMARY GENERATOR
# ─────────────────────────────────────────────

def generate_markdown_summary(
    agg: AggregatedResults,
    flaky: dict[str, dict[str, int]],
) -> str:
    """
    Generate a GitHub Actions-compatible markdown job summary.

    Includes:
    - Overall status header (✅ pass / ❌ fail)
    - Total counts table (passed / failed / skipped / duration)
    - Per-suite breakdown table
    - Flaky tests section (if any)
    """
    lines: list[str] = []

    # ── Overall status ──
    if agg.total_failed == 0:
        status_icon = "✅"
        status_text = "All tests passed"
    else:
        status_icon = "❌"
        status_text = f"{agg.total_failed} test(s) failed"

    lines.append(f"# Test Results {status_icon}")
    lines.append("")
    lines.append(f"**{status_text}**")
    lines.append("")

    # ── Summary totals table ──
    lines.append("## Summary")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| ✅ Passed  | {agg.total_passed} |")
    lines.append(f"| ❌ Failed  | {agg.total_failed} |")
    lines.append(f"| ⏭️ Skipped | {agg.total_skipped} |")
    lines.append(f"| 📊 Total   | {agg.total_tests} |")
    lines.append(f"| ⏱️ Duration | {agg.total_duration:.2f}s |")
    lines.append("")

    # ── Per-suite breakdown ──
    lines.append("## Suite Breakdown")
    lines.append("")
    lines.append("| Suite | Passed | Failed | Skipped | Duration |")
    lines.append("|-------|--------|--------|---------|----------|")
    for suite in agg.suites:
        icon = "✅" if suite.failed == 0 else "❌"
        lines.append(
            f"| {icon} {suite.name} | {suite.passed} | {suite.failed} "
            f"| {suite.skipped} | {suite.duration:.2f}s |"
        )
    lines.append("")

    # ── Flaky tests ──
    if flaky:
        lines.append("## ⚠️ Flaky Tests Detected")
        lines.append("")
        lines.append(
            "> The following tests had mixed results across runs "
            "(passed in some, failed in others)."
        )
        lines.append("")
        lines.append("| Test | Passed Runs | Failed Runs |")
        lines.append("|------|-------------|-------------|")
        for name, counts in sorted(flaky.items()):
            lines.append(f"| `{name}` | {counts['passed']} | {counts['failed']} |")
        lines.append("")
    else:
        lines.append("## Flaky Tests")
        lines.append("")
        lines.append("_No flaky tests detected._")
        lines.append("")

    return "\n".join(lines)


# ─────────────────────────────────────────────
# CLI ENTRY POINT
# ─────────────────────────────────────────────

def _parse_file(path: str) -> TestSuiteResult:
    """Auto-detect format by file extension."""
    p = Path(path)
    if p.suffix.lower() == ".xml":
        return parse_junit_xml(path)
    elif p.suffix.lower() == ".json":
        return parse_json_results(path)
    else:
        raise ValueError(f"Unknown file format for {path}; expected .xml or .json")


def main(paths: list[str], output_file: Optional[str] = None) -> None:
    """
    CLI entry point: parse each file, aggregate, detect flaky, print/save summary.
    """
    if not paths:
        print("Usage: python aggregator.py <result-file> [result-file ...] [--output FILE]")
        return

    suites: list[TestSuiteResult] = []
    for p in paths:
        try:
            suite = _parse_file(p)
            suites.append(suite)
            print(f"  Loaded: {p} ({suite.name}) — "
                  f"{suite.passed}P/{suite.failed}F/{suite.skipped}S")
        except (FileNotFoundError, ValueError) as exc:
            print(f"  ERROR loading {p}: {exc}")

    if not suites:
        print("No valid test result files loaded. Exiting.")
        return

    agg = aggregate_results(suites)
    flaky = detect_flaky_tests(agg)
    summary = generate_markdown_summary(agg, flaky)

    if output_file:
        Path(output_file).write_text(summary, encoding="utf-8")
        print(f"\nSummary written to: {output_file}")
    else:
        print("\n" + summary)


if __name__ == "__main__":
    import sys

    args = sys.argv[1:]
    output = None

    if "--output" in args:
        idx = args.index("--output")
        output = args[idx + 1]
        args = args[:idx] + args[idx + 2:]

    main(args, output)
