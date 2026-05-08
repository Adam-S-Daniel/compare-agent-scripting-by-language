#!/usr/bin/env python3
"""
Test harness for environment-matrix-generator.

Sets up a temporary git repository containing all project files, runs the
GitHub Actions workflow via `act push --rm`, captures output to act-result.txt,
and asserts on EXACT expected values from the workflow output.

Usage:
    python3 run_tests.py

Requirements:
    - act (nektos/act) and Docker must be available
    - Run from the project root directory
"""
import os
import shutil
import subprocess
import sys
import tempfile

# Path anchors — resolve relative to this script's directory.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Files and directories to copy into the temp repo for each act run.
PROJECT_FILES = [
    "generate_matrix.py",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
]


def log(msg: str) -> None:
    print(msg, flush=True)


def build_temp_repo() -> str:
    """Copy project files into a fresh temp directory and init a git repo."""
    tmp = tempfile.mkdtemp(prefix="matrix-gen-act-")
    for item in PROJECT_FILES:
        src = os.path.join(SCRIPT_DIR, item)
        dst = os.path.join(tmp, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    subprocess.run(["git", "init"], cwd=tmp, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "test: environment matrix generator"],
        cwd=tmp, check=True, capture_output=True
    )
    return tmp


def run_act(repo_dir: str) -> tuple[int, str]:
    """Run `act push --rm` in repo_dir; return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", "push", "--rm"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def assert_contains(output: str, substring: str, label: str) -> None:
    if substring not in output:
        raise AssertionError(
            f"ASSERTION FAILED [{label}]: expected to find {substring!r} in act output"
        )
    log(f"  [PASS] {label}: found {substring!r}")


def assert_job_succeeded(output: str, job_name: str) -> None:
    # act prints "Job succeeded" near the end of each job
    marker = "Job succeeded"
    if marker not in output:
        raise AssertionError(
            f"ASSERTION FAILED: 'Job succeeded' not found in output for job '{job_name}'"
        )
    log(f"  [PASS] job '{job_name}' reported 'Job succeeded'")


def run_test_case(
    name: str,
    description: str,
    assertions: list[tuple[str, str]],
    result_file,
) -> bool:
    """
    Run a single act test case.

    assertions: list of (substring, label) pairs to check in the act output.
    Returns True on pass, False on failure (also writes to result_file).
    """
    log(f"\n{'='*60}")
    log(f"TEST CASE: {name}")
    log(f"Description: {description}")
    log(f"{'='*60}")

    result_file.write(f"\n{'='*60}\n")
    result_file.write(f"TEST CASE: {name}\n")
    result_file.write(f"Description: {description}\n")
    result_file.write(f"{'='*60}\n")

    repo_dir = build_temp_repo()
    try:
        log("Running: act push --rm")
        exit_code, output = run_act(repo_dir)

        result_file.write(output)
        result_file.write(f"\n--- act exit code: {exit_code} ---\n")
        result_file.flush()

        log(f"act exit code: {exit_code}")

        # Assert act itself exited 0
        if exit_code != 0:
            raise AssertionError(
                f"act exited with non-zero code {exit_code}. "
                "Check act-result.txt for details."
            )
        log("  [PASS] act exit code: 0")

        # Assert 'Job succeeded' appears for each job
        assert_job_succeeded(output, "test + generate-and-verify")

        # Assert all specific expected values
        for substring, label in assertions:
            assert_contains(output, substring, label)

        log(f"\n[PASS] {name}")
        result_file.write(f"\nRESULT: PASS\n")
        return True

    except AssertionError as exc:
        log(f"\n[FAIL] {name}: {exc}")
        result_file.write(f"\nRESULT: FAIL — {exc}\n")
        return False
    finally:
        shutil.rmtree(repo_dir, ignore_errors=True)


def main() -> int:
    log("Environment Matrix Generator — act test harness")
    log(f"Writing results to: {ACT_RESULT_FILE}")

    # All test cases share one act run (all fixtures are in the repo).
    # We combine them into a single case to stay within the 3-run budget.

    test_cases = [
        {
            "name": "full-workflow",
            "description": (
                "Run all fixture configs through the workflow. "
                "Verify basic matrix dimensions, include/exclude rules, "
                "and overflow error handling."
            ),
            "assertions": [
                # pytest job
                ("35 passed", "pytest: all 35 tests pass"),
                # Basic matrix (2 OS × 3 python = 6, max-parallel=4, fail-fast=false)
                ("BASIC_OS_COUNT: 2", "basic matrix: 2 OS values"),
                ("BASIC_PYTHON_COUNT: 3", "basic matrix: 3 python versions"),
                ("BASIC_MAX_PARALLEL: 4", "basic matrix: max-parallel=4"),
                ("BASIC_FAIL_FAST: false", "basic matrix: fail-fast=false"),
                ("BASIC_MATRIX_SIZE: 6", "basic matrix: 2×3=6 combinations"),
                # Include matrix (1 include entry with experimental=true)
                ("INCLUDE_COUNT: 1", "include matrix: 1 include entry"),
                ("INCLUDE_EXPERIMENTAL: true", "include matrix: experimental=true"),
                ("INCLUDE_FAIL_FAST: true", "include matrix: fail-fast=true"),
                # Exclude matrix (3 OS values, 2 exclude entries)
                ("EXCLUDE_COUNT: 2", "exclude matrix: 2 exclude entries"),
                ("EXCLUDE_OS_COUNT: 3", "exclude matrix: 3 OS values"),
                # Overflow detection
                ("OVERFLOW_EXIT_CODE: nonzero (correct)", "overflow: non-zero exit detected"),
                ("OVERFLOW_SIZE_IN_MSG: true", "overflow: error message contains size 24"),
                ("OVERFLOW_LIMIT_IN_MSG: true", "overflow: error message contains limit 10"),
            ],
        },
    ]

    all_passed = True
    with open(ACT_RESULT_FILE, "w") as rf:
        rf.write("Environment Matrix Generator — act test results\n")
        rf.write("=" * 60 + "\n")

        for tc in test_cases:
            passed = run_test_case(
                name=tc["name"],
                description=tc["description"],
                assertions=tc["assertions"],
                result_file=rf,
            )
            if not passed:
                all_passed = False

        rf.write(f"\n{'='*60}\n")
        rf.write(f"OVERALL: {'PASS' if all_passed else 'FAIL'}\n")

    log(f"\n{'='*60}")
    log(f"OVERALL RESULT: {'PASS' if all_passed else 'FAIL'}")
    log(f"Results saved to: {ACT_RESULT_FILE}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
