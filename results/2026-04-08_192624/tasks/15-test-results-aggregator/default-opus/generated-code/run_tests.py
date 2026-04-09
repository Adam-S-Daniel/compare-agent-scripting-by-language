#!/usr/bin/env python3
"""
Test Harness for Test Results Aggregator

Runs all test cases through GitHub Actions via `act`. Each test case:
1. Sets up a temp git repo with the project files + specific fixture data
2. Runs `act push --rm` and captures output
3. Asserts exit code 0 and expected values in output
4. Appends output to act-result.txt

TDD methodology: Each test case was written FIRST as a failing test,
then the aggregator was updated to make it pass.

Test cases:
  TC1 (junit_only)     - Parse a single JUnit XML file, verify exact totals
  TC2 (json_only)      - Parse a single JSON file, verify exact totals
  TC3 (mixed_formats)  - Parse both XML and JSON, verify combined totals
  TC4 (flaky_detection)- Detect flaky tests from multiple runs
  TC5 (empty_results)  - Handle empty directory gracefully
  TC6 (workflow_structure) - Validate YAML structure, triggers, paths, actionlint
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import yaml

# Path to this project directory (where aggregator.py and fixtures/ live)
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")

# Track test results
test_results = []


def setup_temp_repo(fixture_subdir):
    """
    Create a temporary git repo with the project's aggregator, workflow,
    and only the specified fixture directory (copied into fixtures/).
    Returns the path to the temp directory.
    """
    tmpdir = tempfile.mkdtemp(prefix="test_aggregator_")

    # Copy aggregator script
    shutil.copy2(os.path.join(PROJECT_DIR, "aggregator.py"), tmpdir)

    # Copy workflow
    wf_dir = os.path.join(tmpdir, ".github", "workflows")
    os.makedirs(wf_dir, exist_ok=True)
    shutil.copy2(
        os.path.join(PROJECT_DIR, ".github", "workflows", "test-results-aggregator.yml"),
        wf_dir,
    )

    # Copy fixture data into fixtures/ (the RESULTS_DIR the workflow expects)
    fixtures_dst = os.path.join(tmpdir, "fixtures")
    os.makedirs(fixtures_dst, exist_ok=True)

    if fixture_subdir is not None:
        src = os.path.join(PROJECT_DIR, "fixtures", fixture_subdir)
        if os.path.isdir(src):
            for f in os.listdir(src):
                shutil.copy2(os.path.join(src, f), fixtures_dst)

    # Ensure fixtures dir is tracked by git (git ignores empty dirs)
    gitkeep = os.path.join(fixtures_dst, ".gitkeep")
    if not os.listdir(fixtures_dst):
        with open(gitkeep, "w") as f:
            f.write("")

    # Initialize git repo (act requires a git repo)
    subprocess.run(
        ["git", "init", "-b", "main"],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "add", "."],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "initial"],
        cwd=tmpdir, capture_output=True, check=True,
    )

    return tmpdir


def run_act(tmpdir, timeout=300):
    """Run act push --rm in the given directory and return (exit_code, stdout)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--detect-event"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    combined = result.stdout + "\n" + result.stderr
    return result.returncode, combined


def extract_totals(output):
    """Extract the structured totals block from act output."""
    totals = {}
    in_block = False
    for line in output.splitlines():
        # act prefixes lines with job/step info; look for our markers
        if "=== AGGREGATED TOTALS ===" in line:
            in_block = True
            continue
        if "=== END TOTALS ===" in line:
            in_block = False
            continue
        if in_block:
            # Lines like "TOTAL=5" (possibly with act prefix)
            match = re.search(r'(TOTAL|PASSED|FAILED|SKIPPED|DURATION|FILES_PARSED|FLAKY_COUNT|FLAKY_TESTS)=(.+)', line)
            if match:
                totals[match.group(1)] = match.group(2).strip()
    return totals


def assert_eq(label, actual, expected):
    """Assert equality with a descriptive message."""
    if str(actual) != str(expected):
        raise AssertionError(f"  FAIL: {label}: expected '{expected}', got '{actual}'")


def assert_contains(label, haystack, needle):
    """Assert that needle is in haystack."""
    if needle not in haystack:
        raise AssertionError(f"  FAIL: {label}: expected output to contain '{needle}'")


def assert_job_succeeded(output):
    """Assert that act reports the job succeeded."""
    if "Job succeeded" not in output:
        raise AssertionError("  FAIL: Expected 'Job succeeded' in act output")


def run_test_case(name, fixture_subdir, assertions_fn, expect_act_zero=True):
    """
    Run a single test case:
    1. Setup temp repo with given fixtures
    2. Run act
    3. Run assertions
    4. Append to act-result.txt
    """
    print(f"\n{'='*60}")
    print(f"TEST CASE: {name}")
    print(f"{'='*60}")

    tmpdir = None
    try:
        tmpdir = setup_temp_repo(fixture_subdir)
        exit_code, output = run_act(tmpdir)

        # Append to act-result.txt
        with open(ACT_RESULT_FILE, "a") as f:
            f.write(f"\n{'='*60}\n")
            f.write(f"TEST CASE: {name}\n")
            f.write(f"{'='*60}\n")
            f.write(output)
            f.write(f"\nEXIT CODE: {exit_code}\n")

        if expect_act_zero:
            if exit_code != 0:
                print(f"  FAIL: act exited with code {exit_code} (expected 0)")
                print(f"  Output tail:\n{output[-2000:]}")
                test_results.append((name, False, f"act exit code {exit_code}"))
                return

        # Run assertions
        assertions_fn(output, exit_code)

        print(f"  PASS: {name}")
        test_results.append((name, True, ""))

    except AssertionError as e:
        print(str(e))
        test_results.append((name, False, str(e)))
    except Exception as e:
        print(f"  ERROR: {e}")
        test_results.append((name, False, str(e)))
    finally:
        if tmpdir and os.path.exists(tmpdir):
            shutil.rmtree(tmpdir, ignore_errors=True)


# ============================================================
# TEST CASES
# ============================================================

# TDD RED: Wrote this test first. It failed because aggregator.py didn't exist.
# TDD GREEN: Implemented parse_junit_xml() to make it pass.
# TDD REFACTOR: Extracted TestResult dataclass for cleaner code.

def test_junit_only(output, exit_code):
    """TC1: Parse single JUnit XML - 5 tests, 3 passed, 1 failed, 1 skipped."""
    totals = extract_totals(output)

    assert_eq("TOTAL", totals.get("TOTAL"), "5")
    assert_eq("PASSED", totals.get("PASSED"), "3")
    assert_eq("FAILED", totals.get("FAILED"), "1")
    assert_eq("SKIPPED", totals.get("SKIPPED"), "1")
    assert_eq("DURATION", totals.get("DURATION"), "2.5")
    assert_eq("FILES_PARSED", totals.get("FILES_PARSED"), "1")
    assert_eq("FLAKY_COUNT", totals.get("FLAKY_COUNT"), "0")

    # Verify markdown output
    assert_contains("markdown header", output, "# Test Results Summary")
    assert_contains("status", output, "**Status: FAILED**")
    assert_contains("failed test detail", output, "math_tests::test_multiply")
    assert_job_succeeded(output)


# TDD RED: Wrote this test. Failed because parse_json() wasn't implemented.
# TDD GREEN: Implemented parse_json().

def test_json_only(output, exit_code):
    """TC2: Parse single JSON file - 4 tests, 2 passed, 1 failed, 1 skipped."""
    totals = extract_totals(output)

    assert_eq("TOTAL", totals.get("TOTAL"), "4")
    assert_eq("PASSED", totals.get("PASSED"), "2")
    assert_eq("FAILED", totals.get("FAILED"), "1")
    assert_eq("SKIPPED", totals.get("SKIPPED"), "1")
    assert_eq("DURATION", totals.get("DURATION"), "0.65")
    assert_eq("FILES_PARSED", totals.get("FILES_PARSED"), "1")
    assert_eq("FLAKY_COUNT", totals.get("FLAKY_COUNT"), "0")

    assert_contains("failed test", output, "string_tests::test_upper")
    assert_job_succeeded(output)


# TDD RED: Wrote this test. Failed because multi-file aggregation wasn't done.
# TDD GREEN: Implemented find_result_files() + aggregate().

def test_mixed_formats(output, exit_code):
    """TC3: Parse both XML and JSON files - combined totals."""
    totals = extract_totals(output)

    # run1_results.xml: 3 tests (2 passed, 1 failed)
    # run2_results.json: 4 tests (2 passed, 1 failed, 1 skipped)
    # Total: 7 tests, 4 passed, 2 failed, 1 skipped
    assert_eq("TOTAL", totals.get("TOTAL"), "7")
    assert_eq("PASSED", totals.get("PASSED"), "4")
    assert_eq("FAILED", totals.get("FAILED"), "2")
    assert_eq("SKIPPED", totals.get("SKIPPED"), "1")
    # Duration: 1.200 + 0.6+0.4+0.35+0.0 = 1.200 + 1.350 = 2.55
    assert_eq("DURATION", totals.get("DURATION"), "2.55")
    assert_eq("FILES_PARSED", totals.get("FILES_PARSED"), "2")

    assert_contains("api failure", output, "api_tests::test_create_user")
    assert_contains("db failure", output, "db_tests::test_query")
    assert_job_succeeded(output)


# TDD RED: Wrote this test. Failed because detect_flaky_tests() wasn't implemented.
# TDD GREEN: Implemented flaky detection logic.
# TDD REFACTOR: Improved by grouping outcomes per test identity.

def test_flaky_detection(output, exit_code):
    """TC4: Detect flaky tests - test_checkout passes in some runs, fails in others."""
    totals = extract_totals(output)

    # 3 runs x 4 tests = 12 total test results
    assert_eq("TOTAL", totals.get("TOTAL"), "12")
    assert_eq("FILES_PARSED", totals.get("FILES_PARSED"), "3")

    # test_checkout: failed in run1, passed in run2, failed in run3 -> FLAKY
    # test_search: failed in run1, failed in run2, passed in run3 -> FLAKY
    assert_eq("FLAKY_COUNT", totals.get("FLAKY_COUNT"), "2")

    flaky_tests = totals.get("FLAKY_TESTS", "")
    assert_contains("flaky checkout", flaky_tests, "integration::test_checkout")
    assert_contains("flaky search", flaky_tests, "integration::test_search")

    # Verify markdown includes flaky section
    assert_contains("flaky section", output, "## Flaky Tests")
    assert_contains("flaky detail", output, "integration::test_checkout")
    assert_job_succeeded(output)


# TDD RED: Wrote this test. Failed because empty dir caused error.
# TDD GREEN: Made aggregate() handle empty results gracefully.

def test_empty_results(output, exit_code):
    """TC5: Handle empty directory - no test files found."""
    totals = extract_totals(output)

    assert_eq("TOTAL", totals.get("TOTAL"), "0")
    assert_eq("PASSED", totals.get("PASSED"), "0")
    assert_eq("FAILED", totals.get("FAILED"), "0")
    assert_eq("SKIPPED", totals.get("SKIPPED"), "0")
    assert_eq("DURATION", totals.get("DURATION"), "0.0")
    assert_eq("FILES_PARSED", totals.get("FILES_PARSED"), "0")

    assert_contains("no tests status", output, "**Status: NO TESTS FOUND**")
    assert_job_succeeded(output)


# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================

def test_workflow_structure():
    """TC6: Validate workflow YAML structure, triggers, file references, actionlint."""
    print(f"\n{'='*60}")
    print("TEST CASE: workflow_structure")
    print(f"{'='*60}")

    errors = []

    # Parse the YAML
    wf_path = os.path.join(PROJECT_DIR, ".github", "workflows", "test-results-aggregator.yml")
    try:
        with open(wf_path, "r") as f:
            wf = yaml.safe_load(f)
    except Exception as e:
        errors.append(f"Failed to parse workflow YAML: {e}")
        print(f"  FAIL: {errors[-1]}")
        test_results.append(("workflow_structure", False, "; ".join(errors)))
        return

    # Check triggers exist
    triggers = wf.get(True, wf.get("on", {}))  # yaml parses 'on' as True
    if not triggers:
        errors.append("No triggers (on:) found in workflow")
    else:
        # Check for push trigger
        if "push" not in triggers:
            errors.append("Missing 'push' trigger")
        if "workflow_dispatch" not in triggers:
            errors.append("Missing 'workflow_dispatch' trigger")

    # Check jobs exist
    jobs = wf.get("jobs", {})
    if not jobs:
        errors.append("No jobs defined")
    else:
        # At least one job should exist
        job = list(jobs.values())[0]
        steps = job.get("steps", [])
        if len(steps) < 2:
            errors.append(f"Expected at least 2 steps, got {len(steps)}")

        # Verify checkout step
        has_checkout = any(
            s.get("uses", "").startswith("actions/checkout") for s in steps
        )
        if not has_checkout:
            errors.append("Missing actions/checkout step")

        # Verify aggregator.py is referenced
        step_runs = " ".join(s.get("run", "") for s in steps)
        if "aggregator.py" not in step_runs:
            errors.append("Workflow does not reference aggregator.py")

    # Verify aggregator.py exists
    agg_path = os.path.join(PROJECT_DIR, "aggregator.py")
    if not os.path.exists(agg_path):
        errors.append("aggregator.py not found in project directory")

    # Run actionlint
    result = subprocess.run(
        ["actionlint", wf_path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        errors.append(f"actionlint failed: {result.stdout}{result.stderr}")

    # Write to act-result.txt
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write("TEST CASE: workflow_structure\n")
        f.write(f"{'='*60}\n")
        f.write(f"YAML parsed: OK\n")
        f.write(f"Triggers: {list(triggers.keys()) if triggers else 'NONE'}\n")
        f.write(f"Jobs: {list(jobs.keys()) if jobs else 'NONE'}\n")
        f.write(f"actionlint: {'PASS' if result.returncode == 0 else 'FAIL'}\n")
        if errors:
            f.write(f"Errors: {'; '.join(errors)}\n")
        f.write(f"\n")

    if errors:
        for e in errors:
            print(f"  FAIL: {e}")
        test_results.append(("workflow_structure", False, "; ".join(errors)))
    else:
        print("  PASS: workflow_structure")
        test_results.append(("workflow_structure", True, ""))


# ============================================================
# MAIN
# ============================================================

def main():
    # Clear act-result.txt
    with open(ACT_RESULT_FILE, "w") as f:
        f.write("Test Results Aggregator - Act Test Results\n")
        f.write(f"{'='*60}\n")

    print("Running Test Results Aggregator test suite via act...")
    print(f"Project dir: {PROJECT_DIR}")
    print(f"Results file: {ACT_RESULT_FILE}")

    # TC6: Workflow structure tests (no act needed)
    test_workflow_structure()

    # TC1-TC5: Tests that run through act
    # TDD RED/GREEN cycle for each test case:
    run_test_case("junit_only", "junit_only", test_junit_only)
    run_test_case("json_only", "json_only", test_json_only)
    run_test_case("mixed_formats", "mixed", test_mixed_formats)
    run_test_case("flaky_detection", "flaky", test_flaky_detection)
    run_test_case("empty_results", "empty", test_empty_results)

    # Summary
    print(f"\n{'='*60}")
    print("TEST SUMMARY")
    print(f"{'='*60}")

    passed = sum(1 for _, ok, _ in test_results if ok)
    failed = sum(1 for _, ok, _ in test_results if not ok)

    for name, ok, msg in test_results:
        status = "PASS" if ok else "FAIL"
        detail = f" - {msg}" if msg else ""
        print(f"  [{status}] {name}{detail}")

    print(f"\n  Total: {len(test_results)}, Passed: {passed}, Failed: {failed}")

    # Append summary to act-result.txt
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write("OVERALL SUMMARY\n")
        f.write(f"{'='*60}\n")
        for name, ok, msg in test_results:
            status = "PASS" if ok else "FAIL"
            f.write(f"  [{status}] {name}\n")
        f.write(f"\nTotal: {len(test_results)}, Passed: {passed}, Failed: {failed}\n")

    if failed > 0:
        sys.exit(1)
    print("\nAll tests passed!")
    return 0


if __name__ == "__main__":
    main()
