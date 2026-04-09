"""
Test suite for test results aggregator - using red/green TDD methodology.

Each test is written FIRST (failing), then the minimum implementation is added.
Tests are ordered by the TDD cycle they represent.
"""
import json
import os
import textwrap
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

# Import our module under test - this will fail until we create aggregator.py
from aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    detect_flaky_tests,
    generate_markdown_summary,
    TestResult,
    TestSuiteResult,
)


class TestParseJUnitXML(unittest.TestCase):
    """TDD Cycle 1: JUnit XML parsing."""

    def test_parse_simple_junit_xml(self):
        """Parse a minimal JUnit XML with one passing test."""
        xml_content = textwrap.dedent("""\
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuite name="MyTests" tests="1" failures="0" errors="0" skipped="0" time="0.5">
                <testcase name="test_addition" classname="math.tests" time="0.5"/>
            </testsuite>
        """)
        results = parse_junit_xml(xml_content)
        self.assertIsInstance(results, TestSuiteResult)
        self.assertEqual(results.suite_name, "MyTests")
        self.assertEqual(results.total, 1)
        self.assertEqual(results.passed, 1)
        self.assertEqual(results.failed, 0)
        self.assertEqual(results.skipped, 0)
        self.assertAlmostEqual(results.duration, 0.5)

    def test_parse_junit_xml_with_failures(self):
        """Parse JUnit XML with failing tests."""
        xml_content = textwrap.dedent("""\
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuite name="FailingTests" tests="3" failures="1" errors="0" skipped="1" time="2.0">
                <testcase name="test_pass" classname="suite.tests" time="0.5"/>
                <testcase name="test_fail" classname="suite.tests" time="1.0">
                    <failure message="AssertionError: 2 != 3">Expected 3 but got 2</failure>
                </testcase>
                <testcase name="test_skip" classname="suite.tests" time="0.5">
                    <skipped message="Not implemented yet"/>
                </testcase>
            </testsuite>
        """)
        results = parse_junit_xml(xml_content)
        self.assertEqual(results.total, 3)
        self.assertEqual(results.passed, 1)
        self.assertEqual(results.failed, 1)
        self.assertEqual(results.skipped, 1)
        self.assertEqual(len(results.test_cases), 3)

        # Check individual test case details
        failed_case = next(t for t in results.test_cases if t.name == "test_fail")
        self.assertFalse(failed_case.passed)
        self.assertFalse(failed_case.skipped)
        self.assertEqual(failed_case.failure_message, "AssertionError: 2 != 3")

    def test_parse_junit_xml_with_errors(self):
        """Parse JUnit XML with error (not just failure) tests."""
        xml_content = textwrap.dedent("""\
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuite name="ErrorTests" tests="1" failures="0" errors="1" skipped="0" time="0.1">
                <testcase name="test_crash" classname="suite.tests" time="0.1">
                    <error message="RuntimeError: division by zero">Traceback...</error>
                </testcase>
            </testsuite>
        """)
        results = parse_junit_xml(xml_content)
        self.assertEqual(results.failed, 1)  # errors count as failures
        self.assertEqual(results.passed, 0)

    def test_parse_junit_xml_testsuites_wrapper(self):
        """Parse JUnit XML wrapped in <testsuites> element (multiple suites)."""
        xml_content = textwrap.dedent("""\
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuites>
                <testsuite name="Suite1" tests="2" failures="0" errors="0" skipped="0" time="1.0">
                    <testcase name="test_a" classname="s1" time="0.5"/>
                    <testcase name="test_b" classname="s1" time="0.5"/>
                </testsuite>
                <testsuite name="Suite2" tests="1" failures="1" errors="0" skipped="0" time="0.5">
                    <testcase name="test_c" classname="s2" time="0.5">
                        <failure message="Fail">details</failure>
                    </testcase>
                </testsuite>
            </testsuites>
        """)
        results = parse_junit_xml(xml_content)
        # When wrapping testsuites, returns merged result
        self.assertEqual(results.total, 3)
        self.assertEqual(results.passed, 2)
        self.assertEqual(results.failed, 1)

    def test_parse_junit_xml_from_file(self):
        """Parse JUnit XML from a file path."""
        fixture_path = Path(__file__).parent / "fixtures" / "junit_pass.xml"
        results = parse_junit_xml(fixture_path.read_text())
        self.assertIsInstance(results, TestSuiteResult)
        self.assertGreater(results.total, 0)

    def test_parse_invalid_xml_raises(self):
        """Invalid XML raises a meaningful error."""
        with self.assertRaises(ValueError) as ctx:
            parse_junit_xml("not xml at all")
        self.assertIn("parse", str(ctx.exception).lower())


class TestParseJSONResults(unittest.TestCase):
    """TDD Cycle 2: JSON test result parsing."""

    def test_parse_simple_json(self):
        """Parse a minimal JSON test result."""
        data = {
            "suite": "APITests",
            "tests": [
                {"name": "test_get_user", "status": "passed", "duration": 0.1},
                {"name": "test_post_user", "status": "passed", "duration": 0.2},
            ]
        }
        results = parse_json_results(json.dumps(data))
        self.assertEqual(results.suite_name, "APITests")
        self.assertEqual(results.total, 2)
        self.assertEqual(results.passed, 2)
        self.assertEqual(results.failed, 0)
        self.assertAlmostEqual(results.duration, 0.3, places=5)

    def test_parse_json_with_failures(self):
        """Parse JSON with failed and skipped tests."""
        data = {
            "suite": "MixedTests",
            "tests": [
                {"name": "test_a", "status": "passed", "duration": 0.5},
                {"name": "test_b", "status": "failed", "duration": 1.0,
                 "error": "Expected 200 but got 404"},
                {"name": "test_c", "status": "skipped", "duration": 0.0},
            ]
        }
        results = parse_json_results(json.dumps(data))
        self.assertEqual(results.passed, 1)
        self.assertEqual(results.failed, 1)
        self.assertEqual(results.skipped, 1)

        failed_case = next(t for t in results.test_cases if t.name == "test_b")
        self.assertEqual(failed_case.failure_message, "Expected 200 but got 404")

    def test_parse_json_from_fixture(self):
        """Parse JSON from the fixture file."""
        fixture_path = Path(__file__).parent / "fixtures" / "results.json"
        results = parse_json_results(fixture_path.read_text())
        self.assertIsInstance(results, TestSuiteResult)

    def test_parse_invalid_json_raises(self):
        """Invalid JSON raises a meaningful error."""
        with self.assertRaises(ValueError) as ctx:
            parse_json_results("{not valid json}")
        self.assertIn("parse", str(ctx.exception).lower())

    def test_parse_json_missing_suite_name(self):
        """JSON without 'suite' key uses a default name."""
        data = {"tests": [{"name": "test_x", "status": "passed", "duration": 0.1}]}
        results = parse_json_results(json.dumps(data))
        self.assertIsNotNone(results.suite_name)  # Gets a default


class TestAggregateResults(unittest.TestCase):
    """TDD Cycle 3: Aggregating multiple suite results."""

    def _make_suite(self, name, passed, failed, skipped, duration, cases=None):
        """Helper to create a TestSuiteResult."""
        if cases is None:
            cases = []
            for i in range(passed):
                cases.append(TestResult(name=f"test_pass_{i}", classname=name,
                                        passed=True, skipped=False, duration=0.1))
            for i in range(failed):
                cases.append(TestResult(name=f"test_fail_{i}", classname=name,
                                        passed=False, skipped=False, duration=0.1,
                                        failure_message="Fail"))
            for i in range(skipped):
                cases.append(TestResult(name=f"test_skip_{i}", classname=name,
                                        passed=True, skipped=True, duration=0.0))
        return TestSuiteResult(suite_name=name, total=passed+failed+skipped,
                                passed=passed, failed=failed, skipped=skipped,
                                duration=duration, test_cases=cases)

    def test_aggregate_single_suite(self):
        """Aggregate a single suite - totals match suite."""
        suite = self._make_suite("Suite1", passed=3, failed=1, skipped=0, duration=2.0)
        agg = aggregate_results([suite])
        self.assertEqual(agg["total"], 4)
        self.assertEqual(agg["passed"], 3)
        self.assertEqual(agg["failed"], 1)
        self.assertEqual(agg["skipped"], 0)
        self.assertAlmostEqual(agg["duration"], 2.0)

    def test_aggregate_multiple_suites(self):
        """Aggregate multiple suites sums all counts."""
        suites = [
            self._make_suite("Suite1", passed=5, failed=1, skipped=1, duration=3.0),
            self._make_suite("Suite2", passed=3, failed=2, skipped=0, duration=2.0),
            self._make_suite("Suite3", passed=10, failed=0, skipped=2, duration=5.0),
        ]
        agg = aggregate_results(suites)
        self.assertEqual(agg["total"], 24)
        self.assertEqual(agg["passed"], 18)
        self.assertEqual(agg["failed"], 3)
        self.assertEqual(agg["skipped"], 3)
        self.assertAlmostEqual(agg["duration"], 10.0)

    def test_aggregate_empty_list(self):
        """Aggregating empty list returns zeros."""
        agg = aggregate_results([])
        self.assertEqual(agg["total"], 0)
        self.assertEqual(agg["passed"], 0)
        self.assertEqual(agg["failed"], 0)
        self.assertEqual(agg["skipped"], 0)

    def test_aggregate_includes_suite_breakdown(self):
        """Aggregation includes per-suite breakdown."""
        suites = [
            self._make_suite("Alpha", passed=2, failed=0, skipped=0, duration=1.0),
            self._make_suite("Beta", passed=1, failed=1, skipped=0, duration=0.5),
        ]
        agg = aggregate_results(suites)
        self.assertIn("suites", agg)
        suite_names = [s["name"] for s in agg["suites"]]
        self.assertIn("Alpha", suite_names)
        self.assertIn("Beta", suite_names)


class TestDetectFlakyTests(unittest.TestCase):
    """TDD Cycle 4: Flaky test detection across matrix runs."""

    def _make_result(self, name, classname, passed):
        return TestResult(name=name, classname=classname, passed=passed,
                          skipped=False, duration=0.1)

    def test_no_flaky_tests_when_all_pass(self):
        """No flaky tests when all runs pass consistently."""
        run1 = [self._make_result("test_a", "suite", True),
                self._make_result("test_b", "suite", True)]
        run2 = [self._make_result("test_a", "suite", True),
                self._make_result("test_b", "suite", True)]
        flaky = detect_flaky_tests([run1, run2])
        self.assertEqual(flaky, [])

    def test_no_flaky_tests_when_all_fail(self):
        """No flaky tests when a test consistently fails."""
        run1 = [self._make_result("test_a", "suite", False)]
        run2 = [self._make_result("test_a", "suite", False)]
        flaky = detect_flaky_tests([run1, run2])
        self.assertEqual(flaky, [])

    def test_detect_single_flaky_test(self):
        """Detect a test that passes in one run and fails in another."""
        run1 = [self._make_result("test_flaky", "suite", True),
                self._make_result("test_stable", "suite", True)]
        run2 = [self._make_result("test_flaky", "suite", False),
                self._make_result("test_stable", "suite", True)]
        flaky = detect_flaky_tests([run1, run2])
        self.assertEqual(len(flaky), 1)
        self.assertEqual(flaky[0]["name"], "test_flaky")

    def test_detect_multiple_flaky_tests(self):
        """Detect multiple flaky tests across runs."""
        run1 = [self._make_result("test_a", "s", True),
                self._make_result("test_b", "s", False),
                self._make_result("test_c", "s", True)]
        run2 = [self._make_result("test_a", "s", False),
                self._make_result("test_b", "s", True),
                self._make_result("test_c", "s", True)]
        flaky = detect_flaky_tests([run1, run2])
        flaky_names = {f["name"] for f in flaky}
        self.assertIn("test_a", flaky_names)
        self.assertIn("test_b", flaky_names)
        self.assertNotIn("test_c", flaky_names)

    def test_flaky_test_includes_pass_fail_counts(self):
        """Flaky test info includes pass/fail counts across runs."""
        run1 = [self._make_result("test_flaky", "suite", True)]
        run2 = [self._make_result("test_flaky", "suite", False)]
        run3 = [self._make_result("test_flaky", "suite", True)]
        flaky = detect_flaky_tests([run1, run2, run3])
        self.assertEqual(len(flaky), 1)
        info = flaky[0]
        self.assertEqual(info["pass_count"], 2)
        self.assertEqual(info["fail_count"], 1)

    def test_single_run_no_flaky(self):
        """Single run cannot detect flakiness (need at least 2 runs)."""
        run1 = [self._make_result("test_a", "suite", True)]
        flaky = detect_flaky_tests([run1])
        self.assertEqual(flaky, [])


class TestGenerateMarkdownSummary(unittest.TestCase):
    """TDD Cycle 5: Markdown summary generation."""

    def _make_aggregated(self, total, passed, failed, skipped, duration,
                          suites=None, flaky=None):
        return {
            "total": total,
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "duration": duration,
            "suites": suites or [],
            "flaky_tests": flaky or [],
        }

    def test_markdown_contains_header(self):
        """Markdown summary has a top-level header."""
        agg = self._make_aggregated(10, 9, 1, 0, 5.0)
        md = generate_markdown_summary(agg)
        self.assertIn("# Test Results", md)

    def test_markdown_contains_totals(self):
        """Markdown summary shows total/passed/failed/skipped counts."""
        agg = self._make_aggregated(10, 8, 1, 1, 3.5)
        md = generate_markdown_summary(agg)
        self.assertIn("10", md)  # total
        self.assertIn("8", md)   # passed
        self.assertIn("1", md)   # failed/skipped

    def test_markdown_contains_duration(self):
        """Markdown summary shows total duration."""
        agg = self._make_aggregated(5, 5, 0, 0, 12.34)
        md = generate_markdown_summary(agg)
        self.assertIn("12.34", md)

    def test_markdown_all_pass_shows_green(self):
        """All-pass summary includes a success indicator."""
        agg = self._make_aggregated(5, 5, 0, 0, 1.0)
        md = generate_markdown_summary(agg)
        # Should have a pass/success indicator (emoji or word)
        self.assertTrue(
            any(indicator in md for indicator in ["✅", "PASSED", "passed", "All"]),
            f"Expected success indicator in:\n{md}"
        )

    def test_markdown_with_failures_shows_red(self):
        """Summary with failures includes a failure indicator."""
        agg = self._make_aggregated(5, 4, 1, 0, 1.0)
        md = generate_markdown_summary(agg)
        self.assertTrue(
            any(indicator in md for indicator in ["❌", "FAILED", "failed", "Failure"]),
            f"Expected failure indicator in:\n{md}"
        )

    def test_markdown_with_flaky_tests(self):
        """Summary includes flaky test section when flaky tests exist."""
        flaky = [{"name": "test_flaky_one", "classname": "suite",
                  "pass_count": 2, "fail_count": 1}]
        agg = self._make_aggregated(5, 4, 1, 0, 1.0, flaky=flaky)
        md = generate_markdown_summary(agg)
        self.assertIn("test_flaky_one", md)
        self.assertIn("flaky", md.lower())

    def test_markdown_with_suite_breakdown(self):
        """Summary includes per-suite breakdown."""
        suites = [
            {"name": "Frontend", "total": 5, "passed": 5, "failed": 0, "skipped": 0, "duration": 1.0},
            {"name": "Backend", "total": 3, "passed": 2, "failed": 1, "skipped": 0, "duration": 2.0},
        ]
        agg = self._make_aggregated(8, 7, 1, 0, 3.0, suites=suites)
        md = generate_markdown_summary(agg)
        self.assertIn("Frontend", md)
        self.assertIn("Backend", md)

    def test_markdown_no_flaky_section_when_none(self):
        """No flaky section when no flaky tests detected."""
        agg = self._make_aggregated(5, 5, 0, 0, 1.0)
        md = generate_markdown_summary(agg)
        self.assertNotIn("flaky", md.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
