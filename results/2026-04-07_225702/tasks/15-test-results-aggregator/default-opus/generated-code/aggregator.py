"""
Test Results Aggregator

Parses JUnit XML and JSON test result files, aggregates totals across
multiple matrix-build runs, detects flaky tests, and generates a
GitHub Actions-compatible markdown summary.
"""

from __future__ import annotations

import json
import os
import xml.etree.ElementTree as ET
from dataclasses import dataclass


# ── Data model ────────────────────────────────────────────────────────────────

@dataclass
class TestResult:
    """A single test case outcome from one run."""
    suite: str
    name: str
    status: str   # "passed", "failed", or "skipped"
    duration: float
    message: str = ""


@dataclass
class AggregatedTotals:
    """Summary counts across all loaded test results."""
    total: int
    passed: int
    failed: int
    skipped: int
    duration: float


# ── Parsers ───────────────────────────────────────────────────────────────────

def parse_junit_xml(xml_string: str) -> list[TestResult]:
    """Parse a JUnit XML string into TestResult objects.

    Handles <failure> and <skipped> child elements to determine status.
    """
    root = ET.fromstring(xml_string)
    suite_name = root.get("name", "unknown")
    results = []

    for tc in root.iter("testcase"):
        name = tc.get("name", "unnamed")
        duration = float(tc.get("time", "0"))
        message = ""

        if tc.find("failure") is not None:
            status = "failed"
            message = tc.find("failure").get("message", "")
        elif tc.find("skipped") is not None:
            status = "skipped"
            message = tc.find("skipped").get("message", "")
        else:
            status = "passed"

        results.append(TestResult(suite_name, name, status, duration, message))

    return results


def parse_json_results(json_string: str) -> list[TestResult]:
    """Parse a JSON test results string into TestResult objects.

    Expected format:
        {"suite": "...", "tests": [{"name": ..., "status": ..., "duration": ...}, ...]}
    """
    data = json.loads(json_string)
    suite_name = data.get("suite", "unknown")
    results = []

    for t in data["tests"]:
        results.append(TestResult(
            suite=suite_name,
            name=t["name"],
            status=t["status"],
            duration=float(t.get("duration", 0)),
            message=t.get("message", ""),
        ))

    return results


# ── File loader with format auto-detection ────────────────────────────────────

def load_results_file(path: str) -> list[TestResult]:
    """Load test results from a file, auto-detecting format by extension.

    Raises:
        FileNotFoundError: if the file does not exist
        ValueError: for unsupported formats or parse errors
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"No such file: {path}")

    ext = os.path.splitext(path)[1].lower()
    content = open(path, encoding="utf-8").read()

    if ext == ".xml":
        try:
            return parse_junit_xml(content)
        except ET.ParseError as e:
            raise ValueError(f"Failed to parse XML in {path}: {e}") from e
    elif ext == ".json":
        try:
            return parse_json_results(content)
        except (json.JSONDecodeError, KeyError) as e:
            raise ValueError(f"Failed to parse JSON in {path}: {e}") from e
    else:
        raise ValueError(f"Unsupported file format: {ext}")


# ── Aggregation ───────────────────────────────────────────────────────────────

def aggregate(results: list[TestResult]) -> AggregatedTotals:
    """Compute summary totals from a list of test results."""
    passed = sum(1 for r in results if r.status == "passed")
    failed = sum(1 for r in results if r.status == "failed")
    skipped = sum(1 for r in results if r.status == "skipped")
    duration = sum(r.duration for r in results)

    return AggregatedTotals(
        total=len(results),
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
    )


# ── Flaky test detection ─────────────────────────────────────────────────────

def find_flaky_tests(results: list[TestResult]) -> set[str]:
    """Identify tests that both passed AND failed across runs.

    A test is flaky if it has at least one "passed" and at least one "failed"
    outcome. Skipped results are ignored for flakiness detection.
    """
    # Group statuses by test name (only passed/failed matter)
    outcomes: dict[str, set[str]] = {}
    for r in results:
        if r.status in ("passed", "failed"):
            outcomes.setdefault(r.name, set()).add(r.status)

    return {name for name, statuses in outcomes.items()
            if "passed" in statuses and "failed" in statuses}


# ── Markdown summary generation ──────────────────────────────────────────────

def generate_markdown(
    totals: AggregatedTotals,
    results: list[TestResult],
) -> str:
    """Generate a GitHub Actions job summary in markdown.

    Includes: totals table, failed tests list, flaky tests list, and duration.
    """
    lines: list[str] = []

    # Header with pass/fail emoji
    icon = "\u2705" if totals.failed == 0 else "\u274c"
    lines.append(f"## {icon} Test Results Summary\n")

    # Totals table
    lines.append("| Metric | Count |")
    lines.append("|--------|------:|")
    lines.append(f"| Total  | {totals.total} |")
    lines.append(f"| Passed | {totals.passed} |")
    lines.append(f"| Failed | {totals.failed} |")
    lines.append(f"| Skipped | {totals.skipped} |")
    lines.append(f"| Duration | {totals.duration:.2f}s |")
    lines.append("")

    # Failed tests
    failures = [r for r in results if r.status == "failed"]
    if failures:
        lines.append("### Failed Tests\n")
        lines.append("| Suite | Test | Duration | Message |")
        lines.append("|-------|------|----------|---------|")
        for r in failures:
            msg = r.message.replace("|", "\\|")
            lines.append(f"| {r.suite} | {r.name} | {r.duration:.2f}s | {msg} |")
        lines.append("")

    # Flaky tests
    flaky = find_flaky_tests(results)
    if flaky:
        lines.append("### Flaky Tests\n")
        lines.append("These tests produced inconsistent results across runs:\n")
        for name in sorted(flaky):
            lines.append(f"- `{name}`")
        lines.append("")

    return "\n".join(lines)


# ── CLI entry point ──────────────────────────────────────────────────────────

def main():
    """Load all result files passed as arguments, aggregate, and print markdown."""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python aggregator.py <file1.xml> [file2.json] ...", file=sys.stderr)
        sys.exit(1)

    all_results: list[TestResult] = []
    for path in sys.argv[1:]:
        try:
            all_results.extend(load_results_file(path))
        except (FileNotFoundError, ValueError) as e:
            print(f"Warning: {e}", file=sys.stderr)

    totals = aggregate(all_results)
    print(generate_markdown(totals, all_results))


if __name__ == "__main__":
    main()
