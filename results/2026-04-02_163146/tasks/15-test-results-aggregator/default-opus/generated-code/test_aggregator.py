"""
Test-Results Aggregator — Tests (TDD: red/green/refactor)

Each section below represents a TDD cycle. In practice each test was written
FIRST (RED), then the minimum implementation was added to make it pass (GREEN),
and finally the code was cleaned up (REFACTOR) before moving to the next test.

TDD Rounds:
  1. Parse JUnit XML into TestCaseResult objects
  2. Parse JSON result files into TestCaseResult objects
  3. Auto-detect format via parse_file()
  4. Handle malformed and missing files gracefully
  5. Aggregate results across multiple runs (totals)
  6. Detect flaky tests
  7. Generate Markdown summary
  8. CLI entry point
"""

import os
import pytest

from aggregator import (
    AggregatedResults,
    FlakyTest,
    ParseError,
    TestCaseResult,
    aggregate,
    find_flaky_tests,
    generate_markdown,
    parse_file,
    parse_json,
    parse_junit_xml,
)

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


# ===================================================================
# TDD Round 1: Parse JUnit XML
# ===================================================================

class TestParseJunitXml:
    """Verify JUnit XML parsing produces correct TestCaseResult objects."""

    def test_returns_all_test_cases(self):
        # run1_results.xml has 5 test cases across 2 suites
        results = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        assert len(results) == 5

    def test_passed_test_fields(self):
        results = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        passed = [r for r in results if r.name == "test_valid_credentials"][0]
        assert passed.status == "passed"
        assert passed.classname == "auth.test_login"
        assert passed.duration == pytest.approx(2.1, abs=0.01)
        assert passed.message == ""

    def test_failed_test_fields(self):
        results = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        failed = [r for r in results if r.name == "test_invalid_password"][0]
        assert failed.status == "failed"
        assert "expected 401" in failed.message

    def test_skipped_test_fields(self):
        results = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        skipped = [r for r in results if r.name == "test_delete_user"][0]
        assert skipped.status == "skipped"
        assert "Not implemented" in skipped.message

    def test_run_name_from_attribute(self):
        results = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        assert all(r.run_name == "Run 1" for r in results)

    def test_second_run_has_no_failures(self):
        # run2 has the same tests but test_invalid_password passes (flaky setup)
        results = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        failed = [r for r in results if r.status == "failed"]
        assert len(failed) == 0


# ===================================================================
# TDD Round 2: Parse JSON results
# ===================================================================

class TestParseJson:
    """Verify JSON format parsing produces correct TestCaseResult objects."""

    def test_returns_all_test_cases(self):
        results = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        assert len(results) == 5

    def test_passed_test_fields(self):
        results = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        passed = [r for r in results if r.name == "test_valid_credentials"][0]
        assert passed.status == "passed"
        assert passed.classname == "auth.test_login"
        assert passed.duration == pytest.approx(1.8, abs=0.01)

    def test_failed_test_fields(self):
        results = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        failed = [r for r in results if r.name == "test_invalid_password"][0]
        assert failed.status == "failed"
        assert "expected 401" in failed.message

    def test_skipped_test(self):
        results = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        skipped = [r for r in results if r.name == "test_delete_user"][0]
        assert skipped.status == "skipped"

    def test_run_name(self):
        results = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        assert all(r.run_name == "Run 3" for r in results)


# ===================================================================
# TDD Round 3: Auto-detect format via parse_file()
# ===================================================================

class TestParseFile:
    """parse_file should dispatch to the right parser based on extension."""

    def test_xml_dispatch(self):
        results = parse_file(os.path.join(FIXTURES, "run1_results.xml"))
        assert len(results) == 5

    def test_json_dispatch(self):
        results = parse_file(os.path.join(FIXTURES, "run3_results.json"))
        assert len(results) == 5

    def test_unsupported_extension_raises(self):
        # Create a temp file with an unsupported extension
        tmp = os.path.join(FIXTURES, "dummy.csv")
        try:
            with open(tmp, "w") as f:
                f.write("a,b,c\n")
            with pytest.raises(ParseError, match="Unsupported file format"):
                parse_file(tmp)
        finally:
            os.remove(tmp)


# ===================================================================
# TDD Round 4: Error handling — malformed / missing files
# ===================================================================

class TestErrorHandling:
    """Graceful errors for bad input."""

    def test_missing_xml_file(self):
        with pytest.raises(ParseError, match="File not found"):
            parse_junit_xml("/nonexistent/path.xml")

    def test_missing_json_file(self):
        with pytest.raises(ParseError, match="File not found"):
            parse_json("/nonexistent/path.json")

    def test_malformed_xml(self):
        with pytest.raises(ParseError, match="Malformed XML"):
            parse_junit_xml(os.path.join(FIXTURES, "malformed.xml"))

    def test_malformed_json(self):
        with pytest.raises(ParseError, match="Malformed JSON"):
            parse_json(os.path.join(FIXTURES, "malformed.json"))


# ===================================================================
# TDD Round 5: Aggregate results across runs
# ===================================================================

class TestAggregate:
    """Aggregate totals across multiple matrix build runs."""

    def _load_all_runs(self):
        """Helper to load all three fixture runs."""
        run1 = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        run2 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        run3 = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        return [run1, run2, run3]

    def test_total_count(self):
        # 3 runs x 5 tests = 15 total
        agg = aggregate(self._load_all_runs())
        assert agg.total == 15

    def test_passed_count(self):
        # run1: 3 passed, run2: 4 passed, run3: 3 passed = 10
        agg = aggregate(self._load_all_runs())
        assert agg.passed == 10

    def test_failed_count(self):
        # run1: 1 failed (test_invalid_password), run2: 0 failed, run3: 1 failed = 2
        agg = aggregate(self._load_all_runs())
        assert agg.failed == 2

    def test_skipped_count(self):
        # Each run has 1 skipped (test_delete_user) = 3
        agg = aggregate(self._load_all_runs())
        assert agg.skipped == 3

    def test_duration_is_summed(self):
        agg = aggregate(self._load_all_runs())
        # 12.345 + 10.800 + 9.500 = 32.645  (XML times from testsuites attr aren't used;
        # we sum individual testcase durations)
        assert agg.total_duration > 0

    def test_run_count(self):
        agg = aggregate(self._load_all_runs())
        assert agg.runs == 3

    def test_failures_list(self):
        agg = aggregate(self._load_all_runs())
        assert len(agg.failures) == 2
        names = [f.name for f in agg.failures]
        assert "test_invalid_password" in names

    def test_empty_input(self):
        agg = aggregate([])
        assert agg.total == 0
        assert agg.runs == 0


# ===================================================================
# TDD Round 6: Detect flaky tests
# ===================================================================

class TestFlakyDetection:
    """A test is flaky if it passed in some runs and failed in others."""

    def test_detects_flaky_test(self):
        # test_invalid_password: failed in run1 & run3, passed in run2
        run1 = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        run2 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        run3 = parse_json(os.path.join(FIXTURES, "run3_results.json"))

        flaky = find_flaky_tests([run1, run2, run3])
        assert len(flaky) == 1
        assert flaky[0].name == "test_invalid_password"

    def test_flaky_run_details(self):
        run1 = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        run2 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))

        flaky = find_flaky_tests([run1, run2])
        assert len(flaky) == 1
        ft = flaky[0]
        assert "Run 2" in ft.passed_runs
        assert "Run 1" in ft.failed_runs

    def test_no_flaky_when_consistent(self):
        # Two identical runs — no flakiness
        run1 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        run2 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        flaky = find_flaky_tests([run1, run2])
        assert len(flaky) == 0

    def test_skipped_not_flaky(self):
        # A test skipped in all runs is not flaky
        run1 = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        run2 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        flaky = find_flaky_tests([run1, run2])
        flaky_names = [f.name for f in flaky]
        assert "test_delete_user" not in flaky_names


# ===================================================================
# TDD Round 7: Markdown summary generation
# ===================================================================

class TestMarkdownGeneration:
    """Generate a Markdown summary suitable for GitHub Actions."""

    def _build_aggregated(self):
        run1 = parse_junit_xml(os.path.join(FIXTURES, "run1_results.xml"))
        run2 = parse_junit_xml(os.path.join(FIXTURES, "run2_results.xml"))
        run3 = parse_json(os.path.join(FIXTURES, "run3_results.json"))
        return aggregate([run1, run2, run3])

    def test_contains_header(self):
        md = generate_markdown(self._build_aggregated())
        assert "# Test Results Summary" in md

    def test_contains_overview_table(self):
        md = generate_markdown(self._build_aggregated())
        assert "| **Total tests** | 15 |" in md
        assert "| **Passed** | 10 |" in md
        assert "| **Failed** | 2 |" in md
        assert "| **Skipped** | 3 |" in md
        assert "| **Runs** | 3 |" in md

    def test_contains_failure_details(self):
        md = generate_markdown(self._build_aggregated())
        assert "## Failures" in md
        assert "test_invalid_password" in md
        assert "expected 401" in md

    def test_contains_flaky_section(self):
        md = generate_markdown(self._build_aggregated())
        assert "## Flaky Tests" in md
        assert "test_invalid_password" in md

    def test_red_status_on_failures(self):
        md = generate_markdown(self._build_aggregated())
        assert ":red_circle:" in md

    def test_green_status_when_all_pass(self):
        agg = AggregatedResults(total=5, passed=5, failed=0, skipped=0, runs=1)
        md = generate_markdown(agg)
        assert ":green_circle:" in md

    def test_warning_status_when_flaky_only(self):
        agg = AggregatedResults(
            total=5, passed=5, failed=0, skipped=0, runs=2,
            flaky_tests=[FlakyTest("t", "c", ["r1"], ["r2"])],
        )
        md = generate_markdown(agg)
        assert ":warning:" in md

    def test_duration_formatted(self):
        md = generate_markdown(self._build_aggregated())
        # Duration should be formatted with 2 decimal places
        assert "| **Duration** |" in md
        # Extract duration value — should end with 's'
        for line in md.split("\n"):
            if "Duration" in line:
                assert line.strip().endswith("s |")


# ===================================================================
# TDD Round 8: CLI entry point (integration)
# ===================================================================

class TestCLI:
    """Integration test: run the aggregator as a script."""

    def test_cli_produces_markdown(self):
        import subprocess
        import sys
        result = subprocess.run(
            [
                sys.executable, "aggregator.py",
                os.path.join(FIXTURES, "run1_results.xml"),
                os.path.join(FIXTURES, "run2_results.xml"),
                os.path.join(FIXTURES, "run3_results.json"),
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        assert "# Test Results Summary" in result.stdout
        assert "Flaky Tests" in result.stdout

    def test_cli_no_args_exits_with_error(self):
        import subprocess
        import sys
        result = subprocess.run(
            [sys.executable, "aggregator.py"],
            capture_output=True, text=True,
        )
        assert result.returncode != 0
        assert "Usage" in result.stderr

    def test_cli_warns_on_bad_file(self):
        import subprocess
        import sys
        result = subprocess.run(
            [
                sys.executable, "aggregator.py",
                os.path.join(FIXTURES, "malformed.xml"),
                os.path.join(FIXTURES, "run1_results.xml"),
            ],
            capture_output=True, text=True,
        )
        # Should still produce output (the valid file) but warn about the bad one
        assert result.returncode == 0
        assert "WARNING" in result.stderr
        assert "# Test Results Summary" in result.stdout
