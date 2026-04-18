"""
TDD tests for the test-results aggregator.

Approach (red/green/refactor):
- Each test focuses on a single piece of behavior.
- Tests use small inline fixtures written to tmp_path so they're self-contained.
- Error cases assert on exception messages.
"""
import json
from pathlib import Path
import pytest

from aggregator import (
    parse_junit_xml,
    parse_json_report,
    parse_file,
    aggregate,
    identify_flaky,
    render_markdown,
    TestCaseResult,
)


# ---------- JUnit XML parsing ----------

def test_parse_junit_xml_counts_pass_fail_skip(tmp_path: Path):
    xml = """<?xml version="1.0"?>
<testsuites>
  <testsuite name="suite1" tests="3" failures="1" skipped="1" time="1.25">
    <testcase classname="Foo" name="test_a" time="0.5"/>
    <testcase classname="Foo" name="test_b" time="0.5">
      <failure message="boom">stack</failure>
    </testcase>
    <testcase classname="Foo" name="test_c" time="0.25">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
"""
    f = tmp_path / "j.xml"
    f.write_text(xml)
    results = parse_junit_xml(f)
    assert len(results) == 3
    statuses = {r.name: r.status for r in results}
    assert statuses == {"Foo.test_a": "passed", "Foo.test_b": "failed", "Foo.test_c": "skipped"}
    assert sum(r.duration for r in results) == pytest.approx(1.25)


def test_parse_junit_xml_single_testsuite_root(tmp_path: Path):
    # Some tools emit <testsuite> as the root, not wrapped in <testsuites>
    xml = """<?xml version="1.0"?>
<testsuite name="s" tests="1" failures="0" time="0.1">
  <testcase classname="X" name="t" time="0.1"/>
</testsuite>
"""
    f = tmp_path / "j.xml"
    f.write_text(xml)
    results = parse_junit_xml(f)
    assert len(results) == 1
    assert results[0].status == "passed"


def test_parse_junit_xml_missing_file_raises(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        parse_junit_xml(tmp_path / "nope.xml")


def test_parse_junit_xml_malformed_raises(tmp_path: Path):
    f = tmp_path / "bad.xml"
    f.write_text("<not valid xml")
    with pytest.raises(ValueError, match="Invalid JUnit XML"):
        parse_junit_xml(f)


# ---------- JSON parsing ----------

def test_parse_json_report(tmp_path: Path):
    data = {
        "tests": [
            {"name": "suite.t1", "status": "passed", "duration": 0.2},
            {"name": "suite.t2", "status": "failed", "duration": 0.3},
            {"name": "suite.t3", "status": "skipped", "duration": 0.0},
        ]
    }
    f = tmp_path / "r.json"
    f.write_text(json.dumps(data))
    results = parse_json_report(f)
    assert len(results) == 3
    assert results[1].status == "failed"
    assert results[0].duration == 0.2


def test_parse_json_report_invalid_status(tmp_path: Path):
    f = tmp_path / "r.json"
    f.write_text(json.dumps({"tests": [{"name": "x", "status": "weird", "duration": 0}]}))
    with pytest.raises(ValueError, match="Unknown status"):
        parse_json_report(f)


def test_parse_json_report_malformed(tmp_path: Path):
    f = tmp_path / "r.json"
    f.write_text("{not json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        parse_json_report(f)


# ---------- Dispatch by extension ----------

def test_parse_file_dispatches(tmp_path: Path):
    xml = tmp_path / "a.xml"
    xml.write_text('<testsuite name="s" tests="1" time="0.1"><testcase classname="X" name="t" time="0.1"/></testsuite>')
    js = tmp_path / "b.json"
    js.write_text(json.dumps({"tests": [{"name": "y", "status": "passed", "duration": 0.1}]}))
    assert len(parse_file(xml)) == 1
    assert len(parse_file(js)) == 1


def test_parse_file_unknown_extension(tmp_path: Path):
    f = tmp_path / "x.txt"
    f.write_text("hi")
    with pytest.raises(ValueError, match="Unsupported file type"):
        parse_file(f)


# ---------- Aggregation ----------

def test_aggregate_totals_and_runs():
    run1 = [
        TestCaseResult("a", "passed", 1.0),
        TestCaseResult("b", "failed", 0.5),
        TestCaseResult("c", "skipped", 0.0),
    ]
    run2 = [
        TestCaseResult("a", "passed", 1.2),
        TestCaseResult("b", "passed", 0.6),
    ]
    agg = aggregate([run1, run2])
    assert agg["total"] == 5
    assert agg["passed"] == 3
    assert agg["failed"] == 1
    assert agg["skipped"] == 1
    assert agg["duration"] == pytest.approx(3.3)
    assert agg["runs"] == 2


# ---------- Flaky detection ----------

def test_identify_flaky_tests():
    run1 = [TestCaseResult("flaky", "passed", 0.1), TestCaseResult("stable", "passed", 0.1)]
    run2 = [TestCaseResult("flaky", "failed", 0.1), TestCaseResult("stable", "passed", 0.1)]
    run3 = [TestCaseResult("flaky", "passed", 0.1), TestCaseResult("stable", "passed", 0.1)]
    flaky = identify_flaky([run1, run2, run3])
    assert flaky == ["flaky"]


def test_identify_flaky_skipped_does_not_count():
    # A test that is skipped in one run and passed in another is NOT flaky
    # (flaky = passed somewhere AND failed somewhere).
    run1 = [TestCaseResult("t", "passed", 0.1)]
    run2 = [TestCaseResult("t", "skipped", 0.0)]
    assert identify_flaky([run1, run2]) == []


# ---------- Markdown rendering ----------

def test_render_markdown_contains_expected_sections():
    run1 = [TestCaseResult("a", "passed", 1.0), TestCaseResult("b", "failed", 0.5)]
    run2 = [TestCaseResult("a", "failed", 1.1), TestCaseResult("b", "failed", 0.6)]
    md = render_markdown([run1, run2])
    assert "# Test Results Summary" in md
    assert "Total: 4" in md
    assert "Passed: 1" in md
    assert "Failed: 3" in md
    assert "Skipped: 0" in md
    assert "Runs: 2" in md
    # flaky section lists 'a'
    assert "## Flaky Tests" in md
    assert "- a" in md


def test_render_markdown_no_flaky_section_when_none():
    run1 = [TestCaseResult("a", "passed", 1.0)]
    md = render_markdown([run1])
    assert "No flaky tests detected" in md
