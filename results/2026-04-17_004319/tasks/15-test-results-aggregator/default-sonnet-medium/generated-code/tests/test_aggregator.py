"""Tests for test results aggregator — TDD red/green cycle.

Design: fixtures have known, predictable outputs so we can assert exact values.

Fixture summary (used throughout tests):
  run1/junit.xml  — 4 results: 2 passed, 1 failed (test_login_fail), 1 skipped
  run2/json.json  — 3 results: 3 passed (test_login_fail passes here = flaky)
  run3/junit.xml  — 2 results: 2 passed

Aggregate across all three:
  total=9, passed=7, failed=1, skipped=1, duration=3.30s
  flaky: test_login_fail (1 failed, 1 passed)
"""

import os
import sys
import textwrap
import tempfile
import pytest

# Add parent directory to path so we can import aggregator
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

FIXTURES_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "fixtures")


# ---------------------------------------------------------------------------
# RED phase: these tests fail until aggregator.py is implemented
# ---------------------------------------------------------------------------

class TestParseJunitXml:
    """Tests for JUnit XML parsing."""

    def test_parse_basic_junit_xml(self):
        from aggregator import parse_junit_xml
        results = parse_junit_xml(os.path.join(FIXTURES_DIR, "run1", "junit.xml"))
        assert len(results) == 4

    def test_junit_passed_test(self):
        from aggregator import parse_junit_xml
        results = parse_junit_xml(os.path.join(FIXTURES_DIR, "run1", "junit.xml"))
        passed = [r for r in results if r.name == "test_login_success"]
        assert len(passed) == 1
        assert passed[0].status == "passed"
        assert passed[0].duration == pytest.approx(0.5)

    def test_junit_failed_test(self):
        from aggregator import parse_junit_xml
        results = parse_junit_xml(os.path.join(FIXTURES_DIR, "run1", "junit.xml"))
        failed = [r for r in results if r.name == "test_login_fail"]
        assert len(failed) == 1
        assert failed[0].status == "failed"
        assert "AssertionError" in failed[0].message

    def test_junit_skipped_test(self):
        from aggregator import parse_junit_xml
        results = parse_junit_xml(os.path.join(FIXTURES_DIR, "run1", "junit.xml"))
        skipped = [r for r in results if r.name == "test_token_expiry"]
        assert len(skipped) == 1
        assert skipped[0].status == "skipped"

    def test_junit_suite_name_captured(self):
        from aggregator import parse_junit_xml
        results = parse_junit_xml(os.path.join(FIXTURES_DIR, "run1", "junit.xml"))
        assert all(r.suite == "auth-tests" for r in results)

    def test_junit_invalid_xml_raises(self):
        from aggregator import parse_junit_xml
        with tempfile.NamedTemporaryFile(suffix=".xml", mode="w", delete=False) as f:
            f.write("not xml at all {{")
            path = f.name
        try:
            with pytest.raises(ValueError, match="Invalid XML"):
                parse_junit_xml(path)
        finally:
            os.unlink(path)


class TestParseJsonResults:
    """Tests for JSON test result parsing."""

    def test_parse_basic_json(self):
        from aggregator import parse_json_results
        results = parse_json_results(os.path.join(FIXTURES_DIR, "run2", "json.json"))
        assert len(results) == 3

    def test_json_all_passed(self):
        from aggregator import parse_json_results
        results = parse_json_results(os.path.join(FIXTURES_DIR, "run2", "json.json"))
        assert all(r.status == "passed" for r in results)

    def test_json_test_names(self):
        from aggregator import parse_json_results
        results = parse_json_results(os.path.join(FIXTURES_DIR, "run2", "json.json"))
        names = {r.name for r in results}
        assert names == {"test_get_users", "test_post_user", "test_login_fail"}

    def test_json_duration(self):
        from aggregator import parse_json_results
        results = parse_json_results(os.path.join(FIXTURES_DIR, "run2", "json.json"))
        total = sum(r.duration for r in results)
        assert total == pytest.approx(0.9)

    def test_json_invalid_raises(self):
        from aggregator import parse_json_results
        with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as f:
            f.write("{bad json")
            path = f.name
        try:
            with pytest.raises(ValueError, match="Invalid JSON"):
                parse_json_results(path)
        finally:
            os.unlink(path)


class TestParseFile:
    """Tests for the file-type dispatcher."""

    def test_dispatch_xml(self):
        from aggregator import parse_file
        results = parse_file(os.path.join(FIXTURES_DIR, "run1", "junit.xml"))
        assert len(results) == 4

    def test_dispatch_json(self):
        from aggregator import parse_file
        results = parse_file(os.path.join(FIXTURES_DIR, "run2", "json.json"))
        assert len(results) == 3

    def test_missing_file_raises(self):
        from aggregator import parse_file
        with pytest.raises(FileNotFoundError, match="File not found"):
            parse_file("/nonexistent/path/file.xml")

    def test_unsupported_extension_raises(self):
        from aggregator import parse_file
        with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as f:
            path = f.name
        try:
            with pytest.raises(ValueError, match="Unsupported file format"):
                parse_file(path)
        finally:
            os.unlink(path)


class TestAggregateResults:
    """Tests for result aggregation across multiple runs."""

    def _load_all_fixtures(self):
        from aggregator import parse_file
        return [
            parse_file(os.path.join(FIXTURES_DIR, "run1", "junit.xml")),
            parse_file(os.path.join(FIXTURES_DIR, "run2", "json.json")),
            parse_file(os.path.join(FIXTURES_DIR, "run3", "junit.xml")),
        ]

    def test_total_count(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        assert agg.total == 9

    def test_passed_count(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        assert agg.passed == 7

    def test_failed_count(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        assert agg.failed == 1

    def test_skipped_count(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        assert agg.skipped == 1

    def test_duration_total(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        # run1: 1.0s, run2: 0.9s, run3: 1.4s
        assert agg.duration == pytest.approx(3.3, abs=0.01)

    def test_flaky_test_detected(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        assert "test_login_fail" in agg.flaky_tests

    def test_flaky_test_counts(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        flaky = agg.flaky_tests["test_login_fail"]
        assert flaky["passed"] == 1
        assert flaky["failed"] == 1

    def test_non_flaky_test_not_in_flaky(self):
        from aggregator import aggregate_results
        agg = aggregate_results(self._load_all_fixtures())
        assert "test_login_success" not in agg.flaky_tests

    def test_empty_input(self):
        from aggregator import aggregate_results
        agg = aggregate_results([])
        assert agg.total == 0
        assert agg.passed == 0
        assert agg.flaky_tests == {}


class TestGenerateMarkdownSummary:
    """Tests for markdown summary generation."""

    def _get_agg(self):
        from aggregator import parse_file, aggregate_results
        runs = [
            parse_file(os.path.join(FIXTURES_DIR, "run1", "junit.xml")),
            parse_file(os.path.join(FIXTURES_DIR, "run2", "json.json")),
            parse_file(os.path.join(FIXTURES_DIR, "run3", "junit.xml")),
        ]
        return aggregate_results(runs)

    def test_summary_contains_header(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "## Test Results Summary" in md

    def test_summary_total_tests(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "| Total Tests | 9 |" in md

    def test_summary_passed(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "| Passed | 7 |" in md

    def test_summary_failed(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "| Failed | 1 |" in md

    def test_summary_skipped(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "| Skipped | 1 |" in md

    def test_summary_duration(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "| Duration | 3.30s |" in md

    def test_summary_flaky_section(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        md = generate_markdown_summary(agg, [])
        assert "### Flaky Tests" in md
        assert "test_login_fail" in md

    def test_summary_no_flaky_section_when_none(self):
        from aggregator import generate_markdown_summary, AggregatedResults
        agg = AggregatedResults(total=2, passed=2)
        md = generate_markdown_summary(agg, [])
        assert "### Flaky Tests" not in md

    def test_summary_files_listed(self):
        from aggregator import generate_markdown_summary
        agg = self._get_agg()
        files = ["fixtures/run1/junit.xml", "fixtures/run2/json.json"]
        md = generate_markdown_summary(agg, files)
        assert "fixtures/run1/junit.xml" in md
        assert "fixtures/run2/json.json" in md
