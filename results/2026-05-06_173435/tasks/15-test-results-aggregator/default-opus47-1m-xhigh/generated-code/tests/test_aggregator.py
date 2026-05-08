# TDD test suite for the test results aggregator.
# Each section was written FIRST as a failing test, then made to pass.
import json
import os
import tempfile
import textwrap
from pathlib import Path

import pytest

from aggregator import (
    Aggregator,
    TestCase,
    parse_file,
    parse_json,
    parse_junit_xml,
    render_markdown,
)


# ---------- JUnit XML parsing ----------

def test_parse_junit_xml_returns_test_cases_with_status_and_duration(tmp_path):
    xml = textwrap.dedent(
        """\
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites name="root">
          <testsuite name="suite_a" tests="3" failures="1" skipped="1" time="1.5">
            <testcase classname="suite_a" name="test_one" time="0.5"/>
            <testcase classname="suite_a" name="test_two" time="0.7">
              <failure message="boom">stack trace here</failure>
            </testcase>
            <testcase classname="suite_a" name="test_three" time="0.3">
              <skipped/>
            </testcase>
          </testsuite>
        </testsuites>
        """
    )
    path = tmp_path / "junit.xml"
    path.write_text(xml)

    cases = parse_junit_xml(path)

    assert len(cases) == 3
    assert cases[0].full_name == "suite_a.test_one"
    assert cases[0].status == "passed"
    assert cases[0].duration == pytest.approx(0.5)
    assert cases[1].status == "failed"
    assert cases[1].failure_message == "boom"
    assert cases[2].status == "skipped"


def test_parse_junit_xml_handles_error_element_as_failure(tmp_path):
    xml = """<?xml version="1.0"?>
    <testsuite name="s" tests="1">
      <testcase classname="s" name="boom" time="0.1">
        <error message="kaboom">trace</error>
      </testcase>
    </testsuite>"""
    path = tmp_path / "junit.xml"
    path.write_text(xml)
    cases = parse_junit_xml(path)
    assert cases[0].status == "failed"
    assert cases[0].failure_message == "kaboom"


def test_parse_junit_xml_raises_friendly_error_on_invalid_xml(tmp_path):
    path = tmp_path / "bad.xml"
    path.write_text("<not-xml")
    with pytest.raises(ValueError, match="Invalid JUnit XML"):
        parse_junit_xml(path)


# ---------- JSON parsing ----------

def test_parse_json_returns_test_cases(tmp_path):
    payload = {
        "results": [
            {"suite": "suite_b", "name": "alpha", "status": "passed", "duration": 0.2},
            {"suite": "suite_b", "name": "beta", "status": "failed", "duration": 0.4,
             "message": "assertion broke"},
            {"suite": "suite_b", "name": "gamma", "status": "skipped", "duration": 0.0},
        ]
    }
    path = tmp_path / "results.json"
    path.write_text(json.dumps(payload))

    cases = parse_json(path)

    assert {c.full_name for c in cases} == {
        "suite_b.alpha", "suite_b.beta", "suite_b.gamma"
    }
    failed = [c for c in cases if c.status == "failed"][0]
    assert failed.failure_message == "assertion broke"


def test_parse_json_normalizes_status_aliases(tmp_path):
    # Common aliases: "pass"/"ok"/"success", "fail"/"error", "skip"/"pending"
    payload = {"results": [
        {"suite": "s", "name": "a", "status": "pass", "duration": 0.1},
        {"suite": "s", "name": "b", "status": "fail", "duration": 0.1},
        {"suite": "s", "name": "c", "status": "skip", "duration": 0.0},
        {"suite": "s", "name": "d", "status": "ok", "duration": 0.1},
    ]}
    path = tmp_path / "results.json"
    path.write_text(json.dumps(payload))
    cases = parse_json(path)
    statuses = {c.full_name.split(".")[1]: c.status for c in cases}
    assert statuses == {"a": "passed", "b": "failed", "c": "skipped", "d": "passed"}


def test_parse_json_raises_friendly_error_on_invalid_json(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text("{not valid")
    with pytest.raises(ValueError, match="Invalid JSON"):
        parse_json(path)


# ---------- Format dispatch ----------

def test_parse_file_dispatches_by_extension(tmp_path):
    xml_path = tmp_path / "a.xml"
    xml_path.write_text(
        '<?xml version="1.0"?><testsuite name="s" tests="1">'
        '<testcase classname="s" name="t" time="0.1"/></testsuite>'
    )
    json_path = tmp_path / "a.json"
    json_path.write_text(json.dumps(
        {"results": [{"suite": "s", "name": "t", "status": "passed", "duration": 0.1}]}
    ))
    assert len(parse_file(xml_path)) == 1
    assert len(parse_file(json_path)) == 1


def test_parse_file_rejects_unknown_extension(tmp_path):
    p = tmp_path / "data.txt"
    p.write_text("hello")
    with pytest.raises(ValueError, match="Unsupported"):
        parse_file(p)


# ---------- Aggregation totals ----------

def test_aggregator_totals_across_runs():
    agg = Aggregator()
    agg.add_run("run1", [
        TestCase("s", "a", "passed", 0.5),
        TestCase("s", "b", "failed", 0.7, failure_message="oops"),
        TestCase("s", "c", "skipped", 0.0),
    ])
    agg.add_run("run2", [
        TestCase("s", "a", "passed", 0.4),
        TestCase("s", "b", "passed", 0.6),  # was failing — flaky
        TestCase("s", "c", "skipped", 0.0),
    ])

    totals = agg.totals()
    assert totals["passed"] == 3
    assert totals["failed"] == 1
    assert totals["skipped"] == 2
    assert totals["total"] == 6
    assert totals["duration"] == pytest.approx(2.2)
    assert totals["runs"] == 2


# ---------- Flaky detection ----------

def test_aggregator_flags_flaky_tests():
    agg = Aggregator()
    agg.add_run("r1", [
        TestCase("s", "a", "passed", 0.1),
        TestCase("s", "b", "failed", 0.1, failure_message="x"),
    ])
    agg.add_run("r2", [
        TestCase("s", "a", "failed", 0.1, failure_message="y"),
        TestCase("s", "b", "failed", 0.1, failure_message="x"),
    ])
    agg.add_run("r3", [
        TestCase("s", "a", "passed", 0.1),
        TestCase("s", "b", "failed", 0.1, failure_message="x"),
    ])

    flaky = agg.flaky_tests()
    # 'a' passed twice, failed once -> flaky.
    # 'b' failed all three times -> not flaky (consistently failing).
    assert [f.full_name for f in flaky] == ["s.a"]
    assert flaky[0].pass_count == 2
    assert flaky[0].fail_count == 1


def test_aggregator_skipped_runs_do_not_make_a_test_flaky():
    agg = Aggregator()
    agg.add_run("r1", [TestCase("s", "a", "passed", 0.1)])
    agg.add_run("r2", [TestCase("s", "a", "skipped", 0.0)])
    agg.add_run("r3", [TestCase("s", "a", "passed", 0.1)])
    assert agg.flaky_tests() == []


# ---------- Markdown rendering ----------

def test_render_markdown_includes_totals_and_flaky_section():
    agg = Aggregator()
    agg.add_run("r1", [
        TestCase("s", "a", "passed", 0.1),
        TestCase("s", "b", "failed", 0.2, failure_message="boom"),
    ])
    agg.add_run("r2", [
        TestCase("s", "a", "failed", 0.1, failure_message="flake"),
        TestCase("s", "b", "failed", 0.2, failure_message="boom"),
    ])

    md = render_markdown(agg)

    assert "# Test Results Summary" in md
    assert "| Passed |" in md
    assert "| Failed |" in md
    # Flaky section MUST appear and reference the flaky case.
    assert "## Flaky tests" in md
    assert "s.a" in md
    # Failure section MUST appear with the consistently-failing test.
    assert "## Failures" in md
    assert "s.b" in md
    # Job-summary preamble — overall pass/fail status.
    assert "Status" in md


def test_render_markdown_says_all_passed_when_no_failures_or_flakes():
    agg = Aggregator()
    agg.add_run("r1", [TestCase("s", "a", "passed", 0.1)])
    md = render_markdown(agg)
    assert "All tests passed" in md
    assert "## Failures" not in md
    assert "## Flaky tests" not in md


# ---------- End-to-end via CLI/main entry ----------

def test_main_writes_summary_to_output_file(tmp_path, capsys):
    from aggregator import main

    fixtures = tmp_path / "fixtures"
    fixtures.mkdir()

    # JUnit fixture
    (fixtures / "run1.xml").write_text(textwrap.dedent("""\
        <?xml version="1.0"?>
        <testsuite name="suite" tests="2" time="0.3">
          <testcase classname="suite" name="passes" time="0.1"/>
          <testcase classname="suite" name="flakes" time="0.2">
            <failure message="boom"/>
          </testcase>
        </testsuite>
    """))

    # JSON fixture, same tests, different outcomes
    (fixtures / "run2.json").write_text(json.dumps({
        "results": [
            {"suite": "suite", "name": "passes", "status": "passed", "duration": 0.1},
            {"suite": "suite", "name": "flakes", "status": "passed", "duration": 0.2},
        ]
    }))

    summary = tmp_path / "summary.md"
    rc = main([str(fixtures / "run1.xml"), str(fixtures / "run2.json"),
               "--output", str(summary)])
    assert rc == 0
    text = summary.read_text()
    assert "Test Results Summary" in text
    assert "suite.flakes" in text  # flagged as flaky


def test_main_returns_non_zero_when_no_input_files(tmp_path, capsys):
    from aggregator import main
    rc = main([])
    captured = capsys.readouterr()
    assert rc != 0
    assert "no input" in captured.err.lower()


def test_main_succeeds_by_default_even_when_tests_failed(tmp_path):
    """Default policy: producing the summary is success; failures appear
    in the markdown but don't break the workflow step."""
    from aggregator import main
    f = tmp_path / "fail.json"
    f.write_text(json.dumps({"results": [
        {"suite": "s", "name": "t", "status": "failed", "duration": 0.1,
         "message": "x"},
    ]}))
    rc = main([str(f), "--output", str(tmp_path / "out.md")])
    assert rc == 0


def test_main_returns_non_zero_with_fail_on_failures_flag(tmp_path):
    """Opt-in: --fail-on-failures bubbles the failure up as exit 1."""
    from aggregator import main
    f = tmp_path / "fail.json"
    f.write_text(json.dumps({"results": [
        {"suite": "s", "name": "t", "status": "failed", "duration": 0.1,
         "message": "x"},
    ]}))
    rc = main([str(f), "--output", str(tmp_path / "out.md"),
               "--fail-on-failures"])
    assert rc == 1
