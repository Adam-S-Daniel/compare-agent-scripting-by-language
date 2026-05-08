#!/usr/bin/env python3
"""Act-based test harness for the dependency license checker.

For each test case fixture, this script:
1. Sets up a temp git repo with all project files + the fixture's manifest
2. Runs `act push --rm` to execute the workflow in Docker
3. Saves all output to act-result.txt (appended, with delimiters)
4. Asserts the act exit code is 0 and the output contains expected values

Usage:
    python3 run_tests.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WORKSPACE = Path(__file__).parent
ACT_RESULT_FILE = WORKSPACE / "act-result.txt"

# Files to copy into each temp repo (relative to WORKSPACE)
PROJECT_FILES = [
    "license_checker.py",
    "fixtures/license_config.json",
    "fixtures/mock_licenses.json",
    "fixtures/package.json",
    "fixtures/requirements.txt",
    "tests/test_license_checker.py",
    ".github/workflows/dependency-license-checker.yml",
]

# ---------------------------------------------------------------------------
# Test cases: each defines a manifest to use and expected substrings in output
# ---------------------------------------------------------------------------

TEST_CASES = [
    {
        "name": "tc1-all-approved-package-json",
        "description": "package.json with MIT-only dependencies → all approved, result PASSED",
        "manifest_src": "fixtures/package.json",
        # The default package.json has express/axios/lodash — all MIT → approved
        "expect_in_output": [
            "express",
            "MIT",
            "[APPROVED]",
            "3 approved",
            "0 denied",
            "Result: PASSED",
            "Job succeeded",
        ],
        "expect_not_in_output": [
            "[DENIED]",
        ],
    },
    {
        "name": "tc2-requirements-txt-approved",
        "description": "requirements.txt with Apache/BSD dependencies → all approved",
        "manifest_src": "fixtures/requirements.txt",
        "expect_in_output": [
            "requests",
            "Apache-2.0",
            "[APPROVED]",
            "3 approved",
            "0 denied",
            "Result: PASSED",
            "Job succeeded",
        ],
        "expect_not_in_output": [
            "[DENIED]",
        ],
    },
]


def run_act_in_temp_repo(test_case: dict, output_file) -> tuple[int, str]:
    """Create a temp git repo, copy project files, run act, return (exit_code, output)."""
    with tempfile.TemporaryDirectory(prefix="lic-check-") as tmp:
        tmp_path = Path(tmp)

        # Copy project files into temp repo
        for rel in PROJECT_FILES:
            src = WORKSPACE / rel
            dst = tmp_path / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)

        # Initialise git repo (act requires a valid git repo)
        subprocess.run(["git", "init"], cwd=tmp, check=True, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@example.com"],
                       cwd=tmp, check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"],
                       cwd=tmp, check=True, capture_output=True)
        subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "test"],
                       cwd=tmp, check=True, capture_output=True)

        # Copy .actrc from workspace so act uses the pre-built image
        actrc_src = WORKSPACE / ".actrc"
        if actrc_src.exists():
            shutil.copy2(actrc_src, tmp_path / ".actrc")

        # Run act with --pull=false so it uses the local image without trying to pull
        result = subprocess.run(
            ["act", "push", "--rm", "--pull=false"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300,
        )

        combined = result.stdout + result.stderr
        return result.returncode, combined


def write_delimiter(f, label: str):
    f.write(f"\n{'='*70}\n")
    f.write(f"TEST CASE: {label}\n")
    f.write(f"{'='*70}\n\n")


def main():
    failures = []

    # Open act-result.txt for writing (overwrite each run)
    with open(ACT_RESULT_FILE, "w") as out:
        out.write("act test harness results for dependency-license-checker\n")
        out.write(f"Workspace: {WORKSPACE}\n\n")

        for tc in TEST_CASES:
            name = tc["name"]
            print(f"\n--- Running: {name} ---")
            print(f"    {tc['description']}")

            write_delimiter(out, name)
            out.write(f"Description: {tc['description']}\n\n")

            try:
                exit_code, output = run_act_in_temp_repo(tc, out)
            except subprocess.TimeoutExpired:
                msg = f"TIMEOUT after 300s"
                print(f"  FAIL: {msg}")
                out.write(f"RESULT: {msg}\n")
                failures.append(f"{name}: {msg}")
                continue
            except Exception as e:
                msg = f"Exception: {e}"
                print(f"  FAIL: {msg}")
                out.write(f"RESULT: {msg}\n")
                failures.append(f"{name}: {msg}")
                continue

            out.write(f"Exit code: {exit_code}\n\n")
            out.write("--- act output ---\n")
            out.write(output)
            out.write("\n--- end act output ---\n\n")

            case_failures = []

            # Assert exit code
            if exit_code != 0:
                case_failures.append(f"act exited with code {exit_code} (expected 0)")

            # Assert expected substrings
            for expected in tc.get("expect_in_output", []):
                if expected not in output:
                    case_failures.append(f"Expected {expected!r} in output but not found")

            # Assert absence of unexpected substrings
            for unexpected in tc.get("expect_not_in_output", []):
                if unexpected in output:
                    case_failures.append(f"Did not expect {unexpected!r} in output but found it")

            if case_failures:
                out.write("ASSERTIONS FAILED:\n")
                for f_msg in case_failures:
                    out.write(f"  - {f_msg}\n")
                    print(f"  FAIL: {f_msg}")
                failures.extend([f"{name}: {m}" for m in case_failures])
            else:
                out.write("RESULT: ALL ASSERTIONS PASSED\n")
                print(f"  PASS: all assertions passed")

        # Final summary
        out.write(f"\n{'='*70}\n")
        out.write("SUMMARY\n")
        out.write(f"{'='*70}\n")
        if failures:
            out.write(f"FAILED ({len(failures)} failures):\n")
            for f_msg in failures:
                out.write(f"  - {f_msg}\n")
        else:
            out.write("ALL TEST CASES PASSED\n")

    print(f"\nResults saved to: {ACT_RESULT_FILE}")

    if failures:
        print(f"\nFAILED ({len(failures)} failures):")
        for f_msg in failures:
            print(f"  - {f_msg}")
        sys.exit(1)
    else:
        print("\nAll test cases passed.")
        sys.exit(0)


if __name__ == "__main__":
    main()
