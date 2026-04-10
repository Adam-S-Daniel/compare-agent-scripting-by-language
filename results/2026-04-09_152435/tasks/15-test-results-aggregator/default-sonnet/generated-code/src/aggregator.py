"""
Test Results Aggregator

Parses JUnit XML and JSON test result files, aggregates results across multiple
runs (simulating a matrix build), identifies flaky tests, and generates a
markdown summary for GitHub Actions job summaries.

TDD history:
  - Tests in tests/test_aggregator.py were written first (failing).
  - This implementation was written to make them pass.
  - Each function covers the minimal contract the tests require.
"""

import json
import os
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class TestResult:
    """A single test case execution result."""
    name: str
    classname: str
    status: str   # 'passed' | 'failed' | 'skipped' | 'error'
    duration: float
    message: str = ""


@dataclass
class RunResult:
    """All test results from one run (one file, one matrix leg)."""
    run_id: str
    suite_name: str
    tests: list   # list[TestResult]


@dataclass
class AggregatedResult:
    """Aggregated statistics across all runs."""
    total: int
    passed: int
    failed: int
    skipped: int
    errors: int
    total_duration: float


@dataclass
class FlakyTest:
    """A test that passed in some runs and failed in others."""
    name: str
    passed_runs: list   # list[str] of run_ids where this test passed
    failed_runs: list   # list[str] of run_ids where this test failed


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_junit_xml(file_path) -> RunResult:
    """
    Parse a JUnit XML test results file.

    Expected format:
        <testsuite name="Suite" tests="3" failures="1" skipped="0" time="1.0">
          <testcase name="test_x" classname="Cls" time="0.5"/>
          <testcase name="test_y" classname="Cls" time="0.3">
            <failure message="...">traceback</failure>
          </testcase>
          <testcase name="test_z" classname="Cls" time="0.0">
            <skipped/>
          </testcase>
        </testsuite>

    Handles both <testsuite> as root and <testsuites> wrapping a <testsuite>.
    """
    file_path = Path(file_path)
    if not file_path.exists():
        raise FileNotFoundError(f"JUnit XML file not found: {file_path}")

    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
    except ET.ParseError as exc:
        raise ValueError(f"Invalid XML in {file_path}: {exc}") from exc

    # Normalise: accept both <testsuites><testsuite>... and bare <testsuite>
    if root.tag == 'testsuites':
        suite = root.find('testsuite')
        if suite is None:
            raise ValueError(f"No <testsuite> element found in {file_path}")
    else:
        suite = root

    suite_name = suite.get('name', 'Unknown')
    run_id = file_path.stem          # e.g. "junit_run1" from "junit_run1.xml"

    tests = []
    for tc in suite.findall('testcase'):
        name = tc.get('name', 'unknown')
        classname = tc.get('classname', '')
        duration = float(tc.get('time', '0') or '0')

        if tc.find('failure') is not None:
            status = 'failed'
            el = tc.find('failure')
            message = el.get('message', '') if el is not None else ''
        elif tc.find('error') is not None:
            status = 'error'
            el = tc.find('error')
            message = el.get('message', '') if el is not None else ''
        elif tc.find('skipped') is not None:
            status = 'skipped'
            message = ''
        else:
            status = 'passed'
            message = ''

        tests.append(TestResult(
            name=name,
            classname=classname,
            status=status,
            duration=duration,
            message=message,
        ))

    return RunResult(run_id=run_id, suite_name=suite_name, tests=tests)


def parse_json_results(file_path) -> RunResult:
    """
    Parse a JSON test results file.

    Expected format:
        {
          "suite": "SuiteName",
          "tests": [
            {"name": "test_x", "status": "passed", "duration": 0.5},
            {"name": "test_y", "status": "failed", "duration": 0.3, "message": "..."},
            {"name": "test_z", "status": "skipped", "duration": 0.0}
          ]
        }
    """
    file_path = Path(file_path)
    if not file_path.exists():
        raise FileNotFoundError(f"JSON results file not found: {file_path}")

    try:
        with open(file_path, encoding='utf-8') as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {file_path}: {exc}") from exc

    if 'tests' not in data:
        raise ValueError(f"Missing required 'tests' key in {file_path}")

    valid_statuses = {'passed', 'failed', 'skipped', 'error'}
    suite_name = data.get('suite', 'Unknown')
    run_id = file_path.stem

    tests = []
    for item in data['tests']:
        name = item.get('name', 'unknown')
        status = item.get('status', 'unknown')
        if status not in valid_statuses:
            raise ValueError(
                f"Unknown status '{status}' for test '{name}' in {file_path}. "
                f"Valid values: {sorted(valid_statuses)}"
            )
        tests.append(TestResult(
            name=name,
            classname=item.get('classname', ''),
            status=status,
            duration=float(item.get('duration', 0)),
            message=item.get('message', ''),
        ))

    return RunResult(run_id=run_id, suite_name=suite_name, tests=tests)


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def aggregate_results(runs: list) -> AggregatedResult:
    """
    Sum up counts and duration across all runs.

    Each run is a RunResult; each test inside counts once toward the totals.
    """
    total = passed = failed = skipped = errors = 0
    total_duration = 0.0

    for run in runs:
        for test in run.tests:
            total += 1
            total_duration += test.duration
            if test.status == 'passed':
                passed += 1
            elif test.status == 'failed':
                failed += 1
            elif test.status == 'skipped':
                skipped += 1
            elif test.status == 'error':
                errors += 1

    return AggregatedResult(
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        errors=errors,
        total_duration=round(total_duration, 2),
    )


# ---------------------------------------------------------------------------
# Flaky test detection
# ---------------------------------------------------------------------------

def find_flaky_tests(runs: list) -> list:
    """
    Find tests that passed in at least one run AND failed in at least one other.

    Skipped / error results are ignored for flakiness purposes.
    Returns a list of FlakyTest sorted alphabetically by name.
    """
    # Map: test_name -> {run_id: status}
    outcomes: dict = {}
    for run in runs:
        for test in run.tests:
            if test.status in ('passed', 'failed'):
                outcomes.setdefault(test.name, {})[run.run_id] = test.status

    flaky = []
    for name, by_run in outcomes.items():
        statuses = set(by_run.values())
        if 'passed' in statuses and 'failed' in statuses:
            flaky.append(FlakyTest(
                name=name,
                passed_runs=sorted(rid for rid, s in by_run.items() if s == 'passed'),
                failed_runs=sorted(rid for rid, s in by_run.items() if s == 'failed'),
            ))

    return sorted(flaky, key=lambda f: f.name)


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def generate_markdown_summary(aggregated: AggregatedResult, flaky: list) -> str:
    """
    Produce a GitHub-flavoured markdown summary suitable for GITHUB_STEP_SUMMARY.
    """
    lines = [
        '## Test Results Summary',
        '',
        '| Metric | Value |',
        '|--------|-------|',
        f'| Total Tests | {aggregated.total} |',
        f'| Passed | {aggregated.passed} |',
        f'| Failed | {aggregated.failed} |',
        f'| Skipped | {aggregated.skipped} |',
        f'| Errors | {aggregated.errors} |',
        f'| Total Duration | {aggregated.total_duration:.2f}s |',
        '',
    ]

    if flaky:
        lines += [
            '### Flaky Tests',
            '',
            '> Tests that passed in some runs and failed in others.',
            '',
            '| Test Name | Passed In | Failed In |',
            '|-----------|-----------|-----------|',
        ]
        for f in flaky:
            lines.append(
                f'| {f.name} | {", ".join(f.passed_runs)} | {", ".join(f.failed_runs)} |'
            )
        lines.append('')
    else:
        lines += [
            '### Flaky Tests',
            '',
            '_No flaky tests detected._',
            '',
        ]

    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(fixtures_dir: str = 'fixtures') -> None:
    """
    Process all test result files in fixtures_dir, print machine-readable
    output for CI assertions, and write markdown to GITHUB_STEP_SUMMARY.
    """
    fixtures_path = Path(fixtures_dir)
    if not fixtures_path.exists():
        print(f"ERROR: Fixtures directory not found: {fixtures_dir}", file=sys.stderr)
        raise SystemExit(1)

    runs = []
    parse_errors = []

    # Parse JUnit XML files (sorted for deterministic order)
    for xml_file in sorted(fixtures_path.glob('*.xml')):
        try:
            run = parse_junit_xml(xml_file)
            runs.append(run)
            print(f"Parsed JUnit XML : {xml_file.name} ({len(run.tests)} tests)")
        except Exception as exc:
            parse_errors.append(f"ERROR parsing {xml_file.name}: {exc}")

    # Parse JSON files (sorted for deterministic order)
    for json_file in sorted(fixtures_path.glob('*.json')):
        try:
            run = parse_json_results(json_file)
            runs.append(run)
            print(f"Parsed JSON      : {json_file.name} ({len(run.tests)} tests)")
        except Exception as exc:
            parse_errors.append(f"ERROR parsing {json_file.name}: {exc}")

    for err in parse_errors:
        print(err, file=sys.stderr)

    if not runs:
        print("ERROR: No test result files found in: " + fixtures_dir, file=sys.stderr)
        raise SystemExit(1)

    aggregated = aggregate_results(runs)
    flaky = find_flaky_tests(runs)

    # Machine-readable output (used by CI harness for assertions)
    print(
        f"AGGREGATE_RESULTS: total={aggregated.total} passed={aggregated.passed} "
        f"failed={aggregated.failed} skipped={aggregated.skipped} "
        f"duration={aggregated.total_duration:.2f}"
    )

    if flaky:
        print("FLAKY_TESTS: " + ",".join(f.name for f in flaky))
    else:
        print("FLAKY_TESTS: none")

    # Human-readable markdown summary
    md = generate_markdown_summary(aggregated, flaky)
    print("\nMarkdown Summary:")
    print(md)

    # Write to GitHub Actions job summary when running in CI
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY', '')
    if summary_path:
        try:
            with open(summary_path, 'a', encoding='utf-8') as fh:
                fh.write(md)
                fh.write('\n')
            print(f"Job summary written to: {summary_path}")
        except OSError as exc:
            print(f"WARNING: Could not write to GITHUB_STEP_SUMMARY: {exc}", file=sys.stderr)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'fixtures')
