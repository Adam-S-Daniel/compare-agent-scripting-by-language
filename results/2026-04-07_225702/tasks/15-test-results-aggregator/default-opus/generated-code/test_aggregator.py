"""
TDD tests for test results aggregator.

Approach: We build up the aggregator piece by piece using red/green/refactor.
Each test is written FIRST (red), then we write the minimum code to pass (green),
then refactor as needed.
"""

import json
import os
import tempfile
import textwrap

import pytest

# ── Round 1: Parse JUnit XML ─────────────────────────────────────────────────

JUNIT_SIMPLE = textwrap.dedent("""\
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuite name="math" tests="3" failures="1" skipped="0" time="1.23">
      <testcase classname="math" name="test_add" time="0.5"/>
      <testcase classname="math" name="test_subtract" time="0.3">
        <failure message="expected 5 got 4">AssertionError</failure>
      </testcase>
      <testcase classname="math" name="test_multiply" time="0.43"/>
    </testsuite>
""")


def test_parse_junit_xml_returns_test_results():
    """A JUnit XML file should produce a list of TestResult objects."""
    from aggregator import parse_junit_xml

    results = parse_junit_xml(JUNIT_SIMPLE)
    assert len(results) == 3


def test_parse_junit_xml_captures_pass_fail():
    """Each result should have a status: passed, failed, or skipped."""
    from aggregator import parse_junit_xml

    results = parse_junit_xml(JUNIT_SIMPLE)
    statuses = {r.name: r.status for r in results}
    assert statuses["test_add"] == "passed"
    assert statuses["test_subtract"] == "failed"
    assert statuses["test_multiply"] == "passed"


def test_parse_junit_xml_captures_duration():
    """Each result should have a duration in seconds."""
    from aggregator import parse_junit_xml

    results = parse_junit_xml(JUNIT_SIMPLE)
    durations = {r.name: r.duration for r in results}
    assert durations["test_add"] == pytest.approx(0.5)
    assert durations["test_subtract"] == pytest.approx(0.3)


def test_parse_junit_xml_captures_suite_name():
    """Each result should carry the suite name."""
    from aggregator import parse_junit_xml

    results = parse_junit_xml(JUNIT_SIMPLE)
    assert all(r.suite == "math" for r in results)


def test_parse_junit_xml_skipped():
    """Skipped tests should have status 'skipped'."""
    from aggregator import parse_junit_xml

    xml = textwrap.dedent("""\
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite name="skip_suite" tests="1" failures="0" skipped="1" time="0">
          <testcase classname="skip_suite" name="test_todo" time="0">
            <skipped message="not implemented"/>
          </testcase>
        </testsuite>
    """)
    results = parse_junit_xml(xml)
    assert results[0].status == "skipped"


# ── Round 2: Parse JSON results ──────────────────────────────────────────────

JSON_SIMPLE = json.dumps({
    "suite": "api",
    "tests": [
        {"name": "test_get", "status": "passed", "duration": 0.12},
        {"name": "test_post", "status": "failed", "duration": 0.45,
         "message": "404 Not Found"},
        {"name": "test_delete", "status": "skipped", "duration": 0.0},
    ],
})


def test_parse_json_returns_test_results():
    """A JSON results string should produce TestResult objects."""
    from aggregator import parse_json_results

    results = parse_json_results(JSON_SIMPLE)
    assert len(results) == 3


def test_parse_json_captures_statuses():
    from aggregator import parse_json_results

    results = parse_json_results(JSON_SIMPLE)
    statuses = {r.name: r.status for r in results}
    assert statuses["test_get"] == "passed"
    assert statuses["test_post"] == "failed"
    assert statuses["test_delete"] == "skipped"


def test_parse_json_captures_duration():
    from aggregator import parse_json_results

    results = parse_json_results(JSON_SIMPLE)
    durations = {r.name: r.duration for r in results}
    assert durations["test_get"] == pytest.approx(0.12)


def test_parse_json_captures_suite():
    from aggregator import parse_json_results

    results = parse_json_results(JSON_SIMPLE)
    assert all(r.suite == "api" for r in results)


# ── Round 3: Auto-detect format and load from file ───────────────────────────

def test_load_file_detects_xml(tmp_path):
    """load_results_file should auto-detect .xml as JUnit."""
    from aggregator import load_results_file

    p = tmp_path / "results.xml"
    p.write_text(JUNIT_SIMPLE)
    results = load_results_file(str(p))
    assert len(results) == 3


def test_load_file_detects_json(tmp_path):
    """load_results_file should auto-detect .json."""
    from aggregator import load_results_file

    p = tmp_path / "results.json"
    p.write_text(JSON_SIMPLE)
    results = load_results_file(str(p))
    assert len(results) == 3


def test_load_file_unknown_format(tmp_path):
    """Unknown extensions should raise a clear error."""
    from aggregator import load_results_file

    p = tmp_path / "results.csv"
    p.write_text("a,b,c")
    with pytest.raises(ValueError, match="Unsupported.*csv"):
        load_results_file(str(p))


def test_load_file_missing():
    """Missing file should raise FileNotFoundError."""
    from aggregator import load_results_file

    with pytest.raises(FileNotFoundError):
        load_results_file("/nonexistent/file.xml")


def test_load_file_malformed_xml(tmp_path):
    """Malformed XML should raise a clear error."""
    from aggregator import load_results_file

    p = tmp_path / "bad.xml"
    p.write_text("<not valid xml>>>")
    with pytest.raises(ValueError, match="Failed to parse"):
        load_results_file(str(p))


def test_load_file_malformed_json(tmp_path):
    """Malformed JSON should raise a clear error."""
    from aggregator import load_results_file

    p = tmp_path / "bad.json"
    p.write_text("{not json}")
    with pytest.raises(ValueError, match="Failed to parse"):
        load_results_file(str(p))


# ── Round 4: Aggregate totals ────────────────────────────────────────────────

def test_aggregate_totals_basic():
    """aggregate() should compute passed/failed/skipped/duration totals."""
    from aggregator import TestResult, aggregate

    results = [
        TestResult("s", "a", "passed", 1.0),
        TestResult("s", "b", "failed", 2.0),
        TestResult("s", "c", "skipped", 0.0),
        TestResult("s", "d", "passed", 0.5),
    ]
    totals = aggregate(results)
    assert totals.passed == 2
    assert totals.failed == 1
    assert totals.skipped == 1
    assert totals.total == 4
    assert totals.duration == pytest.approx(3.5)


def test_aggregate_empty():
    """Aggregating zero results should return zeroes."""
    from aggregator import aggregate

    totals = aggregate([])
    assert totals.total == 0
    assert totals.passed == 0
    assert totals.duration == pytest.approx(0.0)


# ── Round 5: Flaky test detection ────────────────────────────────────────────

def test_detect_flaky_tests():
    """A test that passes in one run but fails in another is flaky."""
    from aggregator import TestResult, find_flaky_tests

    results = [
        # Run 1
        TestResult("s", "test_network", "passed", 0.1),
        TestResult("s", "test_db", "passed", 0.2),
        # Run 2
        TestResult("s", "test_network", "failed", 0.3),
        TestResult("s", "test_db", "passed", 0.1),
    ]
    flaky = find_flaky_tests(results)
    assert "test_network" in flaky
    assert "test_db" not in flaky


def test_detect_flaky_skipped_not_flaky():
    """A test that is skipped in one run and passes in another is NOT flaky."""
    from aggregator import TestResult, find_flaky_tests

    results = [
        TestResult("s", "test_x", "passed", 0.1),
        TestResult("s", "test_x", "skipped", 0.0),
    ]
    flaky = find_flaky_tests(results)
    assert "test_x" not in flaky


def test_no_flaky_when_consistent():
    """All-pass or all-fail should not be flaky."""
    from aggregator import TestResult, find_flaky_tests

    results = [
        TestResult("s", "test_a", "passed", 0.1),
        TestResult("s", "test_a", "passed", 0.1),
        TestResult("s", "test_b", "failed", 0.1),
        TestResult("s", "test_b", "failed", 0.1),
    ]
    flaky = find_flaky_tests(results)
    assert len(flaky) == 0


# ── Round 6: Markdown summary generation ─────────────────────────────────────

def test_generate_markdown_contains_totals():
    """The markdown summary should include pass/fail/skip counts."""
    from aggregator import TestResult, aggregate, generate_markdown

    results = [
        TestResult("unit", "test_a", "passed", 0.5),
        TestResult("unit", "test_b", "failed", 1.0),
        TestResult("unit", "test_c", "skipped", 0.0),
    ]
    totals = aggregate(results)
    md = generate_markdown(totals, results)
    assert "3" in md  # total=3
    assert "1" in md  # passed=1, failed=1, skipped=1
    assert "Passed" in md


def test_generate_markdown_contains_totals_v2():
    """Verify exact counts appear in the markdown output."""
    from aggregator import TestResult, aggregate, generate_markdown

    results = [
        TestResult("unit", "test_a", "passed", 0.5),
        TestResult("unit", "test_b", "passed", 1.0),
        TestResult("unit", "test_c", "failed", 0.3),
        TestResult("unit", "test_d", "skipped", 0.0),
    ]
    totals = aggregate(results)
    md = generate_markdown(totals, results)
    # Should contain the total counts somewhere
    assert "4" in md  # total
    assert "2" in md  # passed


def test_generate_markdown_shows_failures():
    """Failed tests should be listed in the markdown."""
    from aggregator import TestResult, aggregate, generate_markdown

    results = [
        TestResult("unit", "test_ok", "passed", 0.5),
        TestResult("unit", "test_broken", "failed", 1.0),
    ]
    totals = aggregate(results)
    md = generate_markdown(totals, results)
    assert "test_broken" in md


def test_generate_markdown_shows_flaky():
    """Flaky tests should be called out in the markdown."""
    from aggregator import TestResult, aggregate, generate_markdown

    results = [
        TestResult("unit", "test_flaky_one", "passed", 0.5),
        TestResult("unit", "test_flaky_one", "failed", 0.3),
        TestResult("unit", "test_stable", "passed", 0.2),
        TestResult("unit", "test_stable", "passed", 0.1),
    ]
    totals = aggregate(results)
    md = generate_markdown(totals, results)
    assert "test_flaky_one" in md
    assert "flaky" in md.lower()


def test_generate_markdown_shows_duration():
    """Total duration should appear in the markdown."""
    from aggregator import TestResult, aggregate, generate_markdown

    results = [
        TestResult("unit", "test_a", "passed", 1.5),
        TestResult("unit", "test_b", "passed", 2.5),
    ]
    totals = aggregate(results)
    md = generate_markdown(totals, results)
    assert "4.0" in md or "4.00" in md


def test_generate_markdown_is_valid_markdown():
    """Output should contain markdown headings and table syntax."""
    from aggregator import TestResult, aggregate, generate_markdown

    results = [
        TestResult("unit", "test_a", "passed", 0.5),
    ]
    totals = aggregate(results)
    md = generate_markdown(totals, results)
    assert md.startswith("#") or md.startswith("## ")
    assert "|" in md  # table syntax


# ── Round 7: End-to-end with fixture files ───────────────────────────────────

def test_end_to_end_with_fixtures():
    """Load multiple fixture files, aggregate, and produce markdown."""
    from aggregator import load_results_file, aggregate, generate_markdown

    fixture_dir = os.path.join(os.path.dirname(__file__), "fixtures")
    xml_file = os.path.join(fixture_dir, "junit_run1.xml")
    json_file = os.path.join(fixture_dir, "json_run1.json")

    all_results = []
    all_results.extend(load_results_file(xml_file))
    all_results.extend(load_results_file(json_file))

    totals = aggregate(all_results)
    md = generate_markdown(totals, all_results)

    # Sanity: we loaded results from both files
    assert totals.total > 0
    assert isinstance(md, str)
    assert len(md) > 50


def test_end_to_end_flaky_across_formats():
    """A test appearing in both XML and JSON with different outcomes is flaky."""
    from aggregator import load_results_file, find_flaky_tests

    fixture_dir = os.path.join(os.path.dirname(__file__), "fixtures")
    # These fixtures are designed so 'test_network_call' passes in XML, fails in JSON
    xml_file = os.path.join(fixture_dir, "junit_run1.xml")
    json_file = os.path.join(fixture_dir, "json_run2.json")

    all_results = []
    all_results.extend(load_results_file(xml_file))
    all_results.extend(load_results_file(json_file))

    flaky = find_flaky_tests(all_results)
    assert "test_network_call" in flaky
