#!/usr/bin/env python3
"""
Act test harness for PR Label Assigner
=======================================
This script is the top-level test runner.  It:

  1. Copies the project files into a fresh temporary git repository
  2. Runs `act push --rm` to execute the GitHub Actions workflow in Docker
  3. Writes all output to act-result.txt in the current directory
  4. Asserts that act exited with code 0
  5. Asserts that "Job succeeded" appears in the output
  6. Asserts exact label values emitted by each workflow case step

Run directly:
    python3 run_tests.py

Expected act output markers (emitted by the workflow steps):
    CASE1_LABELS: documentation        (docs/** -> documentation)
    CASE2_LABELS: api,tests            (src/api/** -> api  +  *.test.* -> tests)
    CASE3_LABELS: backend,api          (priority: backend=1, api=2)
    CASE4_LABELS: NONE                 (no rule matches src/main.py etc.)
"""

import os
import shutil
import subprocess
import sys
import tempfile

# Directory containing this script (the project root)
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))

# Where to write act output (required artifact)
ACT_RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")

# Items to exclude when copying the project into the temp repo
EXCLUDE_ITEMS = {".git", "__pycache__", ".pytest_cache", "act-result.txt"}

# Expected label output for each workflow step marker
EXPECTED_LABELS = {
    "CASE1_LABELS:": "documentation",
    "CASE2_LABELS:": "api,tests",
    "CASE3_LABELS:": "backend,api",
    "CASE4_LABELS:": "NONE",
}


def copy_project_to(dest: str) -> None:
    """Copy all project files (including hidden files like .actrc) to dest."""
    for item in os.listdir(PROJECT_DIR):
        if item in EXCLUDE_ITEMS:
            continue
        src = os.path.join(PROJECT_DIR, item)
        dst = os.path.join(dest, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)


def init_git_repo(repo_dir: str) -> None:
    """Initialise a git repo, configure identity, and commit all files."""
    def git(*args):
        subprocess.run(
            ["git", *args],
            cwd=repo_dir,
            check=True,
            capture_output=True,
        )

    git("init")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test Runner")
    git("add", "-A")
    git("commit", "-m", "chore: add project files for act test")


def run_act(repo_dir: str) -> tuple[int, str]:
    """Run `act push --rm` in repo_dir and return (exit_code, combined_output)."""
    result = subprocess.run(
        [
            "act", "push", "--rm",
            "--pull=false",
            "-W", ".github/workflows/pr-label-assigner.yml",
        ],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,  # 5-minute safety timeout
    )
    return result.returncode, result.stdout + result.stderr


def assert_marker(output: str, marker: str, expected: str) -> bool:
    """
    Return True if output contains a line with 'marker <expected>'.
    Print a PASS/FAIL message either way.
    """
    for line in output.splitlines():
        if marker in line:
            # Everything after the marker (stripped)
            actual = line.split(marker, 1)[-1].strip()
            if actual == expected:
                print(f"  PASS  {marker} == '{expected}'")
                return True
            else:
                print(f"  FAIL  {marker}: expected '{expected}', got '{actual}'")
                return False
    print(f"  FAIL  marker '{marker}' not found in act output")
    return False


def main() -> None:
    print("=" * 60)
    print("PR Label Assigner — act test harness")
    print("=" * 60)

    failures = []

    with tempfile.TemporaryDirectory(prefix="pr-label-assigner-") as tmpdir:
        print(f"\n[1] Preparing temp git repo in {tmpdir} …")
        copy_project_to(tmpdir)
        init_git_repo(tmpdir)
        print("    Done.")

        print("\n[2] Running act push --rm …")
        exit_code, output = run_act(tmpdir)
        print(f"    act exited with code {exit_code}")

    # -------------------------------------------------------------------------
    # Write act output to act-result.txt (required artifact)
    # -------------------------------------------------------------------------
    delimiter = "=" * 60
    with open(ACT_RESULT_FILE, "w") as f:
        f.write(f"{delimiter}\n")
        f.write("PR Label Assigner — act run output\n")
        f.write(f"{delimiter}\n")
        f.write(f"Exit code: {exit_code}\n")
        f.write(f"{delimiter}\n")
        f.write(output)
        f.write(f"\n{delimiter}\n")
        f.write("END OF ACT OUTPUT\n")
        f.write(f"{delimiter}\n")

    print(f"\n[3] act output written to: {ACT_RESULT_FILE}")

    # -------------------------------------------------------------------------
    # Assertions
    # -------------------------------------------------------------------------
    print("\n[4] Asserting results …")

    # Exit code
    if exit_code == 0:
        print("  PASS  act exited with code 0")
    else:
        print(f"  FAIL  act exited with code {exit_code} (expected 0)")
        failures.append("act exit code non-zero")

    # Job succeeded marker
    if "Job succeeded" in output:
        print("  PASS  'Job succeeded' found in output")
    else:
        print("  FAIL  'Job succeeded' not found in output")
        failures.append("'Job succeeded' not in output")

    # Exact label output for every case
    for marker, expected in EXPECTED_LABELS.items():
        if not assert_marker(output, marker, expected):
            failures.append(f"{marker} mismatch")

    # -------------------------------------------------------------------------
    # Final summary
    # -------------------------------------------------------------------------
    print("\n" + "=" * 60)
    if failures:
        print(f"RESULT: FAILED ({len(failures)} assertion(s) failed)")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    else:
        print("RESULT: ALL TESTS PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
