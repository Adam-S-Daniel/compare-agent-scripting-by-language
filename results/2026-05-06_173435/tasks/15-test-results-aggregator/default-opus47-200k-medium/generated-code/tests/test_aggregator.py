"""TDD tests for the test results aggregator.

Each test was written before the corresponding implementation in aggregator.py.
"""
from pathlib import Path
import textwrap

import pytest

from aggregator import (
    TestCase,
    TestRun,
    parse_json,
    parse_junit_xml,
    parse_file,
    aggregate,
    find_flaky,
    render_markdown,
)


# ---- JSON parser ----------------------------------------------------------

def test_parse_json_basic(tmp_path: Path):
    path = tmp_path / "results.json"
    path.write_text(
        '{"tests": ['
        '{"name": "a.test_one", "status": "passed", "duration": 0.1},'
        '{"name": "a.test_two", "status": "failed", "duration": 0.2},'
        '{"name": "a.test_three", "status": "skipped", "duration": 0.0}'
        ']}'
    )
    run = parse_json(path)
    assert isinstance(run, TestRun)
    assert run.source == str(path)
    assert len(run.cases) == 3
    assert run.cases[0].name == "a.test_one"
    assert run.cases[0].status == "passed"
    assert run.cases[0].duration == pytest.approx(0.1)
    assert run.cases[1].status == "failed"
    assert run.cases[2].status == "skipped"


def test_parse_json_invalid_raises(tmp_path: Path):
    path = tmp_path / "bad.json"
    path.write_text("not json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        parse_json(path)


# ---- JUnit XML parser -----------------------------------------------------

def test_parse_junit_xml_basic(tmp_path: Path):
    path = tmp_path / "junit.xml"
    path.write_text(textwrap.dedent("""\
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites>
          <testsuite name="suite1" tests="3" failures="1" skipped="1" time="0.5">
            <testcase classname="suite1" name="passes" time="0.1"/>
            <testcase classname="suite1" name="fails" time="0.2">
              <failure message="boom">stack trace</failure>
            </testcase>
            <testcase classname="suite1" name="skipped_case" time="0.0">
              <skipped/>
            </testcase>
          </testsuite>
        </testsuites>
        """))
    run = parse_junit_xml(path)
    assert len(run.cases) == 3
    by_name = {c.name: c for c in run.cases}
    assert by_name["suite1.passes"].status == "passed"
    assert by_name["suite1.fails"].status == "failed"
    assert by_name["suite1.skipped_case"].status == "skipped"
    assert by_name["suite1.fails"].duration == pytest.approx(0.2)


def test_parse_junit_xml_malformed(tmp_path: Path):
    path = tmp_path / "bad.xml"
    path.write_text("<not-closed>")
    with pytest.raises(ValueError, match="Invalid XML"):
        parse_junit_xml(path)


def test_parse_file_dispatches_by_extension(tmp_path: Path):
    j = tmp_path / "r.json"
    j.write_text('{"tests": [{"name": "x", "status": "passed", "duration": 0}]}')
    x = tmp_path / "r.xml"
    x.write_text('<testsuites><testsuite name="s" tests="1"><testcase classname="s" name="t"/></testsuite></testsuites>')
    assert len(parse_file(j).cases) == 1
    assert len(parse_file(x).cases) == 1
    txt = tmp_path / "r.txt"
    txt.write_text("hi")
    with pytest.raises(ValueError, match="Unsupported"):
        parse_file(txt)


def test_parse_file_missing(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        parse_file(tmp_path / "nope.json")


# ---- Aggregation ----------------------------------------------------------

def _run(name: str, *cases) -> TestRun:
    return TestRun(source=name, cases=[TestCase(*c) for c in cases])


def test_aggregate_totals():
    r1 = _run("r1", ("t.a", "passed", 0.1), ("t.b", "failed", 0.2))
    r2 = _run("r2", ("t.a", "passed", 0.15), ("t.c", "skipped", 0.0))
    summary = aggregate([r1, r2])
    assert summary.total == 4
    assert summary.passed == 2
    assert summary.failed == 1
    assert summary.skipped == 1
    assert summary.duration == pytest.approx(0.45)
    assert summary.runs == 2


# ---- Flaky detection ------------------------------------------------------

def test_find_flaky_identifies_inconsistent_tests():
    # t.flaky passes once, fails once -> flaky.
    # t.stable always passes -> not flaky.
    # t.broken always fails -> not flaky (just broken).
    r1 = _run("r1", ("t.flaky", "passed", 0.1), ("t.stable", "passed", 0.1), ("t.broken", "failed", 0.1))
    r2 = _run("r2", ("t.flaky", "failed", 0.1), ("t.stable", "passed", 0.1), ("t.broken", "failed", 0.1))
    flaky = find_flaky([r1, r2])
    names = [f.name for f in flaky]
    assert names == ["t.flaky"]
    assert flaky[0].pass_count == 1
    assert flaky[0].fail_count == 1


def test_find_flaky_ignores_skipped():
    r1 = _run("r1", ("t.x", "passed", 0))
    r2 = _run("r2", ("t.x", "skipped", 0))
    assert find_flaky([r1, r2]) == []


# ---- Markdown rendering ---------------------------------------------------

def test_render_markdown_contains_expected_sections():
    r1 = _run("r1", ("t.a", "passed", 0.1), ("t.b", "failed", 0.2))
    r2 = _run("r2", ("t.a", "failed", 0.15))
    md = render_markdown([r1, r2])
    assert "# Test Results Summary" in md
    assert "Total" in md and "Passed" in md and "Failed" in md
    assert "Flaky" in md
    assert "t.a" in md  # flaky test listed
    assert "| Metric | Count |" in md  # totals table


def test_render_markdown_no_flaky_section_when_none():
    r1 = _run("r1", ("t.a", "passed", 0.1))
    md = render_markdown([r1])
    assert "No flaky tests detected" in md
