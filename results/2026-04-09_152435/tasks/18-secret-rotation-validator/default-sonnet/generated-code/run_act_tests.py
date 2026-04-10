"""
Act Test Harness for Secret Rotation Validator
===============================================
Runs the GitHub Actions workflow via `act` for each test case and asserts
on exact expected output values.  Appends all act output to act-result.txt.

Each test case:
  1. Creates a temp git repo with all project files + that case's fixture data
  2. Runs: act push --rm
  3. Appends output to act-result.txt
  4. Asserts exit code 0 (job success)
  5. Asserts on exact expected strings in the output

Run with: python run_act_tests.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Directory containing this script (= project root)
PROJECT_DIR = Path(__file__).parent.resolve()
ACT_RESULT_PATH = PROJECT_DIR / "act-result.txt"

# Expected values for each test case (exact strings the workflow must print)
# These are derived from the fixture files with reference_date=2026-04-10.
TEST_CASES = [
    {
        "name": "basic-fixture",
        "description": "Basic fixture with all three urgency levels",
        "fixture": "fixtures/secrets_basic.json",
        # The workflow uses --reference-date 2026-04-10 in the CI gate step.
        # secrets_basic.json reference_date=2026-04-10
        # DB_PASSWORD: expires 2026-03-22 -> EXPIRED
        # API_KEY: expires 2026-04-14 (4 days) -> WARNING
        # JWT_SECRET: expires 2026-06-30 (81 days) -> OK
        "expected_strings": [
            "DB_PASSWORD",
            "API_KEY",
            "JWT_SECRET",
            "EXPIRED",
            "WARNING",
            # JSON output from CI gate step
            '"expired": 1',
            '"warning": 1',
            '"ok": 1',
            # Summary line printed by CI gate step
            "Expired: 1 | Warning: 1 | OK: 1",
            # pytest should pass
            "passed",
        ],
        "expected_job_success": True,
    },
]


def run_act(work_dir: Path, case_name: str) -> tuple[int, str]:
    """Run `act push --rm` in work_dir and return (exit_code, combined_output).

    --pull=false prevents act from attempting to pull the local image from Docker Hub.
    """
    cmd = ["act", "push", "--rm", "--pull=false"]
    print(f"  Running: {' '.join(cmd)} in {work_dir}")
    result = subprocess.run(
        cmd,
        cwd=work_dir,
        capture_output=True,
        text=True,
        timeout=300,  # 5 minute timeout
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def setup_temp_repo(case: dict) -> Path:
    """Copy project files into a fresh temp git repo for this test case."""
    tmp = Path(tempfile.mkdtemp(prefix=f"act-test-{case['name']}-"))

    # Copy all project source files
    files_to_copy = [
        "secret_rotation.py",
        "test_secret_rotation.py",
        ".actrc",
    ]
    for fname in files_to_copy:
        src = PROJECT_DIR / fname
        if src.exists():
            shutil.copy2(src, tmp / fname)

    # Copy fixtures directory
    fixtures_src = PROJECT_DIR / "fixtures"
    if fixtures_src.exists():
        shutil.copytree(fixtures_src, tmp / "fixtures")

    # Copy .github directory
    github_src = PROJECT_DIR / ".github"
    if github_src.exists():
        shutil.copytree(github_src, tmp / ".github")

    # Init git repo and commit everything
    subprocess.run(["git", "init"], cwd=tmp, capture_output=True, check=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=tmp, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=tmp, capture_output=True, check=True,
    )
    subprocess.run(["git", "add", "-A"], cwd=tmp, capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-m", f"test: {case['name']}"],
        cwd=tmp, capture_output=True, check=True,
    )

    return tmp


def assert_output(output: str, expected_strings: list[str], case_name: str) -> list[str]:
    """Check that every expected string appears in the act output.

    Returns a list of failure messages (empty = all assertions passed).
    """
    failures = []
    for expected in expected_strings:
        if expected not in output:
            failures.append(
                f"[{case_name}] Expected string not found in output:\n"
                f"  Expected: {expected!r}\n"
                f"  (searched {len(output)} chars of output)"
            )
    return failures


def assert_job_succeeded(output: str, case_name: str) -> list[str]:
    """Assert that at least one job shows 'Job succeeded' in the output."""
    failures = []
    if "Job succeeded" not in output:
        failures.append(
            f"[{case_name}] 'Job succeeded' not found in act output. "
            "The workflow may have failed."
        )
    return failures


def run_all_tests() -> bool:
    """Run all test cases. Returns True if all pass, False otherwise."""
    # Clear (or create) act-result.txt
    ACT_RESULT_PATH.write_text(
        "# Act Test Results — Secret Rotation Validator\n"
        "# Generated by run_act_tests.py\n\n"
    )

    all_passed = True

    for i, case in enumerate(TEST_CASES, 1):
        print(f"\n{'='*60}")
        print(f"Test {i}/{len(TEST_CASES)}: {case['name']}")
        print(f"  {case['description']}")
        print(f"{'='*60}")

        # Write delimiter to act-result.txt
        with open(ACT_RESULT_PATH, "a") as f:
            f.write(f"\n{'='*60}\n")
            f.write(f"TEST CASE {i}: {case['name']}\n")
            f.write(f"Description: {case['description']}\n")
            f.write(f"{'='*60}\n\n")

        # Set up temp repo
        try:
            work_dir = setup_temp_repo(case)
            print(f"  Temp repo: {work_dir}")
        except Exception as e:
            msg = f"SETUP FAILED: {e}"
            print(f"  {msg}")
            with open(ACT_RESULT_PATH, "a") as f:
                f.write(f"{msg}\n")
            all_passed = False
            continue

        # Run act
        try:
            exit_code, output = run_act(work_dir, case["name"])
        except subprocess.TimeoutExpired:
            msg = f"TIMEOUT: act push timed out after 5 minutes"
            print(f"  {msg}")
            with open(ACT_RESULT_PATH, "a") as f:
                f.write(f"{msg}\n")
            all_passed = False
            continue
        except Exception as e:
            msg = f"ACT RUN FAILED: {e}"
            print(f"  {msg}")
            with open(ACT_RESULT_PATH, "a") as f:
                f.write(f"{msg}\n")
            all_passed = False
            continue
        finally:
            # Clean up temp dir
            shutil.rmtree(work_dir, ignore_errors=True)

        # Append full act output to act-result.txt
        with open(ACT_RESULT_PATH, "a") as f:
            f.write(f"Exit code: {exit_code}\n\n")
            f.write("--- ACT OUTPUT ---\n")
            f.write(output)
            f.write("\n--- END ACT OUTPUT ---\n\n")

        # Collect assertion failures
        failures = []

        # 1. Assert exit code 0
        if exit_code != 0:
            failures.append(
                f"[{case['name']}] act exited with code {exit_code} (expected 0)"
            )

        # 2. Assert "Job succeeded" appears
        failures.extend(assert_job_succeeded(output, case["name"]))

        # 3. Assert exact expected strings
        failures.extend(
            assert_output(output, case.get("expected_strings", []), case["name"])
        )

        # Report results for this case
        with open(ACT_RESULT_PATH, "a") as f:
            if failures:
                f.write("ASSERTIONS FAILED:\n")
                for fail in failures:
                    f.write(f"  - {fail}\n")
            else:
                f.write("ALL ASSERTIONS PASSED\n")

        if failures:
            all_passed = False
            print(f"  FAIL — {len(failures)} assertion(s) failed:")
            for fail in failures:
                print(f"    - {fail}")
        else:
            print(f"  PASS — all assertions passed")

    # Write summary
    summary = "\nOVERALL: " + ("ALL TESTS PASSED" if all_passed else "SOME TESTS FAILED")
    print(f"\n{'='*60}")
    print(summary)
    print(f"Full output saved to: {ACT_RESULT_PATH}")

    with open(ACT_RESULT_PATH, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(summary + "\n")

    return all_passed


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
