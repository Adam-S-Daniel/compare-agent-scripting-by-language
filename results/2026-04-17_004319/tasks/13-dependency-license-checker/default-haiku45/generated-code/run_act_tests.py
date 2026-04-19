#!/usr/bin/env python3
"""
Test harness that runs the GitHub Actions workflow through act.
This validates the complete pipeline: unit tests, fixtures, and compliance checks.

TDD Principle: This test harness ensures the workflow actually works in CI/CD.
"""

import subprocess
import sys
import os
import json
from pathlib import Path


def run_command(cmd, capture=True):
    """Run a shell command and return exit code, stdout, stderr."""
    print(f"\n{'='*80}")
    print(f"Running: {' '.join(cmd)}")
    print('='*80)

    result = subprocess.run(
        cmd,
        capture_output=capture,
        text=True
    )

    if capture:
        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)

    return result.returncode, result.stdout, result.stderr


def validate_actionlint():
    """Validate the workflow with actionlint first."""
    print("\n[VALIDATION] Checking actionlint...")
    exit_code, stdout, stderr = run_command([
        "actionlint",
        ".github/workflows/dependency-license-checker.yml"
    ])

    if exit_code != 0:
        print(f"✗ FAILED: actionlint validation failed")
        print(stderr)
        return False

    print("✓ PASSED: actionlint validation")
    return True


def run_pytest_tests():
    """Run local unit tests first (prerequisite)."""
    print("\n[TEST] Running local unit tests...")
    exit_code, stdout, stderr = run_command([
        "python3",
        "-m",
        "pytest",
        "test_license_checker.py",
        "-v"
    ])

    if exit_code != 0:
        print(f"✗ FAILED: Unit tests failed")
        return False

    # Verify we got expected test count
    if "10 passed" not in stdout:
        print(f"✗ FAILED: Did not find '10 passed' in output")
        return False

    print("✓ PASSED: All unit tests passed")
    return True


def run_act_tests():
    """Run the workflow through act."""
    print("\n[ACT] Running GitHub Actions workflow through act...")

    # Run act push with cleanup
    exit_code, stdout, stderr = run_command([
        "act",
        "push",
        "--rm"
    ])

    return exit_code, stdout, stderr


def parse_act_output(output):
    """Parse act output and extract key information."""
    lines = output.split('\n')

    results = {
        "job_count": 0,
        "successful_jobs": 0,
        "failed_jobs": 0,
        "test_runs": 0,
        "jobs": []
    }

    for line in lines:
        # Count job completions
        if "Job succeeded" in line:
            results["successful_jobs"] += 1
        if "Job failed" in line:
            results["failed_jobs"] += 1
        # Count test execution
        if "passed" in line and "failed" not in line:
            results["test_runs"] += 1

    return results


def save_act_output(output, filepath="act-result.txt"):
    """Save act output to file for inspection."""
    with open(filepath, 'w') as f:
        f.write("DEPENDENCY LICENSE CHECKER - ACT TEST RESULTS\n")
        f.write("=" * 80 + "\n")
        f.write(f"Timestamp: {__import__('datetime').datetime.now().isoformat()}\n")
        f.write("=" * 80 + "\n\n")
        f.write(output)
    print(f"\n✓ Act output saved to {filepath}")
    return filepath


def main():
    """Run the complete test suite through act."""
    print("DEPENDENCY LICENSE CHECKER - ACT TEST HARNESS")
    print("=" * 80)

    # Step 1: Validate actionlint
    if not validate_actionlint():
        sys.exit(1)

    # Step 2: Run unit tests locally
    if not run_pytest_tests():
        sys.exit(1)

    # Step 3: Run workflow through act (this is the main test)
    print("\n[ACT] Running workflow...")
    exit_code, stdout, stderr = run_act_tests()

    # Save output
    act_output = stdout + "\n" + stderr
    act_result_path = save_act_output(act_output)

    # Parse results
    results = parse_act_output(act_output)

    # Validate results
    print("\n" + "=" * 80)
    print("TEST RESULTS")
    print("=" * 80)

    # Check exit code
    if exit_code != 0:
        print(f"✗ FAILED: act exited with code {exit_code}")
        print("\nDebugging Info:")
        print("Last 50 lines of output:")
        print('\n'.join(act_output.split('\n')[-50:]))
        sys.exit(1)

    print(f"✓ PASSED: act exited with code 0")

    # Verify jobs completed
    if "Job succeeded" in act_output:
        print("✓ PASSED: Jobs completed successfully")
    else:
        print("⚠ WARNING: Could not find job completion markers in output")

    # Verify workflow file exists and is valid
    workflow_path = Path(".github/workflows/dependency-license-checker.yml")
    if workflow_path.exists():
        print(f"✓ PASSED: Workflow file exists at {workflow_path}")
    else:
        print(f"✗ FAILED: Workflow file not found at {workflow_path}")
        sys.exit(1)

    # Verify script files exist
    required_files = [
        "license_checker.py",
        "test_license_checker.py",
        "config/default-licenses.json",
        "config/strict-licenses.json",
        "tests/fixtures/package.json",
        "tests/fixtures/requirements.txt"
    ]

    for filepath in required_files:
        if Path(filepath).exists():
            print(f"✓ PASSED: {filepath} exists")
        else:
            print(f"✗ FAILED: {filepath} not found")
            sys.exit(1)

    print("\n" + "=" * 80)
    print("ALL TESTS PASSED")
    print("=" * 80)
    print(f"\nTest results saved to: {act_result_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
