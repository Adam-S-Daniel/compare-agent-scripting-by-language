"""
Test Results Aggregator - TDD test suite.

Approach: Red/Green TDD - each test is written first (failing), then
the minimum code is written to make it pass, then we refactor.

Tests cover:
1. JUnit XML parsing
2. JSON format parsing
3. Multi-file aggregation
4. Flaky test detection
5. Markdown summary generation
"""
import pytest
import os
import json
from pathlib import Path

# Import our (not-yet-written) aggregator module
from aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    detect_flaky_tests,
    generate_markdown_summary,
    TestResult,
    TestSuiteResult,
    AggregatedResults,
)


# ─────────────────────────────────────────────
# FIXTURES — paths to sample test result files
# ─────────────────────────────────────────────

FIXTURES_DIR = Path(__file__).parent / "fixtures"


# ─────────────────────────────────────────────
# 1. JUnit XML PARSING TESTS
# ─────────────────────────────────────────────

class TestParseJUnitXML:
    """Tests for JUnit XML format parsing."""

    def test_parse_basic_junit_xml(self):
        """Parse a minimal JUnit XML file and return a TestSuiteResult."""
        xml_path = FIXTURES_DIR / "junit_basic.xml"
        result = parse_junit_xml(str(xml_path))

        assert isinstance(result, TestSuiteResult)
        assert result.name == "BasicSuite"
        assert result.total == 3
        assert result.passed == 2
        assert result.failed == 1
        assert result.skipped == 0
        assert result.duration == pytest.approx(1.5, rel=1e-3)

    def test_parse_junit_xml_with_skipped(self):
        """JUnit XML with skipped tests is parsed correctly."""
        xml_path = FIXTURES_DIR / "junit_with_skipped.xml"
        result = parse_junit_xml(str(xml_path))

        assert result.passed == 3
        assert result.failed == 1
        assert result.skipped == 2
        assert result.total == 6

    def test_parse_junit_xml_individual_tests(self):
        """Individual test cases are captured with name and status."""
        xml_path = FIXTURES_DIR / "junit_basic.xml"
        result = parse_junit_xml(str(xml_path))

        names = [t.name for t in result.tests]
        assert "test_addition" in names
        assert "test_subtraction" in names
        assert "test_division" in names

        # The failing test should have a failure message
        failed = next(t for t in result.tests if t.name == "test_division")
        assert failed.status == "failed"
        assert failed.failure_message is not None

    def test_parse_junit_xml_missing_file(self):
        """Missing file raises FileNotFoundError with clear message."""
        with pytest.raises(FileNotFoundError, match="not found"):
            parse_junit_xml("/nonexistent/path/result.xml")

    def test_parse_junit_xml_invalid_xml(self, tmp_path):
        """Invalid XML raises ValueError with clear message."""
        bad_xml = tmp_path / "bad.xml"
        bad_xml.write_text("this is not xml <<<")
        with pytest.raises(ValueError, match="Invalid XML"):
            parse_junit_xml(str(bad_xml))


# ─────────────────────────────────────────────
# 2. JSON PARSING TESTS
# ─────────────────────────────────────────────

class TestParseJSONResults:
    """Tests for JSON test result format parsing."""

    def test_parse_basic_json_results(self):
        """Parse a JSON test result file into a TestSuiteResult."""
        json_path = FIXTURES_DIR / "results_basic.json"
        result = parse_json_results(str(json_path))

        assert isinstance(result, TestSuiteResult)
        assert result.name == "JSONSuite"
        assert result.passed == 4
        assert result.failed == 1
        assert result.skipped == 1
        assert result.total == 6

    def test_parse_json_individual_tests(self):
        """Individual tests from JSON include name, status, duration."""
        json_path = FIXTURES_DIR / "results_basic.json"
        result = parse_json_results(str(json_path))

        assert len(result.tests) == 6
        test_names = [t.name for t in result.tests]
        assert "test_login" in test_names

        failing = next(t for t in result.tests if t.status == "failed")
        assert failing.failure_message is not None

    def test_parse_json_missing_file(self):
        """Missing JSON file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError, match="not found"):
            parse_json_results("/nonexistent/results.json")

    def test_parse_json_invalid_format(self, tmp_path):
        """JSON missing required keys raises ValueError."""
        bad = tmp_path / "bad.json"
        bad.write_text(json.dumps({"foo": "bar"}))
        with pytest.raises(ValueError, match="Invalid JSON"):
            parse_json_results(str(bad))


# ─────────────────────────────────────────────
# 3. AGGREGATION TESTS
# ─────────────────────────────────────────────

class TestAggregateResults:
    """Tests for aggregating results across multiple suite files."""

    def _make_suite(self, name, passed, failed, skipped, duration, tests=None):
        """Helper to build a TestSuiteResult for aggregation tests."""
        if tests is None:
            tests = []
        return TestSuiteResult(
            name=name,
            passed=passed,
            failed=failed,
            skipped=skipped,
            duration=duration,
            tests=tests,
            source_file="mock.xml",
        )

    def test_aggregate_totals(self):
        """Aggregate sums passed/failed/skipped/duration across suites."""
        suites = [
            self._make_suite("suite-a", passed=5, failed=1, skipped=0, duration=2.0),
            self._make_suite("suite-b", passed=3, failed=0, skipped=2, duration=1.5),
        ]
        agg = aggregate_results(suites)

        assert isinstance(agg, AggregatedResults)
        assert agg.total_passed == 8
        assert agg.total_failed == 1
        assert agg.total_skipped == 2
        assert agg.total_duration == pytest.approx(3.5)

    def test_aggregate_total_tests(self):
        """total_tests = passed + failed + skipped."""
        suites = [
            self._make_suite("a", 4, 2, 1, 1.0),
            self._make_suite("b", 3, 0, 0, 0.5),
        ]
        agg = aggregate_results(suites)
        assert agg.total_tests == 10

    def test_aggregate_suite_list_preserved(self):
        """AggregatedResults preserves the individual suite results."""
        suites = [
            self._make_suite("a", 1, 0, 0, 0.1),
            self._make_suite("b", 2, 1, 0, 0.2),
        ]
        agg = aggregate_results(suites)
        assert len(agg.suites) == 2

    def test_aggregate_empty_list(self):
        """Aggregating an empty list produces zeros."""
        agg = aggregate_results([])
        assert agg.total_tests == 0
        assert agg.total_passed == 0
        assert agg.total_failed == 0
        assert agg.total_duration == 0.0


# ─────────────────────────────────────────────
# 4. FLAKY TEST DETECTION TESTS
# ─────────────────────────────────────────────

class TestDetectFlakyTests:
    """Tests for identifying tests that pass in some runs and fail in others."""

    def _make_test(self, name, status, suite="suite-a"):
        return TestResult(name=name, status=status, duration=0.1,
                          failure_message=None if status != "failed" else "error",
                          classname="", suite=suite)

    def test_detects_flaky_test(self):
        """A test that passes in run-1 and fails in run-2 is flaky."""
        suites = [
            TestSuiteResult("run-1", 1, 0, 0, 0.1,
                            [self._make_test("test_foo", "passed", "run-1")],
                            "run1.xml"),
            TestSuiteResult("run-2", 0, 1, 0, 0.1,
                            [self._make_test("test_foo", "failed", "run-2")],
                            "run2.xml"),
        ]
        agg = aggregate_results(suites)
        flaky = detect_flaky_tests(agg)

        assert "test_foo" in flaky

    def test_stable_passing_test_not_flaky(self):
        """A test that passes in all runs is not flaky."""
        suites = [
            TestSuiteResult("run-1", 1, 0, 0, 0.1,
                            [self._make_test("test_bar", "passed", "run-1")],
                            "run1.xml"),
            TestSuiteResult("run-2", 1, 0, 0, 0.1,
                            [self._make_test("test_bar", "passed", "run-2")],
                            "run2.xml"),
        ]
        agg = aggregate_results(suites)
        flaky = detect_flaky_tests(agg)
        assert "test_bar" not in flaky

    def test_consistently_failing_test_not_flaky(self):
        """A test that fails in all runs is not flaky — it's broken."""
        suites = [
            TestSuiteResult("run-1", 0, 1, 0, 0.1,
                            [self._make_test("test_baz", "failed", "run-1")],
                            "run1.xml"),
            TestSuiteResult("run-2", 0, 1, 0, 0.1,
                            [self._make_test("test_baz", "failed", "run-2")],
                            "run2.xml"),
        ]
        agg = aggregate_results(suites)
        flaky = detect_flaky_tests(agg)
        assert "test_baz" not in flaky

    def test_flaky_test_reports_pass_fail_counts(self):
        """Flaky test entry includes how many times it passed vs failed."""
        suites = [
            TestSuiteResult("r1", 1, 0, 0, 0.1,
                            [self._make_test("test_flaky", "passed", "r1")], "r1.xml"),
            TestSuiteResult("r2", 1, 0, 0, 0.1,
                            [self._make_test("test_flaky", "passed", "r2")], "r2.xml"),
            TestSuiteResult("r3", 0, 1, 0, 0.1,
                            [self._make_test("test_flaky", "failed", "r3")], "r3.xml"),
        ]
        agg = aggregate_results(suites)
        flaky = detect_flaky_tests(agg)

        assert "test_flaky" in flaky
        info = flaky["test_flaky"]
        assert info["passed"] == 2
        assert info["failed"] == 1


# ─────────────────────────────────────────────
# 5. MARKDOWN SUMMARY GENERATION TESTS
# ─────────────────────────────────────────────

class TestGenerateMarkdownSummary:
    """Tests for generating a GitHub Actions-compatible markdown summary."""

    def _build_aggregated(self, passed=8, failed=2, skipped=1, duration=5.0,
                          flaky=None):
        """Build a minimal AggregatedResults for markdown tests."""
        suites = [
            TestSuiteResult("ubuntu / python-3.10", passed, failed, skipped,
                            duration, [], "file1.xml"),
        ]
        agg = AggregatedResults(
            suites=suites,
            total_passed=passed,
            total_failed=failed,
            total_skipped=skipped,
            total_duration=duration,
        )
        return agg, flaky or {}

    def test_markdown_contains_header(self):
        """Generated markdown includes a top-level header."""
        agg, flaky = self._build_aggregated()
        md = generate_markdown_summary(agg, flaky)
        assert "# Test Results" in md

    def test_markdown_contains_totals(self):
        """Markdown summary includes total passed/failed/skipped."""
        agg, flaky = self._build_aggregated(passed=8, failed=2, skipped=1)
        md = generate_markdown_summary(agg, flaky)
        assert "8" in md   # passed count
        assert "2" in md   # failed count
        assert "1" in md   # skipped count

    def test_markdown_contains_suite_table(self):
        """Markdown includes a per-suite breakdown table."""
        agg, flaky = self._build_aggregated()
        md = generate_markdown_summary(agg, flaky)
        assert "ubuntu / python-3.10" in md
        # Markdown table uses | as column separator
        assert "|" in md

    def test_markdown_reports_flaky_tests(self):
        """When flaky tests exist they appear in the markdown."""
        agg, _ = self._build_aggregated()
        flaky = {"test_login": {"passed": 2, "failed": 1}}
        md = generate_markdown_summary(agg, flaky)
        assert "test_login" in md
        assert "flaky" in md.lower()

    def test_markdown_no_flaky_section_when_clean(self):
        """When no flaky tests, the flaky section is omitted or says 'none'."""
        agg, flaky = self._build_aggregated()
        md = generate_markdown_summary(agg, flaky)
        # Either no flaky section or explicit "none" — no table of flaky tests
        assert "test_login" not in md

    def test_markdown_shows_pass_status_emoji(self):
        """Green checkmark when all tests pass, red X when failures exist."""
        agg_pass, _ = self._build_aggregated(failed=0)
        md_pass = generate_markdown_summary(agg_pass, {})
        assert "✅" in md_pass

        agg_fail, _ = self._build_aggregated(failed=3)
        md_fail = generate_markdown_summary(agg_fail, {})
        assert "❌" in md_fail

    def test_markdown_includes_duration(self):
        """Markdown summary includes total run duration."""
        agg, flaky = self._build_aggregated(duration=12.345)
        md = generate_markdown_summary(agg, flaky)
        # Duration should appear — accept either "12.35" or "12.3" etc.
        assert "12." in md


# ─────────────────────────────────────────────
# 6. INTEGRATION TEST — fixture files end-to-end
# ─────────────────────────────────────────────

class TestEndToEndWithFixtures:
    """Integration tests that exercise the full pipeline with fixture files."""

    def test_full_pipeline_produces_markdown(self):
        """
        Load all fixture files, aggregate, detect flaky tests,
        and produce a non-empty markdown summary.
        """
        fixture_files = [
            (FIXTURES_DIR / "junit_basic.xml", "junit"),
            (FIXTURES_DIR / "junit_with_skipped.xml", "junit"),
            (FIXTURES_DIR / "results_basic.json", "json"),
            (FIXTURES_DIR / "results_run2.json", "json"),
        ]
        suites = []
        for path, fmt in fixture_files:
            if fmt == "junit":
                suites.append(parse_junit_xml(str(path)))
            else:
                suites.append(parse_json_results(str(path)))

        agg = aggregate_results(suites)
        flaky = detect_flaky_tests(agg)
        md = generate_markdown_summary(agg, flaky)

        assert len(md) > 100
        assert "# Test Results" in md

    def test_matrix_build_flaky_detection(self):
        """
        Simulate a 2-run matrix build where one test is flaky
        (passes in run 1, fails in run 2).
        """
        suites = [
            parse_junit_xml(str(FIXTURES_DIR / "matrix_run1.xml")),
            parse_junit_xml(str(FIXTURES_DIR / "matrix_run2.xml")),
        ]
        agg = aggregate_results(suites)
        flaky = detect_flaky_tests(agg)

        # matrix_run2.xml has test_networking fail while matrix_run1.xml passes it
        assert "test_networking" in flaky
