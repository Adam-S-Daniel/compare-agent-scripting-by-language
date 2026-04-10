#!/usr/bin/env python3
"""
Test harness for PR Label Assigner.

Sets up a temporary git repo with project files, runs the GitHub Actions
workflow via act, captures output, and verifies all test cases passed
with exact expected values.

Also runs workflow structure tests (YAML validation, file references, actionlint).
"""

import subprocess
import tempfile
import shutil
import os
import sys
import re
import json


WORK_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(WORK_DIR, "act-result.txt")

# Project files to copy into the temp repo
PROJECT_FILES = [
    "pr_label_assigner.py",
    "test_pr_label_assigner.py",
    "label_config.json",
]
WORKFLOW_REL = os.path.join(".github", "workflows", "pr-label-assigner.yml")

# Expected test names and their exact expected values (for strict verification)
EXPECTED_TESTS = {
    "basic_glob_matching":           "['documentation']",
    "multiple_labels_per_file":      "['api', 'core']",
    "wildcard_extension":            "['tests']",
    "priority_ordering_exclusive":   "['api-critical']",
    "priority_non_exclusive":        "['api', 'core']",
    "empty_file_list":               "[]",
    "no_matching_rules":             "[]",
    "multiple_files_different_labels": "['api', 'documentation', 'tests']",
    "github_ci_pattern":             "['ci']",
    "markdown_extension":            "['documentation']",
    "deduplicate_labels":            "['documentation']",
    "load_config_from_file":         "['core']",
    "invalid_config_missing_rules":  "ValueError",
    "config_file_not_found":         "FileNotFoundError",
    "complex_scenario":              "['api', 'ci', 'config', 'core', 'documentation', 'tests']",
    "main_cli_output":               "True",
}


def setup_temp_repo(tmp_dir):
    """Create a git repo in tmp_dir with all project files."""
    # Copy project files
    for f in PROJECT_FILES:
        src = os.path.join(WORK_DIR, f)
        shutil.copy2(src, os.path.join(tmp_dir, f))

    # Copy workflow
    wf_src = os.path.join(WORK_DIR, WORKFLOW_REL)
    wf_dst = os.path.join(tmp_dir, WORKFLOW_REL)
    os.makedirs(os.path.dirname(wf_dst), exist_ok=True)
    shutil.copy2(wf_src, wf_dst)

    # Copy .actrc if it exists
    actrc = os.path.join(WORK_DIR, ".actrc")
    if os.path.exists(actrc):
        shutil.copy2(actrc, os.path.join(tmp_dir, ".actrc"))

    # Initialize git repo with an initial commit
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "test",
        "GIT_AUTHOR_EMAIL": "test@test.com",
        "GIT_COMMITTER_NAME": "test",
        "GIT_COMMITTER_EMAIL": "test@test.com",
    }
    subprocess.run(["git", "init"], cwd=tmp_dir, capture_output=True, check=True)
    subprocess.run(["git", "add", "."], cwd=tmp_dir, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-m", "initial commit"],
                   cwd=tmp_dir, capture_output=True, check=True, env=env)


def run_act(tmp_dir):
    """Run act push --rm and return (combined_output, exit_code)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + "\n" + result.stderr
    return combined, result.returncode


# ========== Workflow Structure Tests ==========

def test_workflow_structure():
    """Validate workflow YAML structure without act."""
    print("\n" + "=" * 60)
    print("WORKFLOW STRUCTURE TESTS")
    print("=" * 60)
    errors = []

    wf_path = os.path.join(WORK_DIR, WORKFLOW_REL)

    # 1. Workflow file exists
    if not os.path.exists(wf_path):
        errors.append("Workflow file does not exist at " + WORKFLOW_REL)
        return errors
    print("  [PASS] Workflow file exists")

    # 2. Read and check structure
    with open(wf_path) as f:
        content = f.read()

    # Check triggers
    if "on:" not in content:
        errors.append("Workflow missing 'on:' trigger block")
    else:
        print("  [PASS] Has 'on:' trigger block")

    for trigger in ["push", "pull_request", "workflow_dispatch"]:
        if trigger in content:
            print(f"  [PASS] Has '{trigger}' trigger")
        # Not an error if missing optional triggers

    # Check jobs
    if "jobs:" not in content:
        errors.append("Workflow missing 'jobs:' block")
    else:
        print("  [PASS] Has 'jobs:' block")

    # Check checkout action
    if "actions/checkout@v4" not in content:
        errors.append("Workflow missing actions/checkout@v4")
    else:
        print("  [PASS] Uses actions/checkout@v4")

    # 3. Verify script file references exist on disk
    for script in PROJECT_FILES:
        if script in content:
            script_path = os.path.join(WORK_DIR, script)
            if os.path.exists(script_path):
                print(f"  [PASS] References '{script}' and file exists")
            else:
                errors.append(f"Workflow references '{script}' but file not found")
        else:
            errors.append(f"Workflow does not reference '{script}'")

    # 4. actionlint validation
    result = subprocess.run(
        ["actionlint", wf_path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        errors.append(f"actionlint failed: {result.stdout.strip()} {result.stderr.strip()}")
    else:
        print("  [PASS] actionlint passes (exit code 0)")

    return errors


# ========== Act Integration Tests ==========

def verify_act_output(output):
    """Parse act output and verify each test case passed with exact values."""
    errors = []

    # Check for job success marker
    if "Job succeeded" not in output:
        # act sometimes uses different casing
        if "success" not in output.lower():
            errors.append("No 'Job succeeded' message found in act output")

    # Extract structured test results
    test_pattern = re.compile(
        r"=== TEST: (\S+) ===.*?"
        r"EXPECTED: (.+?)\n.*?"
        r"ACTUAL: (.+?)\n.*?"
        r"RESULT: (\S+)",
        re.DOTALL,
    )
    matches = test_pattern.findall(output)

    if not matches:
        errors.append("No test results found in act output")
        return errors

    found_tests = {}
    for name, expected, actual, result in matches:
        name = name.strip()
        found_tests[name] = {
            "expected": expected.strip(),
            "actual": actual.strip(),
            "result": result.strip(),
        }

    # Verify each expected test was found and passed
    for test_name, expected_value in EXPECTED_TESTS.items():
        if test_name not in found_tests:
            errors.append(f"Expected test '{test_name}' not found in output")
            continue

        info = found_tests[test_name]

        # Assert RESULT is PASS
        if info["result"] != "PASS":
            errors.append(
                f"Test '{test_name}' FAILED: "
                f"expected={info['expected']}, actual={info['actual']}"
            )

        # Assert exact expected value matches
        if info["actual"] != expected_value:
            errors.append(
                f"Test '{test_name}' value mismatch: "
                f"expected '{expected_value}', got '{info['actual']}'"
            )

    # Verify summary line
    if "ALL TESTS PASSED" not in output:
        errors.append("Summary line 'ALL TESTS PASSED' not found in output")

    # Verify demo run output
    if "LABELS:" not in output:
        errors.append("Demo label assigner run output not found")

    return errors


def main():
    all_errors = []
    act_output_parts = []

    # ---- Part 1: Workflow Structure Tests ----
    struct_errors = test_workflow_structure()
    if struct_errors:
        for e in struct_errors:
            print(f"  [FAIL] {e}")
        all_errors.extend(struct_errors)
    else:
        print("\n  All workflow structure tests passed.")

    # ---- Part 2: Act Integration Test (single run, all test cases) ----
    print("\n" + "=" * 60)
    print("ACT INTEGRATION TEST")
    print("=" * 60)

    with tempfile.TemporaryDirectory() as tmp_dir:
        print(f"  Setting up temp repo in {tmp_dir}...")
        setup_temp_repo(tmp_dir)

        print("  Running: act push --rm")
        output, exit_code = run_act(tmp_dir)
        act_output_parts.append(
            f"=== ACT RUN: all test cases ===\n"
            f"Exit code: {exit_code}\n"
            f"{output}\n"
            f"=== END ACT RUN ===\n"
        )

        print(f"  act exit code: {exit_code}")
        if exit_code != 0:
            all_errors.append(f"act exited with non-zero code {exit_code}")

        # Verify output
        verify_errors = verify_act_output(output)
        if verify_errors:
            for e in verify_errors:
                print(f"  [FAIL] {e}")
            all_errors.extend(verify_errors)
        else:
            print("  All act integration assertions passed.")

    # ---- Save act-result.txt ----
    with open(ACT_RESULT_FILE, "w") as f:
        f.write("\n".join(act_output_parts))
    print(f"\n  Saved act-result.txt -> {ACT_RESULT_FILE}")

    # ---- Final Summary ----
    print("\n" + "=" * 60)
    if all_errors:
        print(f"TOTAL FAILURES: {len(all_errors)}")
        for e in all_errors:
            print(f"  - {e}")
        print("=" * 60)
        sys.exit(1)
    else:
        print("ALL TESTS PASSED")
        print("=" * 60)


if __name__ == "__main__":
    main()
