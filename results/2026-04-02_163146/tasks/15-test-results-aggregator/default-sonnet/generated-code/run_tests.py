"""
Simple test runner for the aggregator — runs all tests manually
(in case pytest is not available or not approved by the sandbox).
"""
import os
import sys
import json
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from aggregator import (
    parse_junit_xml, parse_json_results,
    aggregate_results, detect_flaky_tests,
    generate_markdown_summary,
    TestResult, TestSuiteResult, AggregatedResults,
)

FIXTURES = Path(__file__).parent / "fixtures"

passed_tests = []
failed_tests = []


def run(name, fn):
    try:
        fn()
        passed_tests.append(name)
        print(f"  PASS  {name}")
    except Exception as e:
        failed_tests.append((name, str(e), traceback.format_exc()))
        print(f"  FAIL  {name}: {e}")


def approx(a, b, rel=1e-3):
    return abs(a - b) <= rel * max(abs(a), abs(b), 1e-10)


# ── 1. JUnit XML parsing ───────────────────────────────────────────────────

def test_parse_basic_junit_xml():
    r = parse_junit_xml(str(FIXTURES / "junit_basic.xml"))
    assert isinstance(r, TestSuiteResult), "not TestSuiteResult"
    assert r.name == "BasicSuite", f"name={r.name}"
    assert r.total == 3, f"total={r.total}"
    assert r.passed == 2, f"passed={r.passed}"
    assert r.failed == 1, f"failed={r.failed}"
    assert r.skipped == 0, f"skipped={r.skipped}"
    assert approx(r.duration, 1.5), f"duration={r.duration}"

def test_parse_junit_xml_with_skipped():
    r = parse_junit_xml(str(FIXTURES / "junit_with_skipped.xml"))
    assert r.passed == 3, f"passed={r.passed}"
    assert r.failed == 1, f"failed={r.failed}"
    assert r.skipped == 2, f"skipped={r.skipped}"
    assert r.total == 6, f"total={r.total}"

def test_parse_junit_xml_individual_tests():
    r = parse_junit_xml(str(FIXTURES / "junit_basic.xml"))
    names = [t.name for t in r.tests]
    assert "test_addition" in names
    assert "test_subtraction" in names
    assert "test_division" in names
    failed = next(t for t in r.tests if t.name == "test_division")
    assert failed.status == "failed"
    assert failed.failure_message is not None

def test_parse_junit_xml_missing_file():
    try:
        parse_junit_xml("/nonexistent/path/result.xml")
        assert False, "should have raised FileNotFoundError"
    except FileNotFoundError as e:
        assert "not found" in str(e).lower()

def test_parse_junit_xml_invalid_xml(tmp_dir):
    bad = Path(tmp_dir) / "bad.xml"
    bad.write_text("this is not xml <<<")
    try:
        parse_junit_xml(str(bad))
        assert False, "should have raised ValueError"
    except ValueError as e:
        assert "Invalid XML" in str(e)

# ── 2. JSON parsing ────────────────────────────────────────────────────────

def test_parse_basic_json_results():
    r = parse_json_results(str(FIXTURES / "results_basic.json"))
    assert isinstance(r, TestSuiteResult)
    assert r.name == "JSONSuite", f"name={r.name}"
    assert r.passed == 4, f"passed={r.passed}"
    assert r.failed == 1, f"failed={r.failed}"
    assert r.skipped == 1, f"skipped={r.skipped}"
    assert r.total == 6, f"total={r.total}"

def test_parse_json_individual_tests():
    r = parse_json_results(str(FIXTURES / "results_basic.json"))
    assert len(r.tests) == 6
    assert "test_login" in [t.name for t in r.tests]
    failing = next(t for t in r.tests if t.status == "failed")
    assert failing.failure_message is not None

def test_parse_json_missing_file():
    try:
        parse_json_results("/nonexistent/results.json")
        assert False, "should have raised"
    except FileNotFoundError as e:
        assert "not found" in str(e).lower()

def test_parse_json_invalid_format(tmp_dir):
    bad = Path(tmp_dir) / "bad.json"
    bad.write_text(json.dumps({"foo": "bar"}))
    try:
        parse_json_results(str(bad))
        assert False, "should have raised"
    except ValueError as e:
        assert "Invalid JSON" in str(e)

# ── 3. Aggregation ─────────────────────────────────────────────────────────

def _suite(name, passed, failed, skipped, duration, tests=None):
    return TestSuiteResult(name=name, passed=passed, failed=failed,
                           skipped=skipped, duration=duration,
                           tests=tests or [], source_file="mock.xml")

def test_aggregate_totals():
    agg = aggregate_results([
        _suite("a", 5, 1, 0, 2.0),
        _suite("b", 3, 0, 2, 1.5),
    ])
    assert isinstance(agg, AggregatedResults)
    assert agg.total_passed == 8
    assert agg.total_failed == 1
    assert agg.total_skipped == 2
    assert approx(agg.total_duration, 3.5)

def test_aggregate_total_tests():
    agg = aggregate_results([_suite("a", 4, 2, 1, 1.0), _suite("b", 3, 0, 0, 0.5)])
    assert agg.total_tests == 10

def test_aggregate_suite_list_preserved():
    agg = aggregate_results([_suite("a", 1, 0, 0, 0.1), _suite("b", 2, 1, 0, 0.2)])
    assert len(agg.suites) == 2

def test_aggregate_empty_list():
    agg = aggregate_results([])
    assert agg.total_tests == 0
    assert agg.total_passed == 0
    assert agg.total_failed == 0
    assert agg.total_duration == 0.0

# ── 4. Flaky test detection ────────────────────────────────────────────────

def _test(name, status, suite="s"):
    return TestResult(name=name, status=status, duration=0.1,
                      failure_message=None if status != "failed" else "err",
                      classname="", suite=suite)

def test_detects_flaky_test():
    suites = [
        TestSuiteResult("r1", 1, 0, 0, 0.1, [_test("test_foo", "passed", "r1")], "r1.xml"),
        TestSuiteResult("r2", 0, 1, 0, 0.1, [_test("test_foo", "failed", "r2")], "r2.xml"),
    ]
    flaky = detect_flaky_tests(aggregate_results(suites))
    assert "test_foo" in flaky

def test_stable_passing_not_flaky():
    suites = [
        TestSuiteResult("r1", 1, 0, 0, 0.1, [_test("test_bar", "passed", "r1")], "r1.xml"),
        TestSuiteResult("r2", 1, 0, 0, 0.1, [_test("test_bar", "passed", "r2")], "r2.xml"),
    ]
    flaky = detect_flaky_tests(aggregate_results(suites))
    assert "test_bar" not in flaky

def test_consistently_failing_not_flaky():
    suites = [
        TestSuiteResult("r1", 0, 1, 0, 0.1, [_test("test_baz", "failed", "r1")], "r1.xml"),
        TestSuiteResult("r2", 0, 1, 0, 0.1, [_test("test_baz", "failed", "r2")], "r2.xml"),
    ]
    flaky = detect_flaky_tests(aggregate_results(suites))
    assert "test_baz" not in flaky

def test_flaky_reports_counts():
    suites = [
        TestSuiteResult("r1", 1, 0, 0, 0.1, [_test("test_flaky", "passed", "r1")], "r1.xml"),
        TestSuiteResult("r2", 1, 0, 0, 0.1, [_test("test_flaky", "passed", "r2")], "r2.xml"),
        TestSuiteResult("r3", 0, 1, 0, 0.1, [_test("test_flaky", "failed", "r3")], "r3.xml"),
    ]
    flaky = detect_flaky_tests(aggregate_results(suites))
    assert "test_flaky" in flaky
    assert flaky["test_flaky"]["passed"] == 2
    assert flaky["test_flaky"]["failed"] == 1

# ── 5. Markdown generation ─────────────────────────────────────────────────

def _agg(passed=8, failed=2, skipped=1, duration=5.0):
    suites = [_suite("ubuntu / python-3.10", passed, failed, skipped, duration)]
    return AggregatedResults(suites=suites, total_passed=passed,
                             total_failed=failed, total_skipped=skipped,
                             total_duration=duration)

def test_markdown_contains_header():
    md = generate_markdown_summary(_agg(), {})
    assert "# Test Results" in md

def test_markdown_contains_totals():
    md = generate_markdown_summary(_agg(passed=8, failed=2, skipped=1), {})
    assert "8" in md and "2" in md and "1" in md

def test_markdown_contains_suite_table():
    md = generate_markdown_summary(_agg(), {})
    assert "ubuntu / python-3.10" in md
    assert "|" in md

def test_markdown_reports_flaky_tests():
    md = generate_markdown_summary(_agg(), {"test_login": {"passed": 2, "failed": 1}})
    assert "test_login" in md
    assert "flaky" in md.lower()

def test_markdown_no_flaky_when_clean():
    md = generate_markdown_summary(_agg(), {})
    assert "test_login" not in md

def test_markdown_pass_status_emoji():
    md_pass = generate_markdown_summary(_agg(failed=0), {})
    assert "✅" in md_pass
    md_fail = generate_markdown_summary(_agg(failed=3), {})
    assert "❌" in md_fail

def test_markdown_includes_duration():
    md = generate_markdown_summary(_agg(duration=12.345), {})
    assert "12." in md

# ── 6. Integration / end-to-end ───────────────────────────────────────────

def test_full_pipeline():
    fixture_files = [
        (str(FIXTURES / "junit_basic.xml"), "junit"),
        (str(FIXTURES / "junit_with_skipped.xml"), "junit"),
        (str(FIXTURES / "results_basic.json"), "json"),
        (str(FIXTURES / "results_run2.json"), "json"),
    ]
    suites = []
    for path, fmt in fixture_files:
        if fmt == "junit":
            suites.append(parse_junit_xml(path))
        else:
            suites.append(parse_json_results(path))
    agg = aggregate_results(suites)
    flaky = detect_flaky_tests(agg)
    md = generate_markdown_summary(agg, flaky)
    assert len(md) > 100
    assert "# Test Results" in md

def test_matrix_build_flaky_detection():
    suites = [
        parse_junit_xml(str(FIXTURES / "matrix_run1.xml")),
        parse_junit_xml(str(FIXTURES / "matrix_run2.xml")),
    ]
    agg = aggregate_results(suites)
    flaky = detect_flaky_tests(agg)
    assert "test_networking" in flaky, f"flaky keys: {list(flaky.keys())}"


# ── Main runner ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import tempfile
    tmp = tempfile.mkdtemp()

    # Run each test
    for fn, needs_tmp in [
        (test_parse_basic_junit_xml, False),
        (test_parse_junit_xml_with_skipped, False),
        (test_parse_junit_xml_individual_tests, False),
        (test_parse_junit_xml_missing_file, False),
        (lambda: test_parse_junit_xml_invalid_xml(tmp), False),
        (test_parse_basic_json_results, False),
        (test_parse_json_individual_tests, False),
        (test_parse_json_missing_file, False),
        (lambda: test_parse_json_invalid_format(tmp), False),
        (test_aggregate_totals, False),
        (test_aggregate_total_tests, False),
        (test_aggregate_suite_list_preserved, False),
        (test_aggregate_empty_list, False),
        (test_detects_flaky_test, False),
        (test_stable_passing_not_flaky, False),
        (test_consistently_failing_not_flaky, False),
        (test_flaky_reports_counts, False),
        (test_markdown_contains_header, False),
        (test_markdown_contains_totals, False),
        (test_markdown_contains_suite_table, False),
        (test_markdown_reports_flaky_tests, False),
        (test_markdown_no_flaky_when_clean, False),
        (test_markdown_pass_status_emoji, False),
        (test_markdown_includes_duration, False),
        (test_full_pipeline, False),
        (test_matrix_build_flaky_detection, False),
    ]:
        run(fn.__name__ if hasattr(fn, '__name__') else repr(fn), fn)

    print(f"\n{'='*50}")
    print(f"Results: {len(passed_tests)} passed, {len(failed_tests)} failed")
    if failed_tests:
        print("\nFailed tests:")
        for name, msg, tb in failed_tests:
            print(f"\n  {name}:\n    {msg}")
        sys.exit(1)
    else:
        print("All tests passed!")
