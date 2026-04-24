"""
Test-results aggregator.

Parses JUnit XML and JSON test result files produced by a matrix build,
combines them into a single summary, identifies flaky tests (any test
that both passed and failed across the matrix), and renders a Markdown
report suitable for a GitHub Actions job summary.

Usage:
    python aggregator.py <dir> [--output SUMMARY.md] [--fail-on-failures]

If --output is omitted and $GITHUB_STEP_SUMMARY is set (i.e. inside a
GitHub Actions job) the report is appended there as well.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------


VALID_STATUSES = {"passed", "failed", "skipped"}


@dataclass(frozen=True)
class TestCase:
    """A single test case result."""

    name: str
    classname: str
    status: str  # "passed" | "failed" | "skipped"
    duration: float
    message: str | None = None

    # Tell pytest not to collect this dataclass as a test class.
    __test__ = False

    def __post_init__(self) -> None:
        if self.status not in VALID_STATUSES:
            raise ValueError(f"Invalid status {self.status!r}")


@dataclass
class TestRun:
    """The parsed contents of one result file (one matrix shard)."""

    suite_name: str
    cases: list[TestCase]
    source: str = ""

    __test__ = False


@dataclass
class Aggregate:
    """Summed totals over all runs."""

    runs: list[TestRun]
    total: int
    passed: int
    failed: int
    skipped: int
    duration: float


@dataclass
class FlakyEntry:
    """A test that flipped between passed and failed across runs."""

    name: str
    classname: str
    passed_count: int
    failed_count: int


# ---------------------------------------------------------------------------
# JUnit XML parsing
# ---------------------------------------------------------------------------


def _status_from_junit(testcase: ET.Element) -> tuple[str, str | None]:
    """Return (status, message) for a JUnit <testcase> element."""
    if testcase.find("failure") is not None:
        el = testcase.find("failure")
        return "failed", (el.get("message") if el is not None else None)
    if testcase.find("error") is not None:
        el = testcase.find("error")
        return "failed", (el.get("message") if el is not None else None)
    if testcase.find("skipped") is not None:
        return "skipped", None
    return "passed", None


def parse_junit_xml(path: Path) -> TestRun:
    """Parse a JUnit XML file into a TestRun.

    Handles both a single <testsuite> root and a <testsuites> wrapper.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"JUnit file not found: {path}")
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        raise ValueError(f"Failed to parse JUnit XML {path}: {exc}") from exc

    root = tree.getroot()
    suites: list[ET.Element]
    if root.tag == "testsuites":
        suites = list(root.findall("testsuite"))
    elif root.tag == "testsuite":
        suites = [root]
    else:
        raise ValueError(
            f"Unexpected root element <{root.tag}> in {path}; "
            "expected <testsuite> or <testsuites>"
        )

    cases: list[TestCase] = []
    # Name the run after the first <testsuite>; good enough for grouping.
    suite_name = suites[0].get("name", path.stem) if suites else path.stem
    for suite in suites:
        for tc in suite.findall("testcase"):
            status, message = _status_from_junit(tc)
            try:
                duration = float(tc.get("time", "0") or 0)
            except ValueError:
                duration = 0.0
            cases.append(
                TestCase(
                    name=tc.get("name", "<unnamed>"),
                    classname=tc.get("classname", suite.get("name", "")),
                    status=status,
                    duration=duration,
                    message=message,
                )
            )

    return TestRun(suite_name=suite_name, cases=cases, source=str(path))


# ---------------------------------------------------------------------------
# JSON parsing
# ---------------------------------------------------------------------------


def parse_json(path: Path) -> TestRun:
    """Parse a JSON test-results file.

    Expected shape:
      { "suite": "name", "tests": [
          {"name": str, "classname": str, "status": str,
           "duration": number, "message": str?}
      ] }
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"JSON file not found: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse JSON {path}: {exc}") from exc

    if "tests" not in data:
        raise ValueError(f"JSON file {path} missing 'tests' list")

    cases: list[TestCase] = []
    for entry in data["tests"]:
        status = entry.get("status", "passed")
        cases.append(
            TestCase(
                name=entry.get("name", "<unnamed>"),
                classname=entry.get("classname", ""),
                status=status,
                duration=float(entry.get("duration", 0) or 0),
                message=entry.get("message"),
            )
        )
    return TestRun(
        suite_name=data.get("suite", path.stem),
        cases=cases,
        source=str(path),
    )


# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------


def parse_file(path: Path) -> TestRun:
    """Dispatch to the right parser based on extension."""
    path = Path(path)
    ext = path.suffix.lower()
    if ext == ".xml":
        return parse_junit_xml(path)
    if ext == ".json":
        return parse_json(path)
    raise ValueError(f"Unsupported file extension {ext!r} for {path}")


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------


def aggregate(runs: Sequence[TestRun]) -> Aggregate:
    total = passed = failed = skipped = 0
    duration = 0.0
    for r in runs:
        for c in r.cases:
            total += 1
            duration += c.duration
            if c.status == "passed":
                passed += 1
            elif c.status == "failed":
                failed += 1
            elif c.status == "skipped":
                skipped += 1
    return Aggregate(
        runs=list(runs),
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
    )


def find_flaky(runs: Sequence[TestRun]) -> list[FlakyEntry]:
    """Return tests that both passed and failed across the given runs."""
    counts: dict[tuple[str, str], dict[str, int]] = {}
    for r in runs:
        for c in r.cases:
            key = (c.classname, c.name)
            counts.setdefault(key, {"passed": 0, "failed": 0, "skipped": 0})
            counts[key][c.status] += 1

    flaky: list[FlakyEntry] = []
    for (classname, name), tally in counts.items():
        if tally["passed"] > 0 and tally["failed"] > 0:
            flaky.append(
                FlakyEntry(
                    name=name,
                    classname=classname,
                    passed_count=tally["passed"],
                    failed_count=tally["failed"],
                )
            )
    flaky.sort(key=lambda e: (e.classname, e.name))
    return flaky


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------


def _status_icon(status: str) -> str:
    return {"passed": "PASS", "failed": "FAIL", "skipped": "SKIP"}.get(status, status)


def generate_markdown(agg: Aggregate, flaky: list[FlakyEntry]) -> str:
    lines: list[str] = []
    lines.append("# Test Results Summary")
    lines.append("")
    lines.append("## Totals")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("| --- | --- |")
    lines.append(f"| Total | {agg.total} |")
    lines.append(f"| Passed | {agg.passed} |")
    lines.append(f"| Failed | {agg.failed} |")
    lines.append(f"| Skipped | {agg.skipped} |")
    lines.append(f"| Duration (s) | {agg.duration:.2f} |")
    lines.append("")

    lines.append("## Runs")
    lines.append("")
    lines.append("| Suite | Source | Passed | Failed | Skipped | Duration (s) |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    for r in agg.runs:
        p = sum(1 for c in r.cases if c.status == "passed")
        f = sum(1 for c in r.cases if c.status == "failed")
        s = sum(1 for c in r.cases if c.status == "skipped")
        d = sum(c.duration for c in r.cases)
        source = Path(r.source).name if r.source else ""
        lines.append(f"| {r.suite_name} | {source} | {p} | {f} | {s} | {d:.2f} |")
    lines.append("")

    # Failures detail
    failures = [
        (r, c) for r in agg.runs for c in r.cases if c.status == "failed"
    ]
    if failures:
        lines.append("## Failures")
        lines.append("")
        for r, c in failures:
            msg = c.message or "(no message)"
            lines.append(f"- **{c.classname}::{c.name}** ({r.suite_name}) — {msg}")
        lines.append("")

    # Flaky
    lines.append("## Flaky Tests")
    lines.append("")
    if flaky:
        lines.append("| Test | Passed | Failed |")
        lines.append("| --- | --- | --- |")
        for entry in flaky:
            lines.append(
                f"| {entry.classname}::{entry.name} | {entry.passed_count} | {entry.failed_count} |"
            )
    else:
        lines.append("_No flaky tests detected._")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _discover(directory: Path) -> list[Path]:
    """Return sorted list of .xml and .json files directly in `directory`
    and its subdirectories."""
    patterns = ("*.xml", "*.json")
    found: list[Path] = []
    for pat in patterns:
        found.extend(sorted(directory.rglob(pat)))
    return sorted(found)


def run_cli(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate JUnit XML / JSON test results into a Markdown summary.",
    )
    parser.add_argument("input_dir", help="Directory containing result files (.xml/.json)")
    parser.add_argument("--output", "-o", help="Write the Markdown report to this file")
    parser.add_argument(
        "--fail-on-failures",
        action="store_true",
        help="Exit with code 1 if any test failed",
    )
    args = parser.parse_args(argv)

    input_dir = Path(args.input_dir)
    if not input_dir.exists() or not input_dir.is_dir():
        print(f"error: input directory does not exist: {input_dir}", file=sys.stderr)
        return 2

    files = _discover(input_dir)
    if not files:
        print(f"warning: no result files found in {input_dir}", file=sys.stderr)

    runs: list[TestRun] = []
    for f in files:
        try:
            runs.append(parse_file(f))
        except (ValueError, FileNotFoundError) as exc:
            print(f"error parsing {f}: {exc}", file=sys.stderr)
            return 3

    agg = aggregate(runs)
    flaky = find_flaky(runs)
    md = generate_markdown(agg, flaky)

    # Print to stdout (visible in act logs).
    print(md)

    # Optional explicit output file
    if args.output:
        Path(args.output).write_text(md)

    # Also write to $GITHUB_STEP_SUMMARY when present.
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a") as fh:
            fh.write(md)
            fh.write("\n")

    if args.fail_on_failures and agg.failed > 0:
        return 1
    return 0


def main() -> int:  # pragma: no cover - thin wrapper
    return run_cli(sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
