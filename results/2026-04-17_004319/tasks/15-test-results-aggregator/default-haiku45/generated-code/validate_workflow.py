#!/usr/bin/env python3
"""
Validate the GitHub Actions workflow by running it with act and checking output.
"""

import subprocess
import sys
from pathlib import Path


def run_act_test(test_name: str, description: str) -> bool:
    """Run a single act test and validate output."""
    print(f"\n{'='*70}")
    print(f"TEST: {test_name}")
    print(f"DESC: {description}")
    print('='*70)

    # Run act with the workflow
    cmd = ["act", "push", "--rm", "-v"]
    print(f"Running: {' '.join(cmd)}")

    result = subprocess.run(cmd, cwd=".", capture_output=True, text=True)

    # Combine stdout and stderr for analysis
    output = result.stdout + result.stderr

    # Append to act-result.txt
    with open("act-result.txt", "a") as f:
        f.write(f"\n{'='*70}\n")
        f.write(f"TEST: {test_name}\n")
        f.write(f"DESC: {description}\n")
        f.write('='*70 + '\n')
        f.write(output)
        f.write("\n")

    # Validate exit code
    if result.returncode != 0:
        print(f"✗ Act exited with code {result.returncode} (expected 0)")
        return False
    print("✓ Act exited with code 0")

    # Validate job succeeded
    if "test-aggregator" in output and "Job succeeded" in output:
        print("✓ Job test-aggregator succeeded")
    else:
        print("✗ Job test-aggregator did not show success")
        print("Output snippet:", output[-500:] if output else "(empty)")
        return False

    # Validate expected output
    expected_outputs = [
        ("Unit tests completed", "unit tests message"),
        ("Test Results Summary", "aggregator summary header"),
        ("Passed", "passed metric"),
    ]

    all_found = True
    for expected, desc in expected_outputs:
        if expected in output:
            print(f"✓ Found '{expected}' ({desc})")
        else:
            print(f"✗ Missing '{expected}' ({desc})")
            all_found = False

    return all_found


def main():
    """Run all workflow validation tests."""
    act_result_file = Path("act-result.txt")

    # Clear the result file
    act_result_file.write_text("")
    print("Cleared act-result.txt")

    # Run validation test
    test_passed = run_act_test(
        "test-case-001",
        "Validate workflow runs unit tests and aggregates fixture results"
    )

    # Print summary
    print(f"\n{'='*70}")
    print("SUMMARY")
    print('='*70)

    if test_passed:
        print("✓ All workflow validation tests passed")
        print(f"✓ Results saved to {act_result_file}")
        return 0
    else:
        print("✗ Some workflow validation tests failed")
        print(f"✓ Results saved to {act_result_file}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
