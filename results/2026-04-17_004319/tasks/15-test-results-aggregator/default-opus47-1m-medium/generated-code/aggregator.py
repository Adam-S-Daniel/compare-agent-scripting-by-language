"""
Test results aggregator.

Parses multiple test-report files (JUnit XML and JSON), aggregates totals
across runs (simulating a matrix build), identifies flaky tests, and renders
a markdown summary suitable for `$GITHUB_STEP_SUMMARY`.

Usage:
    python3 aggregator.py <file-or-dir> [<file-or-dir> ...]

Each positional argument represents ONE run (either a single report file or a
directory of report files). Multiple runs are compared against each other to
detect flaky tests.
"""
from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
import xml.etree.ElementTree as ET


VALID_STATUSES = {"passed", "failed", "skipped"}


@dataclass(frozen=True)
class TestCaseResult:
    name: str
    status: str  # passed | failed | skipped
    duration: float


def parse_junit_xml(path: Path) -> list[TestCaseResult]:
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"JUnit XML not found: {path}")
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        raise ValueError(f"Invalid JUnit XML in {path}: {e}") from e

    root = tree.getroot()
    # Root may be <testsuites> or a single <testsuite>
    suites = [root] if root.tag == "testsuite" else root.findall("testsuite")

    results: list[TestCaseResult] = []
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
            results.append(TestCaseResult(full, status, duration))
    return results


def parse_json_report(path: Path) -> list[TestCaseResult]:
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"JSON report not found: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e

    tests = data.get("tests", [])
    results: list[TestCaseResult] = []
    for t in tests:
        status = t.get("status")
        if status not in VALID_STATUSES:
            raise ValueError(f"Unknown status '{status}' in {path}")
        results.append(TestCaseResult(t["name"], status, float(t.get("duration", 0))))
    return results


def parse_file(path: Path) -> list[TestCaseResult]:
    path = Path(path)
    suffix = path.suffix.lower()
    if suffix == ".xml":
        return parse_junit_xml(path)
    if suffix == ".json":
        return parse_json_report(path)
    raise ValueError(f"Unsupported file type: {path.suffix} (expected .xml or .json)")


def _collect_run(entry: Path) -> list[TestCaseResult]:
    """Collect results from a single run, which is either a file or directory."""
    entry = Path(entry)
    if entry.is_file():
        return parse_file(entry)
    if entry.is_dir():
        out: list[TestCaseResult] = []
        for p in sorted(entry.iterdir()):
            if p.suffix.lower() in (".xml", ".json"):
                out.extend(parse_file(p))
        return out
    raise FileNotFoundError(f"Path not found: {entry}")


def aggregate(runs: Iterable[list[TestCaseResult]]) -> dict:
    runs = list(runs)
    total = passed = failed = skipped = 0
    duration = 0.0
    for run in runs:
        for r in run:
            total += 1
            duration += r.duration
            if r.status == "passed":
                passed += 1
            elif r.status == "failed":
                failed += 1
            elif r.status == "skipped":
                skipped += 1
    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "duration": duration,
        "runs": len(runs),
    }


def identify_flaky(runs: Iterable[list[TestCaseResult]]) -> list[str]:
    """A test is flaky if it PASSED in some run and FAILED in another."""
    statuses: dict[str, set[str]] = {}
    for run in runs:
        for r in run:
            statuses.setdefault(r.name, set()).add(r.status)
    flaky = [name for name, s in statuses.items() if "passed" in s and "failed" in s]
    return sorted(flaky)


def render_markdown(runs: list[list[TestCaseResult]]) -> str:
    agg = aggregate(runs)
    flaky = identify_flaky(runs)

    lines: list[str] = []
    lines.append("# Test Results Summary")
    lines.append("")
    lines.append(f"- Runs: {agg['runs']}")
    lines.append(f"- Total: {agg['total']}")
    lines.append(f"- Passed: {agg['passed']}")
    lines.append(f"- Failed: {agg['failed']}")
    lines.append(f"- Skipped: {agg['skipped']}")
    lines.append(f"- Duration: {agg['duration']:.2f}s")
    lines.append("")
    if flaky:
        lines.append("## Flaky Tests")
        lines.append("")
        for name in flaky:
            lines.append(f"- {name}")
    else:
        lines.append("## Flaky Tests")
        lines.append("")
        lines.append("No flaky tests detected.")
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: aggregator.py <run-path> [<run-path> ...]", file=sys.stderr)
        return 2
    try:
        runs = [_collect_run(Path(a)) for a in argv[1:]]
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    md = render_markdown(runs)
    print(md)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
