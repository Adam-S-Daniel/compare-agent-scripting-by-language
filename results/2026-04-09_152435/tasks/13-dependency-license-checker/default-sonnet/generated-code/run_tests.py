"""
Act Test Harness for Dependency License Checker
================================================
Runs the GitHub Actions workflow via `act` in an isolated Docker container
and asserts on exact expected output values.

Test cases:
  1. Full workflow run — pytest (all 31 tests) + license checker on both fixtures
     Expected: all test names PASSED, specific dep/license/status lines, Job succeeded

Usage:
    python3 run_tests.py
"""

import os
import shutil
import subprocess
import sys
import tempfile

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT = os.path.join(WORKSPACE, "act-result.txt")

# Project files to copy into each temp git repo
PROJECT_FILES = [
    "license_checker.py",
    "test_license_checker.py",
    "config.json",
    ".actrc",
]
PROJECT_DIRS = [
    "fixtures",
    ".github",
]


def copy_project_to(dest: str) -> None:
    """Copy all project files and directories into dest."""
    for fname in PROJECT_FILES:
        src = os.path.join(WORKSPACE, fname)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(dest, fname))
    for dname in PROJECT_DIRS:
        src = os.path.join(WORKSPACE, dname)
        if os.path.exists(src):
            shutil.copytree(src, os.path.join(dest, dname), dirs_exist_ok=True)


def init_git_repo(repo_dir: str) -> None:
    """Initialise a git repo and commit all files so act sees a real push event."""
    cmds = [
        ["git", "init"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test User"],
        ["git", "checkout", "-b", "main"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test: initial commit for license checker"],
    ]
    for cmd in cmds:
        result = subprocess.run(cmd, cwd=repo_dir, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Git command failed: {cmd}\n{result.stderr}")


def run_act(repo_dir: str) -> subprocess.CompletedProcess:
    """Run `act push --rm` in the repo directory and return the result."""
    return subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )


def append_to_result_file(label: str, output: str) -> None:
    """Append labelled act output to act-result.txt."""
    separator = "=" * 60
    with open(ACT_RESULT, "a") as f:
        f.write(f"\n{separator}\n")
        f.write(f"TEST CASE: {label}\n")
        f.write(f"{separator}\n")
        f.write(output)
        f.write(f"\n{separator}\n")


def assert_contains(output: str, expected: str, label: str) -> None:
    """Assert that `expected` is a substring of `output`, else print a diff hint."""
    if expected not in output:
        print(f"  FAIL [{label}]: expected string not found in output:")
        print(f"    Expected: {repr(expected)}")
        # Show surrounding context if possible
        lines = output.splitlines()
        for i, line in enumerate(lines):
            if any(word in line for word in expected.split()):
                start = max(0, i - 2)
                end = min(len(lines), i + 3)
                print(f"    Context (lines {start}-{end}):")
                for l in lines[start:end]:
                    print(f"      {l}")
                break
        return False
    return True


def run_test_case(name: str, expected_strings: list[str]) -> bool:
    """
    Set up a temp git repo, run act, save output, and assert on expected values.
    Returns True if all assertions pass.
    """
    print(f"\n{'='*60}")
    print(f"Running test case: {name}")
    print(f"{'='*60}")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Copy all project files into the temp repo
        copy_project_to(tmpdir)
        # Initialise git
        init_git_repo(tmpdir)
        # Run act
        print("  Running act push --rm ...")
        result = run_act(tmpdir)
        combined = result.stdout + result.stderr

    # Save output regardless of outcome
    append_to_result_file(name, combined)

    # Print a preview
    lines = combined.splitlines()
    print(f"  Act output ({len(lines)} lines). Last 20:")
    for line in lines[-20:]:
        print(f"    {line}")

    passed = True

    # Assert exit code 0
    if result.returncode != 0:
        print(f"  FAIL: act exited with code {result.returncode} (expected 0)")
        passed = False
    else:
        print(f"  OK: act exited with code 0")

    # Assert each expected string is present
    for expected in expected_strings:
        ok = assert_contains(combined, expected, name)
        if ok is False:
            passed = False
        else:
            print(f"  OK: found {repr(expected[:80])}")

    return passed


def main() -> int:
    # Clear/create act-result.txt
    with open(ACT_RESULT, "w") as f:
        f.write("Act Test Results — Dependency License Checker\n")
        f.write("=" * 60 + "\n")

    all_passed = True

    # -----------------------------------------------------------------------
    # Test case 1: Full workflow run
    # Expected: pytest passes, license checker output shows specific values
    # -----------------------------------------------------------------------
    tc1_expected = [
        # Pytest test results (all rounds)
        "test_parse_manifest_missing_file_raises PASSED",
        "test_parse_package_json_extracts_deps PASSED",
        "test_parse_requirements_txt_extracts_deps PASSED",
        "test_check_compliance_approved PASSED",
        "test_check_compliance_denied PASSED",
        "test_check_compliance_none_is_unknown PASSED",
        "test_generate_report_package_json PASSED",
        "test_generate_report_requirements_txt PASSED",
        "test_format_report_compliance_failed_when_denied PASSED",
        "test_workflow_file_exists PASSED",
        "test_actionlint_passes PASSED",
        # Pytest summary
        "31 passed",
        # package.json checker output — specific dep/license/status lines
        "react==18.2.0: MIT [approved]",
        "lodash==4.17.21: MIT [approved]",
        "copyleft-lib==1.0.0: GPL-3.0 [denied]",
        "mystery-pkg==2.5.0: UNKNOWN [unknown]",
        "Summary: 4 approved, 1 denied, 1 unknown",
        "COMPLIANCE FAILED",
        # requirements.txt checker output
        "requests==2.28.0: MIT [approved]",
        "numpy==1.24.0: BSD-3-Clause [approved]",
        "gpl-package==3.0.0: GPL-3.0 [denied]",
        "mystery-lib==1.0.0: UNKNOWN [unknown]",
        "Summary: 3 approved, 1 denied, 1 unknown",
        # Job success marker
        "Job succeeded",
    ]

    ok = run_test_case("full-workflow-run", tc1_expected)
    if not ok:
        all_passed = False

    # -----------------------------------------------------------------------
    # Summary
    # -----------------------------------------------------------------------
    print(f"\n{'='*60}")
    if all_passed:
        print("ALL TEST CASES PASSED")
        print(f"Results saved to: {ACT_RESULT}")
        return 0
    else:
        print("SOME TEST CASES FAILED — see act-result.txt for details")
        print(f"Results saved to: {ACT_RESULT}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
