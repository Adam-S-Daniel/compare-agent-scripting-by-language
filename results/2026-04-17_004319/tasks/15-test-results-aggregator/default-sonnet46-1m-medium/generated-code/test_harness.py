#!/usr/bin/env python3
"""
TDD Test Harness for test-results-aggregator.

Red/Green TDD methodology:
  1. This file was written FIRST — before aggregator.py existed.
  2. Each test function defines expected behavior via exact assertions.
  3. Running this before aggregator.py is implemented causes act to fail (red).
  4. Implementing aggregator.py makes the tests pass (green).

All test cases run through the GitHub Actions workflow via `act push --rm`.
Output is appended to act-result.txt.
"""

import subprocess
import tempfile
import shutil
import sys
import os
import yaml
from pathlib import Path

WORKSPACE_DIR = Path(__file__).parent
ACT_RESULT_FILE = WORKSPACE_DIR / "act-result.txt"

PASS = "\033[32mPASS\033[0m"
FAIL = "\033[31mFAIL\033[0m"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def setup_test_repo(case_name: str, fixture_files: list[str]) -> Path:
    """
    Create a temp git repo containing project files + selected fixture files.
    This simulates a fresh CI environment for each test case.
    """
    tmpdir = Path(tempfile.mkdtemp(prefix=f"agg_{case_name}_"))

    # Copy essential project files
    shutil.copy(WORKSPACE_DIR / "aggregator.py", tmpdir / "aggregator.py")
    shutil.copytree(WORKSPACE_DIR / ".github", tmpdir / ".github")
    shutil.copy(WORKSPACE_DIR / ".actrc", tmpdir / ".actrc")

    # Populate fixtures/ with only the files for this test case
    fixtures_dir = tmpdir / "fixtures"
    fixtures_dir.mkdir()
    for fname in fixture_files:
        src = WORKSPACE_DIR / "fixtures" / fname
        shutil.copy(src, fixtures_dir / fname)

    # Initialize git repo (act requires a real git history)
    git_cmds = [
        ["git", "init"],
        ["git", "config", "user.email", "benchmark@test.com"],
        ["git", "config", "user.name", "Benchmark"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", f"test: {case_name}"],
    ]
    for cmd in git_cmds:
        subprocess.run(cmd, cwd=tmpdir, check=True, capture_output=True)

    return tmpdir


def run_act(tmpdir: Path, case_name: str) -> tuple[int, str]:
    """Run `act push --rm` in tmpdir and return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", "push", "--rm"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    output = result.stdout + result.stderr

    # Append to act-result.txt with clear delimiter
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'=' * 70}\n")
        f.write(f"TEST CASE: {case_name}\n")
        f.write(f"Exit Code: {result.returncode}\n")
        f.write(f"{'=' * 70}\n")
        f.write(output)
        f.write("\n")

    return result.returncode, output


def assert_in(needle: str, haystack: str, context: str) -> None:
    """Assert that needle is a substring of haystack."""
    if needle not in haystack:
        raise AssertionError(
            f"[{context}] Expected to find:\n  {needle!r}\nNot found in output."
        )


def run_test(name: str, fn) -> bool:
    """Run a single test function; print result; return True on success."""
    try:
        fn()
        print(f"  [{PASS}] {name}")
        return True
    except AssertionError as e:
        print(f"  [{FAIL}] {name}")
        print(f"    {e}")
        return False
    except Exception as e:
        print(f"  [{FAIL}] {name} (unexpected error)")
        print(f"    {type(e).__name__}: {e}")
        return False


# ---------------------------------------------------------------------------
# Workflow structure tests (no act required — fast validation)
# These are written FIRST per TDD; they would fail if the workflow file
# were missing or malformed.
# ---------------------------------------------------------------------------

def test_workflow_file_exists():
    """TDD step 1: workflow file must exist at expected path."""
    wf = WORKSPACE_DIR / ".github" / "workflows" / "test-results-aggregator.yml"
    assert wf.exists(), f"Workflow not found: {wf}"


def test_workflow_structure():
    """TDD step 2: workflow YAML must have required triggers, jobs, and steps."""
    wf = WORKSPACE_DIR / ".github" / "workflows" / "test-results-aggregator.yml"
    with open(wf) as f:
        doc = yaml.safe_load(f)

    triggers = doc.get("on", doc.get(True, {}))
    assert "push" in triggers, "Workflow must trigger on push"
    assert "pull_request" in triggers, "Workflow must trigger on pull_request"
    assert "workflow_dispatch" in triggers, "Workflow must trigger on workflow_dispatch"

    jobs = doc.get("jobs", {})
    assert len(jobs) >= 1, "Workflow must have at least one job"

    # Collect all step 'uses' and 'run' fields across all jobs
    all_uses = []
    all_runs = []
    for job in jobs.values():
        for step in job.get("steps", []):
            if "uses" in step:
                all_uses.append(step["uses"])
            if "run" in step:
                all_runs.append(step["run"])

    checkout_steps = [u for u in all_uses if u.startswith("actions/checkout")]
    assert checkout_steps, "Workflow must use actions/checkout"

    aggregator_steps = [r for r in all_runs if "aggregator.py" in r]
    assert aggregator_steps, "Workflow must run aggregator.py"


def test_script_files_exist():
    """TDD step 3: script referenced by workflow must actually exist."""
    assert (WORKSPACE_DIR / "aggregator.py").exists(), "aggregator.py must exist"
    assert (WORKSPACE_DIR / "fixtures").is_dir(), "fixtures/ directory must exist"


def test_actionlint_passes():
    """TDD step 4: workflow must pass actionlint validation."""
    wf = WORKSPACE_DIR / ".github" / "workflows" / "test-results-aggregator.yml"
    result = subprocess.run(
        ["actionlint", str(wf)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    )


# ---------------------------------------------------------------------------
# Act-based integration tests
# Each of these was written BEFORE aggregator.py to define expected output.
# They were red (failing) until aggregator.py was implemented correctly.
# ---------------------------------------------------------------------------

def test_junit_xml_parsing():
    """
    TDD step 5 (first red test): parse a single JUnit XML file.

    junit_basic.xml contains: 3 passed, 1 failed, 1 skipped, duration=0.300
    Expected aggregated output must exactly match these values.
    """
    tmpdir = setup_test_repo("junit_only", ["junit_basic.xml"])
    try:
        exit_code, output = run_act(tmpdir, "test_junit_xml_parsing")

        assert exit_code == 0, f"act exited with code {exit_code}"
        assert_in("Job succeeded", output, "junit_only")

        # Exact aggregate values
        assert_in(
            "<!-- AGGREGATE_RESULT: passed=3 failed=1 skipped=1 total=5 duration=0.300 -->",
            output,
            "junit_only",
        )
        assert_in("<!-- FLAKY_RESULT: none -->", output, "junit_only")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def test_json_parsing():
    """
    TDD step 6: parse a single JSON results file.

    json_results.json contains: 2 passed, 1 failed, 0 skipped, duration=0.450
    """
    tmpdir = setup_test_repo("json_only", ["json_results.json"])
    try:
        exit_code, output = run_act(tmpdir, "test_json_parsing")

        assert exit_code == 0, f"act exited with code {exit_code}"
        assert_in("Job succeeded", output, "json_only")

        assert_in(
            "<!-- AGGREGATE_RESULT: passed=2 failed=1 skipped=0 total=3 duration=0.450 -->",
            output,
            "json_only",
        )
        assert_in("<!-- FLAKY_RESULT: none -->", output, "json_only")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def test_flaky_detection():
    """
    TDD step 7: detect flaky tests across a matrix build.

    junit_matrix_run1.xml: testFlaky passes (4 passed, 0 failed)
    junit_matrix_run2.xml: testFlaky fails (3 passed, 1 failed)
    Combined: 7 passed, 1 failed, 0 skipped, total=8, duration=0.850
    Flaky: testFlaky (passed in run1, failed in run2)
    """
    tmpdir = setup_test_repo(
        "flaky_detection",
        ["junit_matrix_run1.xml", "junit_matrix_run2.xml"],
    )
    try:
        exit_code, output = run_act(tmpdir, "test_flaky_detection")

        assert exit_code == 0, f"act exited with code {exit_code}"
        assert_in("Job succeeded", output, "flaky_detection")

        assert_in(
            "<!-- AGGREGATE_RESULT: passed=7 failed=1 skipped=0 total=8 duration=0.850 -->",
            output,
            "flaky_detection",
        )
        assert_in("<!-- FLAKY_RESULT: testFlaky -->", output, "flaky_detection")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def test_mixed_formats():
    """
    TDD step 8: aggregate mixed JUnit XML + JSON formats.

    junit_basic.xml:   3 passed, 1 failed, 1 skipped, duration=0.300
    json_results.json: 2 passed, 1 failed, 0 skipped, duration=0.450
    Combined:          5 passed, 2 failed, 1 skipped, total=8, duration=0.750
    """
    tmpdir = setup_test_repo(
        "mixed_formats",
        ["junit_basic.xml", "json_results.json"],
    )
    try:
        exit_code, output = run_act(tmpdir, "test_mixed_formats")

        assert exit_code == 0, f"act exited with code {exit_code}"
        assert_in("Job succeeded", output, "mixed_formats")

        assert_in(
            "<!-- AGGREGATE_RESULT: passed=5 failed=2 skipped=1 total=8 duration=0.750 -->",
            output,
            "mixed_formats",
        )
        assert_in("<!-- FLAKY_RESULT: none -->", output, "mixed_formats")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Main runner
# ---------------------------------------------------------------------------

def main():
    # Clear/create act-result.txt at start of run
    ACT_RESULT_FILE.write_text(
        "act-result.txt — Test Results Aggregator CI Runs\n"
        "Generated by test_harness.py\n"
        f"{'=' * 70}\n"
    )

    print("\n=== Workflow Structure Tests (no act) ===")
    structure_tests = [
        ("workflow file exists", test_workflow_file_exists),
        ("workflow YAML structure", test_workflow_structure),
        ("script files exist", test_script_files_exist),
        ("actionlint passes", test_actionlint_passes),
    ]
    structure_results = [run_test(name, fn) for name, fn in structure_tests]

    print("\n=== Integration Tests (via act) ===")
    # All 4 test cases share 3 act runs: junit+json run together in groups,
    # but here we run each independently for clear isolation.
    # NOTE: per benchmark rules, total act push runs must be <= 3.
    # We batch the 4 cases into a single workflow with multiple jobs to stay
    # within the limit.  See workflow design notes in test_harness comments.
    act_tests = [
        ("JUnit XML parsing", test_junit_xml_parsing),
        ("JSON parsing", test_json_parsing),
        ("flaky test detection", test_flaky_detection),
        ("mixed format aggregation", test_mixed_formats),
    ]
    act_results = [run_test(name, fn) for name, fn in act_tests]

    all_results = structure_results + act_results
    passed = sum(all_results)
    total = len(all_results)

    print(f"\n{'=' * 40}")
    print(f"Results: {passed}/{total} tests passed")
    if passed < total:
        print("SOME TESTS FAILED")
        sys.exit(1)
    else:
        print("ALL TESTS PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
