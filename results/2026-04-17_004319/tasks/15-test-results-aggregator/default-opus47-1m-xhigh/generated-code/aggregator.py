"""Test Results Aggregator.

Parses JUnit XML and JSON test report files, aggregates results across a set
of files (useful for matrix CI builds), detects flaky tests, and emits a
markdown summary suitable for a GitHub Actions job summary.

Design notes:
- We keep the data model small and explicit (TestCase, AggregatedReport) so
  the parsers and the renderer don't need to understand each other's details.
- Status values are normalized at parse time to: "passed" | "failed" | "skipped".
- The CLI exits 1 when any test failed so that a calling CI job can surface
  failure, 2 for input/parse errors, and 0 otherwise.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree as ET


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class TestCase:
    """A single test result from one file (one run)."""
    name: str
    status: str                 # "passed" | "failed" | "skipped"
    duration: float = 0.0       # seconds
    message: str = ""           # failure/error message if any
    source: str = ""            # file the result came from


@dataclass
class FlakyTest:
    name: str
    passed: int
    failed: int


@dataclass
class AggregatedReport:
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    duration: float = 0.0
    cases: list[TestCase] = field(default_factory=list)
    flaky: list[FlakyTest] = field(default_factory=list)
    sources: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Status normalization
# ---------------------------------------------------------------------------
_STATUS_MAP = {
    "passed": "passed", "pass": "passed", "ok": "passed", "success": "passed",
    "failed": "failed", "fail": "failed", "failure": "failed", "error": "failed",
    "skipped": "skipped", "skip": "skipped", "ignored": "skipped",
}


def _normalize_status(raw: str) -> str:
    s = (raw or "").strip().lower()
    if s not in _STATUS_MAP:
        raise ValueError(f"Unknown test status: {raw!r}")
    return _STATUS_MAP[s]


# ---------------------------------------------------------------------------
# JUnit XML parsing
# ---------------------------------------------------------------------------
def parse_junit_xml(path: Path | str) -> list[TestCase]:
    """Parse a JUnit XML file into a list of TestCase objects.

    Handles both single-suite (<testsuite>) and multi-suite (<testsuites>) roots.
    A <testcase> is failed if it has a <failure> or <error> child, skipped if
    it has a <skipped> child, otherwise passed.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"JUnit XML file not found: {p}")
    try:
        tree = ET.parse(p)
    except ET.ParseError as exc:
        raise ValueError(f"Malformed JUnit XML in {p}: {exc}") from exc

    root = tree.getroot()
    # Walk every <testcase> anywhere under the root — handles both layouts.
    cases: list[TestCase] = []
    for tc in root.iter("testcase"):
        classname = tc.attrib.get("classname", "").strip()
        name = tc.attrib.get("name", "").strip()
        full_name = f"{classname}.{name}" if classname else name

        try:
            duration = float(tc.attrib.get("time", "0") or 0)
        except ValueError:
            duration = 0.0

        failure = tc.find("failure")
        error = tc.find("error")
        skipped = tc.find("skipped")
        if failure is not None or error is not None:
            status = "failed"
            el = failure if failure is not None else error
            message = (el.attrib.get("message") or (el.text or "")).strip()
        elif skipped is not None:
            status = "skipped"
            message = (skipped.attrib.get("message") or (skipped.text or "")).strip()
        else:
            status = "passed"
            message = ""

        cases.append(TestCase(
            name=full_name, status=status, duration=duration,
            message=message, source=str(p),
        ))
    return cases


# ---------------------------------------------------------------------------
# JSON parsing
# ---------------------------------------------------------------------------
def parse_json(path: Path | str) -> list[TestCase]:
    """Parse a JSON test report.

    Expected shape:
        {"tests": [{"name": "...", "status": "passed|failed|skipped",
                    "duration": 0.1, "message": "..."}, ...]}

    The top-level may also be a bare list of tests (same shape as .tests).
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"JSON file not found: {p}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Malformed JSON in {p}: {exc}") from exc

    if isinstance(data, list):
        tests = data
    elif isinstance(data, dict):
        tests = data.get("tests") or data.get("results") or []
    else:
        raise ValueError(f"Unexpected JSON shape in {p}: top-level {type(data).__name__}")

    cases: list[TestCase] = []
    for idx, item in enumerate(tests):
        if not isinstance(item, dict):
            raise ValueError(f"{p}: tests[{idx}] must be an object, got {type(item).__name__}")
        try:
            status = _normalize_status(item.get("status", ""))
        except ValueError as exc:
            raise ValueError(f"{p}: tests[{idx}]: {exc}") from exc
        cases.append(TestCase(
            name=str(item.get("name", f"test_{idx}")),
            status=status,
            duration=float(item.get("duration", 0.0) or 0.0),
            message=str(item.get("message", "") or ""),
            source=str(p),
        ))
    return cases


# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------
def parse_file(path: Path | str) -> list[TestCase]:
    """Parse any supported test result file, dispatched by extension."""
    p = Path(path)
    suffix = p.suffix.lower()
    if suffix == ".xml":
        return parse_junit_xml(p)
    if suffix == ".json":
        return parse_json(p)
    raise ValueError(f"Unsupported test result format for {p} (want .xml or .json)")


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------
def aggregate(paths: Iterable[Path | str]) -> AggregatedReport:
    """Aggregate results across multiple files, detecting flaky tests.

    A test is considered flaky if, across the supplied files, it appears
    with status=passed in at least one run AND status=failed in at least
    one other run. Skipped runs are ignored for flakiness determination.
    """
    paths = list(paths)
    if not paths:
        raise ValueError("aggregate requires at least one input file")

    report = AggregatedReport()
    # name -> {"passed": count, "failed": count, "skipped": count}
    by_name: dict[str, dict[str, int]] = defaultdict(lambda: {"passed": 0, "failed": 0, "skipped": 0})

    for path in paths:
        cases = parse_file(path)
        report.sources.append(str(path))
        for c in cases:
            report.cases.append(c)
            report.total += 1
            report.duration += c.duration
            if c.status == "passed":
                report.passed += 1
            elif c.status == "failed":
                report.failed += 1
            else:
                report.skipped += 1
            by_name[c.name][c.status] += 1

    for name, counts in by_name.items():
        if counts["passed"] > 0 and counts["failed"] > 0:
            report.flaky.append(FlakyTest(name=name, passed=counts["passed"], failed=counts["failed"]))
    report.flaky.sort(key=lambda f: f.name)
    return report


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------
def render_markdown(report: AggregatedReport) -> str:
    """Produce a GitHub Actions-friendly markdown summary."""
    lines: list[str] = []
    lines.append("# Test Results Summary")
    lines.append("")
    lines.append(f"_Aggregated across {len(report.sources)} file(s)._")
    lines.append("")

    # Totals table
    lines.append("## Totals")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("| --- | --- |")
    lines.append(f"| Passed | {report.passed} |")
    lines.append(f"| Failed | {report.failed} |")
    lines.append(f"| Skipped | {report.skipped} |")
    lines.append(f"| Total | {report.total} |")
    lines.append(f"| Duration | {report.duration:.2f}s |")
    lines.append("")

    # Failures
    failures = [c for c in report.cases if c.status == "failed"]
    lines.append("## Failures")
    lines.append("")
    if not failures:
        lines.append("No failures.")
    else:
        lines.append("| Test | Message | Source |")
        lines.append("| --- | --- | --- |")
        for c in failures:
            msg = (c.message or "").splitlines()[0] if c.message else ""
            # Escape pipe characters so they don't break the table.
            msg = msg.replace("|", "\\|")
            name = c.name.replace("|", "\\|")
            src = Path(c.source).name.replace("|", "\\|")
            lines.append(f"| `{name}` | {msg} | {src} |")
    lines.append("")

    # Flaky tests
    lines.append("## Flaky Tests")
    lines.append("")
    if not report.flaky:
        lines.append("No flaky tests detected.")
    else:
        lines.append("| Test | Outcome |")
        lines.append("| --- | --- |")
        for f in report.flaky:
            lines.append(f"| `{f.name}` | {f.passed} passed, {f.failed} failed |")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="aggregator",
        description="Aggregate JUnit XML and JSON test reports into a markdown summary.",
    )
    parser.add_argument("files", nargs="+", help="Test report files (.xml or .json)")
    parser.add_argument("--output", "-o", help="Write markdown to this file (default: stdout)")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        report = aggregate(args.files)
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    markdown = render_markdown(report)

    if args.output:
        Path(args.output).write_text(markdown)
    else:
        print(markdown)

    # If GITHUB_STEP_SUMMARY is defined (running under GH Actions), append there.
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as fh:
            fh.write(markdown)
            fh.write("\n")

    # Print a concise machine-readable line to stdout that the workflow can grep.
    print(
        f"AGGREGATOR_RESULT total={report.total} passed={report.passed} "
        f"failed={report.failed} skipped={report.skipped} flaky={len(report.flaky)} "
        f"duration={report.duration:.2f}"
    )

    return 1 if report.failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
