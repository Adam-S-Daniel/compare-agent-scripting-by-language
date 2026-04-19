import pytest
import os
from pathlib import Path
from test_results_aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    find_flaky_tests,
    generate_markdown_summary,
)

FIXTURES_DIR = Path(__file__).parent / "fixtures"


class TestParseJunitXml:
    def test_parse_passing_tests(self):
        """Test parsing JUnit XML with all passing tests."""
        result = parse_junit_xml(str(FIXTURES_DIR / "junit_pass.xml"))

        assert result["passed"] == 3
        assert result["failed"] == 0
        assert result["skipped"] == 0
        assert result["total"] == 3
        assert result["duration"] == pytest.approx(1.234, abs=0.001)
        assert len(result["tests"]) == 3

    def test_parse_mixed_results(self):
        """Test parsing JUnit XML with mixed pass/fail/skip."""
        result = parse_junit_xml(str(FIXTURES_DIR / "junit_mixed.xml"))

        assert result["passed"] == 2
        assert result["failed"] == 1
        assert result["skipped"] == 1
        assert result["total"] == 4
        assert result["duration"] == pytest.approx(2.341, abs=0.001)


class TestParseJson:
    def test_parse_json_passing(self):
        """Test parsing JSON test results with all passing."""
        result = parse_json_results(str(FIXTURES_DIR / "results_pass.json"))

        assert result["passed"] == 2
        assert result["failed"] == 0
        assert result["skipped"] == 0
        assert result["total"] == 2
        assert result["duration"] == pytest.approx(0.987, abs=0.001)

    def test_parse_json_mixed(self):
        """Test parsing JSON with mixed results."""
        result = parse_json_results(str(FIXTURES_DIR / "results_mixed.json"))

        assert result["passed"] == 1
        assert result["failed"] == 1
        assert result["skipped"] == 1
        assert result["total"] == 3


class TestAggregateResults:
    def test_aggregate_single_file(self):
        """Test aggregating a single result file."""
        files = [str(FIXTURES_DIR / "junit_pass.xml")]
        aggregated = aggregate_results(files)

        assert aggregated["total_passed"] == 3
        assert aggregated["total_failed"] == 0
        assert aggregated["total_skipped"] == 0
        assert aggregated["total_duration"] == pytest.approx(1.234, abs=0.001)
        assert aggregated["num_runs"] == 1

    def test_aggregate_multiple_files(self):
        """Test aggregating multiple result files (matrix build simulation)."""
        files = [
            str(FIXTURES_DIR / "junit_pass.xml"),
            str(FIXTURES_DIR / "junit_mixed.xml"),
        ]
        aggregated = aggregate_results(files)

        # 3 passed from first file + 2 passed from second file
        assert aggregated["total_passed"] == 5
        # 0 failed from first + 1 failed from second
        assert aggregated["total_failed"] == 1
        # 0 skipped from first + 1 skipped from second
        assert aggregated["total_skipped"] == 1
        assert aggregated["total_duration"] == pytest.approx(3.575, abs=0.001)
        assert aggregated["num_runs"] == 2

    def test_aggregate_mixed_formats(self):
        """Test aggregating both JUnit XML and JSON files."""
        files = [
            str(FIXTURES_DIR / "junit_pass.xml"),
            str(FIXTURES_DIR / "results_pass.json"),
        ]
        aggregated = aggregate_results(files)

        assert aggregated["total_passed"] == 5
        assert aggregated["total_failed"] == 0
        assert aggregated["num_runs"] == 2


class TestFlakyTests:
    def test_find_flaky_tests(self):
        """Test detecting tests that are flaky (pass in some runs, fail in others)."""
        files = [
            str(FIXTURES_DIR / "junit_run1.xml"),
            str(FIXTURES_DIR / "junit_run2.xml"),
        ]
        flaky = find_flaky_tests(files)

        # test_sometimes_fails should be in flaky list
        assert "test_sometimes_fails" in flaky
        assert len(flaky["test_sometimes_fails"]["runs"]) == 2
        assert flaky["test_sometimes_fails"]["runs"][0]["status"] == "passed"
        assert flaky["test_sometimes_fails"]["runs"][1]["status"] == "failed"

        # test_always_passes should not be flaky
        assert "test_always_passes" not in flaky

    def test_no_flaky_tests(self):
        """Test when there are no flaky tests."""
        files = [
            str(FIXTURES_DIR / "junit_pass.xml"),
            str(FIXTURES_DIR / "junit_pass.xml"),
        ]
        flaky = find_flaky_tests(files)

        assert len(flaky) == 0


class TestMarkdownGeneration:
    def test_generate_markdown_summary(self):
        """Test generating markdown summary from aggregated results."""
        files = [
            str(FIXTURES_DIR / "junit_pass.xml"),
            str(FIXTURES_DIR / "junit_mixed.xml"),
        ]
        aggregated = aggregate_results(files)
        flaky = find_flaky_tests(files)

        markdown = generate_markdown_summary(aggregated, flaky)

        assert "Test Results Summary" in markdown
        assert "Passed" in markdown
        assert "Failed" in markdown
        assert "5" in markdown  # total passed
        assert "1" in markdown  # total failed
        assert "## Flaky Tests" in markdown

    def test_markdown_with_flaky_tests(self):
        """Test markdown generation includes flaky test details."""
        files = [
            str(FIXTURES_DIR / "junit_run1.xml"),
            str(FIXTURES_DIR / "junit_run2.xml"),
        ]
        aggregated = aggregate_results(files)
        flaky = find_flaky_tests(files)

        markdown = generate_markdown_summary(aggregated, flaky)

        assert "## Flaky Tests" in markdown
        assert "test_sometimes_fails" in markdown
