#!/usr/bin/env python3
"""
Act-based integration test harness for the Environment Matrix Generator.

This script:
1. Creates a temporary git repository with all project files.
2. Runs `act push --rm` once to execute the GitHub Actions workflow in Docker.
3. Captures the full output and saves it to act-result.txt.
4. Asserts exit code 0 and verifies expected values in the output.

All test cases execute through the GitHub Actions workflow via act, as required.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Directory of this script (the project workspace)
PROJECT_DIR = Path(__file__).parent.resolve()
ACT_RESULT_FILE = PROJECT_DIR / "act-result.txt"

# These are the exact expected values the test harness asserts on.
# Each tuple: (marker_string, description)
EXPECTED_MARKERS = [
    ("MATRIX_SIZE_BASIC: 4",        "basic 2x2 matrix has size 4"),
    ("MATRIX_SIZE_EXCLUDES: 3",     "matrix with 1 exclude has size 3"),
    ("MATRIX_SIZE_INCLUDES: 5",     "matrix with 1 include has size 5"),
    ("MATRIX_SIZE_FLAGS: 8",        "matrix with feature flags has size 8 (2x2x2)"),
    ("EXPECTED_ERROR: Matrix too large confirmed", "oversized matrix is rejected with error"),
    ("PASS: basic matrix size is 4",              "basic fixture passes verification"),
    ("PASS: exclude matrix size is 3",            "exclude fixture passes verification"),
    ("PASS: include matrix size is 5",            "include fixture passes verification"),
    ("PASS: flags matrix size is 8",              "flags fixture passes verification"),
    ("PASS: oversized matrix correctly rejected", "too-large fixture passes verification"),
]


def run_act(work_dir: Path) -> tuple[int, str]:
    """
    Run `act push --rm` in work_dir and return (exit_code, combined_output).
    """
    print(f"Running act push --rm in {work_dir} ...")
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=work_dir,
        capture_output=True,
        text=True,
        timeout=300,  # 5 minutes max
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def setup_git_repo(work_dir: Path) -> None:
    """
    Initialize a git repository and commit all project files into it.
    """
    # Files and directories to copy (excluding the result file itself)
    items_to_copy = [
        "matrix_generator.py",
        "test_matrix_generator.py",
        "fixtures",
        ".github",
        ".actrc",
    ]

    for item in items_to_copy:
        src = PROJECT_DIR / item
        dst = work_dir / item
        if src.is_dir():
            shutil.copytree(src, dst)
        elif src.exists():
            shutil.copy2(src, dst)

    # Initialize git repo and make an initial commit
    subprocess.run(["git", "init", "-b", "main"], cwd=work_dir, check=True,
                   capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=work_dir,
                   check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=work_dir,
                   check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=work_dir, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "test: run environment matrix generator workflow"],
        cwd=work_dir, check=True, capture_output=True,
    )


def assert_markers(output: str, markers: list[tuple[str, str]]) -> list[str]:
    """
    Check that each expected marker appears in the output.
    Returns a list of failure messages (empty means all passed).
    """
    failures = []
    for marker, description in markers:
        if marker not in output:
            failures.append(f"MISSING: '{marker}' ({description})")
        else:
            print(f"  OK: found '{marker}'")
    return failures


def assert_job_succeeded(output: str) -> list[str]:
    """Check that at least one 'Job succeeded' line appears in output."""
    if "Job succeeded" in output:
        print("  OK: found 'Job succeeded'")
        return []
    return ["MISSING: 'Job succeeded' in act output"]


def main() -> int:
    print("=" * 60)
    print("Environment Matrix Generator — Act Integration Tests")
    print("=" * 60)

    # Clear previous result file
    ACT_RESULT_FILE.write_text("")

    with tempfile.TemporaryDirectory(prefix="matrix-gen-act-") as tmp:
        work_dir = Path(tmp)

        print(f"\n[1/3] Setting up git repo in {work_dir}")
        try:
            setup_git_repo(work_dir)
            print("      Git repo initialized and committed.")
        except subprocess.CalledProcessError as e:
            print(f"ERROR: git setup failed: {e}")
            return 1

        print("\n[2/3] Running act push --rm (this takes ~30-90s)...")
        exit_code, output = run_act(work_dir)

        # Append output to act-result.txt
        delimiter = "\n" + "=" * 60 + "\n"
        ACT_RESULT_FILE.write_text(
            delimiter + "=== ACT RUN OUTPUT ===\n" + delimiter + output + delimiter
        )
        print(f"      Output saved to {ACT_RESULT_FILE}")

        print("\n[3/3] Asserting expected values...")

        failures = []

        # Assert exit code 0
        if exit_code == 0:
            print("  OK: act exited with code 0")
        else:
            print(f"  FAIL: act exited with code {exit_code}")
            failures.append(f"act exit code was {exit_code}, expected 0")
            # Print last 80 lines of output for diagnosis
            lines = output.splitlines()
            print("\n--- Last 80 lines of act output ---")
            print("\n".join(lines[-80:]))
            print("--- end ---")

        # Assert expected markers
        failures.extend(assert_markers(output, EXPECTED_MARKERS))

        # Assert job succeeded
        failures.extend(assert_job_succeeded(output))

    print()
    if failures:
        print(f"FAILED: {len(failures)} assertion(s) failed:")
        for f in failures:
            print(f"  - {f}")
        return 1
    else:
        print(f"PASSED: all {len(EXPECTED_MARKERS) + 2} assertions passed.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
