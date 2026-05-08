#!/usr/bin/env python3
"""
Test harness that runs all test cases through the GitHub Actions workflow via act.

Sets up a temp git repo with project files and fixture data, runs act push --rm,
captures output to act-result.txt, and asserts on exact expected values.
"""
import os
import shutil
import subprocess
import sys
import tempfile

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(WORK_DIR, "act-result.txt")

# Files to copy into the temp repo for act
PROJECT_FILES = [
    "version_bumper.py",
    "VERSION",
    ".github/workflows/semantic-version-bumper.yml",
    "fixtures/case_patch.txt",
    "fixtures/case_minor.txt",
    "fixtures/case_major.txt",
    "fixtures/case_breaking_footer.txt",
]

# Expected results for each test scenario
# VERSION file starts at 1.2.3
EXPECTED = {
    "patch": {
        "marker_start": "---PATCH RESULT---",
        "marker_end": "---END PATCH---",
        "expected_version": "1.2.4",
    },
    "minor": {
        "marker_start": "---MINOR RESULT---",
        "marker_end": "---END MINOR---",
        "expected_version": "1.3.0",
    },
    "major": {
        "marker_start": "---MAJOR RESULT---",
        "marker_end": "---END MAJOR---",
        "expected_version": "2.0.0",
    },
    "breaking_footer": {
        "marker_start": "---BREAKING FOOTER RESULT---",
        "marker_end": "---END BREAKING FOOTER---",
        "expected_version": "2.0.0",
    },
    "error_invalid": {
        "marker": "ERROR_HANDLED: invalid version correctly rejected",
    },
    "error_missing": {
        "marker": "ERROR_HANDLED: missing file correctly rejected",
    },
    "changelog": {
        "marker_start": "---CHANGELOG---",
        "marker_end": "---END CHANGELOG---",
        "expected_contains": [
            "## [1.3.0] - 2026-05-06",
            "### Features",
            "add user profile image upload",
            "### Fixes",
            "handle empty email validation",
        ],
    },
}


def setup_temp_repo(tmp_dir):
    """Copy project files into a temp directory and init as git repo."""
    for fpath in PROJECT_FILES:
        src = os.path.join(WORK_DIR, fpath)
        dst = os.path.join(tmp_dir, fpath)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    # Copy .actrc if present
    actrc = os.path.join(WORK_DIR, ".actrc")
    if os.path.isfile(actrc):
        shutil.copy2(actrc, os.path.join(tmp_dir, ".actrc"))
    # Init git repo (needed for actions/checkout)
    subprocess.run(["git", "init"], cwd=tmp_dir, capture_output=True)
    subprocess.run(["git", "add", "."], cwd=tmp_dir, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "initial commit", "--allow-empty"],
        cwd=tmp_dir, capture_output=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@test.com",
             "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@test.com"}
    )
    subprocess.run(
        ["git", "commit", "-m", "feat: initial", "--allow-empty"],
        cwd=tmp_dir, capture_output=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@test.com",
             "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@test.com"}
    )


def run_act(tmp_dir):
    """Run act push --rm in the temp directory, return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return result.returncode, result.stdout + result.stderr


def extract_between_markers(output, start_marker, end_marker):
    """Extract text between two markers in the output."""
    lines = output.split("\n")
    capturing = False
    captured = []
    for line in lines:
        if start_marker in line:
            capturing = True
            continue
        if end_marker in line:
            capturing = False
            continue
        if capturing:
            captured.append(line)
    return "\n".join(captured).strip()


def run_tests():
    """Main test execution."""
    print("=" * 60)
    print("SEMANTIC VERSION BUMPER - ACT INTEGRATION TESTS")
    print("=" * 60)

    # Clear previous results
    with open(ACT_RESULT_FILE, "w") as f:
        f.write("")

    tmp_dir = tempfile.mkdtemp(prefix="semver_test_")
    print(f"\nTemp directory: {tmp_dir}")

    try:
        print("\n[1/3] Setting up test repository...")
        setup_temp_repo(tmp_dir)

        print("[2/3] Running act push --rm...")
        exit_code, output = run_act(tmp_dir)

        # Save output to act-result.txt
        with open(ACT_RESULT_FILE, "w") as f:
            f.write("=" * 60 + "\n")
            f.write("ACT OUTPUT - Semantic Version Bumper Tests\n")
            f.write("=" * 60 + "\n\n")
            f.write(output)

        print(f"    Act exit code: {exit_code}")
        print(f"    Output length: {len(output)} chars")
        print(f"    Saved to: {ACT_RESULT_FILE}")

        print("\n[3/3] Asserting test results...\n")
        passed = 0
        failed = 0

        # Check act succeeded
        if exit_code == 0:
            print("  PASS: act exited with code 0")
            passed += 1
        else:
            print(f"  FAIL: act exited with code {exit_code}")
            failed += 1
            # Print last 50 lines for debugging
            lines = output.split("\n")
            print("  --- Last 50 lines of output ---")
            for line in lines[-50:]:
                print(f"  | {line}")
            print("  --- End output ---")

        # Check job succeeded
        if "Job succeeded" in output:
            print("  PASS: Job succeeded marker found")
            passed += 1
        else:
            print("  FAIL: 'Job succeeded' not found in output")
            failed += 1

        # Test patch bump: 1.2.3 -> 1.2.4
        patch_version = extract_between_markers(
            output, EXPECTED["patch"]["marker_start"], EXPECTED["patch"]["marker_end"]
        )
        if EXPECTED["patch"]["expected_version"] in patch_version:
            print(f"  PASS: Patch bump = {EXPECTED['patch']['expected_version']}")
            passed += 1
        else:
            print(f"  FAIL: Patch bump expected '{EXPECTED['patch']['expected_version']}', got '{patch_version}'")
            failed += 1

        # Test minor bump: 1.2.3 -> 1.3.0
        minor_version = extract_between_markers(
            output, EXPECTED["minor"]["marker_start"], EXPECTED["minor"]["marker_end"]
        )
        if EXPECTED["minor"]["expected_version"] in minor_version:
            print(f"  PASS: Minor bump = {EXPECTED['minor']['expected_version']}")
            passed += 1
        else:
            print(f"  FAIL: Minor bump expected '{EXPECTED['minor']['expected_version']}', got '{minor_version}'")
            failed += 1

        # Test major bump: 1.2.3 -> 2.0.0
        major_version = extract_between_markers(
            output, EXPECTED["major"]["marker_start"], EXPECTED["major"]["marker_end"]
        )
        if EXPECTED["major"]["expected_version"] in major_version:
            print(f"  PASS: Major bump = {EXPECTED['major']['expected_version']}")
            passed += 1
        else:
            print(f"  FAIL: Major bump expected '{EXPECTED['major']['expected_version']}', got '{major_version}'")
            failed += 1

        # Test breaking change footer: 1.2.3 -> 2.0.0
        breaking_version = extract_between_markers(
            output,
            EXPECTED["breaking_footer"]["marker_start"],
            EXPECTED["breaking_footer"]["marker_end"],
        )
        if EXPECTED["breaking_footer"]["expected_version"] in breaking_version:
            print(f"  PASS: Breaking footer bump = {EXPECTED['breaking_footer']['expected_version']}")
            passed += 1
        else:
            print(f"  FAIL: Breaking footer expected '{EXPECTED['breaking_footer']['expected_version']}', got '{breaking_version}'")
            failed += 1

        # Test error handling - invalid version
        if EXPECTED["error_invalid"]["marker"] in output:
            print("  PASS: Invalid version error handled correctly")
            passed += 1
        else:
            print("  FAIL: Invalid version error not handled")
            failed += 1

        # Test error handling - missing file
        if EXPECTED["error_missing"]["marker"] in output:
            print("  PASS: Missing file error handled correctly")
            passed += 1
        else:
            print("  FAIL: Missing file error not handled")
            failed += 1

        # Test changelog content
        changelog_content = extract_between_markers(
            output,
            EXPECTED["changelog"]["marker_start"],
            EXPECTED["changelog"]["marker_end"],
        )
        changelog_pass = True
        for expected_str in EXPECTED["changelog"]["expected_contains"]:
            if expected_str in changelog_content:
                pass
            else:
                print(f"  FAIL: Changelog missing '{expected_str}'")
                changelog_pass = False
                failed += 1
        if changelog_pass:
            print("  PASS: Changelog contains all expected entries")
            passed += 1

        print(f"\n{'=' * 60}")
        print(f"RESULTS: {passed} passed, {failed} failed")
        print(f"{'=' * 60}")

        # Append summary to act-result.txt
        with open(ACT_RESULT_FILE, "a") as f:
            f.write(f"\n\n{'=' * 60}\n")
            f.write(f"TEST SUMMARY: {passed} passed, {failed} failed\n")
            f.write(f"{'=' * 60}\n")

        return failed == 0

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    # First run workflow structure tests
    print("Running workflow structure tests first...\n")
    result = subprocess.run(
        [sys.executable, "test_structure.py"],
        capture_output=True, text=True
    )
    print(result.stdout)
    if result.returncode != 0:
        print("Structure tests failed! Fix before running act.")
        sys.exit(1)

    # Then run act integration tests
    success = run_tests()
    sys.exit(0 if success else 1)
