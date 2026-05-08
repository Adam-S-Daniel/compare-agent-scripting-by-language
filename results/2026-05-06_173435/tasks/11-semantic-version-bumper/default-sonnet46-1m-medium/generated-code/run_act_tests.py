"""
Act test harness for the semantic version bumper.

For each test case:
  1. Create a temp git repo with the project files + test-specific fixture data
  2. Run `act push --rm` inside it
  3. Assert exit code 0, "Job succeeded", and the exact expected NEW_VERSION value
  4. Append delimited output to act-result.txt in the CWD

Usage:
  python3 run_act_tests.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WORKSPACE = Path(__file__).parent.resolve()
ACT_RESULT_FILE = WORKSPACE / "act-result.txt"

# Files from the project that must be present in every test repo
PROJECT_FILES = [
    "bump_version.py",
    "tests/__init__.py",
    "tests/test_bump_version.py",
    "tests/test_workflow.py",
    ".github/workflows/semantic-version-bumper.yml",
    ".actrc",
    "fixtures/commits_patch.txt",
    "fixtures/commits_minor.txt",
    "fixtures/commits_major.txt",
    "fixtures/commits_mixed.txt",
]

TEST_CASES = [
    {
        "name": "patch-bump",
        "description": "fix commits only -> patch bump",
        "version": "1.0.0",
        "commits": "fix: correct typo in README\nfix(auth): handle null pointer\n",
        "expected_version": "1.0.1",
    },
    {
        "name": "minor-bump",
        "description": "feat commit -> minor bump",
        "version": "1.1.0",
        "commits": "feat: add user profile API\nfix: correct date formatting\n",
        "expected_version": "1.2.0",
    },
    {
        "name": "major-bump",
        "description": "breaking commit -> major bump",
        "version": "2.0.0",
        "commits": "feat!: redesign public REST API\nfix: update internal logger\n",
        "expected_version": "3.0.0",
    },
    {
        "name": "minor-beats-patch",
        "description": "mixed fix+feat commits -> minor bump (feat wins)",
        "version": "0.5.3",
        "commits": "fix: memory leak\nfeat: dark mode\nfix: typo\n",
        "expected_version": "0.6.0",
    },
]


def copy_project_to(dest: Path) -> None:
    """Copy required project files into dest, preserving directory structure."""
    for rel in PROJECT_FILES:
        src = WORKSPACE / rel
        if not src.exists():
            print(f"  WARNING: source file missing: {src}")
            continue
        dst = dest / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    # Copy .actrc so act uses the correct container image
    actrc_src = WORKSPACE / ".actrc"
    if actrc_src.exists():
        shutil.copy2(actrc_src, dest / ".actrc")


def setup_test_repo(tmp_dir: Path, version: str, commits: str) -> None:
    """Initialise a git repo in tmp_dir with test-specific VERSION and commits.txt."""
    copy_project_to(tmp_dir)
    (tmp_dir / "VERSION").write_text(version + "\n")
    (tmp_dir / "commits.txt").write_text(commits)

    subprocess.run(["git", "init"], cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"],
                   cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"],
                   cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "test fixture commit"],
                   cwd=tmp_dir, check=True, capture_output=True)


def run_act(tmp_dir: Path) -> tuple[int, str]:
    """Run `act push --rm` in tmp_dir and return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def assert_test_case(case: dict, exit_code: int, output: str) -> list[str]:
    """Return list of assertion failures (empty = all passed)."""
    failures = []

    if exit_code != 0:
        failures.append(f"act exited with code {exit_code} (expected 0)")

    if "Job succeeded" not in output:
        failures.append("'Job succeeded' not found in act output")

    expected = case["expected_version"]
    if f"NEW_VERSION={expected}" not in output:
        failures.append(
            f"Expected 'NEW_VERSION={expected}' in output but not found"
        )

    return failures


def main() -> int:
    print("=== Act Test Harness: Semantic Version Bumper ===\n")

    # Truncate/create act-result.txt
    ACT_RESULT_FILE.write_text("")

    all_passed = True

    for case in TEST_CASES:
        name = case["name"]
        print(f"--- Test case: {name} ({case['description']}) ---")

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            print(f"  Setting up repo in {tmp_path}")
            try:
                setup_test_repo(tmp_path, case["version"], case["commits"])
            except subprocess.CalledProcessError as exc:
                print(f"  ERROR: git setup failed: {exc}")
                all_passed = False
                continue

            print(f"  Running: act push --rm")
            try:
                exit_code, output = run_act(tmp_path)
            except subprocess.TimeoutExpired:
                print("  ERROR: act timed out after 300s")
                all_passed = False
                with ACT_RESULT_FILE.open("a") as f:
                    f.write(f"\n{'='*60}\nTEST CASE: {name}\nRESULT: TIMEOUT\n{'='*60}\n")
                continue

            # Append to act-result.txt
            with ACT_RESULT_FILE.open("a") as f:
                f.write(f"\n{'='*60}\n")
                f.write(f"TEST CASE: {name}\n")
                f.write(f"DESCRIPTION: {case['description']}\n")
                f.write(f"INPUT VERSION: {case['version']}\n")
                f.write(f"EXPECTED VERSION: {case['expected_version']}\n")
                f.write(f"ACT EXIT CODE: {exit_code}\n")
                f.write(f"{'='*60}\n")
                f.write(output)
                f.write(f"\n{'='*60}\n")

            failures = assert_test_case(case, exit_code, output)

            if failures:
                all_passed = False
                print(f"  FAILED:")
                for fail in failures:
                    print(f"    - {fail}")
                # Print last 30 lines of output for debugging
                lines = output.splitlines()
                print("  Last 30 lines of act output:")
                for line in lines[-30:]:
                    print(f"    {line}")
            else:
                print(f"  PASSED: NEW_VERSION={case['expected_version']}, Job succeeded")

        print()

    print("=== Summary ===")
    if all_passed:
        print("ALL TEST CASES PASSED")
        return 0
    else:
        print("SOME TEST CASES FAILED")
        return 1


if __name__ == "__main__":
    sys.exit(main())
