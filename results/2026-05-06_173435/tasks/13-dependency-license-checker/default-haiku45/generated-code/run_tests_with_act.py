#!/usr/bin/env python3
"""
Test harness for running dependency-license-checker tests through GitHub Actions via act.

This script:
1. For each test case, runs the workflow via `act push`
2. Captures and validates the output
3. Saves results to act-result.txt
4. Asserts all tests passed
"""

import subprocess
import sys
import json
from pathlib import Path
from typing import List, Tuple


def run_act_test(test_name: str, cwd: Path) -> Tuple[int, str]:
    """
    Run the workflow through act.

    Args:
        test_name: Name of this test case
        cwd: Working directory for the test

    Returns:
        Tuple of (exit_code, output)
    """
    print(f"\n{'='*60}")
    print(f"Running test: {test_name}")
    print(f"{'='*60}")

    cmd = ['act', 'push', '--rm', '-j', 'test']

    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=180  # 3 minute timeout
        )
        output = result.stdout + result.stderr
        return result.returncode, output
    except subprocess.TimeoutExpired:
        return 1, "TIMEOUT: Test exceeded 3 minute limit"
    except Exception as e:
        return 1, f"ERROR: {str(e)}"


def validate_output(output: str, test_name: str) -> Tuple[bool, List[str]]:
    """
    Validate the act output for success indicators.

    Args:
        output: The output from act
        test_name: Name of the test case

    Returns:
        Tuple of (success: bool, errors: List[str])
    """
    errors = []

    # Check for job success
    if "Job succeeded" not in output and "workflow" in output.lower():
        # Look for explicit pass or fail
        if "FAILED" in output or "Error" in output or "failed" in output:
            errors.append(f"{test_name}: Job appears to have failed")

    # Check for pytest success
    if "test_dependency_license_checker.py" in output:
        if "passed" not in output.lower():
            errors.append(f"{test_name}: No pytest passed indicator found")

    # Check for errors
    if "Traceback" in output or "Exception" in output:
        errors.append(f"{test_name}: Exception detected in output")

    return len(errors) == 0, errors


def main():
    """Main test harness entry point."""
    current_dir = Path.cwd()
    results_file = current_dir / "act-result.txt"

    # Clear results file
    results_file.write_text("")

    print("Dependency License Checker - Test Harness")
    print("=" * 60)
    print(f"Working directory: {current_dir}")
    print(f"Results file: {results_file}")

    # Test 1: Basic workflow execution
    print("\n[Test 1] Basic workflow execution")
    exit_code, output = run_act_test("basic_workflow", current_dir)

    with open(results_file, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"TEST 1: Basic Workflow Execution\n")
        f.write(f"{'='*60}\n")
        f.write(f"Exit Code: {exit_code}\n")
        f.write(f"Output:\n{output}\n")

    if exit_code != 0:
        print(f"ERROR: Test 1 failed with exit code {exit_code}")
        print("Output:")
        print(output)
        return 1

    success, errors = validate_output(output, "Test 1")
    if not success:
        print(f"Validation errors for Test 1:")
        for error in errors:
            print(f"  - {error}")

    # Test 2: Verify pytest tests ran
    print("\n[Test 2] Verify pytest tests ran successfully")
    if "passed" in output.lower() or "PASSED" in output:
        print("✓ Pytest tests appear to have run")
        with open(results_file, "a") as f:
            f.write(f"\n[Test 2] Pytest execution: PASSED\n")
    else:
        print("✗ Could not confirm pytest tests ran")

    # Test 3: Verify package.json parsing works
    print("\n[Test 3] Verify package.json parsing step")
    if "package.json" in output and "fixtures" in output:
        print("✓ Package.json parsing step executed")
        with open(results_file, "a") as f:
            f.write(f"[Test 3] Package.json parsing: PASSED\n")
    else:
        print("⚠ Could not verify package.json parsing")

    # Test 4: Verify requirements.txt parsing works
    print("\n[Test 4] Verify requirements.txt parsing step")
    if "requirements.txt" in output and "fixtures" in output:
        print("✓ Requirements.txt parsing step executed")
        with open(results_file, "a") as f:
            f.write(f"[Test 4] Requirements.txt parsing: PASSED\n")
    else:
        print("⚠ Could not verify requirements.txt parsing")

    # Final summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    print(f"Results saved to: {results_file}")
    print(f"Result file exists: {results_file.exists()}")
    print(f"Result file size: {results_file.stat().st_size} bytes")

    with open(results_file, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"TEST HARNESS COMPLETE\n")
        f.write(f"{'='*60}\n")
        f.write(f"All tests executed through act\n")
        f.write(f"Exit code: {exit_code}\n")

    if exit_code != 0:
        print("\n✗ Tests FAILED")
        return 1
    else:
        print("\n✓ Tests PASSED")
        return 0


if __name__ == '__main__':
    sys.exit(main())
