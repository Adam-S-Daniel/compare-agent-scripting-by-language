#!/usr/bin/env python3
"""Act-based test harness for test-results-aggregator.

For each test case:
1. Create a temp git repo containing all project files.
2. Run `act push --rm` inside it (workflow executes in Docker).
3. Append the full output to act-result.txt (delimited).
4. Assert exit code 0 and "Job succeeded" in output.
5. Assert exact expected values appear in the workflow output.

Limit: at most 3 `act push` runs total.
"""

import os
import shutil
import subprocess
import sys
import tempfile

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(WORKSPACE, "act-result.txt")

# ---------------------------------------------------------------------------
# Test cases — each defines expected output strings that must appear verbatim
# ---------------------------------------------------------------------------

TEST_CASES = [
    {
        "name": "all-fixtures",
        "description": (
            "Aggregate run1/junit.xml + run2/json.json + run3/junit.xml; "
            "expect total=9, passed=7, failed=1, skipped=1, flaky=test_login_fail"
        ),
        # Exact substrings that must appear in the act output
        "expected": [
            "| Total Tests | 9 |",
            "| Passed | 7 |",
            "| Failed | 1 |",
            "| Skipped | 1 |",
            "| Duration | 3.30s |",
            "test_login_fail",
            "### Flaky Tests",
            "Job succeeded",
            "49 passed",        # all 49 pytest tests pass inside the container
        ],
    },
]

# Files to copy into the temp git repo for each test case
PROJECT_FILES = [
    "aggregator.py",
    "tests/__init__.py",
    "tests/test_aggregator.py",
    "tests/test_workflow.py",
    "fixtures/run1/junit.xml",
    "fixtures/run2/json.json",
    "fixtures/run3/junit.xml",
    ".github/workflows/test-results-aggregator.yml",
    ".actrc",
]


def copy_project_into(dest_dir: str) -> None:
    """Copy all project files into dest_dir, preserving relative paths."""
    for rel_path in PROJECT_FILES:
        src = os.path.join(WORKSPACE, rel_path)
        dst = os.path.join(dest_dir, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)


def run_act(repo_dir: str) -> tuple[int, str]:
    """Initialise git in repo_dir and run `act push --rm`. Return (returncode, output)."""
    # Initialise a minimal git repo so act can detect events
    subprocess.run(
        ["git", "init", "-b", "main"],
        cwd=repo_dir, check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=repo_dir, check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test Runner"],
        cwd=repo_dir, check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "add", "-A"],
        cwd=repo_dir, check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "test"],
        cwd=repo_dir, check=True, capture_output=True,
    )

    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def append_to_result_file(test_name: str, output: str, passed: bool) -> None:
    """Append act output to act-result.txt with clear delimiters."""
    status = "PASSED" if passed else "FAILED"
    separator = "=" * 70
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{separator}\n")
        f.write(f"TEST CASE: {test_name}  [{status}]\n")
        f.write(f"{separator}\n")
        f.write(output)
        f.write(f"\n{separator}\n")


def run_test_case(case: dict) -> bool:
    """Run a single test case. Returns True if all assertions pass."""
    name = case["name"]
    print(f"\n{'='*60}")
    print(f"Running test case: {name}")
    print(f"  {case['description']}")

    with tempfile.TemporaryDirectory() as tmp:
        copy_project_into(tmp)
        try:
            returncode, output = run_act(tmp)
        except subprocess.TimeoutExpired:
            output = "ERROR: act timed out after 300 seconds"
            returncode = -1

    passed = True
    failures = []

    # Assert exit code 0
    if returncode != 0:
        passed = False
        failures.append(f"act exit code {returncode} (expected 0)")

    # Assert all expected substrings are present
    for expected in case["expected"]:
        if expected not in output:
            passed = False
            failures.append(f"Expected string not found in output: {expected!r}")

    append_to_result_file(name, output, passed)

    if passed:
        print(f"  PASSED")
    else:
        print(f"  FAILED:")
        for f in failures:
            print(f"    - {f}")
        # Print a snippet of the output to aid debugging
        print("\n--- Act output (last 80 lines) ---")
        lines = output.splitlines()
        for line in lines[-80:]:
            print(line)
        print("--- End of output ---")

    return passed


def main() -> int:
    # Clear/create act-result.txt at the start of the run
    with open(RESULT_FILE, "w") as f:
        f.write("Act Test Results\n")
        f.write("=" * 70 + "\n")

    total = len(TEST_CASES)
    passed_count = 0

    for case in TEST_CASES:
        if run_test_case(case):
            passed_count += 1

    print(f"\n{'='*60}")
    print(f"Results: {passed_count}/{total} test cases passed")

    if passed_count == total:
        print("All test cases PASSED.")
        return 0
    else:
        print("Some test cases FAILED.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
