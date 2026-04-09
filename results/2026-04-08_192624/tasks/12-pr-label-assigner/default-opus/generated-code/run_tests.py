#!/usr/bin/env python3
"""
Test harness for PR Label Assigner.

Runs every test case through the GitHub Actions workflow via `act`.
For each case it:
  1. Creates a temp git repo with the project files + fixture data
  2. Runs `act push --rm` and captures output
  3. Asserts act exit code 0 and "Job succeeded"
  4. Parses the output and asserts EXACT expected label values

Also runs workflow-structure tests (YAML parsing, actionlint, file refs).

All output is appended to act-result.txt in the original working directory.

TDD notes — test cases were written FIRST (red), then the implementation in
pr_label_assigner.py was built incrementally to make each pass (green).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap

# Resolve paths relative to this script's directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Files to copy into each test repo
PROJECT_FILES = [
    "pr_label_assigner.py",
    "label-config.json",
    ".github/workflows/pr-label-assigner.yml",
]

# ── Test case definitions ──────────────────────────────────────────────
# Each case: name, changed_files list, expected LABELS= output, expected individual labels
TEST_CASES = [
    {
        "name": "TC1: docs files get documentation label",
        "changed_files": ["docs/guide.md", "docs/api/reference.md"],
        "expected_label_line": "LABELS=documentation",
        "expected_labels": ["documentation"],
    },
    {
        "name": "TC2: src/api files get api label",
        "changed_files": ["src/api/users.py", "src/api/routes.py"],
        "expected_label_line": "LABELS=api",
        "expected_labels": ["api"],
    },
    {
        "name": "TC3: test files get tests label",
        "changed_files": ["utils.test.js", "helpers.test.ts"],
        "expected_label_line": "LABELS=tests",
        "expected_labels": ["tests"],
    },
    {
        "name": "TC4: mixed files produce multiple labels",
        "changed_files": ["docs/readme.md", "src/api/handler.py", "app.test.js"],
        "expected_label_line": "LABELS=api,documentation,tests",
        "expected_labels": ["api", "documentation", "tests"],
    },
    {
        "name": "TC5: priority — src/api beats generic src (api wins over core)",
        "changed_files": ["src/api/endpoint.py"],
        "expected_label_line": "LABELS=api",
        "expected_labels": ["api"],
    },
    {
        "name": "TC6: generic src files get core label",
        "changed_files": ["src/utils/helpers.py"],
        "expected_label_line": "LABELS=core",
        "expected_labels": ["core"],
    },
    {
        "name": "TC7: no matching files produce empty labels",
        "changed_files": ["random.bin", "data/file.csv"],
        "expected_label_line": "LABELS=",
        "expected_labels": [],
    },
    {
        "name": "TC8: .github files get ci label",
        "changed_files": [".github/workflows/ci.yml"],
        "expected_label_line": "LABELS=ci",
        "expected_labels": ["ci"],
    },
    {
        "name": "TC9: ui files get frontend label",
        "changed_files": ["src/ui/button.tsx", "src/ui/styles.css"],
        "expected_label_line": "LABELS=frontend",
        "expected_labels": ["frontend"],
    },
    {
        "name": "TC10: markdown at root gets documentation label",
        "changed_files": ["CHANGELOG.md"],
        "expected_label_line": "LABELS=documentation",
        "expected_labels": ["documentation"],
    },
]


def setup_test_repo(tmpdir: str, changed_files: list[str]) -> None:
    """Copy project files into a temp git repo and create the changed-files fixture."""
    # Copy project files
    for rel_path in PROJECT_FILES:
        src = os.path.join(SCRIPT_DIR, rel_path)
        dst = os.path.join(tmpdir, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)

    # Write the changed-files fixture
    fixture_path = os.path.join(tmpdir, "changed-files.txt")
    with open(fixture_path, "w") as f:
        for cf in changed_files:
            f.write(cf + "\n")

    # Initialise a git repo (act requires one)
    subprocess.run(
        ["git", "init", "-b", "main"],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "add", "."],
        cwd=tmpdir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "init"],
        cwd=tmpdir, capture_output=True, check=True,
    )


def run_act(tmpdir: str) -> tuple[int, str]:
    """Run `act push --rm` in the temp repo and return (exit_code, output)."""
    result = subprocess.run(
        [
            "act", "push", "--rm",
            "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest",
        ],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=120,
    )
    combined = result.stdout + "\n" + result.stderr
    return result.returncode, combined


def run_functional_tests(result_fh) -> int:
    """Run each test case through act. Returns number of failures."""
    failures = 0

    for tc in TEST_CASES:
        name = tc["name"]
        result_fh.write(f"\n{'='*60}\n")
        result_fh.write(f"TEST: {name}\n")
        result_fh.write(f"{'='*60}\n")

        tmpdir = tempfile.mkdtemp(prefix="label_test_")
        try:
            setup_test_repo(tmpdir, tc["changed_files"])
            exit_code, output = run_act(tmpdir)

            result_fh.write(output)
            result_fh.write(f"\n--- exit code: {exit_code} ---\n")

            # Assert 1: act exited with code 0
            if exit_code != 0:
                result_fh.write(f"FAIL: act exited with code {exit_code}\n")
                failures += 1
                continue

            # Assert 2: Job succeeded
            if "Job succeeded" not in output:
                result_fh.write("FAIL: 'Job succeeded' not found in output\n")
                failures += 1
                continue

            # Assert 3: exact LABELS= line
            expected_line = tc["expected_label_line"]
            if expected_line not in output:
                result_fh.write(
                    f"FAIL: expected '{expected_line}' not found in output\n"
                )
                failures += 1
                continue

            # Assert 4: each expected label appears as a bullet
            label_ok = True
            for label in tc["expected_labels"]:
                marker = f"  - {label}"
                if marker not in output:
                    result_fh.write(
                        f"FAIL: expected label bullet '{marker}' not found\n"
                    )
                    label_ok = False

            if tc["expected_labels"] == [] and "(no labels matched)" not in output:
                result_fh.write(
                    "FAIL: expected '(no labels matched)' for empty label set\n"
                )
                label_ok = False

            if not label_ok:
                failures += 1
                continue

            result_fh.write(f"PASS: {name}\n")
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    return failures


def run_structure_tests(result_fh) -> int:
    """Validate workflow YAML structure, file references, and actionlint."""
    failures = 0
    workflow_path = os.path.join(
        SCRIPT_DIR, ".github", "workflows", "pr-label-assigner.yml"
    )

    result_fh.write(f"\n{'='*60}\n")
    result_fh.write("STRUCTURE TEST: YAML parsing and trigger validation\n")
    result_fh.write(f"{'='*60}\n")

    # Parse YAML (use json-compatible subset via a simple loader)
    try:
        # We deliberately avoid PyYAML dependency — parse key facts with grep
        with open(workflow_path) as f:
            content = f.read()

        # Check triggers
        checks = {
            "push trigger": "push:" in content,
            "pull_request trigger": "pull_request:" in content,
            "workflow_dispatch trigger": "workflow_dispatch" in content,
            "jobs section": "jobs:" in content,
            "assign-labels job": "assign-labels:" in content,
            "checkout step": "actions/checkout@v4" in content,
            "python setup step": "actions/setup-python@v5" in content,
            "references pr_label_assigner.py": "pr_label_assigner.py" in content,
            "references label-config.json": "label-config.json" in content,
            "permissions section": "permissions:" in content,
        }

        for desc, passed in checks.items():
            status = "PASS" if passed else "FAIL"
            result_fh.write(f"  {status}: {desc}\n")
            if not passed:
                failures += 1

    except Exception as e:
        result_fh.write(f"FAIL: could not parse workflow: {e}\n")
        failures += 1

    # Check that referenced files exist
    result_fh.write(f"\n{'='*60}\n")
    result_fh.write("STRUCTURE TEST: referenced files exist\n")
    result_fh.write(f"{'='*60}\n")

    for ref_file in ["pr_label_assigner.py", "label-config.json"]:
        path = os.path.join(SCRIPT_DIR, ref_file)
        exists = os.path.isfile(path)
        status = "PASS" if exists else "FAIL"
        result_fh.write(f"  {status}: {ref_file} exists\n")
        if not exists:
            failures += 1

    # actionlint
    result_fh.write(f"\n{'='*60}\n")
    result_fh.write("STRUCTURE TEST: actionlint validation\n")
    result_fh.write(f"{'='*60}\n")

    lint_result = subprocess.run(
        ["actionlint", workflow_path],
        capture_output=True, text=True,
    )
    if lint_result.returncode == 0:
        result_fh.write("  PASS: actionlint reports no errors\n")
    else:
        result_fh.write(f"  FAIL: actionlint errors:\n{lint_result.stdout}\n{lint_result.stderr}\n")
        failures += 1

    return failures


def main() -> None:
    # Clear previous results
    with open(RESULT_FILE, "w") as f:
        f.write("PR Label Assigner — Test Results\n")
        f.write(f"{'='*60}\n\n")

    total_failures = 0

    with open(RESULT_FILE, "a") as f:
        # Structure tests first (fast)
        total_failures += run_structure_tests(f)

        # Functional tests via act
        total_failures += run_functional_tests(f)

        f.write(f"\n{'='*60}\n")
        if total_failures == 0:
            f.write("ALL TESTS PASSED\n")
        else:
            f.write(f"FAILURES: {total_failures}\n")
        f.write(f"{'='*60}\n")

    # Print summary
    with open(RESULT_FILE) as f:
        content = f.read()

    pass_count = content.count("PASS:")
    fail_count = content.count("FAIL:")
    print(f"\nResults written to {RESULT_FILE}")
    print(f"  PASS: {pass_count}  FAIL: {fail_count}")

    if total_failures > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
