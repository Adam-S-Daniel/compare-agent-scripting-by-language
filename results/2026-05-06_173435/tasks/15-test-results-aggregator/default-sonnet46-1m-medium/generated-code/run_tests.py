#!/usr/bin/env python3
"""
Test harness: runs the test-results-aggregator workflow via act and asserts
on the output. Saves full act output to act-result.txt.

Requirements:
- act and Docker must be installed
- .actrc must configure the act container image
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WORKSPACE = Path(__file__).parent
ACT_RESULT_FILE = WORKSPACE / "act-result.txt"

# Expected values from aggregating all 4 fixture files
EXPECTED = {
    "TOTAL_TESTS": "16",
    "PASSED": "8",
    "FAILED": "6",
    "SKIPPED": "2",
    "DURATION": "10.80",
    "FLAKY_COUNT": "1",
    "CONSISTENTLY_FAILING_COUNT": "1",
    "FLAKY_TEST": "test_module::test_beta",
    "CONSISTENTLY_FAILING_TEST": "test_module::test_gamma",
    # Exact table rows in the markdown summary
    "TABLE_TOTAL": "| Total Tests | 16 |",
    "TABLE_PASSED": "| Passed | 8 |",
    "TABLE_FAILED": "| Failed | 6 |",
    "TABLE_SKIPPED": "| Skipped | 2 |",
    "TABLE_DURATION": "10.80s",
}


def setup_temp_repo(tmp_dir: Path) -> None:
    """Copy project files into a fresh git repo in tmp_dir."""
    files_to_copy = [
        "aggregator.py",
        "tests/test_aggregator.py",
        ".github/workflows/test-results-aggregator.yml",
        "fixtures/junit_run1.xml",
        "fixtures/junit_run2.xml",
        "fixtures/json_run1.json",
        "fixtures/json_run2.json",
        ".actrc",
    ]

    for rel in files_to_copy:
        src = WORKSPACE / rel
        dst = tmp_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Initialize git repo
    subprocess.run(["git", "init"], cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"],
                   cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"],
                   cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "test fixtures"],
                   cwd=tmp_dir, check=True, capture_output=True)


def run_act(tmp_dir: Path, label: str) -> tuple[int, str]:
    """Run act push --rm in tmp_dir and return (returncode, output)."""
    print(f"\n{'='*60}")
    print(f"Running act for: {label}")
    print(f"Working dir: {tmp_dir}")
    print(f"{'='*60}")

    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )

    output = f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    print(output)
    return result.returncode, output


def assert_in_output(output: str, expected: str, label: str) -> None:
    """Assert that expected string appears in output."""
    if expected not in output:
        print(f"ASSERTION FAILED [{label}]: expected to find:")
        print(f"  {expected!r}")
        print("in act output (first 3000 chars):")
        print(output[:3000])
        sys.exit(1)
    print(f"  OK: found {expected!r}")


def main() -> int:
    # Clear act-result.txt at the start
    ACT_RESULT_FILE.write_text("")

    all_passed = True

    # ----------------------------------------------------------------
    # Test case 1: Full matrix aggregation (all 4 fixtures)
    # ----------------------------------------------------------------
    with tempfile.TemporaryDirectory(prefix="act-test-") as tmpstr:
        tmp_dir = Path(tmpstr)
        setup_temp_repo(tmp_dir)

        rc, output = run_act(tmp_dir, "full matrix aggregation")

        # Append to act-result.txt
        with open(ACT_RESULT_FILE, "a") as f:
            f.write(f"\n{'='*60}\n")
            f.write("TEST CASE 1: Full matrix aggregation (all 4 fixtures)\n")
            f.write(f"{'='*60}\n")
            f.write(output)
            f.write(f"\nExit code: {rc}\n")

        # Assert exit code
        if rc != 0:
            print(f"ASSERTION FAILED: act exited with code {rc} (expected 0)")
            with open(ACT_RESULT_FILE, "a") as f:
                f.write("RESULT: FAILED (non-zero exit code)\n")
            all_passed = False
        else:
            print("  OK: act exited with code 0")

        # Assert job succeeded
        assert_in_output(output, "Job succeeded", "job-succeeded")

        # Assert exact expected values in output
        combined = output
        print("\nChecking exact expected values:")
        assert_in_output(combined, f"TOTAL_TESTS={EXPECTED['TOTAL_TESTS']}", "total-tests")
        assert_in_output(combined, f"PASSED={EXPECTED['PASSED']}", "passed")
        assert_in_output(combined, f"FAILED={EXPECTED['FAILED']}", "failed")
        assert_in_output(combined, f"SKIPPED={EXPECTED['SKIPPED']}", "skipped")
        assert_in_output(combined, f"DURATION={EXPECTED['DURATION']}", "duration")
        assert_in_output(combined, f"FLAKY_COUNT={EXPECTED['FLAKY_COUNT']}", "flaky-count")
        assert_in_output(combined,
                         f"CONSISTENTLY_FAILING_COUNT={EXPECTED['CONSISTENTLY_FAILING_COUNT']}",
                         "consistently-failing-count")
        assert_in_output(combined, f"FLAKY={EXPECTED['FLAKY_TEST']}", "flaky-test")
        assert_in_output(combined,
                         f"CONSISTENTLY_FAILING={EXPECTED['CONSISTENTLY_FAILING_TEST']}",
                         "consistently-failing-test")

        # Assert markdown table rows appear in output
        assert_in_output(combined, EXPECTED["TABLE_TOTAL"], "table-total")
        assert_in_output(combined, EXPECTED["TABLE_PASSED"], "table-passed")
        assert_in_output(combined, EXPECTED["TABLE_FAILED"], "table-failed")
        assert_in_output(combined, EXPECTED["TABLE_SKIPPED"], "table-skipped")
        assert_in_output(combined, EXPECTED["TABLE_DURATION"], "table-duration")

        # Assert aggregation completed successfully
        assert_in_output(combined, "AGGREGATION_COMPLETE", "aggregation-complete")

        with open(ACT_RESULT_FILE, "a") as f:
            f.write("RESULT: PASSED\n")

    # ----------------------------------------------------------------
    # Final summary
    # ----------------------------------------------------------------
    print(f"\n{'='*60}")
    if all_passed:
        print("ALL ACT TESTS PASSED")
    else:
        print("SOME ACT TESTS FAILED - see act-result.txt for details")
    print(f"Full output saved to: {ACT_RESULT_FILE}")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
