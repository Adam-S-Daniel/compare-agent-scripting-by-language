"""Test results aggregator.

Parses JUnit XML and JSON test reports, aggregates totals across multiple
files (e.g. a CI matrix build), detects flaky tests (tests that pass in some
runs and fail in others), and renders a markdown summary suitable for use as
a GitHub Actions job summary (`$GITHUB_STEP_SUMMARY`).
"""
from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

VALID_STATUSES = {"passed", "failed", "skipped"}


@dataclass(frozen=True)
class TestCase:
    name: str
    status: str  # "passed" | "failed" | "skipped"
    duration: float  # seconds


@dataclass
class TestRun:
    source: str
    cases: list[TestCase] = field(default_factory=list)


@dataclass
class Summary:
    total: int
    passed: int
    failed: int
    skipped: int
    duration: float
    runs: int


@dataclass
class FlakyTest:
    name: str
    pass_count: int
    fail_count: int


# ---- Parsing --------------------------------------------------------------

def parse_json(path: Path) -> TestRun:
    """Parse a simple JSON test-results file: {"tests": [{name, status, duration}, ...]}."""
    path = Path(path)
    text = path.read_text()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e

    tests = data.get("tests", []) if isinstance(data, dict) else []
    cases: list[TestCase] = []
    for t in tests:
        status = str(t.get("status", "")).lower()
        if status not in VALID_STATUSES:
            # Tolerate unknown statuses by mapping to "failed" so they're surfaced.
            status = "failed"
        cases.append(TestCase(
            name=str(t["name"]),
            status=status,
            duration=float(t.get("duration", 0.0) or 0.0),
        ))
    return TestRun(source=str(path), cases=cases)


def parse_junit_xml(path: Path) -> TestRun:
    """Parse a JUnit-style XML file. Supports either <testsuites> root or a single <testsuite>."""
    path = Path(path)
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        raise ValueError(f"Invalid XML in {path}: {e}") from e

    root = tree.getroot()
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))

    cases: list[TestCase] = []
    for suite in suites:
        for tc in suite.findall("testcase"):
            classname = tc.get("classname", "")
            name = tc.get("name", "")
            full = f"{classname}.{name}" if classname else name
            duration = float(tc.get("time", 0.0) or 0.0)
            if tc.find("failure") is not None or tc.find("error") is not None:
                status = "failed"
            elif tc.find("skipped") is not None:
                status = "skipped"
            else:
                status = "passed"
            cases.append(TestCase(name=full, status=status, duration=duration))
    return TestRun(source=str(path), cases=cases)


def parse_file(path: Path) -> TestRun:
    """Dispatch to the right parser based on file extension."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Test results file not found: {path}")
    suffix = path.suffix.lower()
    if suffix == ".json":
        return parse_json(path)
    if suffix == ".xml":
        return parse_junit_xml(path)
    raise ValueError(f"Unsupported file format: {suffix} (expected .json or .xml)")


# ---- Aggregation & flaky detection ---------------------------------------

def aggregate(runs: Iterable[TestRun]) -> Summary:
    runs = list(runs)
    passed = failed = skipped = 0
    duration = 0.0
    for r in runs:
        for c in r.cases:
            duration += c.duration
            if c.status == "passed":
                passed += 1
            elif c.status == "failed":
                failed += 1
            elif c.status == "skipped":
                skipped += 1
    return Summary(
        total=passed + failed + skipped,
        passed=passed,
        failed=failed,
        skipped=skipped,
        duration=duration,
        runs=len(runs),
    )


def find_flaky(runs: Iterable[TestRun]) -> list[FlakyTest]:
    """A test is flaky if it has BOTH a 'passed' and a 'failed' result across runs.
    Skipped results are ignored for flakiness detection."""
    counts: dict[str, dict[str, int]] = {}
    for r in runs:
        for c in r.cases:
            if c.status not in ("passed", "failed"):
                continue
            counts.setdefault(c.name, {"passed": 0, "failed": 0})[c.status] += 1
    flaky = [
        FlakyTest(name=name, pass_count=v["passed"], fail_count=v["failed"])
        for name, v in counts.items()
        if v["passed"] > 0 and v["failed"] > 0
    ]
    flaky.sort(key=lambda f: f.name)
    return flaky


# ---- Markdown rendering ---------------------------------------------------

def render_markdown(runs: Iterable[TestRun]) -> str:
    runs = list(runs)
    s = aggregate(runs)
    flaky = find_flaky(runs)

    pass_rate = (s.passed / s.total * 100) if s.total else 0.0
    overall = "PASSED" if s.failed == 0 and s.total > 0 else ("FAILED" if s.failed else "NO TESTS")

    lines: list[str] = []
    lines.append("# Test Results Summary")
    lines.append("")
    lines.append(f"**Status:** {overall}  ")
    lines.append(f"**Runs aggregated:** {s.runs}  ")
    lines.append(f"**Pass rate:** {pass_rate:.1f}%")
    lines.append("")
    lines.append("## Totals")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("| --- | ---: |")
    lines.append(f"| Total | {s.total} |")
    lines.append(f"| Passed | {s.passed} |")
    lines.append(f"| Failed | {s.failed} |")
    lines.append(f"| Skipped | {s.skipped} |")
    lines.append(f"| Duration (s) | {s.duration:.3f} |")
    lines.append("")
    lines.append("## Flaky Tests")
    lines.append("")
    if not flaky:
        lines.append("No flaky tests detected.")
    else:
        lines.append("| Test | Passed | Failed |")
        lines.append("| --- | ---: | ---: |")
        for f in flaky:
            lines.append(f"| `{f.name}` | {f.pass_count} | {f.fail_count} |")
    lines.append("")
    lines.append("## Sources")
    lines.append("")
    for r in runs:
        lines.append(f"- `{r.source}` ({len(r.cases)} cases)")
    lines.append("")
    return "\n".join(lines)
