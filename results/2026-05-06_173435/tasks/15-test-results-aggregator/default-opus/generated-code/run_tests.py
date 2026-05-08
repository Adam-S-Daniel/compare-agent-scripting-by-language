#!/usr/bin/env python3
"""Test harness for the test results aggregator.

TDD approach: these assertions were written FIRST, before the aggregator code.
Each test case sets up a temp git repo, runs `act push --rm`, captures output,
and asserts on exact expected values.
"""

import os
import sys
import shutil
import subprocess
import tempfile
import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")
WORKFLOW_PATH = os.path.join(SCRIPT_DIR, ".github", "workflows", "test-results-aggregator.yml")

# Expected values computed from fixture data:
#
# junit_run1.xml: api_tests — 3 pass, 1 fail (test_signup), 0 skip, 3.5s
# junit_run2.xml: api_tests — 3 pass, 0 fail, 1 skip (test_logout), 2.8s
# json_run1.json: db_tests  — 3 pass, 1 fail (test_insert), 0 skip, 1.8s
# json_run2.json: db_tests  — 2 pass, 2 fail (test_query, test_insert), 0 skip, 1.8s
#
# Totals: 16 tests, 11 passed, 4 failed, 1 skipped, 9.9s duration
# Flaky: api_tests.test_signup (fail run1, pass run2),
#        db_tests.test_query (pass run1, fail run2)

EXPECTED_TOTAL = 16
EXPECTED_PASSED = 11
EXPECTED_FAILED = 4
EXPECTED_SKIPPED = 1
EXPECTED_DURATION = "9.9"
EXPECTED_FLAKY = sorted(["api_tests.test_signup", "db_tests.test_query"])


def clear_act_result():
    if os.path.exists(ACT_RESULT_FILE):
        os.remove(ACT_RESULT_FILE)


def append_act_result(label, content):
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"TEST CASE: {label}\n")
        f.write(f"{'='*60}\n")
        f.write(content)
        f.write("\n")


def run_workflow_structure_tests():
    """Parse the YAML and check expected structure, file refs, and actionlint."""
    print("\n--- Workflow Structure Tests ---")
    failures = []

    # Test 1: YAML is valid and has expected triggers
    print("  [TEST] Workflow YAML parses correctly and has expected triggers...")
    try:
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)

        triggers = wf.get(True, wf.get("on", {}))
        expected_triggers = {"push", "workflow_dispatch"}
        actual_triggers = set(triggers.keys()) if isinstance(triggers, dict) else set()
        if not expected_triggers.issubset(actual_triggers):
            failures.append(
                f"Missing triggers: expected at least {expected_triggers}, got {actual_triggers}"
            )
        else:
            print("    PASS: triggers include push and workflow_dispatch")
    except Exception as e:
        failures.append(f"YAML parse error: {e}")

    # Test 2: Jobs and steps exist
    print("  [TEST] Workflow has 'aggregate' job with run steps...")
    try:
        jobs = wf.get("jobs", {})
        if "aggregate" not in jobs:
            failures.append("Missing 'aggregate' job")
        else:
            steps = jobs["aggregate"].get("steps", [])
            step_names = [s.get("name", "") for s in steps]
            if not any("checkout" in n.lower() or "actions/checkout" in s.get("uses", "") for n, s in zip(step_names, steps)):
                failures.append("No checkout step found")
            else:
                print("    PASS: 'aggregate' job exists with checkout step")

            if not any("run" in s for s in steps):
                failures.append("No 'run' step found in aggregate job")
            else:
                print("    PASS: 'aggregate' job has run steps")
    except Exception as e:
        failures.append(f"Job structure error: {e}")

    # Test 3: Script files referenced by workflow exist
    print("  [TEST] Script files referenced in workflow exist...")
    try:
        for step in jobs.get("aggregate", {}).get("steps", []):
            run_cmd = step.get("run", "")
            if "aggregator.py" in run_cmd:
                agg_path = os.path.join(SCRIPT_DIR, "aggregator.py")
                if not os.path.exists(agg_path):
                    failures.append(f"aggregator.py not found at {agg_path}")
                else:
                    print("    PASS: aggregator.py exists")
                break
    except Exception as e:
        failures.append(f"File reference check error: {e}")

    # Test 4: actionlint passes
    print("  [TEST] actionlint passes with exit code 0...")
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        failures.append(f"actionlint failed:\n{result.stdout}\n{result.stderr}")
    else:
        print("    PASS: actionlint clean")

    return failures


def setup_temp_repo(fixtures_subdir=None):
    """Create a temp git repo with project files and optional fixture subset."""
    tmpdir = tempfile.mkdtemp(prefix="act_test_")

    # Copy project files
    for item in ["aggregator.py", ".github"]:
        src = os.path.join(SCRIPT_DIR, item)
        dst = os.path.join(tmpdir, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Copy fixtures
    fixtures_src = os.path.join(SCRIPT_DIR, "fixtures")
    fixtures_dst = os.path.join(tmpdir, "fixtures")
    if fixtures_subdir:
        os.makedirs(fixtures_dst)
        for fname in fixtures_subdir:
            shutil.copy2(
                os.path.join(fixtures_src, fname),
                os.path.join(fixtures_dst, fname)
            )
    else:
        shutil.copytree(fixtures_src, fixtures_dst)

    # Copy .actrc if present
    actrc = os.path.join(SCRIPT_DIR, ".actrc")
    if os.path.exists(actrc):
        shutil.copy2(actrc, os.path.join(tmpdir, ".actrc"))

    # Init git repo
    subprocess.run(
        ["git", "init"], cwd=tmpdir,
        capture_output=True, check=True
    )
    subprocess.run(
        ["git", "add", "-A"], cwd=tmpdir,
        capture_output=True, check=True
    )
    subprocess.run(
        ["git", "commit", "-m", "initial"],
        cwd=tmpdir, capture_output=True, check=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@test.com",
             "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@test.com"}
    )
    return tmpdir


def run_act(tmpdir, label):
    """Run act push in the temp repo and return (exit_code, output)."""
    print(f"\n  Running act for: {label}")
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True, text=True,
        timeout=180
    )
    output = result.stdout + "\n" + result.stderr
    append_act_result(label, output)
    return result.returncode, output


def test_full_aggregation():
    """Test with all 4 fixture files — verifies totals, flaky detection, markdown."""
    print("\n--- Test: Full Aggregation (all fixtures) ---")
    failures = []

    tmpdir = setup_temp_repo()
    try:
        exit_code, output = run_act(tmpdir, "full_aggregation")

        # Assert act succeeded
        if exit_code != 0:
            failures.append(f"act exited with code {exit_code}")
            print(f"  FAIL: act exit code {exit_code}")
            # Still check output for diagnostics
        else:
            print("  PASS: act exited with code 0")

        # Assert job succeeded
        if "Job succeeded" not in output:
            failures.append("'Job succeeded' not found in output")
        else:
            print("  PASS: Job succeeded")

        # Assert exact totals
        if f"TOTAL_TESTS: {EXPECTED_TOTAL}" not in output:
            failures.append(f"Expected TOTAL_TESTS: {EXPECTED_TOTAL} not in output")
        else:
            print(f"  PASS: TOTAL_TESTS = {EXPECTED_TOTAL}")

        if f"TOTAL_PASSED: {EXPECTED_PASSED}" not in output:
            failures.append(f"Expected TOTAL_PASSED: {EXPECTED_PASSED} not in output")
        else:
            print(f"  PASS: TOTAL_PASSED = {EXPECTED_PASSED}")

        if f"TOTAL_FAILED: {EXPECTED_FAILED}" not in output:
            failures.append(f"Expected TOTAL_FAILED: {EXPECTED_FAILED} not in output")
        else:
            print(f"  PASS: TOTAL_FAILED = {EXPECTED_FAILED}")

        if f"TOTAL_SKIPPED: {EXPECTED_SKIPPED}" not in output:
            failures.append(f"Expected TOTAL_SKIPPED: {EXPECTED_SKIPPED} not in output")
        else:
            print(f"  PASS: TOTAL_SKIPPED = {EXPECTED_SKIPPED}")

        if f"TOTAL_DURATION: {EXPECTED_DURATION}" not in output:
            failures.append(f"Expected TOTAL_DURATION: {EXPECTED_DURATION} not in output")
        else:
            print(f"  PASS: TOTAL_DURATION = {EXPECTED_DURATION}")

        # Assert flaky tests
        for flaky in EXPECTED_FLAKY:
            if flaky not in output:
                failures.append(f"Expected flaky test '{flaky}' not in output")
            else:
                print(f"  PASS: Flaky test detected: {flaky}")

        # Assert markdown summary sections
        for section in ["# Test Results Summary", "## Totals", "## Flaky Tests"]:
            if section not in output:
                failures.append(f"Markdown section '{section}' not in output")
            else:
                print(f"  PASS: Markdown contains '{section}'")

        # Assert markdown has exact pass rate
        # 11/16 = 68.8% (rounded to 1 decimal)
        if "68.8%" not in output:
            failures.append("Expected pass rate '68.8%' not in markdown")
        else:
            print("  PASS: Pass rate 68.8% in markdown")

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    return failures


def test_partial_no_flaky():
    """Test with only run1 files — no flaky tests should be detected."""
    print("\n--- Test: Partial (run1 only, no flaky tests) ---")
    failures = []

    tmpdir = setup_temp_repo(fixtures_subdir=["junit_run1.xml", "json_run1.json"])
    try:
        exit_code, output = run_act(tmpdir, "partial_no_flaky")

        if exit_code != 0:
            failures.append(f"act exited with code {exit_code}")
        else:
            print("  PASS: act exited with code 0")

        if "Job succeeded" not in output:
            failures.append("'Job succeeded' not found in output")
        else:
            print("  PASS: Job succeeded")

        # run1 totals: junit(3p,1f,0s) + json(3p,1f,0s) = 8 tests, 6 pass, 2 fail, 0 skip
        # duration: 3.5 + 1.8 = 5.3
        if "TOTAL_TESTS: 8" not in output:
            failures.append("Expected TOTAL_TESTS: 8")
        else:
            print("  PASS: TOTAL_TESTS = 8")

        if "TOTAL_PASSED: 6" not in output:
            failures.append("Expected TOTAL_PASSED: 6")
        else:
            print("  PASS: TOTAL_PASSED = 6")

        if "TOTAL_FAILED: 2" not in output:
            failures.append("Expected TOTAL_FAILED: 2")
        else:
            print("  PASS: TOTAL_FAILED = 2")

        if "TOTAL_SKIPPED: 0" not in output:
            failures.append("Expected TOTAL_SKIPPED: 0")
        else:
            print("  PASS: TOTAL_SKIPPED = 0")

        if "TOTAL_DURATION: 5.3" not in output:
            failures.append("Expected TOTAL_DURATION: 5.3")
        else:
            print("  PASS: TOTAL_DURATION = 5.3")

        # No flaky tests with single runs per suite
        if "FLAKY_TESTS: none" not in output:
            failures.append("Expected 'FLAKY_TESTS: none' for single-run data")
        else:
            print("  PASS: No flaky tests detected")

        # pass rate: 6/8 = 75.0%
        if "75.0%" not in output:
            failures.append("Expected pass rate '75.0%'")
        else:
            print("  PASS: Pass rate 75.0%")

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    return failures


def main():
    clear_act_result()
    all_failures = []

    # Phase 1: Workflow structure tests (no act needed)
    struct_failures = run_workflow_structure_tests()
    all_failures.extend(struct_failures)

    if struct_failures:
        print(f"\n*** {len(struct_failures)} structure test(s) FAILED ***")
        for f in struct_failures:
            print(f"  - {f}")
        print("\nFix structure issues before running act tests.")
        sys.exit(1)

    # Phase 2: Act-based integration tests
    # Test case 1: full aggregation with all fixtures
    failures1 = test_full_aggregation()
    all_failures.extend(failures1)

    # Test case 2: partial fixtures (no flaky)
    failures2 = test_partial_no_flaky()
    all_failures.extend(failures2)

    # Summary
    print(f"\n{'='*60}")
    print("TEST SUMMARY")
    print(f"{'='*60}")

    total_tests = 0
    total_pass = 0

    for label, fails in [("Structure", struct_failures), ("Full Aggregation", failures1), ("Partial No-Flaky", failures2)]:
        # Count individual assertions, not just failure groups
        if not fails:
            print(f"  {label}: ALL PASSED")
            total_pass += 1
        else:
            print(f"  {label}: FAILED ({len(fails)} failures)")
            for f in fails:
                print(f"    - {f}")
        total_tests += 1

    print(f"\n{total_pass}/{total_tests} test groups passed")

    if not os.path.exists(ACT_RESULT_FILE):
        print("\nWARNING: act-result.txt was not created!")
    else:
        size = os.path.getsize(ACT_RESULT_FILE)
        print(f"\nact-result.txt: {size} bytes")

    if all_failures:
        print(f"\n*** FAILED: {len(all_failures)} total failure(s) ***")
        sys.exit(1)
    else:
        print("\n*** ALL TESTS PASSED ***")
        sys.exit(0)


if __name__ == "__main__":
    main()
