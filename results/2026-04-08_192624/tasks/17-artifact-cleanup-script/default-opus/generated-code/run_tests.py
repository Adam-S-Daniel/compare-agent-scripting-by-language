#!/usr/bin/env python3
"""
Test harness for artifact cleanup script.

Runs all tests through GitHub Actions via `act`. Each test case:
1. Sets up a temp git repo with project files + fixture data
2. Runs `act push --rm` to execute the workflow
3. Captures output and asserts on exact expected values
4. Appends output to act-result.txt

Also includes workflow structure tests (YAML parsing, actionlint, file references).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import yaml

# --- Configuration ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")
WORKFLOW_FILE = os.path.join(SCRIPT_DIR, ".github", "workflows", "artifact-cleanup-script.yml")
SCRIPT_FILE = os.path.join(SCRIPT_DIR, "artifact_cleanup.py")
FIXTURES_DIR = os.path.join(SCRIPT_DIR, "fixtures")

# Track pass/fail counts
passed = 0
failed = 0
errors = []


def log(msg):
    """Print a test log message."""
    print(msg)


def write_result(content):
    """Append content to act-result.txt."""
    with open(RESULT_FILE, "a") as f:
        f.write(content)


def setup_temp_repo(fixture_file):
    """
    Create a temporary git repo with the project files and a specific fixture
    as input.json. Returns the temp directory path.
    """
    tmpdir = tempfile.mkdtemp(prefix="act-test-")

    # Copy the script
    shutil.copy(SCRIPT_FILE, os.path.join(tmpdir, "artifact_cleanup.py"))

    # Copy the workflow
    wf_dir = os.path.join(tmpdir, ".github", "workflows")
    os.makedirs(wf_dir)
    shutil.copy(WORKFLOW_FILE, os.path.join(wf_dir, "artifact-cleanup-script.yml"))

    # Copy fixture as input.json
    shutil.copy(fixture_file, os.path.join(tmpdir, "input.json"))

    # Initialize git repo (required by act and actions/checkout)
    subprocess.run(["git", "init", tmpdir], capture_output=True, check=True)
    subprocess.run(["git", "-C", tmpdir, "config", "user.email", "test@test.com"], capture_output=True, check=True)
    subprocess.run(["git", "-C", tmpdir, "config", "user.name", "Test"], capture_output=True, check=True)
    subprocess.run(["git", "-C", tmpdir, "add", "."], capture_output=True, check=True)
    subprocess.run(["git", "-C", tmpdir, "commit", "-m", "initial"], capture_output=True, check=True)

    return tmpdir


def run_act(tmpdir, timeout=120):
    """Run act push --rm in the given directory. Returns (exit_code, output)."""
    try:
        result = subprocess.run(
            ["act", "push", "--rm",
             "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest",
             "--defaultbranch", "master"],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        output = result.stdout + "\n" + result.stderr
        return result.returncode, output
    except subprocess.TimeoutExpired:
        return -1, "ERROR: act timed out"


def assert_contains(output, expected, test_name, description=""):
    """Assert that output contains the expected string. Track results."""
    global passed, failed, errors
    if expected in output:
        passed += 1
        log(f"  PASS: {description or expected}")
    else:
        failed += 1
        msg = f"  FAIL: {description or 'expected string not found'}\n    Expected: {expected!r}\n    (not found in output)"
        log(msg)
        errors.append(f"[{test_name}] {msg}")


def assert_not_contains(output, expected, test_name, description=""):
    """Assert that output does NOT contain the expected string."""
    global passed, failed, errors
    if expected not in output:
        passed += 1
        log(f"  PASS: {description or 'string correctly absent'}")
    else:
        failed += 1
        msg = f"  FAIL: {description or 'unexpected string found'}\n    Did not expect: {expected!r}"
        log(msg)
        errors.append(f"[{test_name}] {msg}")


def assert_exit_code(actual, expected, test_name):
    """Assert act exit code."""
    global passed, failed, errors
    if actual == expected:
        passed += 1
        log(f"  PASS: exit code {actual}")
    else:
        failed += 1
        msg = f"  FAIL: expected exit code {expected}, got {actual}"
        log(msg)
        errors.append(f"[{test_name}] {msg}")


# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================

def test_workflow_structure():
    """Parse the YAML and verify expected structure (triggers, jobs, steps)."""
    global passed, failed, errors
    test_name = "workflow_structure"
    log(f"\n{'='*60}")
    log(f"TEST: {test_name} — Verify workflow YAML structure")
    log(f"{'='*60}")

    write_result(f"\n{'='*60}\nTEST: {test_name}\n{'='*60}\n")

    with open(WORKFLOW_FILE) as f:
        wf = yaml.safe_load(f)

    # Check triggers
    triggers = wf.get("on", wf.get(True, {}))
    assert_contains(str(triggers), "push", test_name, "trigger: push is present")
    assert_contains(str(triggers), "workflow_dispatch", test_name, "trigger: workflow_dispatch is present")
    assert_contains(str(triggers), "schedule", test_name, "trigger: schedule is present")

    # Check jobs
    jobs = wf.get("jobs", {})
    assert_contains(str(list(jobs.keys())), "cleanup", test_name, "job 'cleanup' exists")

    # Check steps in cleanup job
    steps = jobs.get("cleanup", {}).get("steps", [])
    step_names = [s.get("name", s.get("uses", "")) for s in steps]
    step_str = str(step_names)

    assert_contains(step_str, "checkout", test_name, "step: actions/checkout present")
    assert_contains(step_str, "Python", test_name, "step: Python setup present")

    # Check that workflow references the script file
    workflow_text = open(WORKFLOW_FILE).read()
    assert_contains(workflow_text, "artifact_cleanup.py", test_name, "workflow references artifact_cleanup.py")
    assert_contains(workflow_text, "input.json", test_name, "workflow references input.json")

    # Verify referenced files exist
    assert_exit_code(0 if os.path.exists(SCRIPT_FILE) else 1, 0, test_name + "/script_exists")

    write_result(f"Workflow structure tests complete\n")


def test_actionlint():
    """Verify actionlint passes with exit code 0."""
    global passed, failed, errors
    test_name = "actionlint"
    log(f"\n{'='*60}")
    log(f"TEST: {test_name} — Verify actionlint passes")
    log(f"{'='*60}")

    result = subprocess.run(
        ["actionlint", WORKFLOW_FILE],
        capture_output=True, text=True
    )
    output = result.stdout + result.stderr

    write_result(f"\n{'='*60}\nTEST: {test_name}\n{'='*60}\n")
    write_result(f"actionlint output:\n{output}\n")
    write_result(f"Exit code: {result.returncode}\n")

    assert_exit_code(result.returncode, 0, test_name)
    if result.returncode != 0:
        log(f"  actionlint errors:\n{output}")


# ============================================================
# ACT-BASED FUNCTIONAL TESTS
# ============================================================

def run_fixture_test(fixture_name, test_name, assertions_fn):
    """
    Run a single fixture through act and apply assertion function.
    """
    fixture_path = os.path.join(FIXTURES_DIR, fixture_name)
    log(f"\n{'='*60}")
    log(f"TEST: {test_name}")
    log(f"{'='*60}")

    write_result(f"\n{'='*60}\nTEST: {test_name}\n{'='*60}\n")

    tmpdir = setup_temp_repo(fixture_path)
    try:
        exit_code, output = run_act(tmpdir)
        write_result(f"act exit code: {exit_code}\n")
        write_result(output)
        write_result(f"\n--- end {test_name} ---\n")

        # Every test must have act exit 0 and show job succeeded
        assert_exit_code(exit_code, 0, test_name)
        assert_contains(output, "Job succeeded", test_name, "Job succeeded")

        # Run test-specific assertions
        assertions_fn(output, test_name)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def test_max_age(output, test_name):
    """
    Test: max_age_days=30, reference_date=2026-04-09
    - old-build-feb01 (Feb 1, 67 days old) -> DELETE (exceeded max age)
    - old-build-feb15 (Feb 15, 53 days old) -> DELETE (exceeded max age)
    - recent-build-apr01 (Apr 1, 8 days old) -> RETAIN
    - recent-build-apr05 (Apr 5, 4 days old) -> RETAIN
    Summary: 2 deleted, 2 retained, 250 MB reclaimed, 125 MB retained
    """
    # Verify artifacts marked for deletion
    assert_contains(output, "old-build-feb01", test_name, "old-build-feb01 appears in output")
    assert_contains(output, "old-build-feb15", test_name, "old-build-feb15 appears in output")
    assert_contains(output, "exceeded max age", test_name, "reason: exceeded max age")

    # Verify exact summary values
    assert_contains(output, "Artifacts to delete: 2", test_name, "exactly 2 artifacts deleted")
    assert_contains(output, "Artifacts to retain: 2", test_name, "exactly 2 artifacts retained")
    assert_contains(output, "Space reclaimed: 250 MB", test_name, "space reclaimed: 250 MB")
    assert_contains(output, "Space retained: 125 MB", test_name, "space retained: 125 MB")
    assert_contains(output, "DRY RUN", test_name, "dry run mode indicated")


def test_keep_latest_n(output, test_name):
    """
    Test: keep_latest_n_per_workflow=2
    wf-deploy: deploy-v3 (Apr 1), deploy-v2 (Mar 15) kept; deploy-v1 (Mar 1) deleted
    wf-test: test-run-2 (Apr 2), test-run-1 (Mar 10) both kept (only 2)
    Summary: 1 deleted, 4 retained, 80 MB reclaimed, 240 MB retained
    """
    assert_contains(output, "deploy-v1", test_name, "deploy-v1 in output")
    assert_contains(output, "exceeded keep-latest-N", test_name, "reason: exceeded keep-latest-N")

    assert_contains(output, "Artifacts to delete: 1", test_name, "exactly 1 artifact deleted")
    assert_contains(output, "Artifacts to retain: 4", test_name, "exactly 4 artifacts retained")
    assert_contains(output, "Space reclaimed: 80 MB", test_name, "space reclaimed: 80 MB")
    assert_contains(output, "Space retained: 240 MB", test_name, "space retained: 240 MB")


def test_max_total_size(output, test_name):
    """
    Test: max_total_size_mb=200
    Total = 100+120+80+90 = 390 MB. Need to remove 190 MB.
    Delete oldest first:
      - artifact-oldest (100 MB, Mar 1) -> DELETE -> remaining 290, still > 200
      - artifact-middle (120 MB, Mar 15) -> DELETE -> remaining 170, under 200
    Retain: artifact-newer (80), artifact-newest (90) = 170 MB
    Summary: 2 deleted, 2 retained, 220 MB reclaimed, 170 MB retained
    """
    assert_contains(output, "artifact-oldest", test_name, "artifact-oldest in output")
    assert_contains(output, "artifact-middle", test_name, "artifact-middle in output")
    assert_contains(output, "exceeded max total size", test_name, "reason: exceeded max total size")

    assert_contains(output, "Artifacts to delete: 2", test_name, "exactly 2 artifacts deleted")
    assert_contains(output, "Artifacts to retain: 2", test_name, "exactly 2 artifacts retained")
    assert_contains(output, "Space reclaimed: 220 MB", test_name, "space reclaimed: 220 MB")
    assert_contains(output, "Space retained: 170 MB", test_name, "space retained: 170 MB")


def test_combined_policies(output, test_name):
    """
    Test: max_age_days=30, keep_latest_n_per_workflow=2, max_total_size_mb=300
    Reference: 2026-04-09

    Step 1 — max_age_days=30 (cutoff = 2026-03-10):
      DELETE: build-ancient (Jan 15), build-old (Feb 20), test-old (Feb 10)
      RETAIN: build-recent (Apr 1), build-latest (Apr 7), test-latest (Apr 6)

    Step 2 — keep_latest_n=2 per workflow:
      wf-build retained: build-recent, build-latest (2 -> OK)
      wf-test retained: test-latest (1 -> OK)
      No additional deletions.

    Step 3 — max_total_size_mb=300:
      Retained total: 100 + 100 + 50 = 250 MB <= 300 -> OK

    Final: 3 deleted (build-ancient, build-old, test-old), 3 retained
    Space reclaimed: 200+150+60 = 410 MB
    Space retained: 100+100+50 = 250 MB
    """
    assert_contains(output, "build-ancient", test_name, "build-ancient in output")
    assert_contains(output, "build-old", test_name, "build-old in output")
    assert_contains(output, "test-old", test_name, "test-old in output")

    assert_contains(output, "Artifacts to delete: 3", test_name, "exactly 3 artifacts deleted")
    assert_contains(output, "Artifacts to retain: 3", test_name, "exactly 3 artifacts retained")
    assert_contains(output, "Space reclaimed: 410 MB", test_name, "space reclaimed: 410 MB")
    assert_contains(output, "Space retained: 250 MB", test_name, "space retained: 250 MB")


def test_empty_artifacts(output, test_name):
    """
    Test: empty artifact list.
    Should report 0 across the board with no errors.
    """
    assert_contains(output, "Total artifacts: 0", test_name, "total artifacts: 0")
    assert_contains(output, "Artifacts to delete: 0", test_name, "artifacts to delete: 0")
    assert_contains(output, "Artifacts to retain: 0", test_name, "artifacts to retain: 0")
    assert_contains(output, "Space reclaimed: 0 MB", test_name, "space reclaimed: 0 MB")
    assert_contains(output, "Space retained: 0 MB", test_name, "space retained: 0 MB")


def test_live_mode(output, test_name):
    """
    Test: dry_run=false with max_age_days=30.
    - stale-artifact (Jan 1, ~98 days old) -> DELETE
    - fresh-artifact (Apr 8, 1 day old) -> RETAIN
    Output should say LIVE instead of DRY RUN.
    """
    assert_contains(output, "LIVE", test_name, "LIVE mode indicated")
    assert_not_contains(output, "DRY RUN", test_name, "DRY RUN not shown in LIVE mode")

    assert_contains(output, "Artifacts to delete: 1", test_name, "exactly 1 artifact deleted")
    assert_contains(output, "Artifacts to retain: 1", test_name, "exactly 1 artifact retained")
    assert_contains(output, "Space reclaimed: 200 MB", test_name, "space reclaimed: 200 MB")
    assert_contains(output, "Space retained: 50 MB", test_name, "space retained: 50 MB")


# ============================================================
# MAIN
# ============================================================

def main():
    global passed, failed

    # Clear result file
    with open(RESULT_FILE, "w") as f:
        f.write("=== Artifact Cleanup Script — Test Results ===\n")
        f.write(f"Date: 2026-04-09\n\n")

    # --- Workflow structure tests ---
    test_workflow_structure()
    test_actionlint()

    # --- Functional tests via act ---
    run_fixture_test("test_max_age.json", "max_age_policy", test_max_age)
    run_fixture_test("test_keep_latest_n.json", "keep_latest_n_policy", test_keep_latest_n)
    run_fixture_test("test_max_total_size.json", "max_total_size_policy", test_max_total_size)
    run_fixture_test("test_combined_policies.json", "combined_policies", test_combined_policies)
    run_fixture_test("test_empty.json", "empty_artifacts", test_empty_artifacts)
    run_fixture_test("test_live_mode.json", "live_mode", test_live_mode)

    # --- Final summary ---
    total = passed + failed
    summary = f"\n{'='*60}\nFINAL RESULTS: {passed}/{total} passed, {failed}/{total} failed\n{'='*60}\n"
    log(summary)
    write_result(summary)

    if errors:
        log("\nFailed assertions:")
        for e in errors:
            log(f"  {e}")
        write_result("\nFailed assertions:\n")
        for e in errors:
            write_result(f"  {e}\n")

    if failed > 0:
        sys.exit(1)
    else:
        log("\nAll tests passed!")
        write_result("\nAll tests passed!\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
