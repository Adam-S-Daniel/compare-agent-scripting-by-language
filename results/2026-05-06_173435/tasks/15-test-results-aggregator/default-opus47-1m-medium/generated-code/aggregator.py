#!/usr/bin/env python3
"""Aggregate test results from JUnit XML and JSON files into a markdown summary.

Designed to be invoked from a GitHub Actions matrix build where each job writes
its results to a shared directory; this script then crunches them into a single
job summary, calling out flaky tests (passed in some runs, failed in others).

Usage:
    aggregator.py <results_dir> [--summary-out FILE]

Exit code is 0 when no tests failed, 1 otherwise — this lets the workflow surface
red builds even when the aggregator step itself ran cleanly.
"""
from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


# A single test execution. ``run_id`` identifies which file/matrix-shard this came
# from so we can detect flakes (same name with different statuses across runs).
@dataclass
class TestCase:
    # Tell pytest not to try to collect this as a test class
    __test__ = False
    name: str
    status: str  # "passed" | "failed" | "skipped"
    duration: float
    run_id: str


@dataclass
class AggregateResult:
    passed: int
    failed: int
    skipped: int
    duration: float
    flaky: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)

    @property
    def total(self) -> int:
        return self.passed + self.failed + self.skipped


def parse_junit_xml(path: Path) -> list[TestCase]:
    """Parse a JUnit XML file. Accepts both <testsuite> and <testsuites> roots."""
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        raise ValueError(f"Invalid JUnit XML in {path}: {e}") from e

    root = tree.getroot()
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
    run_id = path.stem

    cases: list[TestCase] = []
    for suite in suites:
        for tc in suite.findall("testcase"):
            classname = tc.get("classname", "")
            name = tc.get("name", "")
            full = f"{classname}.{name}" if classname else name
            duration = float(tc.get("time", "0") or 0)
            if tc.find("failure") is not None or tc.find("error") is not None:
                status = "failed"
            elif tc.find("skipped") is not None:
                status = "skipped"
            else:
                status = "passed"
            cases.append(TestCase(full, status, duration, run_id))
    return cases


def parse_json(path: Path) -> list[TestCase]:
    """Parse a simple JSON test report: ``{"tests": [{"name","status","duration"}]}``."""
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e

    if not isinstance(data, dict) or "tests" not in data:
        raise ValueError(f"JSON file {path} missing 'tests' array")

    run_id = path.stem
    cases = []
    for t in data["tests"]:
        cases.append(TestCase(
            name=t["name"],
            status=t["status"],
            duration=float(t.get("duration", 0)),
            run_id=run_id,
        ))
    return cases


def parse_file(path: Path) -> list[TestCase]:
    """Dispatch to the right parser based on file extension."""
    ext = path.suffix.lower()
    if ext == ".xml":
        return parse_junit_xml(path)
    if ext == ".json":
        return parse_json(path)
    raise ValueError(f"Unsupported file extension {ext!r} for {path}")


def load_results(paths: Iterable[Path]) -> list[TestCase]:
    """Load and concatenate test cases from many result files."""
    out: list[TestCase] = []
    for p in paths:
        out.extend(parse_file(Path(p)))
    return out


def find_flaky_tests(cases: list[TestCase]) -> list[str]:
    """A test is flaky if it has both a 'passed' and 'failed' run.

    Skipped runs don't count toward flakiness — a test skipped on one platform
    and passed on another is intentional, not flaky.
    """
    by_name: dict[str, set[str]] = {}
    for c in cases:
        by_name.setdefault(c.name, set()).add(c.status)
    return sorted(name for name, statuses in by_name.items()
                  if "passed" in statuses and "failed" in statuses)


def aggregate(cases: list[TestCase]) -> AggregateResult:
    """Compute totals + flaky list + sorted failure list."""
    passed = sum(1 for c in cases if c.status == "passed")
    failed = sum(1 for c in cases if c.status == "failed")
    skipped = sum(1 for c in cases if c.status == "skipped")
    duration = sum(c.duration for c in cases)
    flaky = find_flaky_tests(cases)
    # Failures = tests that failed in *every* run they appeared in (i.e. not flaky).
    failed_names = sorted({c.name for c in cases if c.status == "failed"})
    failures = [n for n in failed_names if n not in set(flaky)]
    return AggregateResult(passed, failed, skipped, duration, flaky, failures)


def render_markdown(agg: AggregateResult) -> str:
    """Render a markdown summary suitable for $GITHUB_STEP_SUMMARY."""
    icon = "✅" if agg.failed == 0 else "❌"
    lines = [
        f"# Test Results {icon}",
        "",
        "| Metric | Count |",
        "|---|---|",
        f"| Passed | {agg.passed} |",
        f"| Failed | {agg.failed} |",
        f"| Skipped | {agg.skipped} |",
        f"| Total | {agg.total} |",
        f"| Duration (s) | {agg.duration:.2f} |",
        "",
    ]
    if agg.failures:
        lines.append("## Failures")
        lines.extend(f"- `{n}`" for n in agg.failures)
        lines.append("")
    if agg.flaky:
        lines.append("## Flaky tests ⚠️")
        lines.append("These tests passed in some runs and failed in others.")
        lines.extend(f"- `{n}`" for n in agg.flaky)
        lines.append("")
    if not agg.failures and not agg.flaky:
        lines.append("All tests passed cleanly across runs.")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("results_dir", type=Path,
                   help="Directory containing .xml / .json test result files")
    p.add_argument("--summary-out", type=Path, default=None,
                   help="Where to write the markdown summary (default: stdout)")
    args = p.parse_args(argv)

    if not args.results_dir.is_dir():
        print(f"ERROR: results dir not found: {args.results_dir}", file=sys.stderr)
        return 2

    files = sorted(
        list(args.results_dir.glob("*.xml")) + list(args.results_dir.glob("*.json"))
    )
    if not files:
        print(f"ERROR: no .xml or .json files in {args.results_dir}", file=sys.stderr)
        return 2

    try:
        cases = load_results(files)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    agg = aggregate(cases)
    md = render_markdown(agg)

    if args.summary_out:
        args.summary_out.write_text(md + "\n")
    else:
        print(md)

    # Also emit a one-line stats summary on stderr for CI logs
    print(
        f"STATS passed={agg.passed} failed={agg.failed} skipped={agg.skipped} "
        f"flaky={len(agg.flaky)} duration={agg.duration:.2f}",
        file=sys.stderr,
    )
    return 0 if agg.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
