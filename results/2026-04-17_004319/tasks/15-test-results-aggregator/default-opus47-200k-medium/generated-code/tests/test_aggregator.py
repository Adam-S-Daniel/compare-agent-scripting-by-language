"""Tests for the test-results aggregator.

Written TDD-style: each test targets one unit of functionality.
Fixtures live under tests/fixtures/.
"""
from pathlib import Path
import json
import textwrap
import pytest

from aggregator import (
    parse_junit_xml,
    parse_json,
    parse_file,
    aggregate,
    find_flaky,
    generate_markdown,
    TestResult,
    Aggregate,
)

FIXTURES = Path(__file__).parent / "fixtures"


# ---------- parse_junit_xml ----------

def test_parse_junit_xml_passed_failed_skipped(tmp_path):
    xml = tmp_path / "r.xml"
    xml.write_text(textwrap.dedent("""\
        <?xml version="1.0"?>
        <testsuite name="suite1" tests="3" failures="1" skipped="1" time="1.5">
          <testcase classname="A" name="t_pass" time="0.1"/>
          <testcase classname="A" name="t_fail" time="0.4">
            <failure message="boom">stack</failure>
          </testcase>
          <testcase classname="A" name="t_skip" time="0.0">
            <skipped/>
          </testcase>
        </testsuite>
    """))
    results = parse_junit_xml(xml)
    statuses = {r.name: r.status for r in results}
    assert statuses == {"A.t_pass": "passed", "A.t_fail": "failed", "A.t_skip": "skipped"}
    durations = {r.name: r.duration for r in results}
    assert durations["A.t_fail"] == pytest.approx(0.4)


def test_parse_junit_xml_with_testsuites_root(tmp_path):
    xml = tmp_path / "r.xml"
    xml.write_text("""<?xml version="1.0"?>
        <testsuites>
          <testsuite name="s" tests="1" failures="0" time="0.2">
            <testcase classname="C" name="ok" time="0.2"/>
          </testsuite>
        </testsuites>""")
    results = parse_junit_xml(xml)
    assert len(results) == 1
    assert results[0].status == "passed"


def test_parse_junit_xml_error_treated_as_failed(tmp_path):
    xml = tmp_path / "r.xml"
    xml.write_text("""<?xml version="1.0"?>
        <testsuite name="s" tests="1" errors="1" time="0.1">
          <testcase classname="C" name="boom" time="0.1"><error message="x"/></testcase>
        </testsuite>""")
    results = parse_junit_xml(xml)
    assert results[0].status == "failed"


def test_parse_junit_xml_invalid_raises(tmp_path):
    bad = tmp_path / "bad.xml"
    bad.write_text("<not-xml")
    with pytest.raises(ValueError, match="Failed to parse JUnit XML"):
        parse_junit_xml(bad)


# ---------- parse_json ----------

def test_parse_json_basic(tmp_path):
    j = tmp_path / "r.json"
    j.write_text(json.dumps({
        "tests": [
            {"name": "m.t1", "status": "passed", "duration": 0.3},
            {"name": "m.t2", "status": "failed", "duration": 0.5, "message": "bad"},
            {"name": "m.t3", "status": "skipped", "duration": 0.0},
        ]
    }))
    results = parse_json(j)
    assert [r.name for r in results] == ["m.t1", "m.t2", "m.t3"]
    assert [r.status for r in results] == ["passed", "failed", "skipped"]
    assert results[1].message == "bad"


def test_parse_json_missing_tests_raises(tmp_path):
    j = tmp_path / "r.json"
    j.write_text(json.dumps({"wrong": []}))
    with pytest.raises(ValueError, match="missing 'tests'"):
        parse_json(j)


def test_parse_json_invalid_raises(tmp_path):
    j = tmp_path / "bad.json"
    j.write_text("{not json")
    with pytest.raises(ValueError, match="Failed to parse JSON"):
        parse_json(j)


# ---------- parse_file dispatcher ----------

def test_parse_file_dispatches_by_extension(tmp_path):
    xml = tmp_path / "a.xml"
    xml.write_text('<?xml version="1.0"?><testsuite name="s" tests="1" time="0"><testcase classname="C" name="t" time="0"/></testsuite>')
    j = tmp_path / "a.json"
    j.write_text(json.dumps({"tests": [{"name": "n", "status": "passed", "duration": 0}]}))
    assert len(parse_file(xml)) == 1
    assert len(parse_file(j)) == 1


def test_parse_file_unknown_extension(tmp_path):
    f = tmp_path / "x.txt"
    f.write_text("hi")
    with pytest.raises(ValueError, match="Unsupported"):
        parse_file(f)


# ---------- aggregate + flaky ----------

def _r(name, status, dur=0.0, run="run1"):
    return TestResult(name=name, status=status, duration=dur, run=run, message=None)


def test_aggregate_totals():
    results = [
        _r("a", "passed", 1.0),
        _r("b", "failed", 0.5),
        _r("c", "skipped", 0.0),
        _r("a", "passed", 1.1, run="run2"),
    ]
    agg = aggregate(results)
    assert agg.passed == 2
    assert agg.failed == 1
    assert agg.skipped == 1
    assert agg.total == 4
    assert agg.duration == pytest.approx(2.6)


def test_find_flaky_detects_mixed_outcomes():
    results = [
        _r("flaky", "passed", run="run1"),
        _r("flaky", "failed", run="run2"),
        _r("stable_pass", "passed", run="run1"),
        _r("stable_pass", "passed", run="run2"),
        _r("always_fail", "failed", run="run1"),
        _r("always_fail", "failed", run="run2"),
    ]
    flaky = find_flaky(results)
    assert [f.name for f in flaky] == ["flaky"]


def test_find_flaky_ignores_skipped_only_mix():
    # A test that was skipped in one run and passed in another is not flaky.
    results = [
        _r("t", "passed", run="run1"),
        _r("t", "skipped", run="run2"),
    ]
    assert find_flaky(results) == []


# ---------- markdown generation ----------

def test_generate_markdown_contains_summary():
    agg = Aggregate(passed=5, failed=2, skipped=1, duration=3.25, total=8,
                    flaky=[], runs=["run1", "run2"], failures=[])
    md = generate_markdown(agg)
    assert "# Test Results Summary" in md
    assert "Passed" in md and "5" in md
    assert "Failed" in md and "2" in md
    assert "Skipped" in md and "1" in md
    assert "3.25" in md or "3.25s" in md


def test_generate_markdown_lists_flaky_and_failures():
    flaky = [TestResult(name="flaky_one", status="failed", duration=0.1, run="run2", message="x")]
    failures = [TestResult(name="hard_fail", status="failed", duration=0.2, run="run1", message="bad")]
    agg = Aggregate(passed=1, failed=1, skipped=0, duration=0.3, total=2,
                    flaky=flaky, runs=["run1", "run2"], failures=failures)
    md = generate_markdown(agg)
    assert "Flaky Tests" in md
    assert "flaky_one" in md
    assert "Failures" in md
    assert "hard_fail" in md


def test_generate_markdown_no_flaky_section_when_none():
    agg = Aggregate(passed=1, failed=0, skipped=0, duration=0.1, total=1,
                    flaky=[], runs=["run1"], failures=[])
    md = generate_markdown(agg)
    assert "No flaky tests detected" in md


# ---------- integration with fixtures ----------

def test_end_to_end_with_bundled_fixtures():
    """Parse the bundled fixtures, aggregate, and check known totals."""
    files = sorted(FIXTURES.glob("run*.*"))
    assert files, "fixtures must exist"
    all_results = []
    for f in files:
        all_results.extend(parse_file(f))
    agg = aggregate(all_results, flaky=find_flaky(all_results),
                    failures=[r for r in all_results if r.status == "failed"])
    # fixtures: 3 runs; see fixtures for expected counts.
    assert agg.total >= 6
    # "flaky_test" appears as flaky (passed in run1, failed in run2)
    assert any(f.name == "suite.flaky_test" for f in agg.flaky)
