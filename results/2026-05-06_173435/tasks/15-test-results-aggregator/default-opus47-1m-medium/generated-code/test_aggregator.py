"""TDD tests for the test results aggregator.

Each test was written before the corresponding implementation in aggregator.py.
"""
import json
import os
import textwrap
from pathlib import Path

import pytest

from aggregator import (
    AggregateResult,
    TestCase,
    aggregate,
    find_flaky_tests,
    load_results,
    parse_file,
    parse_json,
    parse_junit_xml,
    render_markdown,
)


# ---------- JUnit XML parser ----------

def test_parse_junit_xml_simple(tmp_path: Path):
    xml = textwrap.dedent("""\
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite name="suite1" tests="3" failures="1" skipped="1" time="1.5">
          <testcase classname="pkg.Mod" name="test_a" time="0.1"/>
          <testcase classname="pkg.Mod" name="test_b" time="0.2">
            <failure message="boom">stack</failure>
          </testcase>
          <testcase classname="pkg.Mod" name="test_c" time="0.0">
            <skipped/>
          </testcase>
        </testsuite>
    """)
    f = tmp_path / "j.xml"
    f.write_text(xml)
    cases = parse_junit_xml(f)
    assert len(cases) == 3
    by_name = {c.name: c for c in cases}
    assert by_name["pkg.Mod.test_a"].status == "passed"
    assert by_name["pkg.Mod.test_b"].status == "failed"
    assert by_name["pkg.Mod.test_c"].status == "skipped"
    assert by_name["pkg.Mod.test_a"].duration == pytest.approx(0.1)


def test_parse_junit_xml_testsuites_wrapper(tmp_path: Path):
    """JUnit files often wrap multiple suites in <testsuites>."""
    xml = """<testsuites>
        <testsuite name="s1"><testcase classname="A" name="t1" time="0.5"/></testsuite>
        <testsuite name="s2"><testcase classname="B" name="t2" time="0.7"><error message="x"/></testcase></testsuite>
    </testsuites>"""
    f = tmp_path / "j.xml"
    f.write_text(xml)
    cases = parse_junit_xml(f)
    assert len(cases) == 2
    assert {c.status for c in cases} == {"passed", "failed"}


def test_parse_junit_xml_invalid(tmp_path: Path):
    f = tmp_path / "bad.xml"
    f.write_text("<not-closed>")
    with pytest.raises(ValueError, match="JUnit XML"):
        parse_junit_xml(f)


# ---------- JSON parser ----------

def test_parse_json_simple(tmp_path: Path):
    data = {
        "tests": [
            {"name": "suite.test_x", "status": "passed", "duration": 0.4},
            {"name": "suite.test_y", "status": "failed", "duration": 1.0,
             "message": "AssertionError"},
            {"name": "suite.test_z", "status": "skipped", "duration": 0},
        ]
    }
    f = tmp_path / "r.json"
    f.write_text(json.dumps(data))
    cases = parse_json(f)
    assert {c.name for c in cases} == {"suite.test_x", "suite.test_y", "suite.test_z"}
    assert sum(c.duration for c in cases) == pytest.approx(1.4)


def test_parse_json_invalid(tmp_path: Path):
    f = tmp_path / "bad.json"
    f.write_text("not json{")
    with pytest.raises(ValueError, match="JSON"):
        parse_json(f)


# ---------- Format dispatch ----------

def test_parse_file_dispatches_by_extension(tmp_path: Path):
    xml_file = tmp_path / "a.xml"
    xml_file.write_text(
        '<testsuite><testcase classname="C" name="t" time="0.1"/></testsuite>'
    )
    json_file = tmp_path / "a.json"
    json_file.write_text('{"tests":[{"name":"x.t","status":"passed","duration":0.2}]}')
    assert len(parse_file(xml_file)) == 1
    assert len(parse_file(json_file)) == 1


def test_parse_file_unknown_extension(tmp_path: Path):
    f = tmp_path / "weird.txt"
    f.write_text("oops")
    with pytest.raises(ValueError, match="Unsupported"):
        parse_file(f)


# ---------- Aggregation ----------

def test_aggregate_totals():
    cases = [
        TestCase("a.t1", "passed", 0.1, "run1"),
        TestCase("a.t2", "failed", 0.2, "run1"),
        TestCase("a.t3", "skipped", 0.0, "run1"),
        TestCase("a.t1", "passed", 0.15, "run2"),
        TestCase("a.t2", "passed", 0.25, "run2"),  # flaky
    ]
    agg = aggregate(cases)
    assert agg.passed == 3
    assert agg.failed == 1
    assert agg.skipped == 1
    assert agg.total == 5
    assert agg.duration == pytest.approx(0.7)


# ---------- Flaky detection ----------

def test_find_flaky_tests():
    cases = [
        TestCase("a.flaky", "passed", 0.1, "run1"),
        TestCase("a.flaky", "failed", 0.1, "run2"),
        TestCase("a.always_pass", "passed", 0.1, "run1"),
        TestCase("a.always_pass", "passed", 0.1, "run2"),
        TestCase("a.always_fail", "failed", 0.1, "run1"),
        TestCase("a.always_fail", "failed", 0.1, "run2"),
    ]
    flaky = find_flaky_tests(cases)
    assert flaky == ["a.flaky"]


def test_find_flaky_ignores_skipped():
    """A test that is skipped in some runs and passed in others is not flaky."""
    cases = [
        TestCase("t.x", "passed", 0.1, "r1"),
        TestCase("t.x", "skipped", 0.0, "r2"),
    ]
    assert find_flaky_tests(cases) == []


# ---------- Load multiple files ----------

def test_load_results_multiple_files(tmp_path: Path):
    (tmp_path / "run1.xml").write_text(
        '<testsuite><testcase classname="C" name="t1" time="0.1"/></testsuite>'
    )
    (tmp_path / "run2.json").write_text(
        '{"tests":[{"name":"C.t1","status":"failed","duration":0.2}]}'
    )
    cases = load_results([tmp_path / "run1.xml", tmp_path / "run2.json"])
    assert len(cases) == 2
    assert {c.run_id for c in cases} == {"run1", "run2"}


# ---------- Markdown rendering ----------

def test_render_markdown_includes_totals_and_flaky():
    agg = AggregateResult(passed=10, failed=2, skipped=1, duration=12.34,
                         flaky=["pkg.flaky_test"], failures=["pkg.broken"])
    md = render_markdown(agg)
    assert "# Test Results" in md
    assert "10" in md and "2" in md and "1" in md
    assert "12.34" in md
    assert "pkg.flaky_test" in md
    assert "pkg.broken" in md


def test_render_markdown_no_failures_or_flaky():
    agg = AggregateResult(passed=5, failed=0, skipped=0, duration=1.0,
                         flaky=[], failures=[])
    md = render_markdown(agg)
    # Should still produce useful output and indicate clean run
    assert "5" in md
    assert "✅" in md or "passed" in md.lower()
