# Test Results Aggregator - TDD Implementation
# Using pytest for testing
#
# Approach:
# 1. Parse JUnit XML and JSON test result files
# 2. Aggregate results across multiple files (matrix build simulation)
# 3. Compute totals: passed, failed, skipped, duration
# 4. Identify flaky tests (passed in some runs, failed in others)
# 5. Generate GitHub Actions job summary in Markdown

import pytest
from pathlib import Path


# ============================================================
# RED: First failing test - JUnit XML parsing
# ============================================================
# We expect parse_junit_xml() to return a list of TestCase objects
# with name, classname, status, and duration fields.

def test_parse_junit_xml_returns_test_cases():
    """Parse a JUnit XML file and return structured test case data."""
    from aggregator import parse_junit_xml

    xml_content = """<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="pytest" time="0.456" tests="3" failures="1" errors="0" skipped="1">
  <testsuite name="test_math" tests="3" failures="1" errors="0" skipped="1" time="0.456">
    <testcase classname="test_math" name="test_add" time="0.100"/>
    <testcase classname="test_math" name="test_subtract" time="0.200">
      <failure message="AssertionError: assert 0 == 1">AssertionError: assert 0 == 1</failure>
    </testcase>
    <testcase classname="test_math" name="test_multiply" time="0.050">
      <skipped message="Skip reason"/>
    </testcase>
  </testsuite>
</testsuites>"""

    cases = parse_junit_xml(xml_content)

    assert len(cases) == 3

    assert cases[0].name == "test_add"
    assert cases[0].classname == "test_math"
    assert cases[0].status == "passed"
    assert cases[0].duration == pytest.approx(0.100)

    assert cases[1].name == "test_subtract"
    assert cases[1].status == "failed"
    assert cases[1].message == "AssertionError: assert 0 == 1"

    assert cases[2].name == "test_multiply"
    assert cases[2].status == "skipped"


# ============================================================
# RED: JUnit XML with no testsuites wrapper (single testsuite)
# ============================================================

def test_parse_junit_xml_single_testsuite():
    """Parse a JUnit XML with a single <testsuite> root element."""
    from aggregator import parse_junit_xml

    xml_content = """<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="api_tests" tests="2" failures="0" errors="0" skipped="0" time="1.5">
  <testcase classname="api_tests.TestUsers" name="test_get_user" time="0.8"/>
  <testcase classname="api_tests.TestUsers" name="test_create_user" time="0.7"/>
</testsuite>"""

    cases = parse_junit_xml(xml_content)
    assert len(cases) == 2
    assert cases[0].status == "passed"
    assert cases[1].status == "passed"


# ============================================================
# RED: JSON format parsing
# ============================================================

def test_parse_json_results_returns_test_cases():
    """Parse a JSON test result file and return structured test case data."""
    from aggregator import parse_json_results

    json_content = """{
  "suite": "unit-tests",
  "timestamp": "2024-01-01T00:00:00Z",
  "tests": [
    {"name": "test_foo", "classname": "TestFoo", "status": "passed", "duration": 0.050},
    {"name": "test_bar", "classname": "TestFoo", "status": "failed", "duration": 0.120,
     "message": "Expected True but got False"},
    {"name": "test_baz", "classname": "TestFoo", "status": "skipped", "duration": 0.001,
     "message": "Not implemented yet"}
  ]
}"""

    cases = parse_json_results(json_content)

    assert len(cases) == 3
    assert cases[0].name == "test_foo"
    assert cases[0].classname == "TestFoo"
    assert cases[0].status == "passed"
    assert cases[0].duration == pytest.approx(0.050)

    assert cases[1].name == "test_bar"
    assert cases[1].status == "failed"
    assert cases[1].message == "Expected True but got False"

    assert cases[2].status == "skipped"


# ============================================================
# RED: Aggregation across multiple runs
# ============================================================

def test_aggregate_results_computes_totals():
    """Aggregate multiple RunResult objects into overall totals."""
    from aggregator import aggregate_results, RunResult, TestCase

    run1 = RunResult(
        run_id="linux-py3.11",
        cases=[
            TestCase("test_add", "math_tests", "passed", 0.1),
            TestCase("test_sub", "math_tests", "failed", 0.2, "AssertionError"),
            TestCase("test_mul", "math_tests", "skipped", 0.0),
        ]
    )
    run2 = RunResult(
        run_id="windows-py3.12",
        cases=[
            TestCase("test_add", "math_tests", "passed", 0.15),
            TestCase("test_sub", "math_tests", "passed", 0.18),
            TestCase("test_mul", "math_tests", "skipped", 0.0),
        ]
    )

    summary = aggregate_results([run1, run2])

    assert summary.total_passed == 3   # test_add(x2) + test_sub(run2)
    assert summary.total_failed == 1   # test_sub(run1)
    assert summary.total_skipped == 2  # test_mul(x2)
    assert summary.total_tests == 6
    assert summary.total_duration == pytest.approx(0.1 + 0.2 + 0.0 + 0.15 + 0.18 + 0.0)


# ============================================================
# RED: Flaky test detection
# ============================================================

def test_detect_flaky_tests():
    """Identify tests that passed in some runs but failed in others."""
    from aggregator import aggregate_results, RunResult, TestCase

    run1 = RunResult(
        run_id="linux",
        cases=[
            TestCase("test_stable_pass", "suite", "passed", 0.1),
            TestCase("test_stable_fail", "suite", "failed", 0.1),
            TestCase("test_flaky", "suite", "passed", 0.1),
        ]
    )
    run2 = RunResult(
        run_id="windows",
        cases=[
            TestCase("test_stable_pass", "suite", "passed", 0.1),
            TestCase("test_stable_fail", "suite", "failed", 0.1),
            TestCase("test_flaky", "suite", "failed", 0.1, "Timeout"),
        ]
    )

    summary = aggregate_results([run1, run2])

    assert "suite::test_flaky" in summary.flaky_tests
    assert "suite::test_stable_pass" not in summary.flaky_tests
    assert "suite::test_stable_fail" not in summary.flaky_tests


# ============================================================
# RED: Markdown summary generation
# ============================================================

def test_generate_markdown_summary_contains_key_sections():
    """Generate a Markdown summary suitable for GitHub Actions job summary."""
    from aggregator import generate_markdown_summary, AggregateSummary, FlakyTest

    summary = AggregateSummary(
        total_passed=5,
        total_failed=1,
        total_skipped=2,
        total_tests=8,
        total_duration=3.14,
        run_count=2,
        flaky_tests={
            "suite::test_flaky": FlakyTest(
                key="suite::test_flaky",
                classname="suite",
                name="test_flaky",
                passed_runs=["linux"],
                failed_runs=["windows"],
            )
        },
        failed_test_details=[
            ("windows", "suite", "test_stable_fail", "AssertionError")
        ]
    )

    md = generate_markdown_summary(summary)

    # Must have a heading
    assert "# Test Results Summary" in md

    # Must show totals
    assert "5" in md   # passed
    assert "1" in md   # failed
    assert "2" in md   # skipped

    # Must show flaky section
    assert "Flaky" in md
    assert "test_flaky" in md

    # Must show failure details
    assert "test_stable_fail" in md
    assert "AssertionError" in md


# ============================================================
# RED: File-based integration - load from disk
# ============================================================

def test_load_results_from_file_junit(tmp_path):
    """Load test results from an actual JUnit XML file on disk."""
    from aggregator import load_results_from_file

    xml_file = tmp_path / "results.xml"
    xml_file.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="suite" tests="1" failures="0" errors="0" skipped="0" time="0.5">
  <testcase classname="suite" name="test_one" time="0.5"/>
</testsuite>""")

    run = load_results_from_file(str(xml_file), run_id="run-1")
    assert run.run_id == "run-1"
    assert len(run.cases) == 1
    assert run.cases[0].status == "passed"


def test_load_results_from_file_json(tmp_path):
    """Load test results from an actual JSON file on disk."""
    from aggregator import load_results_from_file

    json_file = tmp_path / "results.json"
    json_file.write_text("""{
  "suite": "integration",
  "tests": [
    {"name": "test_alpha", "classname": "IntegTests", "status": "passed", "duration": 1.0}
  ]
}""")

    run = load_results_from_file(str(json_file), run_id="run-2")
    assert run.run_id == "run-2"
    assert run.cases[0].name == "test_alpha"


def test_load_results_unknown_format(tmp_path):
    """Raise an error for unsupported file formats."""
    from aggregator import load_results_from_file

    txt_file = tmp_path / "results.txt"
    txt_file.write_text("not a valid format")

    with pytest.raises(ValueError, match="Unsupported file format"):
        load_results_from_file(str(txt_file), run_id="run-3")


# ============================================================
# RED: End-to-end with fixture files
# ============================================================

def test_end_to_end_with_fixtures():
    """Full pipeline: load fixture files, aggregate, generate summary."""
    from aggregator import load_results_from_file, aggregate_results, generate_markdown_summary

    fixtures_dir = Path(__file__).parent / "fixtures"
    fixture_files = [
        ("linux-py3.11", "results_linux_py311.xml"),
        ("linux-py3.12", "results_linux_py312.xml"),
        ("windows-py3.11", "results_windows_py311.json"),
        ("windows-py3.12", "results_windows_py312.json"),
    ]

    runs = []
    for run_id, filename in fixture_files:
        path = fixtures_dir / filename
        runs.append(load_results_from_file(str(path), run_id=run_id))

    summary = aggregate_results(runs)
    md = generate_markdown_summary(summary)

    # Sanity checks on a real end-to-end run
    assert summary.total_tests > 0
    assert summary.run_count == 4
    assert "# Test Results Summary" in md
    # The fixtures include a deliberately flaky test
    assert len(summary.flaky_tests) > 0
