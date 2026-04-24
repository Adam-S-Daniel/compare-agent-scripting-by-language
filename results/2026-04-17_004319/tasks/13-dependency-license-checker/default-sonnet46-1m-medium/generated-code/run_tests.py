#!/usr/bin/env python3
# Test harness: runs each test case through the GitHub Actions workflow via act.
# For each case: sets up a temp git repo with project files + fixture, runs
# `act push --rm`, captures output, and asserts exact expected values.
#
# All output is appended to act-result.txt in the current working directory.
# Usage: python3 run_tests.py

import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")

# Files from the project that every test case needs
PROJECT_FILES = [
    "license_checker.py",
    "config",
    ".github",
    ".actrc",
]

# ── Test case definitions ─────────────────────────────────────────────────────
# Each case specifies:
#   fixture_src: path relative to fixtures/ to use as package.json
#   expected_in_output: list of strings that MUST appear in the act stdout
#   expected_not_in_output: list of strings that must NOT appear

TEST_CASES = [
    {
        "name": "all_approved",
        "description": "All packages have approved licenses → PASS, no denied",
        "fixture_src": "fixtures/package_all_approved.json",
        "fixture_dest": "package.json",
        "expected_in_output": [
            "APPROVED: flask (BSD-3-Clause)",
            "APPROVED: pytest (MIT)",
            "APPROVED: requests (Apache-2.0)",
            "Summary: 3 approved, 0 denied, 0 unknown",
            "Status: PASS",
            "Job succeeded",
        ],
        "expected_not_in_output": ["DENIED:", "Status: FAIL"],
    },
    {
        "name": "with_denied",
        "description": "Has a GPL package → DENIED line appears, Status: FAIL",
        "fixture_src": "fixtures/package_with_denied.json",
        "fixture_dest": "package.json",
        "expected_in_output": [
            "APPROVED: numpy (BSD-3-Clause)",
            "APPROVED: requests (Apache-2.0)",
            "DENIED: gpl-lib (GPL-3.0)",
            "Summary: 2 approved, 1 denied, 0 unknown",
            "Status: FAIL",
            "Job succeeded",
        ],
        "expected_not_in_output": [],
    },
    {
        "name": "with_unknown",
        "description": "Has an unrecognized package → UNKNOWN line, Status: PASS",
        "fixture_src": "fixtures/package_with_unknown.json",
        "fixture_dest": "package.json",
        "expected_in_output": [
            "APPROVED: flask (BSD-3-Clause)",
            "UNKNOWN: mystery-package (unknown)",
            "Summary: 1 approved, 0 denied, 1 unknown",
            "Status: PASS",
            "Job succeeded",
        ],
        "expected_not_in_output": ["Status: FAIL"],
    },
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg: str) -> None:
    print(msg, flush=True)


def append_to_result(text: str) -> None:
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(text)


def copy_project_to(dest: str) -> None:
    """Copy required project files into the temp directory."""
    for name in PROJECT_FILES:
        src = os.path.join(PROJECT_DIR, name)
        dst = os.path.join(dest, name)
        if os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        elif os.path.isfile(src):
            shutil.copy2(src, dst)


def run_act(repo_dir: str) -> tuple[int, str]:
    """Run `act push --rm` in repo_dir and return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false",
             "-W", ".github/workflows/dependency-license-checker.yml"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def run_test_case(case: dict) -> bool:
    """Set up a temp repo, run act, assert expectations. Returns True on success."""
    name = case["name"]
    log(f"\n{'='*60}")
    log(f"TEST CASE: {name}")
    log(f"  {case['description']}")
    log(f"{'='*60}")

    passed = True
    failures = []

    with tempfile.TemporaryDirectory(prefix=f"lic_test_{name}_") as tmp:
        # 1. Copy project files
        copy_project_to(tmp)

        # 2. Copy fixture as the manifest file
        fixture_src = os.path.join(PROJECT_DIR, case["fixture_src"])
        fixture_dest = os.path.join(tmp, case["fixture_dest"])
        shutil.copy2(fixture_src, fixture_dest)

        # 3. Initialise a git repo and commit everything
        for cmd in [
            ["git", "init", "-b", "main"],
            ["git", "config", "user.email", "test@example.com"],
            ["git", "config", "user.name", "Test"],
            ["git", "add", "-A"],
            ["git", "commit", "-m", f"test: {name}"],
        ]:
            subprocess.run(cmd, cwd=tmp, capture_output=True, check=True)

        # 4. Run act
        log("  Running act push --rm …")
        exit_code, output = run_act(tmp)

        # 5. Write output to act-result.txt
        delimiter = f"\n{'#'*60}\n# TEST CASE: {name}\n# {case['description']}\n{'#'*60}\n"
        append_to_result(delimiter + output + "\n")

        # 6. Assert exit code 0
        if exit_code != 0:
            failures.append(f"act exited with code {exit_code} (expected 0)")
            passed = False

        # 7. Assert expected strings appear in output
        for expected in case["expected_in_output"]:
            if expected not in output:
                failures.append(f"Expected in output but missing: {expected!r}")
                passed = False

        # 8. Assert forbidden strings do not appear
        for forbidden in case["expected_not_in_output"]:
            if forbidden in output:
                failures.append(f"Unexpected string in output: {forbidden!r}")
                passed = False

    # Report
    if passed:
        log(f"  PASS")
    else:
        log(f"  FAIL")
        for f in failures:
            log(f"    - {f}")
        # Print last 40 lines of output for diagnosis
        tail = output.split("\n")[-40:]
        log("  --- act output tail ---")
        for line in tail:
            log(f"  | {line}")

    return passed


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    # Clear/create act-result.txt
    with open(ACT_RESULT_FILE, "w") as f:
        f.write(f"# Dependency License Checker — act test results\n\n")

    results = []
    for case in TEST_CASES:
        ok = run_test_case(case)
        results.append((case["name"], ok))

    log(f"\n{'='*60}")
    log("RESULTS SUMMARY")
    log(f"{'='*60}")
    all_passed = True
    for name, ok in results:
        status = "PASS" if ok else "FAIL"
        log(f"  {status}: {name}")
        if not ok:
            all_passed = False

    append_to_result(
        "\n\n# === SUMMARY ===\n"
        + "\n".join(f"# {s}: {n}" for n, s in [(n, "PASS" if ok else "FAIL") for n, ok in results])
        + "\n"
    )

    if all_passed:
        log("\nAll test cases passed.")
        return 0
    else:
        log("\nSome test cases FAILED.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
