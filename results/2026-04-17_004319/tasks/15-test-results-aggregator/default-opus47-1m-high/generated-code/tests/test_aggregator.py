"""
Unit tests for the test results aggregator.

Written following red/green TDD: each test was authored before the
corresponding implementation, then the minimum code was added to make
the test pass.
"""
from __future__ import annotations

import json
import os
import textwrap
from pathlib import Path

import pytest

from aggregator import (
    TestCase,
    TestRun,
    aggregate,
    find_flaky,
    generate_markdown,
    parse_file,
    parse_json,
    parse_junit_xml,
    run_cli,
)


# ---------------------------------------------------------------------------
# JUnit XML parsing
# ---------------------------------------------------------------------------


def test_parse_junit_xml_basic(tmp_path: Path) -> None:
    """A minimal JUnit file with one passing case should parse correctly."""
    xml = textwrap.dedent(
        """\
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite name="suite1" tests="1" failures="0" skipped="0" time="0.25">
            <testcase classname="suite1" name="test_one" time="0.25"/>
        </testsuite>
        """
    )
    f = tmp_path / "junit.xml"
    f.write_text(xml)

    run = parse_junit_xml(f)

    assert run.suite_name == "suite1"
    assert len(run.cases) == 1
    case = run.cases[0]
    assert case.name == "test_one"
    assert case.classname == "suite1"
    assert case.status == "passed"
    assert case.duration == pytest.approx(0.25)


def test_parse_junit_xml_failure_and_skip(tmp_path: Path) -> None:
    """JUnit failure/error/skipped elements should become the right status."""
    xml = textwrap.dedent(
        """\
        <testsuite name="suite2" tests="3" failures="1" skipped="1" time="1.5">
            <testcase classname="c" name="t_pass" time="0.5"/>
            <testcase classname="c" name="t_fail" time="0.5">
                <failure message="boom">stack trace</failure>
            </testcase>
            <testcase classname="c" name="t_skip" time="0.5">
                <skipped/>
            </testcase>
        </testsuite>
        """
    )
    f = tmp_path / "junit.xml"
    f.write_text(xml)

    run = parse_junit_xml(f)
    statuses = {c.name: c.status for c in run.cases}
    assert statuses == {"t_pass": "passed", "t_fail": "failed", "t_skip": "skipped"}
    assert run.cases[1].message == "boom"


def test_parse_junit_xml_testsuites_wrapper(tmp_path: Path) -> None:
    """Files wrapped in <testsuites> with multiple <testsuite> children also parse."""
    xml = textwrap.dedent(
        """\
        <testsuites>
            <testsuite name="s1" tests="1" time="0.1">
                <testcase classname="c" name="a" time="0.1"/>
            </testsuite>
            <testsuite name="s2" tests="1" time="0.2">
                <testcase classname="c" name="b" time="0.2">
                    <error message="bad">trace</error>
                </testcase>
            </testsuite>
        </testsuites>
        """
    )
    f = tmp_path / "junit.xml"
    f.write_text(xml)

    run = parse_junit_xml(f)
    names = [c.name for c in run.cases]
    assert names == ["a", "b"]
    assert run.cases[1].status == "failed"


def test_parse_junit_xml_missing_file_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        parse_junit_xml(tmp_path / "does-not-exist.xml")


def test_parse_junit_xml_malformed_gives_clear_error(tmp_path: Path) -> None:
    f = tmp_path / "bad.xml"
    f.write_text("<not valid xml")
    with pytest.raises(ValueError, match="Failed to parse JUnit XML"):
        parse_junit_xml(f)


# ---------------------------------------------------------------------------
# JSON parsing
# ---------------------------------------------------------------------------


def test_parse_json_basic(tmp_path: Path) -> None:
    payload = {
        "suite": "json-suite",
        "tests": [
            {"name": "a", "classname": "c", "status": "passed", "duration": 0.3},
            {"name": "b", "classname": "c", "status": "failed", "duration": 0.2,
             "message": "assertion error"},
            {"name": "c", "classname": "c", "status": "skipped", "duration": 0.0},
        ],
    }
    f = tmp_path / "results.json"
    f.write_text(json.dumps(payload))

    run = parse_json(f)
    assert run.suite_name == "json-suite"
    assert len(run.cases) == 3
    assert [c.status for c in run.cases] == ["passed", "failed", "skipped"]
    assert run.cases[1].message == "assertion error"


def test_parse_json_malformed_gives_clear_error(tmp_path: Path) -> None:
    f = tmp_path / "bad.json"
    f.write_text("{not valid json")
    with pytest.raises(ValueError, match="Failed to parse JSON"):
        parse_json(f)


def test_parse_json_requires_tests_list(tmp_path: Path) -> None:
    f = tmp_path / "bad.json"
    f.write_text(json.dumps({"suite": "x"}))
    with pytest.raises(ValueError, match="missing 'tests'"):
        parse_json(f)


# ---------------------------------------------------------------------------
# parse_file dispatch
# ---------------------------------------------------------------------------


def test_parse_file_dispatches_by_extension(tmp_path: Path) -> None:
    xml_path = tmp_path / "r.xml"
    xml_path.write_text(
        '<testsuite name="x" tests="1"><testcase name="t" classname="c" time="0"/></testsuite>'
    )
    json_path = tmp_path / "r.json"
    json_path.write_text(json.dumps({
        "suite": "j",
        "tests": [{"name": "t", "classname": "c", "status": "passed", "duration": 0}],
    }))

    assert parse_file(xml_path).suite_name == "x"
    assert parse_file(json_path).suite_name == "j"


def test_parse_file_unknown_extension_raises(tmp_path: Path) -> None:
    p = tmp_path / "results.txt"
    p.write_text("whatever")
    with pytest.raises(ValueError, match="Unsupported file extension"):
        parse_file(p)


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------


def _run(name: str, cases: list[TestCase]) -> TestRun:
    return TestRun(suite_name=name, cases=cases, source=f"{name}.xml")


def test_aggregate_totals() -> None:
    r1 = _run("s1", [
        TestCase("a", "c", "passed", 0.1),
        TestCase("b", "c", "failed", 0.2, message="x"),
        TestCase("c", "c", "skipped", 0.0),
    ])
    r2 = _run("s2", [
        TestCase("d", "c", "passed", 0.5),
        TestCase("e", "c", "passed", 0.3),
    ])

    agg = aggregate([r1, r2])

    assert agg.total == 5
    assert agg.passed == 3
    assert agg.failed == 1
    assert agg.skipped == 1
    assert agg.duration == pytest.approx(1.1)
    assert agg.runs == [r1, r2]


def test_aggregate_empty_gives_zeros() -> None:
    agg = aggregate([])
    assert agg.total == 0
    assert agg.passed == agg.failed == agg.skipped == 0
    assert agg.duration == 0.0


# ---------------------------------------------------------------------------
# Flaky detection
# ---------------------------------------------------------------------------


def test_find_flaky_identifies_tests_with_mixed_statuses() -> None:
    # A test is flaky when (classname, name) appears with both passed and
    # failed across at least two runs.
    r1 = _run("s", [TestCase("flaky", "c", "passed", 0.1), TestCase("stable", "c", "passed", 0.1)])
    r2 = _run("s", [TestCase("flaky", "c", "failed", 0.1, message="boom"),
                    TestCase("stable", "c", "passed", 0.1)])
    r3 = _run("s", [TestCase("flaky", "c", "passed", 0.1),
                    TestCase("stable", "c", "passed", 0.1)])

    flaky = find_flaky([r1, r2, r3])
    assert len(flaky) == 1
    entry = flaky[0]
    assert entry.name == "flaky"
    assert entry.classname == "c"
    assert entry.passed_count == 2
    assert entry.failed_count == 1


def test_find_flaky_ignores_always_failing_tests() -> None:
    r1 = _run("s", [TestCase("bad", "c", "failed", 0.1)])
    r2 = _run("s", [TestCase("bad", "c", "failed", 0.1)])
    assert find_flaky([r1, r2]) == []


def test_find_flaky_ignores_skipped_runs() -> None:
    """Skipped runs don't count toward flakiness either direction."""
    r1 = _run("s", [TestCase("t", "c", "passed", 0.1)])
    r2 = _run("s", [TestCase("t", "c", "skipped", 0.0)])
    r3 = _run("s", [TestCase("t", "c", "passed", 0.1)])
    assert find_flaky([r1, r2, r3]) == []


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------


def test_generate_markdown_contains_totals_and_headers() -> None:
    r1 = _run("s1", [
        TestCase("a", "c", "passed", 0.1),
        TestCase("b", "c", "failed", 0.2, message="boom"),
    ])
    r2 = _run("s2", [
        TestCase("a", "c", "passed", 0.15),
        TestCase("c", "c", "passed", 0.05),
    ])

    md = generate_markdown(aggregate([r1, r2]), find_flaky([r1, r2]))

    # Must have a top-level heading
    assert md.startswith("# ")
    # Totals table
    assert "Total" in md and "Passed" in md and "Failed" in md and "Skipped" in md
    assert "| 4 |" in md  # total tests
    # Per-run section
    assert "s1" in md and "s2" in md
    # Failures section with the failure message
    assert "boom" in md


def test_generate_markdown_reports_no_flaky_when_none() -> None:
    r1 = _run("s", [TestCase("a", "c", "passed", 0.1)])
    md = generate_markdown(aggregate([r1]), find_flaky([r1]))
    assert "No flaky tests detected" in md


def test_generate_markdown_lists_flaky_tests() -> None:
    r1 = _run("s", [TestCase("flaky", "c", "passed", 0.1)])
    r2 = _run("s", [TestCase("flaky", "c", "failed", 0.1, message="intermittent")])
    md = generate_markdown(aggregate([r1, r2]), find_flaky([r1, r2]))
    assert "Flaky Tests" in md
    assert "flaky" in md
    # pass/fail counts shown
    assert "1" in md


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def test_cli_processes_directory_and_writes_summary(tmp_path: Path) -> None:
    """End-to-end: point the CLI at a directory and check it writes markdown."""
    # Two runs of the same "suite" so we get a flaky test.
    (tmp_path / "run1.xml").write_text(textwrap.dedent(
        """\
        <testsuite name="matrix" tests="2" time="0.3">
            <testcase classname="c" name="stable" time="0.1"/>
            <testcase classname="c" name="flaky" time="0.2"/>
        </testsuite>
        """
    ))
    (tmp_path / "run2.json").write_text(json.dumps({
        "suite": "matrix",
        "tests": [
            {"name": "stable", "classname": "c", "status": "passed", "duration": 0.1},
            {"name": "flaky", "classname": "c", "status": "failed", "duration": 0.2,
             "message": "intermittent"},
        ],
    }))

    out = tmp_path / "summary.md"
    exit_code = run_cli([str(tmp_path), "--output", str(out)])

    assert exit_code == 0
    text = out.read_text()
    assert "Total" in text
    assert "flaky" in text
    # Two runs discovered, totals summed
    assert "| 4 |" in text


def test_cli_writes_to_github_step_summary(tmp_path: Path, monkeypatch) -> None:
    """When GITHUB_STEP_SUMMARY is set and --output is omitted, write there."""
    (tmp_path / "r.json").write_text(json.dumps({
        "suite": "s",
        "tests": [{"name": "t", "classname": "c", "status": "passed", "duration": 0.1}],
    }))
    summary = tmp_path / "step_summary"
    monkeypatch.setenv("GITHUB_STEP_SUMMARY", str(summary))
    # Also ensure the CLI still prints to stdout for visibility in act logs.
    exit_code = run_cli([str(tmp_path)])
    assert exit_code == 0
    assert summary.exists()
    assert "Total" in summary.read_text()


def test_cli_exit_code_nonzero_when_failures_and_flag(tmp_path: Path) -> None:
    """--fail-on-failures makes the CLI exit nonzero if any test failed."""
    (tmp_path / "r.json").write_text(json.dumps({
        "suite": "s",
        "tests": [{"name": "t", "classname": "c", "status": "failed", "duration": 0.1,
                   "message": "nope"}],
    }))
    out = tmp_path / "s.md"
    assert run_cli([str(tmp_path), "--output", str(out), "--fail-on-failures"]) == 1
    # Without the flag the CLI still succeeds.
    assert run_cli([str(tmp_path), "--output", str(out)]) == 0


def test_cli_missing_directory_errors_cleanly(tmp_path: Path, capsys) -> None:
    missing = tmp_path / "nope"
    exit_code = run_cli([str(missing), "--output", str(tmp_path / "s.md")])
    assert exit_code == 2
    err = capsys.readouterr().err
    assert "not found" in err or "does not exist" in err
