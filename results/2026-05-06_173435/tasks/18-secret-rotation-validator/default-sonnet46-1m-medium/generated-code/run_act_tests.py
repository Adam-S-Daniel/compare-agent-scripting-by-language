#!/usr/bin/env python3
"""
Act test harness for Secret Rotation Validator.

For each test case this script:
  1. Copies the project into a temp git repo.
  2. Runs `act push --rm` to execute the GitHub Actions workflow in Docker.
  3. Asserts act exits with code 0.
  4. Asserts every expected string is present in the output (exact values).
  5. Asserts both jobs report "Job succeeded".
  6. Appends delimited output to act-result.txt.

Usage:
    python run_act_tests.py
"""

import os
import shutil
import subprocess
import sys
import tempfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Test cases: each defines what must appear verbatim in the act output.
TEST_CASES = [
    {
        "name": "mixed_secrets_full_pipeline",
        "description": (
            "Full pipeline run: both jobs succeed, pytest passes all 41 tests, "
            "validator reports 2 expired / 1 warning / 2 ok for fixtures/secrets_mixed.json."
        ),
        # Strings that MUST appear in the act output.
        "required_strings": [
            # Both jobs must succeed.
            "Job succeeded",
            # pytest passes (string from verbose output).
            "passed",
            # Specific test names confirm the right suite ran.
            "test_expired_secret_is_identified",
            "test_warning_secret_is_identified",
            "test_ok_secret_is_identified",
            # The markdown report mentions exact secret names and urgency labels.
            "API_KEY_PROD",
            "WEBHOOK_SECRET",
            "JWT_SECRET",
            "DB_PASSWORD",
            "OAUTH_CLIENT_SECRET",
            "EXPIRED",
            "WARNING",
            # The JSON report summary must show exact counts.
            '"expired_count": 2',
            '"warning_count": 1',
            '"ok_count": 2',
        ],
    },
]


def _copy_project_to(dest: str) -> None:
    """Copy project files (excluding .git) into dest directory."""
    for entry in os.listdir(SCRIPT_DIR):
        if entry == ".git":
            continue
        src = os.path.join(SCRIPT_DIR, entry)
        dst = os.path.join(dest, entry)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)


def _init_git(repo_dir: str) -> None:
    """Create a minimal git repo so act can detect a push event."""
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "ci@example.com"],
        ["git", "config", "user.name", "CI"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "initial commit"],
    ]:
        subprocess.run(cmd, cwd=repo_dir, capture_output=True, check=True)


def run_test_case(case: dict, outfile) -> bool:
    """Run one test case. Returns True if it passes."""
    print(f"\n{'='*64}")
    print(f"TEST CASE: {case['name']}")
    print(f"{'='*64}")

    header = f"\n{'='*64}\nTEST CASE: {case['name']}\nDescription: {case['description']}\n{'='*64}\n"
    outfile.write(header)

    passed = True

    with tempfile.TemporaryDirectory() as tmpdir:
        # Set up isolated git repo with project files.
        _copy_project_to(tmpdir)
        _init_git(tmpdir)

        print("Running: act push --rm  (this may take 30-90 seconds …)")
        # --pull=false: use local Docker images instead of pulling from registry
        result = subprocess.run(
            ["act", "push", "--rm", "--pull=false"],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            timeout=300,
        )
        output = result.stdout + result.stderr

    outfile.write(output)
    outfile.write(f"\nEXIT CODE: {result.returncode}\n")

    # Assertion 1: act must exit 0.
    if result.returncode != 0:
        msg = f"FAIL [{case['name']}]: act exited with code {result.returncode}"
        print(msg)
        outfile.write(msg + "\n")
        passed = False
    else:
        print(f"  act exit code: 0  OK")

    # Assertion 2: all required strings must appear in the output.
    for expected in case["required_strings"]:
        if expected in output:
            print(f"  FOUND: {expected!r}")
        else:
            msg = f"FAIL [{case['name']}]: expected string not found: {expected!r}"
            print(msg)
            outfile.write(msg + "\n")
            passed = False

    # Assertion 3: both jobs must show "Job succeeded".
    job_succeeded_count = output.count("Job succeeded")
    if job_succeeded_count >= 2:
        print(f"  'Job succeeded' appears {job_succeeded_count} times  OK")
    else:
        msg = (
            f"FAIL [{case['name']}]: expected at least 2 'Job succeeded' lines, "
            f"found {job_succeeded_count}"
        )
        print(msg)
        outfile.write(msg + "\n")
        passed = False

    status = "PASSED" if passed else "FAILED"
    outfile.write(f"\nTEST CASE RESULT: {status}\n")
    return passed


def main() -> None:
    # Validate actionlint before burning Docker time.
    wf = os.path.join(SCRIPT_DIR, ".github", "workflows", "secret-rotation-validator.yml")
    lint = subprocess.run(["actionlint", wf], capture_output=True, text=True)
    if lint.returncode != 0:
        print("ERROR: actionlint failed — fix the workflow before running act.")
        print(lint.stdout)
        print(lint.stderr)
        sys.exit(1)
    print("actionlint: OK")

    failures = []

    with open(RESULT_FILE, "w") as outfile:
        outfile.write("# act Test Results — Secret Rotation Validator\n\n")
        outfile.write(f"Workflow: {wf}\n")

        for case in TEST_CASES:
            ok = run_test_case(case, outfile)
            if not ok:
                failures.append(case["name"])

        summary = "\n" + "="*64 + "\n"
        if failures:
            summary += f"OVERALL: FAILED ({len(failures)} case(s) failed: {', '.join(failures)})\n"
        else:
            summary += f"OVERALL: ALL {len(TEST_CASES)} TEST CASE(S) PASSED\n"
        summary += "="*64 + "\n"
        outfile.write(summary)
        print(summary)

    if failures:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
