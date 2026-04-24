#!/usr/bin/env python3
"""
Act test harness for PR Label Assigner.

For each test case:
  1. Creates a temp git repo containing all project files.
  2. Writes the test case's fixture to fixtures/test_input.json.
  3. Runs `act push --rm` and captures output.
  4. Appends output (with delimiter) to act-result.txt.
  5. Asserts exit code 0, "Job succeeded", and exact ASSIGNED_LABELS value.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

# ---------------------------------------------------------------------------
# Test cases: each defines the fixture input and the exact expected output.
# The workflow reads fixtures/test_input.json and prints ASSIGNED_LABELS.
# ---------------------------------------------------------------------------
TEST_CASES = [
    {
        "name": "docs_files_get_documentation_label",
        "input": {
            "files": ["docs/README.md", "docs/contributing.md"],
            "rules": [
                {"pattern": "docs/**",  "label": "documentation", "priority": 1},
                {"pattern": "src/**",   "label": "backend",       "priority": 2},
            ],
        },
        # Only docs files changed; no backend files -> only documentation
        "expected": "documentation",
    },
    {
        "name": "api_files_get_api_and_backend_labels",
        "input": {
            "files": ["src/api/users.py", "src/api/auth.py"],
            "rules": [
                {"pattern": "src/api/**", "label": "api",           "priority": 1},
                {"pattern": "src/**",     "label": "backend",       "priority": 2},
                {"pattern": "docs/**",    "label": "documentation", "priority": 3},
            ],
        },
        # src/api/** matches -> api; src/** matches -> backend; docs/** no match
        "expected": "api,backend",
    },
    {
        "name": "test_file_and_docs_get_tests_and_documentation",
        "input": {
            "files": ["src/api/users.test.py", "docs/README.md"],
            "rules": [
                {"pattern": "*.test.*", "label": "tests",         "priority": 1},
                {"pattern": "docs/**",  "label": "documentation", "priority": 2},
            ],
        },
        # *.test.* matches users.test.py -> tests; docs/** matches README.md -> documentation
        "expected": "tests,documentation",
    },
]

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")


def setup_temp_repo(tmpdir: str, fixture_input: dict) -> None:
    """Copy project files into tmpdir and write the fixture for this test case."""
    # Copy all project files except .git
    for item in sorted(os.listdir(PROJECT_DIR)):
        if item == ".git":
            continue
        src = os.path.join(PROJECT_DIR, item)
        dst = os.path.join(tmpdir, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Overwrite fixtures/test_input.json with this test case's data
    fixtures_dir = os.path.join(tmpdir, "fixtures")
    os.makedirs(fixtures_dir, exist_ok=True)
    with open(os.path.join(fixtures_dir, "test_input.json"), "w") as fh:
        json.dump(fixture_input, fh, indent=2)

    # Initialise git repo
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test fixture"],
    ]:
        subprocess.run(cmd, cwd=tmpdir, check=True, capture_output=True)


def run_act(tmpdir: str) -> subprocess.CompletedProcess:
    """Run `act push --rm` in tmpdir and return the result."""
    return subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )


def append_to_results(section: str) -> None:
    with open(ACT_RESULT_FILE, "a") as fh:
        fh.write(section)


def run_test_case(tc: dict) -> bool:
    name = tc["name"]
    expected = tc["expected"]
    expected_line = f"ASSIGNED_LABELS: {expected}"

    print(f"\n{'='*60}")
    print(f"TEST: {name}")
    print(f"Expected: {expected_line}")
    print(f"{'='*60}")

    with tempfile.TemporaryDirectory() as tmpdir:
        setup_temp_repo(tmpdir, tc["input"])
        result = run_act(tmpdir)

    output = result.stdout + result.stderr

    delimiter = f"\n{'='*60}\n"
    section = (
        f"{delimiter}"
        f"TEST CASE: {name}\n"
        f"EXIT CODE: {result.returncode}\n"
        f"{delimiter}"
        f"{output}"
        f"{delimiter}"
    )
    append_to_results(section)
    print(output[-3000:] if len(output) > 3000 else output)

    passed = True

    if result.returncode != 0:
        print(f"FAIL [{name}]: act exited {result.returncode}")
        passed = False

    if "Job succeeded" not in output:
        print(f"FAIL [{name}]: 'Job succeeded' not found in output")
        passed = False

    if expected_line not in output:
        print(f"FAIL [{name}]: '{expected_line}' not found in output")
        passed = False

    if passed:
        print(f"PASS [{name}]")

    return passed


def main() -> None:
    # Initialise (or clear) act-result.txt
    with open(ACT_RESULT_FILE, "w") as fh:
        fh.write("ACT TEST RESULTS — PR Label Assigner\n")
        fh.write("=" * 60 + "\n")

    results = []
    for tc in TEST_CASES:
        results.append(run_test_case(tc))

    # Summary
    total = len(results)
    passed = sum(results)
    summary = f"\nOVERALL: {passed}/{total} test cases passed\n"
    if passed == total:
        summary += "ALL PASSED\n"
    else:
        failed = [tc["name"] for tc, ok in zip(TEST_CASES, results) if not ok]
        summary += f"FAILED: {', '.join(failed)}\n"

    append_to_results(summary)
    print(summary)
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
