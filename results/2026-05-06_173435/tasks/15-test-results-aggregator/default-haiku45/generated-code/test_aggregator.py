"""Test results aggregator - tests using TDD methodology."""
import pytest
import json
from pathlib import Path
from aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    find_flaky_tests,
    generate_markdown_summary,
)


class TestParseJunitXml:
    """Test parsing of JUnit XML format."""

    def test_parse_valid_junit_xml(self, tmp_path):
        """Test parsing a valid JUnit XML file."""
        # Create a sample JUnit XML file
        junit_file = tmp_path / "results.xml"
        junit_file.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="SampleTests" tests="4" failures="1" skipped="1" time="10.5">
    <testcase name="test_pass" classname="TestClass" time="1.0"/>
    <testcase name="test_fail" classname="TestClass" time="2.0">
      <failure message="Test failed">AssertionError: expected True</failure>
    </testcase>
    <testcase name="test_skip" classname="TestClass" time="0.0">
      <skipped message="Test skipped"/>
    </testcase>
    <testcase name="test_pass_2" classname="TestClass" time="3.0"/>
  </testsuite>
</testsuites>""")

        # Parse the file
        result = parse_junit_xml(str(junit_file))

        # Assert the results
        assert result["passed"] == 2
        assert result["failed"] == 1
        assert result["skipped"] == 1
        assert result["total"] == 4
        assert result["duration"] == 10.5
        assert len(result["tests"]) == 4


class TestParseJsonResults:
    """Test parsing of JSON format."""

    def test_parse_valid_json_results(self, tmp_path):
        """Test parsing a valid JSON results file."""
        json_file = tmp_path / "results.json"
        json_file.write_text(json.dumps({
            "results": [
                {"name": "test_pass", "status": "passed", "duration": 1.5},
                {"name": "test_fail", "status": "failed", "duration": 2.0},
            ],
            "summary": {
                "total": 2,
                "passed": 1,
                "failed": 1,
                "skipped": 0,
                "duration": 3.5,
            }
        }))

        result = parse_json_results(str(json_file))

        assert result["passed"] == 1
        assert result["failed"] == 1
        assert result["skipped"] == 0
        assert result["total"] == 2
        assert result["duration"] == 3.5
        assert len(result["tests"]) == 2


class TestAggregateResults:
    """Test aggregation across multiple result files."""

    def test_aggregate_multiple_results(self, tmp_path):
        """Test aggregating results from multiple files (matrix build)."""
        # Create two result files
        junit_file = tmp_path / "junit.xml"
        junit_file.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Tests" tests="2" failures="0" skipped="0" time="5.0">
    <testcase name="test_a" classname="TestClass" time="2.0"/>
    <testcase name="test_b" classname="TestClass" time="3.0"/>
  </testsuite>
</testsuites>""")

        json_file = tmp_path / "results.json"
        json_file.write_text(json.dumps({
            "results": [
                {"name": "test_c", "status": "passed", "duration": 1.0},
            ],
            "summary": {
                "total": 1,
                "passed": 1,
                "failed": 0,
                "skipped": 0,
                "duration": 1.0,
            }
        }))

        result_files = [str(junit_file), str(json_file)]
        aggregated = aggregate_results(result_files)

        assert aggregated["total_passed"] == 3
        assert aggregated["total_failed"] == 0
        assert aggregated["total_skipped"] == 0
        assert aggregated["total_tests"] == 3
        assert aggregated["total_duration"] == 6.0


class TestFlakyTests:
    """Test detection of flaky tests."""

    def test_find_flaky_tests(self, tmp_path):
        """Test identifying tests that pass in some runs but fail in others."""
        junit_file1 = tmp_path / "run1.xml"
        junit_file1.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Tests" tests="2" failures="0" skipped="0" time="5.0">
    <testcase name="test_flaky" classname="TestClass" time="2.0"/>
    <testcase name="test_stable" classname="TestClass" time="3.0"/>
  </testsuite>
</testsuites>""")

        junit_file2 = tmp_path / "run2.xml"
        junit_file2.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Tests" tests="2" failures="1" skipped="0" time="5.0">
    <testcase name="test_flaky" classname="TestClass" time="2.0">
      <failure message="Failed">Error</failure>
    </testcase>
    <testcase name="test_stable" classname="TestClass" time="3.0"/>
  </testsuite>
</testsuites>""")

        result_files = [str(junit_file1), str(junit_file2)]
        flaky = find_flaky_tests(result_files)

        assert "test_flaky" in flaky
        assert "test_stable" not in flaky
        assert flaky["test_flaky"]["passed_count"] == 1
        assert flaky["test_flaky"]["failed_count"] == 1


class TestMarkdownSummary:
    """Test markdown summary generation."""

    def test_generate_markdown_summary(self, tmp_path):
        """Test generating markdown summary for GitHub Actions."""
        junit_file = tmp_path / "results.xml"
        junit_file.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Tests" tests="3" failures="1" skipped="1" time="5.0">
    <testcase name="test_pass" classname="TestClass" time="1.0"/>
    <testcase name="test_fail" classname="TestClass" time="2.0">
      <failure message="Failed">Error</failure>
    </testcase>
    <testcase name="test_skip" classname="TestClass" time="2.0">
      <skipped message="Skipped"/>
    </testcase>
  </testsuite>
</testsuites>""")

        result_files = [str(junit_file)]
        summary = generate_markdown_summary(result_files)

        assert "✅ Passed: 1" in summary
        assert "❌ Failed: 1" in summary
        assert "⏭️ Skipped: 1" in summary
        assert "Total Tests: 3" in summary
        assert "Duration" in summary
