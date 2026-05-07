"""Test suite for the test results aggregator.

Built with red/green TDD: each test was written failing first, then the
minimum code in aggregator.py was added to turn it green.
"""

import json
import textwrap
from pathlib import Path

import pytest

from aggregator import (
    TestCase,
    TestResults,
    aggregate,
    find_flaky,
    parse_file,
    parse_json,
    parse_junit_xml,
    render_markdown,
    run,
)


# ---------------------------------------------------------------------------
# JUnit XML parsing
# ---------------------------------------------------------------------------

def test_parse_junit_xml_basic(tmp_path: Path) -> None:
    """Single suite, one passed and one failed case."""
    xml = textwrap.dedent("""\
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite name="suite1" tests="2" failures="1" skipped="0" time="1.5">
          <testcase classname="suite1" name="test_a" time="0.5"/>
          <testcase classname="suite1" name="test_b" time="1.0">
            <failure message="boom">stack</failure>
          </testcase>
        </testsuite>
    """)
    path = tmp_path / "junit.xml"
    path.write_text(xml)

    results = parse_junit_xml(path)

    assert isinstance(results, TestResults)
    assert len(results.cases) == 2
    a = next(c for c in results.cases if c.name == "test_a")
    b = next(c for c in results.cases if c.name == "test_b")
    assert a.status == "passed"
    assert a.duration == pytest.approx(0.5)
    assert b.status == "failed"
    assert b.duration == pytest.approx(1.0)
    assert b.classname == "suite1"


def test_parse_junit_xml_skipped_and_error(tmp_path: Path) -> None:
    xml = textwrap.dedent("""\
        <testsuites>
          <testsuite name="s">
            <testcase classname="s" name="skipper" time="0.1">
              <skipped/>
            </testcase>
            <testcase classname="s" name="errored" time="0.2">
              <error message="oops"/>
            </testcase>
          </testsuite>
        </testsuites>
    """)
    path = tmp_path / "junit.xml"
    path.write_text(xml)

    results = parse_junit_xml(path)
    by_name = {c.name: c for c in results.cases}
    assert by_name["skipper"].status == "skipped"
    assert by_name["errored"].status == "failed"


def test_parse_junit_xml_invalid(tmp_path: Path) -> None:
    path = tmp_path / "bad.xml"
    path.write_text("<not-valid")
    with pytest.raises(ValueError, match="Failed to parse JUnit XML"):
        parse_junit_xml(path)


# ---------------------------------------------------------------------------
# JSON parsing
# ---------------------------------------------------------------------------

def test_parse_json_basic(tmp_path: Path) -> None:
    """JSON format: list of testcases under "tests"."""
    payload = {
        "tests": [
            {"name": "json_pass", "classname": "json_suite",
             "status": "passed", "duration": 0.25},
            {"name": "json_fail", "classname": "json_suite",
             "status": "failed", "duration": 0.75,
             "message": "expected 1, got 2"},
            {"name": "json_skip", "classname": "json_suite",
             "status": "skipped", "duration": 0.0},
        ]
    }
    path = tmp_path / "results.json"
    path.write_text(json.dumps(payload))

    results = parse_json(path)
    assert len(results.cases) == 3
    statuses = {c.name: c.status for c in results.cases}
    assert statuses == {
        "json_pass": "passed",
        "json_fail": "failed",
        "json_skip": "skipped",
    }


def test_parse_json_invalid(tmp_path: Path) -> None:
    path = tmp_path / "bad.json"
    path.write_text("{not json")
    with pytest.raises(ValueError, match="Failed to parse JSON"):
        parse_json(path)


# ---------------------------------------------------------------------------
# Format auto-detection
# ---------------------------------------------------------------------------

def test_parse_file_detects_format_by_extension(tmp_path: Path) -> None:
    xml_path = tmp_path / "a.xml"
    xml_path.write_text(
        '<testsuite name="s" tests="1" failures="0" skipped="0">'
        '<testcase classname="s" name="t" time="0.1"/></testsuite>'
    )
    json_path = tmp_path / "a.json"
    json_path.write_text(json.dumps({"tests": [
        {"name": "t", "classname": "s", "status": "passed", "duration": 0.1}
    ]}))

    assert len(parse_file(xml_path).cases) == 1
    assert len(parse_file(json_path).cases) == 1


def test_parse_file_unknown_extension(tmp_path: Path) -> None:
    p = tmp_path / "a.txt"
    p.write_text("nope")
    with pytest.raises(ValueError, match="Unsupported file format"):
        parse_file(p)


def test_parse_file_missing(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        parse_file(tmp_path / "does-not-exist.xml")


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def _case(name: str, status: str, duration: float = 0.1,
          classname: str = "suite") -> TestCase:
    return TestCase(name=name, classname=classname,
                    status=status, duration=duration)


def test_aggregate_totals() -> None:
    run_a = TestResults(cases=[
        _case("t1", "passed"), _case("t2", "passed", 0.2),
        _case("t3", "failed", 0.3), _case("t4", "skipped"),
    ])
    run_b = TestResults(cases=[
        _case("t1", "passed", 0.5), _case("t5", "passed"),
    ])

    summary = aggregate([run_a, run_b])

    assert summary.total == 6
    assert summary.passed == 4
    assert summary.failed == 1
    assert summary.skipped == 1
    assert summary.duration == pytest.approx(0.1 + 0.2 + 0.3 + 0.1 + 0.5 + 0.1)


def test_aggregate_empty() -> None:
    summary = aggregate([])
    assert summary.total == summary.passed == summary.failed == 0
    assert summary.skipped == 0
    assert summary.duration == 0.0


# ---------------------------------------------------------------------------
# Flaky test detection
# ---------------------------------------------------------------------------

def test_find_flaky_identifies_inconsistent() -> None:
    """A flaky test passes in one run and fails in another (same identity)."""
    run_a = TestResults(cases=[
        _case("flaky_one", "passed"),
        _case("stable_pass", "passed"),
        _case("stable_fail", "failed"),
    ])
    run_b = TestResults(cases=[
        _case("flaky_one", "failed"),
        _case("stable_pass", "passed"),
        _case("stable_fail", "failed"),
    ])

    flaky = find_flaky([run_a, run_b])

    names = {f.name for f in flaky}
    assert names == {"flaky_one"}


def test_find_flaky_skipped_does_not_count() -> None:
    """Skipped runs are ignored when judging stability."""
    run_a = TestResults(cases=[_case("t", "passed")])
    run_b = TestResults(cases=[_case("t", "skipped")])
    run_c = TestResults(cases=[_case("t", "passed")])
    assert find_flaky([run_a, run_b, run_c]) == []


def test_find_flaky_uses_full_identity() -> None:
    """Tests with same name but different classname are distinct."""
    run_a = TestResults(cases=[
        _case("t", "passed", classname="alpha"),
        _case("t", "failed", classname="beta"),
    ])
    run_b = TestResults(cases=[
        _case("t", "passed", classname="alpha"),
        _case("t", "failed", classname="beta"),
    ])
    assert find_flaky([run_a, run_b]) == []


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------

def test_render_markdown_contains_totals_and_flaky() -> None:
    run_a = TestResults(cases=[
        _case("t1", "passed", 0.1), _case("t2", "failed", 0.2),
    ])
    run_b = TestResults(cases=[
        _case("t1", "failed", 0.3), _case("t2", "failed", 0.2),
    ])

    md = render_markdown([("run-a", run_a), ("run-b", run_b)])

    assert "# Test Results Summary" in md
    assert "Total" in md and "Passed" in md and "Failed" in md
    # 4 total cases
    assert "| 4 |" in md
    # Flaky section lists t1 (passed once, failed once)
    assert "## Flaky tests" in md
    assert "t1" in md
    # Per-run breakdown
    assert "run-a" in md and "run-b" in md


def test_render_markdown_no_flaky_section_when_none() -> None:
    run = TestResults(cases=[_case("t1", "passed")])
    md = render_markdown([("only", run)])
    assert "No flaky tests detected" in md


def test_render_markdown_overall_status_passed() -> None:
    run = TestResults(cases=[_case("t1", "passed")])
    md = render_markdown([("r", run)])
    assert "PASSED" in md


def test_render_markdown_overall_status_failed() -> None:
    run = TestResults(cases=[_case("t1", "failed")])
    md = render_markdown([("r", run)])
    assert "FAILED" in md


# ---------------------------------------------------------------------------
# End-to-end CLI behavior (via run())
# ---------------------------------------------------------------------------

def test_run_writes_summary_file(tmp_path: Path) -> None:
    """run() reads input files, writes the rendered markdown to output."""
    xml_path = tmp_path / "a.xml"
    xml_path.write_text(textwrap.dedent("""\
        <testsuite name="s" tests="2" failures="1">
          <testcase classname="s" name="t1" time="0.1"/>
          <testcase classname="s" name="t2" time="0.2">
            <failure/>
          </testcase>
        </testsuite>
    """))

    json_path = tmp_path / "b.json"
    json_path.write_text(json.dumps({"tests": [
        {"name": "t1", "classname": "s", "status": "failed", "duration": 0.1},
        {"name": "t2", "classname": "s", "status": "failed", "duration": 0.2},
    ]}))

    out = tmp_path / "summary.md"
    exit_code = run([str(xml_path), str(json_path), "--output", str(out)])
    assert exit_code == 1  # because tests failed overall
    text = out.read_text()
    assert "# Test Results Summary" in text
    # t1 is flaky (passed in xml, failed in json)
    assert "t1" in text


def test_run_returns_zero_when_all_pass(tmp_path: Path) -> None:
    xml_path = tmp_path / "a.xml"
    xml_path.write_text(
        '<testsuite name="s" tests="1" failures="0">'
        '<testcase classname="s" name="t1" time="0.1"/></testsuite>'
    )
    out = tmp_path / "summary.md"
    code = run([str(xml_path), "--output", str(out)])
    assert code == 0


def test_run_missing_file_returns_error(tmp_path: Path) -> None:
    out = tmp_path / "summary.md"
    code = run([str(tmp_path / "nope.xml"), "--output", str(out)])
    assert code == 2  # CLI/usage error
