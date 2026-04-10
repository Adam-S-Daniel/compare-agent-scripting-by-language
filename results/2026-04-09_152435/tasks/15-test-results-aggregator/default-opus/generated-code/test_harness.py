#!/usr/bin/env python3
"""
Test harness for the test-results-aggregator.

This harness validates:
1. Workflow structure (YAML parsing, triggers, jobs, steps, file references)
2. actionlint passes
3. Act-based integration tests (run act, verify exact output values)

TDD Approach: These assertions were written FIRST, before the aggregator
script existed. The act run will fail until aggregator.py is implemented.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import yaml


# -- Paths relative to this script --
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(SCRIPT_DIR, ".github", "workflows", "test-results-aggregator.yml")
AGGREGATOR_PATH = os.path.join(SCRIPT_DIR, "aggregator.py")
FIXTURES_DIR = os.path.join(SCRIPT_DIR, "fixtures")
ACT_RESULT_PATH = os.path.join(SCRIPT_DIR, "act-result.txt")

# -- Expected values computed from fixture data --
# junit_run1.xml: 3 pass, 1 fail, 1 skip, 2.80s
# junit_run2.xml: 3 pass, 1 fail, 1 skip, 2.90s
# json_run1.json: 2 pass, 1 fail, 0 skip, 1.00s
# json_run2.json: 1 pass, 2 fail, 0 skip, 0.90s
EXPECTED_TOTAL_PASSED = 9
EXPECTED_TOTAL_FAILED = 5
EXPECTED_TOTAL_SKIPPED = 2
EXPECTED_TOTAL_DURATION = "7.60"
EXPECTED_TOTAL_TESTS = 16  # total test executions
EXPECTED_FLAKY_TESTS = sorted(["test_signup", "test_search", "test_api_create"])


def run_cmd(cmd, cwd=None, check=True):
    """Run a shell command and return the result."""
    result = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, cwd=cwd
    )
    if check and result.returncode != 0:
        print(f"FAIL: Command failed: {cmd}")
        print(f"  stdout: {result.stdout[:500]}")
        print(f"  stderr: {result.stderr[:500]}")
    return result


# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================

def test_workflow_file_exists():
    """The workflow YAML file must exist."""
    assert os.path.isfile(WORKFLOW_PATH), f"Workflow file not found: {WORKFLOW_PATH}"
    print("PASS: test_workflow_file_exists")


def test_workflow_valid_yaml():
    """The workflow must be valid YAML."""
    with open(WORKFLOW_PATH) as f:
        data = yaml.safe_load(f)
    assert isinstance(data, dict), "Workflow YAML did not parse to a dict"
    print("PASS: test_workflow_valid_yaml")
    return data


def test_workflow_triggers(data):
    """Workflow must have appropriate trigger events."""
    assert "on" in data or True in data, "Workflow missing 'on' triggers"
    triggers = data.get("on") or data.get(True)
    # Must have at least push trigger (needed for act)
    if isinstance(triggers, dict):
        trigger_names = set(triggers.keys())
    elif isinstance(triggers, list):
        trigger_names = set(triggers)
    else:
        trigger_names = {triggers}
    assert "push" in trigger_names, f"Missing 'push' trigger. Found: {trigger_names}"
    print("PASS: test_workflow_triggers")


def test_workflow_jobs(data):
    """Workflow must have jobs defined."""
    assert "jobs" in data, "Workflow missing 'jobs'"
    jobs = data["jobs"]
    assert len(jobs) > 0, "Workflow has no jobs"
    print("PASS: test_workflow_jobs")
    return jobs


def test_workflow_steps(jobs):
    """Each job must have steps, including checkout and running the aggregator."""
    for job_name, job in jobs.items():
        assert "steps" in job, f"Job '{job_name}' missing steps"
        steps = job["steps"]
        assert len(steps) > 0, f"Job '{job_name}' has no steps"

        # Check for checkout action
        step_uses = [s.get("uses", "") for s in steps]
        has_checkout = any("actions/checkout" in u for u in step_uses)
        assert has_checkout, f"Job '{job_name}' missing actions/checkout"

        # Check that aggregator.py is referenced somewhere in run steps
        step_runs = [s.get("run", "") for s in steps]
        has_aggregator = any("aggregator.py" in r for r in step_runs)
        assert has_aggregator, f"Job '{job_name}' does not reference aggregator.py"

    print("PASS: test_workflow_steps")


def test_workflow_references_existing_files(jobs):
    """Script files referenced in the workflow must actually exist."""
    assert os.path.isfile(AGGREGATOR_PATH), f"aggregator.py not found: {AGGREGATOR_PATH}"
    assert os.path.isdir(FIXTURES_DIR), f"fixtures/ dir not found: {FIXTURES_DIR}"
    print("PASS: test_workflow_references_existing_files")


def test_actionlint_passes():
    """actionlint must pass with no errors."""
    result = run_cmd(f"actionlint {WORKFLOW_PATH}", check=False)
    assert result.returncode == 0, (
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    )
    print("PASS: test_actionlint_passes")


# ============================================================
# ACT INTEGRATION TESTS
# ============================================================

def setup_temp_git_repo():
    """
    Create a temporary git repo containing all project files.
    Returns the path to the temp directory.
    """
    tmpdir = tempfile.mkdtemp(prefix="act_test_")

    # Copy all project files into temp repo
    for item in os.listdir(SCRIPT_DIR):
        if item.startswith(".git") and item != ".github" and item != ".actrc":
            continue
        if item == "act-result.txt":
            continue
        src = os.path.join(SCRIPT_DIR, item)
        dst = os.path.join(tmpdir, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Copy .actrc if it exists
    actrc = os.path.join(SCRIPT_DIR, ".actrc")
    if os.path.isfile(actrc):
        shutil.copy2(actrc, os.path.join(tmpdir, ".actrc"))

    # Initialize git repo (act requires it)
    run_cmd("git init", cwd=tmpdir)
    run_cmd("git config user.email 'test@test.com'", cwd=tmpdir)
    run_cmd("git config user.name 'Test'", cwd=tmpdir)
    run_cmd("git add -A", cwd=tmpdir)
    run_cmd("git commit -m 'initial'", cwd=tmpdir)

    return tmpdir


def run_act_test():
    """
    Run act push in a temp git repo and capture output.
    Returns (exit_code, output_text).
    """
    tmpdir = setup_temp_git_repo()
    try:
        print(f"Running act in: {tmpdir}")
        result = run_cmd(
            "act push --rm --pull=false -j aggregate 2>&1",
            cwd=tmpdir,
            check=False,
        )
        output = result.stdout + result.stderr
        return result.returncode, output
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def test_act_integration():
    """
    Run the full workflow through act and verify:
    - Exit code is 0
    - Job succeeded
    - Output contains exact expected values for totals, flaky tests, etc.
    """
    exit_code, output = run_act_test()

    # Save to act-result.txt (required artifact)
    with open(ACT_RESULT_PATH, "a") as f:
        f.write("=" * 60 + "\n")
        f.write("ACT INTEGRATION TEST\n")
        f.write("=" * 60 + "\n")
        f.write(output)
        f.write("\n")

    # -- Assert act succeeded --
    assert exit_code == 0, f"act exited with code {exit_code}. Check act-result.txt"
    print("PASS: act exited with code 0")

    # -- Assert job succeeded --
    assert "Job succeeded" in output, "Output missing 'Job succeeded'"
    print("PASS: Job succeeded found in output")

    # -- Assert exact totals --
    assert f"Passed: {EXPECTED_TOTAL_PASSED}" in output, (
        f"Expected 'Passed: {EXPECTED_TOTAL_PASSED}' in output"
    )
    print(f"PASS: Found Passed: {EXPECTED_TOTAL_PASSED}")

    assert f"Failed: {EXPECTED_TOTAL_FAILED}" in output, (
        f"Expected 'Failed: {EXPECTED_TOTAL_FAILED}' in output"
    )
    print(f"PASS: Found Failed: {EXPECTED_TOTAL_FAILED}")

    assert f"Skipped: {EXPECTED_TOTAL_SKIPPED}" in output, (
        f"Expected 'Skipped: {EXPECTED_TOTAL_SKIPPED}' in output"
    )
    print(f"PASS: Found Skipped: {EXPECTED_TOTAL_SKIPPED}")

    assert f"Duration: {EXPECTED_TOTAL_DURATION}s" in output, (
        f"Expected 'Duration: {EXPECTED_TOTAL_DURATION}s' in output"
    )
    print(f"PASS: Found Duration: {EXPECTED_TOTAL_DURATION}s")

    assert f"Total: {EXPECTED_TOTAL_TESTS}" in output, (
        f"Expected 'Total: {EXPECTED_TOTAL_TESTS}' in output"
    )
    print(f"PASS: Found Total: {EXPECTED_TOTAL_TESTS}")

    # -- Assert flaky tests --
    for flaky in EXPECTED_FLAKY_TESTS:
        assert flaky in output, f"Expected flaky test '{flaky}' in output"
        print(f"PASS: Found flaky test: {flaky}")

    # -- Assert markdown summary markers --
    assert "# Test Results Summary" in output, "Missing markdown heading"
    print("PASS: Markdown summary heading found")

    assert "## Flaky Tests" in output, "Missing flaky tests section"
    print("PASS: Flaky tests section found")

    print("\nAll act integration assertions passed!")


# ============================================================
# ERROR HANDLING TEST
# ============================================================

def test_act_error_handling():
    """
    Test that the aggregator handles missing/malformed files gracefully.
    We create a temp repo with a bad fixture and verify the workflow still
    completes (the aggregator should report errors, not crash).
    """
    tmpdir = tempfile.mkdtemp(prefix="act_err_test_")
    try:
        # Copy project files
        for item in os.listdir(SCRIPT_DIR):
            if item.startswith(".git") and item != ".github" and item != ".actrc":
                continue
            if item == "act-result.txt":
                continue
            src = os.path.join(SCRIPT_DIR, item)
            dst = os.path.join(tmpdir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        actrc = os.path.join(SCRIPT_DIR, ".actrc")
        if os.path.isfile(actrc):
            shutil.copy2(actrc, os.path.join(tmpdir, ".actrc"))

        # Add a malformed XML fixture
        bad_xml = os.path.join(tmpdir, "fixtures", "bad_file.xml")
        with open(bad_xml, "w") as f:
            f.write("<not valid junit xml></whoops>")

        # Add a malformed JSON fixture
        bad_json = os.path.join(tmpdir, "fixtures", "bad_file.json")
        with open(bad_json, "w") as f:
            f.write("{not valid json")

        # Init git
        run_cmd("git init", cwd=tmpdir)
        run_cmd("git config user.email 'test@test.com'", cwd=tmpdir)
        run_cmd("git config user.name 'Test'", cwd=tmpdir)
        run_cmd("git add -A", cwd=tmpdir)
        run_cmd("git commit -m 'initial with bad fixtures'", cwd=tmpdir)

        print(f"Running act (error handling test) in: {tmpdir}")
        result = run_cmd(
            "act push --rm --pull=false -j aggregate 2>&1",
            cwd=tmpdir,
            check=False,
        )
        output = result.stdout + result.stderr

        # Save to act-result.txt
        with open(ACT_RESULT_PATH, "a") as f:
            f.write("=" * 60 + "\n")
            f.write("ACT ERROR HANDLING TEST\n")
            f.write("=" * 60 + "\n")
            f.write(output)
            f.write("\n")

        # The workflow should still succeed (graceful error handling)
        assert exit_code_ok(result.returncode, output), (
            f"act failed for error handling test (exit {result.returncode})"
        )
        print("PASS: Error handling test - workflow completed despite bad fixtures")

        # Should still show some valid results from the good fixtures
        assert "Passed:" in output, "Expected some passing results even with bad fixtures"
        print("PASS: Error handling test - still shows results from good fixtures")

        # Should mention errors/warnings about bad files
        assert "error" in output.lower() or "warning" in output.lower() or "skipping" in output.lower(), (
            "Expected error/warning messages about malformed fixtures"
        )
        print("PASS: Error handling test - reports errors for bad files")

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    print("\nAll error handling assertions passed!")


def exit_code_ok(code, output):
    """Check if act succeeded (exit 0 and Job succeeded in output)."""
    return code == 0 and "Job succeeded" in output


# ============================================================
# MAIN
# ============================================================

def main():
    """Run all tests."""
    # Clear act-result.txt for fresh run
    if os.path.exists(ACT_RESULT_PATH):
        os.remove(ACT_RESULT_PATH)

    # Ensure act-result.txt file is created even if we fail early
    with open(ACT_RESULT_PATH, "w") as f:
        f.write("Test Results Aggregator - Act Test Output\n")
        f.write("=" * 60 + "\n\n")

    passed = 0
    failed = 0
    errors = []

    # -- Workflow structure tests (fast, no act needed) --
    print("\n--- WORKFLOW STRUCTURE TESTS ---\n")

    try:
        test_workflow_file_exists()
        passed += 1
    except AssertionError as e:
        failed += 1
        errors.append(f"test_workflow_file_exists: {e}")
        print(f"FAIL: test_workflow_file_exists: {e}")
        # Can't continue without the workflow file
        print(f"\nResults: {passed} passed, {failed} failed")
        sys.exit(1)

    try:
        data = test_workflow_valid_yaml()
        passed += 1
    except (AssertionError, yaml.YAMLError) as e:
        failed += 1
        errors.append(f"test_workflow_valid_yaml: {e}")
        print(f"FAIL: test_workflow_valid_yaml: {e}")
        print(f"\nResults: {passed} passed, {failed} failed")
        sys.exit(1)

    for test_fn, args in [
        (test_workflow_triggers, (data,)),
        (test_workflow_jobs, (data,)),
    ]:
        try:
            result = test_fn(*args)
            passed += 1
            if test_fn == test_workflow_jobs:
                jobs = result
        except AssertionError as e:
            failed += 1
            errors.append(f"{test_fn.__name__}: {e}")
            print(f"FAIL: {test_fn.__name__}: {e}")

    if "jobs" in dir() or True:
        try:
            jobs = data.get("jobs", {})
            test_workflow_steps(jobs)
            passed += 1
        except AssertionError as e:
            failed += 1
            errors.append(f"test_workflow_steps: {e}")
            print(f"FAIL: test_workflow_steps: {e}")

        try:
            test_workflow_references_existing_files(jobs)
            passed += 1
        except AssertionError as e:
            failed += 1
            errors.append(f"test_workflow_references_existing_files: {e}")
            print(f"FAIL: test_workflow_references_existing_files: {e}")

    try:
        test_actionlint_passes()
        passed += 1
    except AssertionError as e:
        failed += 1
        errors.append(f"test_actionlint_passes: {e}")
        print(f"FAIL: test_actionlint_passes: {e}")

    # -- Act integration tests --
    print("\n--- ACT INTEGRATION TESTS ---\n")

    try:
        test_act_integration()
        passed += 1
    except AssertionError as e:
        failed += 1
        errors.append(f"test_act_integration: {e}")
        print(f"FAIL: test_act_integration: {e}")

    try:
        test_act_error_handling()
        passed += 1
    except AssertionError as e:
        failed += 1
        errors.append(f"test_act_error_handling: {e}")
        print(f"FAIL: test_act_error_handling: {e}")

    # -- Summary --
    print(f"\n{'=' * 60}")
    print(f"TOTAL: {passed} passed, {failed} failed")
    print(f"{'=' * 60}")

    if errors:
        print("\nFailures:")
        for e in errors:
            print(f"  - {e}")

    # Ensure act-result.txt exists
    assert os.path.isfile(ACT_RESULT_PATH), "act-result.txt was not created!"

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
