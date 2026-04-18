"""Unit tests for the test results aggregator.

TDD approach: each test is written BEFORE its implementation.
The tests here drive the design of aggregator.py.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Make the project root importable so `import aggregator` works.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest

import aggregator


# ---------------------------------------------------------------------------
# JUnit XML parsing
# ---------------------------------------------------------------------------
def test_parse_junit_xml_basic(tmp_path: Path):
    """Parse a minimal JUnit XML file and return TestCase objects."""
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite1" tests="3" failures="1" skipped="1" time="1.25">
    <testcase classname="pkg.Mod" name="test_pass" time="0.10"/>
    <testcase classname="pkg.Mod" name="test_fail" time="0.20">
      <failure message="boom">Traceback ...</failure>
    </testcase>
    <testcase classname="pkg.Mod" name="test_skip" time="0.05">
      <skipped message="not ready"/>
    </testcase>
  </testsuite>
</testsuites>
"""
    path = tmp_path / "junit.xml"
    path.write_text(xml)

    cases = aggregator.parse_junit_xml(path)

    assert len(cases) == 3
    names = {c.name for c in cases}
    assert names == {"pkg.Mod.test_pass", "pkg.Mod.test_fail", "pkg.Mod.test_skip"}
    statuses = {c.name: c.status for c in cases}
    assert statuses["pkg.Mod.test_pass"] == "passed"
    assert statuses["pkg.Mod.test_fail"] == "failed"
    assert statuses["pkg.Mod.test_skip"] == "skipped"
    durations = {c.name: c.duration for c in cases}
    assert durations["pkg.Mod.test_pass"] == pytest.approx(0.10)
    assert durations["pkg.Mod.test_fail"] == pytest.approx(0.20)


def test_parse_junit_xml_error_is_failed(tmp_path: Path):
    """<error> elements should count as failed."""
    xml = """<?xml version="1.0"?>
<testsuite name="s" tests="1" errors="1" time="0.3">
  <testcase classname="c" name="t" time="0.3">
    <error message="ouch">stack</error>
  </testcase>
</testsuite>
"""
    path = tmp_path / "junit.xml"
    path.write_text(xml)

    cases = aggregator.parse_junit_xml(path)
    assert len(cases) == 1
    assert cases[0].status == "failed"


def test_parse_junit_xml_missing_file(tmp_path: Path):
    """A missing file should raise FileNotFoundError with a clear message."""
    missing = tmp_path / "nope.xml"
    with pytest.raises(FileNotFoundError) as excinfo:
        aggregator.parse_junit_xml(missing)
    assert "nope.xml" in str(excinfo.value)


def test_parse_junit_xml_malformed(tmp_path: Path):
    """Malformed XML should raise ValueError with a meaningful message."""
    path = tmp_path / "bad.xml"
    path.write_text("<testsuites><unterminated>")
    with pytest.raises(ValueError) as excinfo:
        aggregator.parse_junit_xml(path)
    assert "bad.xml" in str(excinfo.value)


# ---------------------------------------------------------------------------
# JSON parsing
# ---------------------------------------------------------------------------
def test_parse_json_basic(tmp_path: Path):
    """Parse a simple JSON test report."""
    data = {
        "tests": [
            {"name": "suite.a", "status": "passed", "duration": 0.5},
            {"name": "suite.b", "status": "failed", "duration": 1.0,
             "message": "AssertionError"},
            {"name": "suite.c", "status": "skipped", "duration": 0.0},
        ]
    }
    path = tmp_path / "results.json"
    path.write_text(json.dumps(data))

    cases = aggregator.parse_json(path)
    assert len(cases) == 3
    statuses = {c.name: c.status for c in cases}
    assert statuses == {"suite.a": "passed", "suite.b": "failed", "suite.c": "skipped"}


def test_parse_json_accepts_pass_as_synonym(tmp_path: Path):
    """Normalize 'pass'/'fail'/'skip' to canonical statuses."""
    data = {"tests": [
        {"name": "x", "status": "pass", "duration": 0.1},
        {"name": "y", "status": "fail", "duration": 0.2},
        {"name": "z", "status": "skip", "duration": 0.0},
    ]}
    path = tmp_path / "results.json"
    path.write_text(json.dumps(data))

    cases = aggregator.parse_json(path)
    by_name = {c.name: c.status for c in cases}
    assert by_name == {"x": "passed", "y": "failed", "z": "skipped"}


def test_parse_json_malformed(tmp_path: Path):
    """Malformed JSON should raise ValueError mentioning the file."""
    path = tmp_path / "bad.json"
    path.write_text("{not-json")
    with pytest.raises(ValueError) as excinfo:
        aggregator.parse_json(path)
    assert "bad.json" in str(excinfo.value)


# ---------------------------------------------------------------------------
# Auto-detecting parser (dispatches on file extension / content)
# ---------------------------------------------------------------------------
def test_parse_file_dispatches_by_extension(tmp_path: Path):
    (tmp_path / "a.xml").write_text(
        '<testsuite name="s" tests="1" time="0.1">'
        '<testcase classname="c" name="t" time="0.1"/></testsuite>'
    )
    (tmp_path / "b.json").write_text(
        json.dumps({"tests": [{"name": "t2", "status": "passed", "duration": 0.2}]})
    )

    xml_cases = aggregator.parse_file(tmp_path / "a.xml")
    json_cases = aggregator.parse_file(tmp_path / "b.json")
    assert len(xml_cases) == 1
    assert len(json_cases) == 1


def test_parse_file_unknown_extension(tmp_path: Path):
    path = tmp_path / "weird.txt"
    path.write_text("stuff")
    with pytest.raises(ValueError) as excinfo:
        aggregator.parse_file(path)
    assert "weird.txt" in str(excinfo.value)


# ---------------------------------------------------------------------------
# Aggregation across multiple files (matrix build simulation)
# ---------------------------------------------------------------------------
def test_aggregate_totals(tmp_path: Path):
    """Totals count each test case occurrence across all files."""
    (tmp_path / "run1.json").write_text(json.dumps({"tests": [
        {"name": "a", "status": "passed", "duration": 0.1},
        {"name": "b", "status": "failed", "duration": 0.2},
        {"name": "c", "status": "skipped", "duration": 0.0},
    ]}))
    (tmp_path / "run2.json").write_text(json.dumps({"tests": [
        {"name": "a", "status": "passed", "duration": 0.15},
        {"name": "b", "status": "passed", "duration": 0.25},  # flaky!
        {"name": "c", "status": "skipped", "duration": 0.0},
    ]}))

    report = aggregator.aggregate([tmp_path / "run1.json", tmp_path / "run2.json"])

    # Totals are per (test, run) occurrence, not unique tests
    assert report.total == 6
    assert report.passed == 3   # a x2, b x1 (c skipped doesn't count as passed)
    assert report.failed == 1   # b failed once
    assert report.skipped == 2  # c skipped x2
    assert report.duration == pytest.approx(0.70)


def test_aggregate_identifies_flaky_tests(tmp_path: Path):
    """A test is flaky if it passed in >=1 run AND failed in >=1 run."""
    (tmp_path / "run1.json").write_text(json.dumps({"tests": [
        {"name": "stable_pass", "status": "passed", "duration": 0.1},
        {"name": "stable_fail", "status": "failed", "duration": 0.1},
        {"name": "flaky",       "status": "passed", "duration": 0.1},
    ]}))
    (tmp_path / "run2.json").write_text(json.dumps({"tests": [
        {"name": "stable_pass", "status": "passed", "duration": 0.1},
        {"name": "stable_fail", "status": "failed", "duration": 0.1},
        {"name": "flaky",       "status": "failed", "duration": 0.1},
    ]}))

    report = aggregator.aggregate([tmp_path / "run1.json", tmp_path / "run2.json"])
    flaky_names = sorted(t.name for t in report.flaky)
    assert flaky_names == ["flaky"]


def test_aggregate_mixed_formats(tmp_path: Path):
    """Aggregate handles JUnit XML and JSON in the same batch."""
    (tmp_path / "run1.xml").write_text("""<?xml version="1.0"?>
<testsuite name="s" tests="2" failures="0" time="0.3">
  <testcase classname="c" name="alpha" time="0.1"/>
  <testcase classname="c" name="beta" time="0.2"/>
</testsuite>""")
    (tmp_path / "run2.json").write_text(json.dumps({"tests": [
        {"name": "c.alpha", "status": "failed", "duration": 0.15},
        {"name": "c.beta", "status": "passed", "duration": 0.25},
    ]}))

    report = aggregator.aggregate([tmp_path / "run1.xml", tmp_path / "run2.json"])
    assert report.total == 4
    assert report.failed == 1
    flaky = {t.name for t in report.flaky}
    assert "c.alpha" in flaky  # alpha passed in XML, failed in JSON


def test_aggregate_empty_file_list_raises():
    with pytest.raises(ValueError):
        aggregator.aggregate([])


# ---------------------------------------------------------------------------
# Markdown rendering (GitHub Actions job summary)
# ---------------------------------------------------------------------------
def test_render_markdown_contains_totals(tmp_path: Path):
    (tmp_path / "r1.json").write_text(json.dumps({"tests": [
        {"name": "a", "status": "passed", "duration": 0.5},
        {"name": "b", "status": "failed", "duration": 0.25, "message": "nope"},
    ]}))
    report = aggregator.aggregate([tmp_path / "r1.json"])
    md = aggregator.render_markdown(report)

    # Headings
    assert "# Test Results Summary" in md
    # Totals table contains the counts we expect
    assert "| Passed | 1 |" in md
    assert "| Failed | 1 |" in md
    assert "| Skipped | 0 |" in md
    assert "| Total | 2 |" in md
    # Duration in seconds with a 2dp precision
    assert "0.75s" in md


def test_render_markdown_flaky_section(tmp_path: Path):
    (tmp_path / "r1.json").write_text(json.dumps({"tests": [
        {"name": "flaky", "status": "passed", "duration": 0.1},
        {"name": "stable", "status": "passed", "duration": 0.1},
    ]}))
    (tmp_path / "r2.json").write_text(json.dumps({"tests": [
        {"name": "flaky", "status": "failed", "duration": 0.1},
        {"name": "stable", "status": "passed", "duration": 0.1},
    ]}))
    report = aggregator.aggregate([tmp_path / "r1.json", tmp_path / "r2.json"])
    md = aggregator.render_markdown(report)

    assert "## Flaky Tests" in md
    assert "flaky" in md
    # Should mention runs that passed vs failed
    assert "1 passed" in md and "1 failed" in md


def test_render_markdown_no_flaky(tmp_path: Path):
    (tmp_path / "r1.json").write_text(json.dumps({"tests": [
        {"name": "stable", "status": "passed", "duration": 0.1},
    ]}))
    report = aggregator.aggregate([tmp_path / "r1.json"])
    md = aggregator.render_markdown(report)
    # When no flaky tests, section should state that clearly
    assert "No flaky tests detected" in md


def test_render_markdown_failures_listed(tmp_path: Path):
    (tmp_path / "r1.json").write_text(json.dumps({"tests": [
        {"name": "bad", "status": "failed", "duration": 0.1,
         "message": "AssertionError: expected 1 got 2"},
    ]}))
    report = aggregator.aggregate([tmp_path / "r1.json"])
    md = aggregator.render_markdown(report)
    assert "## Failures" in md
    assert "bad" in md
    assert "AssertionError" in md


# ---------------------------------------------------------------------------
# CLI behavior
# ---------------------------------------------------------------------------
def test_cli_writes_summary(tmp_path: Path, capsys):
    input_file = tmp_path / "r.json"
    input_file.write_text(json.dumps({"tests": [
        {"name": "a", "status": "passed", "duration": 0.1},
        {"name": "b", "status": "failed", "duration": 0.2, "message": "nope"},
    ]}))
    output = tmp_path / "summary.md"

    exit_code = aggregator.main(["--output", str(output), str(input_file)])
    assert exit_code == 1  # non-zero because of failed test

    content = output.read_text()
    assert "# Test Results Summary" in content
    assert "| Failed | 1 |" in content


def test_cli_all_green(tmp_path: Path):
    input_file = tmp_path / "r.json"
    input_file.write_text(json.dumps({"tests": [
        {"name": "a", "status": "passed", "duration": 0.1},
    ]}))
    output = tmp_path / "summary.md"
    exit_code = aggregator.main(["--output", str(output), str(input_file)])
    assert exit_code == 0


def test_cli_supports_github_step_summary(tmp_path: Path, monkeypatch):
    """When GITHUB_STEP_SUMMARY env var is set, write there too."""
    input_file = tmp_path / "r.json"
    input_file.write_text(json.dumps({"tests": [
        {"name": "a", "status": "passed", "duration": 0.1},
    ]}))
    step_summary = tmp_path / "step_summary.md"
    monkeypatch.setenv("GITHUB_STEP_SUMMARY", str(step_summary))

    exit_code = aggregator.main([str(input_file)])
    assert exit_code == 0
    assert step_summary.exists()
    assert "# Test Results Summary" in step_summary.read_text()


def test_cli_missing_file_returns_error(tmp_path: Path, capsys):
    output = tmp_path / "summary.md"
    exit_code = aggregator.main(["--output", str(output), str(tmp_path / "nope.xml")])
    assert exit_code == 2
    err = capsys.readouterr().err
    assert "nope.xml" in err
