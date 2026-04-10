"""
Tests for test results aggregator.

TDD approach: these tests were written FIRST to define the expected behavior,
then the implementation in src/aggregator.py was written to make them pass.

Test fixture data (in fixtures/):
  junit_run1.xml: 3 tests (test_a:pass, test_b:pass, test_c:fail), duration=1.00s
  junit_run2.xml: 4 tests (test_a:pass, test_b:fail, test_c:pass, test_d:skip), duration=0.90s
  json_run3.json: 3 tests (test_alpha:pass, test_beta:fail, test_gamma:skip), duration=1.00s

Aggregated: total=10, passed=5, failed=3, skipped=2, duration=2.90s
Flaky: test_b (pass in run1, fail in run2), test_c (fail in run1, pass in run2)
"""
import pytest
from pathlib import Path
import sys

# Add src to path so we can import aggregator
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    find_flaky_tests,
    generate_markdown_summary,
    RunResult,
    TestResult,
    AggregatedResult,
    FlakyTest,
)

FIXTURES_DIR = Path(__file__).parent.parent / 'fixtures'


class TestParseJUnitXML:
    """Tests for JUnit XML parsing."""

    def test_parse_returns_run_result(self):
        """Parser returns a RunResult instance."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        assert isinstance(result, RunResult)

    def test_parse_suite_name(self):
        """Suite name is extracted from the testsuite element."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        assert result.suite_name == 'TestSuite'

    def test_parse_test_count(self):
        """Correct number of test cases parsed."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        assert len(result.tests) == 3

    def test_parse_passed_and_failed(self):
        """Passed and failed tests are correctly classified."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        passed = [t for t in result.tests if t.status == 'passed']
        failed = [t for t in result.tests if t.status == 'failed']
        assert len(passed) == 2
        assert len(failed) == 1

    def test_parse_test_names(self):
        """Test names are correctly extracted."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        names = {t.name for t in result.tests}
        assert names == {'test_a', 'test_b', 'test_c'}

    def test_parse_duration(self):
        """Test durations are parsed; total matches expected sum."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        total = sum(t.duration for t in result.tests)
        assert abs(total - 1.00) < 0.001

    def test_parse_skipped(self):
        """Skipped tests are identified correctly."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run2.xml')
        skipped = [t for t in result.tests if t.status == 'skipped']
        assert len(skipped) == 1
        assert skipped[0].name == 'test_d'

    def test_run_id_from_filename(self):
        """run_id is the stem (no extension) of the filename."""
        result = parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')
        assert result.run_id == 'junit_run1'

    def test_missing_file_raises_error(self):
        """FileNotFoundError raised for missing files."""
        with pytest.raises(FileNotFoundError):
            parse_junit_xml(FIXTURES_DIR / 'does_not_exist.xml')


class TestParseJSON:
    """Tests for JSON test result parsing."""

    def test_parse_returns_run_result(self):
        """Parser returns a RunResult instance."""
        result = parse_json_results(FIXTURES_DIR / 'json_run3.json')
        assert isinstance(result, RunResult)

    def test_parse_suite_name(self):
        """Suite name extracted from 'suite' key."""
        result = parse_json_results(FIXTURES_DIR / 'json_run3.json')
        assert result.suite_name == 'TestSuiteJSON'

    def test_parse_test_count(self):
        """Correct number of tests parsed."""
        result = parse_json_results(FIXTURES_DIR / 'json_run3.json')
        assert len(result.tests) == 3

    def test_json_statuses(self):
        """All three statuses (passed/failed/skipped) are parsed correctly."""
        result = parse_json_results(FIXTURES_DIR / 'json_run3.json')
        statuses = {t.name: t.status for t in result.tests}
        assert statuses['test_alpha'] == 'passed'
        assert statuses['test_beta'] == 'failed'
        assert statuses['test_gamma'] == 'skipped'

    def test_json_run_id(self):
        """run_id is derived from the JSON filename stem."""
        result = parse_json_results(FIXTURES_DIR / 'json_run3.json')
        assert result.run_id == 'json_run3'

    def test_missing_file_raises_error(self):
        """FileNotFoundError raised for missing files."""
        with pytest.raises(FileNotFoundError):
            parse_json_results(FIXTURES_DIR / 'does_not_exist.json')


class TestAggregateResults:
    """Tests for aggregating results across multiple runs."""

    def _load_all_runs(self):
        return [
            parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml'),
            parse_junit_xml(FIXTURES_DIR / 'junit_run2.xml'),
            parse_json_results(FIXTURES_DIR / 'json_run3.json'),
        ]

    def test_aggregate_returns_aggregated_result(self):
        """aggregate_results returns an AggregatedResult instance."""
        agg = aggregate_results(self._load_all_runs())
        assert isinstance(agg, AggregatedResult)

    def test_aggregate_total(self):
        """Total count = sum of all tests across all runs (3+4+3=10)."""
        agg = aggregate_results(self._load_all_runs())
        assert agg.total == 10

    def test_aggregate_passed(self):
        """Passed count across runs: run1=2, run2=2, run3=1 => 5."""
        agg = aggregate_results(self._load_all_runs())
        assert agg.passed == 5

    def test_aggregate_failed(self):
        """Failed count across runs: run1=1, run2=1, run3=1 => 3."""
        agg = aggregate_results(self._load_all_runs())
        assert agg.failed == 3

    def test_aggregate_skipped(self):
        """Skipped count across runs: run1=0, run2=1, run3=1 => 2."""
        agg = aggregate_results(self._load_all_runs())
        assert agg.skipped == 2

    def test_aggregate_duration(self):
        """Total duration = 1.00 + 0.90 + 1.00 = 2.90s."""
        agg = aggregate_results(self._load_all_runs())
        assert abs(agg.total_duration - 2.90) < 0.001


class TestFlakyTests:
    """Tests for flaky test detection (passed in some runs, failed in others)."""

    def _load_xml_runs(self):
        return [
            parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml'),
            parse_junit_xml(FIXTURES_DIR / 'junit_run2.xml'),
        ]

    def test_returns_list(self):
        """find_flaky_tests returns a list."""
        flaky = find_flaky_tests(self._load_xml_runs())
        assert isinstance(flaky, list)

    def test_find_flaky_test_b(self):
        """test_b passed in run1, failed in run2 => flaky."""
        flaky_names = {f.name for f in find_flaky_tests(self._load_xml_runs())}
        assert 'test_b' in flaky_names

    def test_find_flaky_test_c(self):
        """test_c failed in run1, passed in run2 => flaky."""
        flaky_names = {f.name for f in find_flaky_tests(self._load_xml_runs())}
        assert 'test_c' in flaky_names

    def test_stable_tests_not_flaky(self):
        """test_a passed in both runs => not flaky."""
        flaky_names = {f.name for f in find_flaky_tests(self._load_xml_runs())}
        assert 'test_a' not in flaky_names

    def test_flaky_test_records_run_ids(self):
        """FlakyTest records which runs passed and which failed."""
        flaky = find_flaky_tests(self._load_xml_runs())
        by_name = {f.name: f for f in flaky}
        assert 'junit_run1' in by_name['test_b'].passed_runs
        assert 'junit_run2' in by_name['test_b'].failed_runs

    def test_flaky_results_are_flaky_test_instances(self):
        """Each item in the result list is a FlakyTest instance."""
        for item in find_flaky_tests(self._load_xml_runs()):
            assert isinstance(item, FlakyTest)


class TestMarkdownGeneration:
    """Tests for markdown summary generation."""

    def _setup(self):
        runs = [
            parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml'),
            parse_junit_xml(FIXTURES_DIR / 'junit_run2.xml'),
            parse_json_results(FIXTURES_DIR / 'json_run3.json'),
        ]
        agg = aggregate_results(runs)
        flaky = find_flaky_tests(runs)
        return agg, flaky

    def test_returns_string(self):
        """generate_markdown_summary returns a string."""
        agg, flaky = self._setup()
        assert isinstance(generate_markdown_summary(agg, flaky), str)

    def test_contains_summary_heading(self):
        """Output contains the expected H2 heading."""
        agg, flaky = self._setup()
        md = generate_markdown_summary(agg, flaky)
        assert '## Test Results Summary' in md

    def test_contains_passed_failed_skipped(self):
        """Output includes Passed, Failed, Skipped labels."""
        agg, flaky = self._setup()
        md = generate_markdown_summary(agg, flaky)
        assert 'Passed' in md
        assert 'Failed' in md
        assert 'Skipped' in md

    def test_contains_flaky_section(self):
        """Output includes Flaky Tests section when flaky tests exist."""
        agg, flaky = self._setup()
        md = generate_markdown_summary(agg, flaky)
        assert 'Flaky Tests' in md

    def test_contains_correct_totals(self):
        """Output contains the expected numeric totals."""
        agg, flaky = self._setup()
        md = generate_markdown_summary(agg, flaky)
        assert '10' in md   # total
        assert '| 5 |' in md   # passed
        assert '| 3 |' in md   # failed
        assert '| 2 |' in md   # skipped

    def test_no_flaky_message_when_none(self):
        """When no flaky tests, output contains 'no flaky tests' message."""
        runs = [parse_junit_xml(FIXTURES_DIR / 'junit_run1.xml')]
        agg = aggregate_results(runs)
        flaky = find_flaky_tests(runs)  # only one run, nothing can be flaky
        md = generate_markdown_summary(agg, flaky)
        assert 'No flaky tests' in md or 'no flaky tests' in md.lower()
