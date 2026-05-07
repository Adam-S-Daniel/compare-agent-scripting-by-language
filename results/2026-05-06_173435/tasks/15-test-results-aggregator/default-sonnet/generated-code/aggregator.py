"""
Test Results Aggregator: parse JUnit XML and JSON test results from a matrix build,
compute totals, detect flaky tests, and generate a GitHub Actions markdown summary.

Usage:
    python aggregator.py <fixtures_dir>
    python aggregator.py fixtures/          # default

Output: markdown written to stdout (pipe to $GITHUB_STEP_SUMMARY or a file).
"""
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class TestResult:
    name: str
    classname: str
    status: str         # "passed" | "failed" | "skipped" | "error"
    duration: float
    message: Optional[str] = None
    file_source: str = ""

    @property
    def full_name(self) -> str:
        return f"{self.classname}.{self.name}"


def parse_junit_xml(filepath: Path) -> list[TestResult]:
    """Parse a JUnit XML file and return a flat list of TestResult objects."""
    filepath = Path(filepath)
    if not filepath.exists():
        raise FileNotFoundError(f"JUnit XML file not found: {filepath}")

    try:
        tree = ET.parse(filepath)
    except ET.ParseError as exc:
        raise ValueError(f"Invalid XML in {filepath}: {exc}") from exc

    root = tree.getroot()
    # Support both <testsuites><testsuite> and bare <testsuite> roots.
    if root.tag == "testsuites":
        suites = root.findall("testsuite")
    elif root.tag == "testsuite":
        suites = [root]
    else:
        raise ValueError(f"Unexpected root element '{root.tag}' in {filepath}")

    results: list[TestResult] = []
    for suite in suites:
        for tc in suite.findall("testcase"):
            name = tc.get("name", "")
            classname = tc.get("classname", "")
            duration = float(tc.get("time", "0") or "0")

            failure = tc.find("failure")
            error = tc.find("error")
            skipped = tc.find("skipped")

            if failure is not None:
                status = "failed"
                message = failure.get("message") or failure.text or ""
            elif error is not None:
                status = "error"
                message = error.get("message") or error.text or ""
            elif skipped is not None:
                status = "skipped"
                message = skipped.get("message") or skipped.text or ""
            else:
                status = "passed"
                message = None

            results.append(TestResult(
                name=name,
                classname=classname,
                status=status,
                duration=duration,
                message=message,
                file_source=filepath.name,
            ))

    return results


def parse_json_results(filepath: Path) -> list[TestResult]:
    """Parse a JSON test results file and return a list of TestResult objects.

    Expected schema:
        {"tests": [{"name": str, "classname": str, "status": str, "duration": float}, ...]}
    """
    filepath = Path(filepath)
    if not filepath.exists():
        raise FileNotFoundError(f"JSON results file not found: {filepath}")

    try:
        data = json.loads(filepath.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {filepath}: {exc}") from exc

    if "tests" not in data:
        raise ValueError(f"Missing 'tests' key in {filepath}")

    results: list[TestResult] = []
    for entry in data["tests"]:
        status = entry.get("status", "unknown")
        # Normalise alternate spellings
        if status == "skip":
            status = "skipped"
        results.append(TestResult(
            name=entry["name"],
            classname=entry.get("classname", ""),
            status=status,
            duration=float(entry.get("duration", 0)),
            message=entry.get("message"),
            file_source=filepath.name,
        ))

    return results


def aggregate_results(runs: list[list[TestResult]]) -> dict:
    """Sum totals across all runs from a matrix build."""
    total = passed = failed = skipped = 0
    duration = 0.0

    for run in runs:
        for r in run:
            total += 1
            if r.status == "passed":
                passed += 1
            elif r.status in ("failed", "error"):
                failed += 1
            elif r.status == "skipped":
                skipped += 1
            duration += r.duration

    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "duration": duration,
    }


def detect_flaky_tests(runs: list[list[TestResult]]) -> list[dict]:
    """Return tests that passed in some runs and failed in others.

    A test is flaky if it appears in more than one run and its outcome
    is not consistent (at least one pass and at least one fail/error).
    """
    # Accumulate per-test outcome counts across runs.
    pass_count: dict[str, int] = defaultdict(int)
    fail_count: dict[str, int] = defaultdict(int)
    # Track which run indices each test appeared in (to require >1 run).
    run_indices: dict[str, set] = defaultdict(set)

    for run_idx, run in enumerate(runs):
        for r in run:
            key = r.full_name
            run_indices[key].add(run_idx)
            if r.status == "passed":
                pass_count[key] += 1
            elif r.status in ("failed", "error"):
                fail_count[key] += 1

    flaky = []
    for name in sorted(pass_count.keys() | fail_count.keys()):
        # Must appear in multiple runs AND have both passes and failures.
        if len(run_indices[name]) > 1 and pass_count[name] > 0 and fail_count[name] > 0:
            flaky.append({
                "name": name,
                "passed": pass_count[name],
                "failed": fail_count[name],
            })

    return flaky


def generate_markdown(aggregated: dict, flaky: list[dict]) -> str:
    """Generate a GitHub Actions job summary in markdown format."""
    lines: list[str] = []

    lines.append("## Test Results Summary")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Total Tests | {aggregated['total']} |")
    lines.append(f"| Passed | {aggregated['passed']} |")
    lines.append(f"| Failed | {aggregated['failed']} |")
    lines.append(f"| Skipped | {aggregated['skipped']} |")
    lines.append(f"| Duration | {aggregated['duration']:.2f}s |")
    lines.append("")

    if flaky:
        lines.append(f"## Flaky Tests ({len(flaky)} detected)")
        lines.append("")
        lines.append("| Test Name | Passed Runs | Failed Runs |")
        lines.append("|-----------|-------------|-------------|")
        for f in flaky:
            lines.append(f"| {f['name']} | {f['passed']} | {f['failed']} |")
    else:
        lines.append("## Flaky Tests")
        lines.append("")
        lines.append("No flaky tests detected.")

    lines.append("")
    return "\n".join(lines)


def load_results_from_dir(fixtures_dir: Path) -> list[list[TestResult]]:
    """Load all JUnit XML and JSON files from a directory."""
    fixtures_dir = Path(fixtures_dir)
    if not fixtures_dir.is_dir():
        raise FileNotFoundError(f"Fixtures directory not found: {fixtures_dir}")

    runs: list[list[TestResult]] = []
    xml_files = sorted(fixtures_dir.glob("*.xml"))
    json_files = sorted(fixtures_dir.glob("*.json"))

    if not xml_files and not json_files:
        print(f"Warning: no .xml or .json files found in {fixtures_dir}", file=sys.stderr)

    for f in xml_files:
        runs.append(parse_junit_xml(f))

    for f in json_files:
        runs.append(parse_json_results(f))

    return runs


def main(fixtures_dir: str = "fixtures") -> None:
    runs = load_results_from_dir(Path(fixtures_dir))
    aggregated = aggregate_results(runs)
    flaky = detect_flaky_tests(runs)
    md = generate_markdown(aggregated, flaky)
    print(md)


if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else "fixtures"
    main(directory)
