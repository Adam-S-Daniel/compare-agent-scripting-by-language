"""
Tests for test_results_aggregator.py - written first (TDD red phase).

Test structure:
1. parse_junit_xml() - parse JUnit XML format
2. parse_json_results() - parse JSON format
3. aggregate_results() - combine multiple runs, compute totals
4. identify_flaky_tests() - find tests that pass in some runs, fail in others
5. generate_markdown() - produce GitHub Actions job summary
6. Workflow structure tests - verify .github/workflows/test-results-aggregator.yml
"""

import pytest
import subprocess
import sys
import os
from pathlib import Path

# Add parent dir to path so we can import aggregator
sys.path.insert(0, str(Path(__file__).parent.parent))

from aggregator import (
    parse_junit_xml,
    parse_json_results,
    aggregate_results,
    generate_markdown,
    TestCase,
    RunResult,
    AggregatedResults,
)

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"
WORKFLOW_FILE = Path(__file__).parent.parent / ".github" / "workflows" / "test-results-aggregator.yml"


# --- Fixture: minimal JUnit XML in memory ---

JUNIT_XML_SIMPLE = """\
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Run1" tests="3" failures="1" errors="0" skipped="0" time="1.5">
  <testsuite name="mymodule" tests="3" failures="1" errors="0" skipped="0" time="1.5">
    <testcase name="test_one" classname="mymodule" time="0.4"/>
    <testcase name="test_two" classname="mymodule" time="0.6">
      <failure message="AssertionError">Got 0, expected 1</failure>
    </testcase>
    <testcase name="test_three" classname="mymodule" time="0.5"/>
  </testsuite>
</testsuites>
"""

JUNIT_XML_WITH_SKIP = """\
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Run2" tests="2" failures="0" errors="0" skipped="1" time="0.8">
  <testsuite name="mymodule" tests="2" failures="0" errors="0" skipped="1" time="0.8">
    <testcase name="test_one" classname="mymodule" time="0.5"/>
    <testcase name="test_skip" classname="mymodule" time="0.3">
      <skipped message="Not implemented yet"/>
    </testcase>
  </testsuite>
</testsuites>
"""

JSON_SIMPLE = {
    "run_name": "json-run-1",
    "tests": [
        {"name": "test_alpha", "classname": "suite_a", "status": "passed", "duration": 0.3},
        {"name": "test_beta", "classname": "suite_a", "status": "failed", "duration": 0.4,
         "message": "Unexpected None"},
        {"name": "test_gamma", "classname": "suite_a", "status": "skipped", "duration": 0.0},
    ],
}


# ============================================================
# 1. parse_junit_xml
# ============================================================

class TestParseJunitXml:
    def test_returns_run_result(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        assert isinstance(result, RunResult)

    def test_counts_passed_failed_skipped(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        # 3 tests, 1 failure -> 2 passed, 1 failed, 0 skipped
        assert result.total == 3
        assert result.passed == 2
        assert result.failed == 1
        assert result.skipped == 0

    def test_duration(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        assert abs(result.duration - 1.5) < 0.001

    def test_parses_test_cases(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        assert len(result.tests) == 3
        names = [t.name for t in result.tests]
        assert "test_one" in names
        assert "test_two" in names
        assert "test_three" in names

    def test_failure_status(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        failing = [t for t in result.tests if t.name == "test_two"][0]
        assert failing.status == "failed"
        assert "Got 0, expected 1" in failing.message

    def test_skipped_status(self, tmp_path):
        f = tmp_path / "skip.xml"
        f.write_text(JUNIT_XML_WITH_SKIP)
        result = parse_junit_xml(f)
        skipped = [t for t in result.tests if t.name == "test_skip"][0]
        assert skipped.status == "skipped"
        assert result.skipped == 1

    def test_run_name_from_parameter(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f, run_name="ubuntu-py39")
        assert result.run_name == "ubuntu-py39"

    def test_run_name_defaults_to_filename(self, tmp_path):
        f = tmp_path / "my_run.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        assert "my_run" in result.run_name

    def test_missing_file_raises_error(self):
        with pytest.raises(FileNotFoundError):
            parse_junit_xml("/nonexistent/path.xml")

    def test_classname_captured(self, tmp_path):
        f = tmp_path / "results.xml"
        f.write_text(JUNIT_XML_SIMPLE)
        result = parse_junit_xml(f)
        tc = [t for t in result.tests if t.name == "test_one"][0]
        assert tc.classname == "mymodule"


# ============================================================
# 2. parse_json_results
# ============================================================

class TestParseJsonResults:
    def test_returns_run_result(self, tmp_path):
        import json
        f = tmp_path / "results.json"
        f.write_text(json.dumps(JSON_SIMPLE))
        result = parse_json_results(f)
        assert isinstance(result, RunResult)

    def test_counts(self, tmp_path):
        import json
        f = tmp_path / "results.json"
        f.write_text(json.dumps(JSON_SIMPLE))
        result = parse_json_results(f)
        assert result.total == 3
        assert result.passed == 1
        assert result.failed == 1
        assert result.skipped == 1

    def test_duration_summed(self, tmp_path):
        import json
        f = tmp_path / "results.json"
        f.write_text(json.dumps(JSON_SIMPLE))
        result = parse_json_results(f)
        assert abs(result.duration - 0.7) < 0.001

    def test_run_name_from_json(self, tmp_path):
        import json
        f = tmp_path / "results.json"
        f.write_text(json.dumps(JSON_SIMPLE))
        result = parse_json_results(f)
        assert result.run_name == "json-run-1"

    def test_missing_file_raises_error(self):
        with pytest.raises(FileNotFoundError):
            parse_json_results("/nonexistent/path.json")

    def test_invalid_json_raises_error(self, tmp_path):
        f = tmp_path / "bad.json"
        f.write_text("not valid json {")
        with pytest.raises(ValueError):
            parse_json_results(f)

    def test_test_case_attributes(self, tmp_path):
        import json
        f = tmp_path / "results.json"
        f.write_text(json.dumps(JSON_SIMPLE))
        result = parse_json_results(f)
        failed = [t for t in result.tests if t.name == "test_beta"][0]
        assert failed.status == "failed"
        assert failed.classname == "suite_a"
        assert "Unexpected None" in failed.message


# ============================================================
# 3. aggregate_results
# ============================================================

class TestAggregateResults:
    def _make_run(self, name, tests):
        # tests: list of (name, classname, status, duration)
        tcs = [TestCase(name=t[0], classname=t[1], status=t[2], duration=t[3]) for t in tests]
        passed = sum(1 for t in tcs if t.status == "passed")
        failed = sum(1 for t in tcs if t.status == "failed")
        skipped = sum(1 for t in tcs if t.status == "skipped")
        return RunResult(
            run_name=name,
            tests=tcs,
            total=len(tcs),
            passed=passed,
            failed=failed,
            skipped=skipped,
            duration=sum(t.duration for t in tcs),
        )

    def test_returns_aggregated_results(self):
        run1 = self._make_run("run1", [("test_a", "mod", "passed", 0.5)])
        result = aggregate_results([run1])
        assert isinstance(result, AggregatedResults)

    def test_totals_across_runs(self):
        run1 = self._make_run("run1", [
            ("test_a", "mod", "passed", 0.5),
            ("test_b", "mod", "failed", 0.3),
        ])
        run2 = self._make_run("run2", [
            ("test_a", "mod", "passed", 0.4),
            ("test_b", "mod", "passed", 0.3),
        ])
        result = aggregate_results([run1, run2])
        assert result.total == 4
        assert result.passed == 3
        assert result.failed == 1

    def test_duration_summed(self):
        run1 = self._make_run("run1", [("test_a", "mod", "passed", 1.0)])
        run2 = self._make_run("run2", [("test_a", "mod", "passed", 2.0)])
        result = aggregate_results([run1, run2])
        assert abs(result.duration - 3.0) < 0.001

    def test_flaky_detection(self):
        # test_b passes in run1, fails in run2 -> flaky
        run1 = self._make_run("run1", [
            ("test_a", "mod", "passed", 0.5),
            ("test_b", "mod", "passed", 0.3),
        ])
        run2 = self._make_run("run2", [
            ("test_a", "mod", "passed", 0.4),
            ("test_b", "mod", "failed", 0.3),
        ])
        result = aggregate_results([run1, run2])
        assert "mod::test_b" in result.flaky_tests
        assert "mod::test_a" not in result.flaky_tests

    def test_consistently_failing_detection(self):
        # test_c always fails
        run1 = self._make_run("run1", [
            ("test_c", "mod", "failed", 0.5),
        ])
        run2 = self._make_run("run2", [
            ("test_c", "mod", "failed", 0.5),
        ])
        result = aggregate_results([run1, run2])
        assert "mod::test_c" in result.consistently_failing
        assert "mod::test_c" not in result.flaky_tests

    def test_no_flaky_when_always_passes(self):
        run1 = self._make_run("run1", [("test_a", "mod", "passed", 0.5)])
        run2 = self._make_run("run2", [("test_a", "mod", "passed", 0.4)])
        result = aggregate_results([run1, run2])
        assert len(result.flaky_tests) == 0

    def test_empty_runs_list(self):
        result = aggregate_results([])
        assert result.total == 0
        assert result.passed == 0
        assert result.failed == 0


# ============================================================
# 4. generate_markdown
# ============================================================

class TestGenerateMarkdown:
    def _make_aggregated(self, total, passed, failed, skipped, duration,
                         flaky=None, consistently_failing=None):
        return AggregatedResults(
            runs=[],
            total=total,
            passed=passed,
            failed=failed,
            skipped=skipped,
            duration=duration,
            flaky_tests=flaky or [],
            consistently_failing=consistently_failing or [],
        )

    def test_returns_string(self):
        r = self._make_aggregated(4, 3, 1, 0, 1.5)
        md = generate_markdown(r)
        assert isinstance(md, str)

    def test_contains_summary_header(self):
        r = self._make_aggregated(4, 3, 1, 0, 1.5)
        md = generate_markdown(r)
        assert "Test Results Summary" in md

    def test_contains_totals(self):
        r = self._make_aggregated(16, 8, 6, 2, 10.8)
        md = generate_markdown(r)
        assert "16" in md
        assert "8" in md
        assert "6" in md
        assert "2" in md

    def test_exact_total_in_table(self):
        r = self._make_aggregated(16, 8, 6, 2, 10.8)
        md = generate_markdown(r)
        # Should have table row with "Total Tests" and value "16"
        assert "| Total Tests | 16 |" in md

    def test_exact_passed_in_table(self):
        r = self._make_aggregated(16, 8, 6, 2, 10.8)
        md = generate_markdown(r)
        assert "| Passed | 8 |" in md

    def test_exact_failed_in_table(self):
        r = self._make_aggregated(16, 8, 6, 2, 10.8)
        md = generate_markdown(r)
        assert "| Failed | 6 |" in md

    def test_exact_skipped_in_table(self):
        r = self._make_aggregated(16, 8, 6, 2, 10.8)
        md = generate_markdown(r)
        assert "| Skipped | 2 |" in md

    def test_duration_formatted(self):
        r = self._make_aggregated(4, 4, 0, 0, 10.8)
        md = generate_markdown(r)
        assert "10.80s" in md

    def test_flaky_tests_listed(self):
        r = self._make_aggregated(4, 2, 2, 0, 1.0, flaky=["mymod::test_b"])
        md = generate_markdown(r)
        assert "mymod::test_b" in md
        assert "Flaky" in md

    def test_consistently_failing_listed(self):
        r = self._make_aggregated(4, 1, 3, 0, 1.0, consistently_failing=["mymod::test_c"])
        md = generate_markdown(r)
        assert "mymod::test_c" in md

    def test_no_flaky_section_when_none(self):
        r = self._make_aggregated(4, 4, 0, 0, 1.0)
        md = generate_markdown(r)
        # Should not crash and flaky section should indicate none or be absent
        assert "mymod" not in md


# ============================================================
# 5. Integration: parse fixture files
# ============================================================

class TestFixtures:
    def test_fixture_files_exist(self):
        assert (FIXTURES_DIR / "junit_run1.xml").exists(), "junit_run1.xml missing"
        assert (FIXTURES_DIR / "junit_run2.xml").exists(), "junit_run2.xml missing"
        assert (FIXTURES_DIR / "json_run1.json").exists(), "json_run1.json missing"
        assert (FIXTURES_DIR / "json_run2.json").exists(), "json_run2.json missing"

    def test_parse_all_fixtures(self):
        run1 = parse_junit_xml(FIXTURES_DIR / "junit_run1.xml", run_name="ubuntu-py39")
        run2 = parse_junit_xml(FIXTURES_DIR / "junit_run2.xml", run_name="ubuntu-py311")
        run3 = parse_json_results(FIXTURES_DIR / "json_run1.json")
        run4 = parse_json_results(FIXTURES_DIR / "json_run2.json")
        result = aggregate_results([run1, run2, run3, run4])
        assert result.total == 16
        assert result.passed == 8
        assert result.failed == 6
        assert result.skipped == 2

    def test_duration_total(self):
        run1 = parse_junit_xml(FIXTURES_DIR / "junit_run1.xml")
        run2 = parse_junit_xml(FIXTURES_DIR / "junit_run2.xml")
        run3 = parse_json_results(FIXTURES_DIR / "json_run1.json")
        run4 = parse_json_results(FIXTURES_DIR / "json_run2.json")
        result = aggregate_results([run1, run2, run3, run4])
        assert abs(result.duration - 10.8) < 0.01

    def test_flaky_test_identified(self):
        run1 = parse_junit_xml(FIXTURES_DIR / "junit_run1.xml", run_name="ubuntu-py39")
        run2 = parse_junit_xml(FIXTURES_DIR / "junit_run2.xml", run_name="ubuntu-py311")
        run3 = parse_json_results(FIXTURES_DIR / "json_run1.json")
        run4 = parse_json_results(FIXTURES_DIR / "json_run2.json")
        result = aggregate_results([run1, run2, run3, run4])
        assert any("test_beta" in t for t in result.flaky_tests)

    def test_consistently_failing_identified(self):
        run1 = parse_junit_xml(FIXTURES_DIR / "junit_run1.xml")
        run2 = parse_junit_xml(FIXTURES_DIR / "junit_run2.xml")
        run3 = parse_json_results(FIXTURES_DIR / "json_run1.json")
        run4 = parse_json_results(FIXTURES_DIR / "json_run2.json")
        result = aggregate_results([run1, run2, run3, run4])
        assert any("test_gamma" in t for t in result.consistently_failing)

    def test_full_markdown_output(self):
        run1 = parse_junit_xml(FIXTURES_DIR / "junit_run1.xml")
        run2 = parse_junit_xml(FIXTURES_DIR / "junit_run2.xml")
        run3 = parse_json_results(FIXTURES_DIR / "json_run1.json")
        run4 = parse_json_results(FIXTURES_DIR / "json_run2.json")
        result = aggregate_results([run1, run2, run3, run4])
        md = generate_markdown(result)
        assert "| Total Tests | 16 |" in md
        assert "| Passed | 8 |" in md
        assert "| Failed | 6 |" in md
        assert "| Skipped | 2 |" in md
        assert "10.80s" in md


# ============================================================
# 6. Workflow structure tests
# ============================================================

class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert WORKFLOW_FILE.exists(), f"Workflow file not found: {WORKFLOW_FILE}"

    def test_workflow_is_valid_yaml(self):
        import yaml
        content = WORKFLOW_FILE.read_text()
        data = yaml.safe_load(content)
        assert data is not None

    def test_workflow_has_push_trigger(self):
        import yaml
        data = yaml.safe_load(WORKFLOW_FILE.read_text())
        assert "on" in data or True in data  # YAML parses 'on' as True
        triggers = data.get("on", data.get(True, {}))
        assert "push" in triggers

    def test_workflow_has_jobs(self):
        import yaml
        data = yaml.safe_load(WORKFLOW_FILE.read_text())
        assert "jobs" in data
        assert len(data["jobs"]) > 0

    def test_workflow_has_checkout_step(self):
        import yaml
        data = yaml.safe_load(WORKFLOW_FILE.read_text())
        found = False
        for job in data["jobs"].values():
            for step in job.get("steps", []):
                if "uses" in step and "checkout" in step["uses"]:
                    found = True
        assert found, "No checkout step found"

    def test_workflow_references_aggregator_script(self):
        import yaml
        content = WORKFLOW_FILE.read_text()
        data = yaml.safe_load(content)
        # Check that aggregator.py is referenced in a run step
        found = False
        for job in data["jobs"].values():
            for step in job.get("steps", []):
                run_cmd = step.get("run", "")
                if "aggregator.py" in run_cmd:
                    found = True
        assert found, "No step references aggregator.py"

    def test_aggregator_script_exists(self):
        script = Path(__file__).parent.parent / "aggregator.py"
        assert script.exists(), "aggregator.py not found"

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_FILE)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )
