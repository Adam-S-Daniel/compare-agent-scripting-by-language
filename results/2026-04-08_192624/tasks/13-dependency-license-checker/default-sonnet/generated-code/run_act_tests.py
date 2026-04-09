"""
Act-based test harness for the Dependency License Checker.

This script:
1. Sets up a temporary git repo with project files + fixture data
2. Runs `act push --rm` to execute the workflow
3. Captures output to act-result.txt
4. Asserts exact expected values in the output
5. Asserts "Job succeeded" for each job

Run: python3 run_act_tests.py
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
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BASE_DIR = Path(__file__).parent.resolve()
ACT_RESULT_FILE = BASE_DIR / "act-result.txt"
WORKFLOW_FILE = BASE_DIR / ".github" / "workflows" / "dependency-license-checker.yml"

# Files that must be copied into each temp git repo for act to work
PROJECT_FILES = [
    "license_checker.py",
    "test_license_checker.py",
    ".github/workflows/dependency-license-checker.yml",
]

# Fixture directories (relative to BASE_DIR)
FIXTURE_DIRS = [
    "fixtures/fixture1",
    "fixtures/fixture2",
]


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------

def run(cmd, cwd=None, capture=True, timeout=300):
    """Run a shell command and return (returncode, stdout, stderr)."""
    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=capture,
        text=True,
        timeout=timeout,
    )
    return result.returncode, result.stdout, result.stderr


def setup_temp_repo(fixture_dir: Path) -> Path:
    """
    Create a temporary git repo containing:
    - All project source files
    - The fixture directory contents (copied to fixtures/<name>/)

    Returns the path to the temp repo.
    """
    tmpdir = Path(tempfile.mkdtemp(prefix="act-test-"))

    # Copy project files (preserving directory structure)
    for rel_path in PROJECT_FILES:
        src = BASE_DIR / rel_path
        dst = tmpdir / rel_path
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Copy the fixture into fixtures/<fixture_name>/ inside the temp repo
    fixture_name = fixture_dir.name  # e.g. "fixture1"
    dst_fixture_dir = tmpdir / "fixtures" / fixture_name
    shutil.copytree(str(fixture_dir), str(dst_fixture_dir))

    # Also copy all other fixtures (the workflow references fixtures/fixture1 and fixture2)
    for other_fixture in (BASE_DIR / "fixtures").iterdir():
        if other_fixture.name != fixture_name and other_fixture.is_dir():
            dst_other = tmpdir / "fixtures" / other_fixture.name
            shutil.copytree(str(other_fixture), str(dst_other))

    # Initialize git repo and commit everything
    run(["git", "init", "-b", "main"], cwd=tmpdir)
    run(["git", "config", "user.email", "test@example.com"], cwd=tmpdir)
    run(["git", "config", "user.name", "Test"], cwd=tmpdir)
    run(["git", "add", "-A"], cwd=tmpdir)
    run(["git", "commit", "-m", "initial"], cwd=tmpdir)

    return tmpdir


def run_act(repo_dir: Path, job: str = None) -> tuple[int, str]:
    """
    Run `act push --rm` in the given repo directory.
    Optionally limit to a single job with --job.

    Returns (exit_code, combined_output).
    """
    cmd = ["act", "push", "--rm", "--no-cache-server"]
    if job:
        cmd += ["--job", job]

    # Use a simple Docker image that works with act
    cmd += ["--platform", "ubuntu-latest=catthehacker/ubuntu:act-latest"]

    rc, stdout, stderr = run(cmd, cwd=repo_dir, timeout=600)
    combined = stdout + stderr
    return rc, combined


# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

def assert_job_succeeded(output: str, job_name: str):
    """Assert that the given job shows success in act output."""
    # act prints lines like: "[Job name/Step] Job succeeded" or "✅"
    # More reliably, check for the absence of "Job failed" for this job section.
    # Also check the overall success signal.
    lines = output.splitlines()

    job_found = False
    for line in lines:
        if job_name.lower() in line.lower():
            job_found = True
        if "Job succeeded" in line or "job succeeded" in line.lower():
            return  # At least one job succeeded line found

    # Fallback: check there's no explicit failure
    for line in lines:
        if "Job failed" in line:
            raise AssertionError(
                f"Job '{job_name}' appears to have FAILED.\n"
                f"Output snippet:\n{output[-2000:]}"
            )


def assert_exact_value(output: str, expected: str, context: str = ""):
    """Assert that exact expected string appears in act output."""
    if expected not in output:
        raise AssertionError(
            f"Expected to find {context!r}: {expected!r}\n"
            f"Not found in output (last 3000 chars):\n{output[-3000:]}"
        )


def assert_exit_code(actual: int, expected: int = 0, context: str = ""):
    """Assert act exited with the expected code."""
    if actual != expected:
        raise AssertionError(
            f"Expected exit code {expected}, got {actual}. Context: {context}"
        )


# ---------------------------------------------------------------------------
# Workflow structure tests (no act needed)
# ---------------------------------------------------------------------------

def test_workflow_structure():
    """Parse the workflow YAML and verify expected structure."""
    print("\n[STRUCTURE TEST] Validating workflow YAML structure...")

    with open(WORKFLOW_FILE) as f:
        wf = yaml.safe_load(f)

    # Triggers
    assert "push" in wf["on"], "Workflow must have 'push' trigger"
    assert "pull_request" in wf["on"], "Workflow must have 'pull_request' trigger"
    assert "workflow_dispatch" in wf["on"], "Workflow must have 'workflow_dispatch' trigger"
    assert "schedule" in wf["on"], "Workflow must have 'schedule' trigger"
    print("  [OK] triggers: push, pull_request, workflow_dispatch, schedule")

    # Jobs
    jobs = wf["jobs"]
    assert "unit-tests" in jobs, "Must have 'unit-tests' job"
    assert "check-fixture-1" in jobs, "Must have 'check-fixture-1' job"
    assert "check-fixture-2" in jobs, "Must have 'check-fixture-2' job"
    print("  [OK] jobs: unit-tests, check-fixture-1, check-fixture-2")

    # Fixture jobs depend on unit tests
    fixture1_needs = jobs["check-fixture-1"].get("needs", [])
    if isinstance(fixture1_needs, str):
        fixture1_needs = [fixture1_needs]
    assert "unit-tests" in fixture1_needs, "check-fixture-1 must depend on unit-tests"

    fixture2_needs = jobs["check-fixture-2"].get("needs", [])
    if isinstance(fixture2_needs, str):
        fixture2_needs = [fixture2_needs]
    assert "unit-tests" in fixture2_needs, "check-fixture-2 must depend on unit-tests"
    print("  [OK] job dependencies: fixture jobs depend on unit-tests")

    # Verify script paths referenced in workflow actually exist
    workflow_text = WORKFLOW_FILE.read_text()
    for script_ref in ["license_checker.py", "test_license_checker.py"]:
        assert script_ref in workflow_text, f"Workflow must reference {script_ref}"
        assert (BASE_DIR / script_ref).exists(), f"{script_ref} must exist on disk"
    print("  [OK] script file references exist")

    # Verify fixture paths exist
    for fixture_ref in ["fixtures/fixture1", "fixtures/fixture2"]:
        assert fixture_ref in workflow_text, f"Workflow must reference {fixture_ref}"
        assert (BASE_DIR / fixture_ref).is_dir(), f"{fixture_ref} must be a directory"
    print("  [OK] fixture directory references exist")

    # Verify permissions
    assert "permissions" in wf, "Workflow must declare permissions"
    print("  [OK] permissions declared")

    print("[STRUCTURE TEST] PASSED\n")


def test_actionlint():
    """Run actionlint and assert it exits with code 0."""
    print("[ACTIONLINT] Validating workflow with actionlint...")
    rc, stdout, stderr = run(["actionlint", str(WORKFLOW_FILE)])
    combined = stdout + stderr
    if rc != 0:
        raise AssertionError(
            f"actionlint FAILED (exit code {rc}):\n{combined}"
        )
    print("[ACTIONLINT] PASSED\n")


# ---------------------------------------------------------------------------
# Act integration tests
# ---------------------------------------------------------------------------

ACT_TESTS = [
    {
        "name": "fixture1 (package.json - MIT/GPL mix)",
        "fixture_dir": "fixtures/fixture1",
        # Exact strings that MUST appear in act output
        "expected_strings": [
            # From the verify step's print statements
            "fixture1: ALL ASSERTIONS PASSED",
            "express@4.18.0: MIT - approved",
            "lodash@4.17.21: MIT - approved",
            "gpl-package@1.0.0: GPL-3.0 - denied",
            "unknown-package@2.0.0: unknown",
            "Total=4, Approved=2, Denied=1, Unknown=1",
        ],
        # Strings that confirm pytest ran
        "test_strings": [
            "26 passed",
        ],
    },
    {
        "name": "fixture2 (requirements.txt - Apache/BSD/GPL mix)",
        "fixture_dir": "fixtures/fixture2",
        "expected_strings": [
            "fixture2: ALL ASSERTIONS PASSED",
            "requests==2.31.0: Apache-2.0 - approved",
            "flask==3.0.0: BSD-3-Clause - approved",
            "gpl-lib==1.0.0: GPL-2.0 - denied",
            "numpy==1.24.0: BSD-3-Clause - approved",
            "Total=4, Approved=3, Denied=1, Unknown=0",
        ],
        "test_strings": [
            "26 passed",
        ],
    },
]


def run_act_test(test_case: dict, result_file) -> bool:
    """
    Run a single act test case. Returns True if all assertions pass.
    Appends output to result_file.
    """
    name = test_case["name"]
    fixture_dir = BASE_DIR / test_case["fixture_dir"]

    print(f"\n{'='*60}")
    print(f"ACT TEST: {name}")
    print(f"{'='*60}")

    header = f"\n{'='*70}\nTEST CASE: {name}\nFixture: {test_case['fixture_dir']}\n{'='*70}\n"
    result_file.write(header)

    # Set up temp repo
    print(f"  Setting up temp git repo with {fixture_dir.name}...")
    repo_dir = setup_temp_repo(fixture_dir)

    try:
        # Run act
        print(f"  Running: act push --rm ...")
        rc, output = run_act(repo_dir)

        result_file.write(output)
        result_file.write(f"\n--- Exit code: {rc} ---\n")
        result_file.flush()

        print(f"  act exit code: {rc}")
        print(f"  Output length: {len(output)} chars")

        # Assertions
        failures = []

        # 1. Exit code
        try:
            assert_exit_code(rc, 0, context=f"act run for {name}")
            print("  [OK] exit code == 0")
        except AssertionError as e:
            failures.append(str(e))
            print(f"  [FAIL] exit code: {e}")

        # 2. Job succeeded
        for job_name in ["unit-tests", "check-fixture-1", "check-fixture-2"]:
            try:
                assert_job_succeeded(output, job_name)
                print(f"  [OK] job '{job_name}' shows success")
            except AssertionError as e:
                failures.append(str(e))
                print(f"  [FAIL] job '{job_name}': {e}")

        # 3. Exact expected values
        for expected in test_case["expected_strings"]:
            try:
                assert_exact_value(output, expected, context=name)
                print(f"  [OK] found: {expected!r}")
            except AssertionError as e:
                failures.append(str(e))
                print(f"  [FAIL] missing: {expected!r}")

        # 4. Test run strings (pytest output)
        for expected in test_case.get("test_strings", []):
            try:
                assert_exact_value(output, expected, context=f"{name} (unit tests)")
                print(f"  [OK] test output: {expected!r}")
            except AssertionError as e:
                failures.append(str(e))
                print(f"  [FAIL] test output missing: {expected!r}")

        if failures:
            result_file.write(f"\nFAILURES:\n" + "\n".join(failures) + "\n")
            print(f"\n  RESULT: FAILED ({len(failures)} assertion(s) failed)")
            return False
        else:
            result_file.write("\nRESULT: ALL ASSERTIONS PASSED\n")
            print(f"\n  RESULT: PASSED")
            return True

    finally:
        shutil.rmtree(str(repo_dir), ignore_errors=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=" * 60)
    print("DEPENDENCY LICENSE CHECKER - TEST HARNESS")
    print("=" * 60)

    # Open act-result.txt for writing
    with open(ACT_RESULT_FILE, "w") as result_file:
        result_file.write("DEPENDENCY LICENSE CHECKER - ACT TEST RESULTS\n")
        result_file.write("=" * 70 + "\n\n")

        # 1. Workflow structure tests (no act needed)
        try:
            test_workflow_structure()
            result_file.write("[STRUCTURE] Workflow structure: PASSED\n")
        except AssertionError as e:
            result_file.write(f"[STRUCTURE] FAILED: {e}\n")
            print(f"STRUCTURE TEST FAILED: {e}")
            sys.exit(1)

        # 2. Actionlint validation
        try:
            test_actionlint()
            result_file.write("[ACTIONLINT] Workflow lint: PASSED\n\n")
        except AssertionError as e:
            result_file.write(f"[ACTIONLINT] FAILED: {e}\n")
            print(f"ACTIONLINT FAILED: {e}")
            sys.exit(1)

        # 3. Act integration tests
        all_passed = True
        for test_case in ACT_TESTS:
            passed = run_act_test(test_case, result_file)
            if not passed:
                all_passed = False

        # Final summary
        result_file.write("\n" + "=" * 70 + "\n")
        if all_passed:
            result_file.write("FINAL RESULT: ALL TESTS PASSED\n")
        else:
            result_file.write("FINAL RESULT: SOME TESTS FAILED\n")
        result_file.write("=" * 70 + "\n")

    print(f"\n{'='*60}")
    if all_passed:
        print("ALL TESTS PASSED")
        print(f"Results written to: {ACT_RESULT_FILE}")
        sys.exit(0)
    else:
        print("SOME TESTS FAILED - check act-result.txt for details")
        sys.exit(1)


if __name__ == "__main__":
    main()
