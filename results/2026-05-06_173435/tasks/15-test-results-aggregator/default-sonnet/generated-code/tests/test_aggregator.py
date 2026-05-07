"""
TDD tests for the test results aggregator.
Written FIRST (red phase) before aggregator.py exists.

Fixture data summary used for exact-value assertions:
  fixtures/junit_run1.xml : 3 tests, 2 pass (test_a, test_c), 1 fail (test_b), 0.60s
  fixtures/junit_run2.xml : 3 tests, 2 pass (test_a, test_b), 1 fail (test_c), 0.60s
  fixtures/json_run1.json : 2 tests, 1 pass (test_d), 1 skip (test_e), 0.50s
  Aggregated: 8 total, 5 passed, 2 failed, 1 skipped, 1.70s
  Flaky: TestClass.test_b (fail run1, pass run2), TestClass.test_c (pass run1, fail run2)
"""
import pytest
from pathlib import Path

FIXTURES = Path(__file__).parent.parent / "fixtures"

# Import under test — will fail until aggregator.py is created (RED phase).
from aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    detect_flaky_tests,
    generate_markdown,
)


class TestParseJunitXml:
    def test_returns_list_of_results(self):
        results = parse_junit_xml(FIXTURES / "junit_run1.xml")
        assert isinstance(results, list)
        assert len(results) == 3

    def test_passed_test_has_correct_fields(self):
        results = parse_junit_xml(FIXTURES / "junit_run1.xml")
        test_a = next(r for r in results if r.name == "test_a")
        assert test_a.status == "passed"
        assert test_a.classname == "TestClass"
        assert abs(test_a.duration - 0.10) < 0.001

    def test_failed_test_has_failure_message(self):
        results = parse_junit_xml(FIXTURES / "junit_run1.xml")
        test_b = next(r for r in results if r.name == "test_b")
        assert test_b.status == "failed"
        assert test_b.message is not None
        assert len(test_b.message) > 0

    def test_file_source_recorded(self):
        results = parse_junit_xml(FIXTURES / "junit_run1.xml")
        assert all(r.file_source == "junit_run1.xml" for r in results)

    def test_missing_file_raises_error(self):
        with pytest.raises((FileNotFoundError, Exception)):
            parse_junit_xml(FIXTURES / "nonexistent.xml")


class TestParseJsonResults:
    def test_returns_list_of_results(self):
        results = parse_json_results(FIXTURES / "json_run1.json")
        assert isinstance(results, list)
        assert len(results) == 2

    def test_passed_test_parsed_correctly(self):
        results = parse_json_results(FIXTURES / "json_run1.json")
        test_d = next(r for r in results if r.name == "test_d")
        assert test_d.status == "passed"
        assert test_d.classname == "TestClass2"
        assert abs(test_d.duration - 0.50) < 0.001

    def test_skipped_test_parsed_correctly(self):
        results = parse_json_results(FIXTURES / "json_run1.json")
        test_e = next(r for r in results if r.name == "test_e")
        assert test_e.status == "skipped"

    def test_file_source_recorded(self):
        results = parse_json_results(FIXTURES / "json_run1.json")
        assert all(r.file_source == "json_run1.json" for r in results)

    def test_missing_file_raises_error(self):
        with pytest.raises((FileNotFoundError, Exception)):
            parse_json_results(FIXTURES / "nonexistent.json")


class TestAggregateResults:
    def setup_method(self):
        self.run1 = parse_junit_xml(FIXTURES / "junit_run1.xml")
        self.run2 = parse_junit_xml(FIXTURES / "junit_run2.xml")
        self.json1 = parse_json_results(FIXTURES / "json_run1.json")
        self.agg = aggregate_results([self.run1, self.run2, self.json1])

    def test_total_count(self):
        # 3 + 3 + 2 = 8 total test runs
        assert self.agg["total"] == 8

    def test_passed_count(self):
        # run1: test_a+test_c pass (2); run2: test_a+test_b pass (2); json1: test_d pass (1) = 5
        assert self.agg["passed"] == 5

    def test_failed_count(self):
        # run1: test_b fails (1); run2: test_c fails (1) = 2
        assert self.agg["failed"] == 2

    def test_skipped_count(self):
        # json1: test_e skipped (1) = 1
        assert self.agg["skipped"] == 1

    def test_duration(self):
        # 0.60 + 0.60 + 0.50 = 1.70
        assert abs(self.agg["duration"] - 1.70) < 0.01

    def test_empty_input(self):
        agg = aggregate_results([])
        assert agg["total"] == 0
        assert agg["passed"] == 0
        assert agg["failed"] == 0
        assert agg["skipped"] == 0
        assert agg["duration"] == 0.0


class TestDetectFlakyTests:
    def setup_method(self):
        self.run1 = parse_junit_xml(FIXTURES / "junit_run1.xml")
        self.run2 = parse_junit_xml(FIXTURES / "junit_run2.xml")
        self.json1 = parse_json_results(FIXTURES / "json_run1.json")

    def test_detects_two_flaky_tests(self):
        flaky = detect_flaky_tests([self.run1, self.run2, self.json1])
        assert len(flaky) == 2

    def test_test_b_is_flaky(self):
        flaky = detect_flaky_tests([self.run1, self.run2, self.json1])
        names = [f["name"] for f in flaky]
        assert "TestClass.test_b" in names

    def test_test_c_is_flaky(self):
        flaky = detect_flaky_tests([self.run1, self.run2, self.json1])
        names = [f["name"] for f in flaky]
        assert "TestClass.test_c" in names

    def test_flaky_entry_has_pass_fail_counts(self):
        flaky = detect_flaky_tests([self.run1, self.run2, self.json1])
        test_b = next(f for f in flaky if f["name"] == "TestClass.test_b")
        assert test_b["passed"] == 1
        assert test_b["failed"] == 1

    def test_no_flaky_when_all_consistent(self):
        # Two identical runs — no flakiness
        flaky = detect_flaky_tests([self.run1, self.run1])
        assert len(flaky) == 0

    def test_single_file_never_flaky(self):
        flaky = detect_flaky_tests([self.run1])
        assert len(flaky) == 0


class TestGenerateMarkdown:
    def setup_method(self):
        run1 = parse_junit_xml(FIXTURES / "junit_run1.xml")
        run2 = parse_junit_xml(FIXTURES / "junit_run2.xml")
        json1 = parse_json_results(FIXTURES / "json_run1.json")
        agg = aggregate_results([run1, run2, json1])
        flaky = detect_flaky_tests([run1, run2, json1])
        self.md = generate_markdown(agg, flaky)

    def test_contains_summary_heading(self):
        assert "## Test Results Summary" in self.md

    def test_contains_total_tests_value(self):
        assert "| Total Tests | 8 |" in self.md

    def test_contains_passed_value(self):
        assert "| Passed | 5 |" in self.md

    def test_contains_failed_value(self):
        assert "| Failed | 2 |" in self.md

    def test_contains_skipped_value(self):
        assert "| Skipped | 1 |" in self.md

    def test_contains_duration(self):
        assert "1.70s" in self.md

    def test_contains_flaky_section(self):
        assert "## Flaky Tests" in self.md

    def test_contains_flaky_test_names(self):
        assert "TestClass.test_b" in self.md
        assert "TestClass.test_c" in self.md

    def test_no_flaky_section_when_none(self):
        run1 = parse_junit_xml(FIXTURES / "junit_run1.xml")
        agg = aggregate_results([run1])
        md = generate_markdown(agg, [])
        assert "No flaky tests" in md or "Flaky Tests" not in md or "0 detected" in md
