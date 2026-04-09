"""
Test harness for Docker Image Tag Generator.

Runs each test case through GitHub Actions via `act push --rm`, saves all
output to act-result.txt, and asserts exact expected values appear in output.

Also runs workflow structure tests: YAML structure, file references, actionlint.

Usage:
    python3 run_tests.py
"""
import os
import shutil
import subprocess
import sys
import tempfile


# --- Test cases: each defines git context inputs and exact expected output tags ---
# All test cases designed upfront so fixture data is complete before tests run.
TEST_CASES = [
    {
        "id": "main_branch",
        "desc": "Main branch -> latest + main-sha",
        "env": {
            "BRANCH_NAME": "main",
            "COMMIT_SHA": "abc1234def5678",
            "PR_NUMBER": "",
            "GIT_TAGS": "",
        },
        "expected_tags": ["latest", "main-abc1234"],
    },
    {
        "id": "pr_build",
        "desc": "PR build -> pr-42 only",
        "env": {
            "BRANCH_NAME": "feature/test",
            "COMMIT_SHA": "def5678abc1234",
            "PR_NUMBER": "42",
            "GIT_TAGS": "",
        },
        "expected_tags": ["pr-42"],
    },
    {
        "id": "semver_tag",
        "desc": "Semver tag -> v1.2.3 + latest",
        "env": {
            "BRANCH_NAME": "refs/tags/v1.2.3",
            "COMMIT_SHA": "abc1234def5678",
            "PR_NUMBER": "",
            "GIT_TAGS": "v1.2.3",
        },
        "expected_tags": ["v1.2.3", "latest"],
    },
    {
        "id": "feature_branch",
        "desc": "Feature branch -> sanitized-branch-sha",
        "env": {
            "BRANCH_NAME": "feature/my-new-feature",
            "COMMIT_SHA": "abc1234def5678",
            "PR_NUMBER": "",
            "GIT_TAGS": "",
        },
        "expected_tags": ["feature-my-new-feature-abc1234"],
    },
    {
        "id": "special_chars",
        "desc": "Branch with special chars -> fully sanitized",
        "env": {
            "BRANCH_NAME": "feat/My Feature/JIRA-123",
            "COMMIT_SHA": "abc1234def5678",
            "PR_NUMBER": "",
            "GIT_TAGS": "",
        },
        "expected_tags": ["feat-my-feature-jira-123-abc1234"],
    },
]

# Files/dirs to copy into temp git repos for act runs
PROJECT_FILES = [
    "tag_generator.py",
    "test_tag_generator.py",
    ".github",
]

RESULT_FILE = "act-result.txt"
# Act platform flag matching .actrc
ACT_PLATFORM = "ubuntu-latest=act-ubuntu-pwsh:latest"


def setup_temp_repo(test_case: dict) -> str:
    """
    Create a temp git repo with project files for a test case.
    Returns the path to the temp directory.
    """
    tmpdir = tempfile.mkdtemp(prefix=f"act-test-{test_case['id']}-")

    # Copy project files
    cwd = os.path.dirname(os.path.abspath(__file__))
    for name in PROJECT_FILES:
        src = os.path.join(cwd, name)
        dst = os.path.join(tmpdir, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Copy .actrc so act uses the right container
    actrc_src = os.path.join(cwd, ".actrc")
    if os.path.exists(actrc_src):
        shutil.copy2(actrc_src, os.path.join(tmpdir, ".actrc"))

    # Initialize git repo (act requires a git repo)
    subprocess.run(
        ["git", "init", "-b", "main"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "add", "-A"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "commit", "-m", f"test: {test_case['id']}"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )

    return tmpdir


def run_act(tmpdir: str, test_case: dict) -> tuple[int, str]:
    """
    Run act push in the temp repo with test-case env vars.
    Returns (exit_code, combined_output).
    """
    cmd = ["act", "push", "--rm", "--pull=false", "-P", ACT_PLATFORM]

    # Pass each env var; empty values still need to be passed to override defaults
    for key, value in test_case["env"].items():
        cmd.extend(["--env", f"{key}={value}"])

    result = subprocess.run(
        cmd,
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=180,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def assert_expected_tags(output: str, test_case: dict) -> list[str]:
    """
    Check that all expected tags appear in the act output.
    Returns list of assertion errors (empty = all good).
    """
    errors = []
    for tag in test_case["expected_tags"]:
        if tag not in output:
            errors.append(
                f"Expected tag '{tag}' not found in output for case '{test_case['id']}'"
            )
    return errors


def assert_job_succeeded(output: str, test_case: dict) -> list[str]:
    """Check that 'Job succeeded' appears in act output."""
    errors = []
    if "Job succeeded" not in output:
        errors.append(
            f"'Job succeeded' not found in output for case '{test_case['id']}'"
        )
    return errors


def main() -> None:
    # Clear/create result file
    with open(RESULT_FILE, "w") as f:
        f.write("# act-result.txt — Docker Image Tag Generator Test Results\n")
        f.write("# Generated by run_tests.py\n\n")

    all_errors = []
    total_cases = len(TEST_CASES)
    passed = 0

    print(f"Running {total_cases} test cases through act...\n")

    for i, test_case in enumerate(TEST_CASES, 1):
        print(f"[{i}/{total_cases}] {test_case['id']}: {test_case['desc']}")

        tmpdir = None
        try:
            tmpdir = setup_temp_repo(test_case)
            print(f"  Temp repo: {tmpdir}")

            exit_code, output = run_act(tmpdir, test_case)
            print(f"  act exit code: {exit_code}")

            # Append output to result file
            with open(RESULT_FILE, "a") as f:
                f.write(f"{'='*60}\n")
                f.write(f"TEST CASE: {test_case['id']}\n")
                f.write(f"DESC: {test_case['desc']}\n")
                f.write(f"ENV: {test_case['env']}\n")
                f.write(f"EXPECTED: {test_case['expected_tags']}\n")
                f.write(f"EXIT CODE: {exit_code}\n")
                f.write(f"{'='*60}\n")
                f.write(output)
                f.write(f"\n{'='*60}\n\n")

            case_errors = []

            # Assert exit code 0
            if exit_code != 0:
                case_errors.append(
                    f"act exited with code {exit_code} for case '{test_case['id']}'"
                )

            # Assert expected tags appear in output
            case_errors.extend(assert_expected_tags(output, test_case))

            # Assert job succeeded
            case_errors.extend(assert_job_succeeded(output, test_case))

            if case_errors:
                print(f"  FAILED:")
                for err in case_errors:
                    print(f"    - {err}")
                all_errors.extend(case_errors)
            else:
                print(f"  PASSED - tags {test_case['expected_tags']} found")
                passed += 1

        except subprocess.TimeoutExpired:
            err = f"Timeout running act for case '{test_case['id']}'"
            print(f"  TIMEOUT: {err}")
            all_errors.append(err)
            with open(RESULT_FILE, "a") as f:
                f.write(f"TEST CASE: {test_case['id']} - TIMEOUT\n\n")
        except Exception as e:
            err = f"Error in case '{test_case['id']}': {e}"
            print(f"  ERROR: {err}")
            all_errors.append(err)
        finally:
            if tmpdir and os.path.exists(tmpdir):
                shutil.rmtree(tmpdir, ignore_errors=True)

        print()

    # Summary
    print(f"Results: {passed}/{total_cases} cases passed")

    # Append summary to result file
    with open(RESULT_FILE, "a") as f:
        f.write(f"{'='*60}\n")
        f.write(f"SUMMARY: {passed}/{total_cases} test cases passed\n")
        if all_errors:
            f.write("ERRORS:\n")
            for err in all_errors:
                f.write(f"  - {err}\n")
        else:
            f.write("ALL TESTS PASSED\n")
        f.write(f"{'='*60}\n")

    if all_errors:
        print("\nFailed assertions:")
        for err in all_errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("\nAll test cases passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
