#!/usr/bin/env python3
"""Host-side test harness that validates workflow structure and runs act.

This script:
1. Validates workflow YAML structure (triggers, jobs, steps, file references)
2. Validates actionlint passes
3. Sets up a temp git repo with project files
4. Runs act push --rm to execute all tests through the pipeline
5. Parses act output and asserts on exact expected values
6. Saves all output to act-result.txt
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(SCRIPT_DIR, ".github", "workflows", "artifact-cleanup-script.yml")
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

PROJECT_FILES = [
    "artifact_cleanup.py",
    "run_fixture_tests.py",
    "test_fixtures",
    ".github",
    ".actrc",
]

EXPECTED_FIXTURES = {
    "test_max_age": {
        "delete_count": 3,
        "retain_count": 2,
        "space_reclaimed": 3670016,
        "space_retained": 2621440,
        "dry_run": True,
    },
    "test_keep_latest_n": {
        "delete_count": 3,
        "retain_count": 2,
        "space_reclaimed": 3145728,
        "space_retained": 2097152,
        "dry_run": True,
    },
    "test_max_size": {
        "delete_count": 2,
        "retain_count": 3,
        "space_reclaimed": 3145728,
        "space_retained": 8388608,
        "dry_run": True,
    },
    "test_combined": {
        "delete_count": 4,
        "retain_count": 4,
        "space_reclaimed": 5242880,
        "space_retained": 5242880,
        "dry_run": True,
    },
    "test_empty": {
        "delete_count": 0,
        "retain_count": 0,
        "space_reclaimed": 0,
        "space_retained": 0,
        "dry_run": True,
    },
    "test_no_deletions": {
        "delete_count": 0,
        "retain_count": 2,
        "space_reclaimed": 0,
        "space_retained": 3145728,
        "dry_run": False,
    },
}


def write_result(content):
    """Append content to the result file."""
    with open(RESULT_FILE, "a") as f:
        f.write(content + "\n")


def test_workflow_structure():
    """Validate workflow YAML structure."""
    print("--- Workflow Structure Tests ---")
    write_result("=== WORKFLOW STRUCTURE TESTS ===")
    failures = []

    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    # Check triggers
    triggers = wf.get(True) or wf.get("on", {})
    expected_triggers = ["push", "pull_request", "workflow_dispatch", "schedule"]
    for trigger in expected_triggers:
        if trigger not in triggers:
            failures.append(f"Missing trigger: {trigger}")
        else:
            write_result(f"  PASS: trigger '{trigger}' present")
            print(f"  PASS: trigger '{trigger}' present")

    # Check jobs
    jobs = wf.get("jobs", {})
    if not jobs:
        failures.append("No jobs defined")
    else:
        write_result(f"  PASS: {len(jobs)} job(s) defined")
        print(f"  PASS: {len(jobs)} job(s) defined")

    # Check that a checkout step exists
    has_checkout = False
    has_script_ref = False
    for job_name, job in jobs.items():
        steps = job.get("steps", [])
        for step in steps:
            uses = step.get("uses", "")
            if "actions/checkout" in uses:
                has_checkout = True
            run_cmd = step.get("run", "")
            if "artifact_cleanup.py" in run_cmd or "run_fixture_tests.py" in run_cmd:
                has_script_ref = True

    if not has_checkout:
        failures.append("No actions/checkout step found")
    else:
        write_result("  PASS: actions/checkout step found")
        print("  PASS: actions/checkout step found")

    if not has_script_ref:
        failures.append("Workflow does not reference project scripts")
    else:
        write_result("  PASS: workflow references project scripts")
        print("  PASS: workflow references project scripts")

    # Check that referenced files exist
    for f_name in ["artifact_cleanup.py", "run_fixture_tests.py"]:
        path = os.path.join(SCRIPT_DIR, f_name)
        if not os.path.exists(path):
            failures.append(f"Referenced file does not exist: {f_name}")
        else:
            write_result(f"  PASS: file exists: {f_name}")
            print(f"  PASS: file exists: {f_name}")

    # Check permissions
    if "permissions" not in wf:
        failures.append("No permissions block defined")
    else:
        write_result("  PASS: permissions block defined")
        print("  PASS: permissions block defined")

    if failures:
        for f in failures:
            write_result(f"  FAIL: {f}")
            print(f"  FAIL: {f}")
        write_result("STRUCTURE_RESULT: FAIL")
        print("STRUCTURE_RESULT: FAIL")
        return False

    write_result("STRUCTURE_RESULT: PASS")
    print("STRUCTURE_RESULT: PASS")
    write_result("=== END WORKFLOW STRUCTURE TESTS ===\n")
    return True


def test_actionlint():
    """Run actionlint and assert exit code 0."""
    print("\n--- Actionlint Validation ---")
    write_result("=== ACTIONLINT VALIDATION ===")

    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        write_result(f"  FAIL: actionlint returned exit code {result.returncode}")
        write_result(f"  OUTPUT: {result.stdout}{result.stderr}")
        print(f"  FAIL: actionlint errors:\n{result.stdout}{result.stderr}")
        write_result("ACTIONLINT_RESULT: FAIL")
        write_result("=== END ACTIONLINT VALIDATION ===\n")
        return False

    write_result("  PASS: actionlint exit code 0")
    write_result("ACTIONLINT_RESULT: PASS")
    write_result("=== END ACTIONLINT VALIDATION ===\n")
    print("  PASS: actionlint exit code 0")
    return True


def run_act_tests():
    """Set up temp git repo and run act."""
    print("\n--- Act Pipeline Tests ---")
    write_result("=== ACT PIPELINE TESTS ===")

    tmpdir = tempfile.mkdtemp(prefix="artifact-cleanup-act-")
    try:
        for item in PROJECT_FILES:
            src = os.path.join(SCRIPT_DIR, item)
            dst = os.path.join(tmpdir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            elif os.path.isfile(src):
                shutil.copy2(src, dst)

        subprocess.run(
            ["git", "init"],
            cwd=tmpdir,
            capture_output=True,
        )
        subprocess.run(
            ["git", "add", "-A"],
            cwd=tmpdir,
            capture_output=True,
        )
        subprocess.run(
            ["git", "-c", "user.name=test", "-c", "user.email=test@test.com",
             "commit", "-m", "test"],
            cwd=tmpdir,
            capture_output=True,
        )

        print("  Running act push --rm ...")
        act_result = subprocess.run(
            ["act", "push", "--rm"],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            timeout=180,
        )

        act_output = act_result.stdout + act_result.stderr
        write_result("--- ACT OUTPUT START ---")
        write_result(act_output)
        write_result("--- ACT OUTPUT END ---")

        # Assert act exit code
        if act_result.returncode != 0:
            write_result(f"  FAIL: act exited with code {act_result.returncode}")
            print(f"  FAIL: act exited with code {act_result.returncode}")
            write_result("ACT_RESULT: FAIL")
            write_result("=== END ACT PIPELINE TESTS ===\n")
            return False
        write_result("  PASS: act exit code 0")
        print("  PASS: act exit code 0")

        # Assert "Job succeeded" appears
        if "Job succeeded" not in act_output:
            # act uses various success messages
            if "success" not in act_output.lower():
                write_result("  FAIL: no job success indicator in output")
                print("  FAIL: no job success indicator in output")
                write_result("ACT_RESULT: FAIL")
                write_result("=== END ACT PIPELINE TESTS ===\n")
                return False
        write_result("  PASS: job success confirmed")
        print("  PASS: job success confirmed")

        # Parse fixture results from act output
        all_fixtures_pass = True
        for fixture_name, expected in EXPECTED_FIXTURES.items():
            fixture_block = extract_fixture_block(act_output, fixture_name)
            if fixture_block is None:
                write_result(f"  FAIL: fixture '{fixture_name}' not found in output")
                print(f"  FAIL: fixture '{fixture_name}' not found in output")
                all_fixtures_pass = False
                continue

            fixture_pass = verify_fixture_output(fixture_name, fixture_block, expected)
            if not fixture_pass:
                all_fixtures_pass = False

        if all_fixtures_pass:
            write_result("  PASS: all fixture assertions passed")
            print("  PASS: all fixture assertions passed")

        # Check overall summary
        overall_match = re.search(r"OVERALL:\s*(PASS|FAIL)", act_output)
        if overall_match:
            overall_status = overall_match.group(1)
            if overall_status == "PASS":
                write_result("  PASS: overall test status is PASS")
                print("  PASS: overall test status is PASS")
            else:
                write_result("  FAIL: overall test status is FAIL")
                print("  FAIL: overall test status is FAIL")
                all_fixtures_pass = False
        else:
            write_result("  WARN: could not find OVERALL status in output")
            print("  WARN: could not find OVERALL status in output")

        if all_fixtures_pass:
            write_result("ACT_RESULT: PASS")
            print("\nACT_RESULT: PASS")
        else:
            write_result("ACT_RESULT: FAIL")
            print("\nACT_RESULT: FAIL")

        write_result("=== END ACT PIPELINE TESTS ===\n")
        return all_fixtures_pass

    except subprocess.TimeoutExpired:
        write_result("  FAIL: act timed out after 180 seconds")
        print("  FAIL: act timed out after 180 seconds")
        write_result("ACT_RESULT: FAIL")
        write_result("=== END ACT PIPELINE TESTS ===\n")
        return False
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def extract_fixture_block(output, fixture_name):
    """Extract the output block for a specific fixture from act output."""
    pattern = rf"=== FIXTURE: {re.escape(fixture_name)} ===(.*?)=== END FIXTURE: {re.escape(fixture_name)} ==="
    match = re.search(pattern, output, re.DOTALL)
    if match:
        return match.group(1)
    return None


def verify_fixture_output(fixture_name, block, expected):
    """Verify fixture output matches expected values."""
    passed = True

    checks = [
        ("DELETE_COUNT", expected["delete_count"]),
        ("RETAIN_COUNT", expected["retain_count"]),
        ("SPACE_RECLAIMED", expected["space_reclaimed"]),
        ("SPACE_RETAINED", expected["space_retained"]),
    ]

    for field, expected_val in checks:
        match = re.search(rf"{field}:\s*(\d+)", block)
        if match:
            actual_val = int(match.group(1))
            if actual_val != expected_val:
                msg = f"  FAIL: {fixture_name}.{field}: got {actual_val}, expected {expected_val}"
                write_result(msg)
                print(msg)
                passed = False
            else:
                msg = f"  PASS: {fixture_name}.{field} = {expected_val}"
                write_result(msg)
                print(msg)
        else:
            msg = f"  FAIL: {fixture_name}.{field} not found in output"
            write_result(msg)
            print(msg)
            passed = False

    # Check dry_run
    dry_run_match = re.search(r"DRY_RUN:\s*(True|False)", block)
    if dry_run_match:
        actual_dry_run = dry_run_match.group(1) == "True"
        if actual_dry_run != expected["dry_run"]:
            msg = f"  FAIL: {fixture_name}.DRY_RUN: got {actual_dry_run}, expected {expected['dry_run']}"
            write_result(msg)
            print(msg)
            passed = False
        else:
            msg = f"  PASS: {fixture_name}.DRY_RUN = {expected['dry_run']}"
            write_result(msg)
            print(msg)

    # Check STATUS
    status_match = re.search(r"STATUS:\s*(PASS|FAIL)", block)
    if status_match:
        if status_match.group(1) != "PASS":
            msg = f"  FAIL: {fixture_name} STATUS is FAIL"
            write_result(msg)
            print(msg)
            passed = False
    else:
        msg = f"  FAIL: {fixture_name} STATUS not found"
        write_result(msg)
        print(msg)
        passed = False

    return passed


def main():
    # Clear result file
    with open(RESULT_FILE, "w") as f:
        f.write("Artifact Cleanup Script - Test Results\n")
        f.write("=" * 50 + "\n\n")

    all_pass = True

    # Workflow structure tests
    if not test_workflow_structure():
        all_pass = False

    # Actionlint validation
    if not test_actionlint():
        all_pass = False

    # Act pipeline tests
    if not run_act_tests():
        all_pass = False

    # Final summary
    write_result("\n=== FINAL RESULT ===")
    if all_pass:
        write_result("ALL TESTS PASSED")
        print("\n=== ALL TESTS PASSED ===")
    else:
        write_result("SOME TESTS FAILED")
        print("\n=== SOME TESTS FAILED ===")
    write_result("=== END FINAL RESULT ===")

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
