#!/usr/bin/env python3
"""Test harness for the Environment Matrix Generator.

Validates workflow structure, runs actionlint, executes the workflow through act,
and verifies exact expected values in the output.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(WORK_DIR, ".github", "workflows", "environment-matrix-generator.yml")
ACT_RESULT_FILE = os.path.join(WORK_DIR, "act-result.txt")

EXPECTED_TESTS = {
    "test_basic": {
        "total_combinations": 4,
        "fail-fast": False,
        "has_max_parallel": False,
    },
    "test_include": {
        "total_combinations": 5,
    },
    "test_exclude": {
        "total_combinations": 3,
    },
    "test_combined": {
        "total_combinations": 18,
        "fail-fast": True,
        "has_max_parallel": True,
        "max-parallel": 4,
    },
    "test_too_large": {
        "is_error": True,
        "error_contains": ["15", "5"],
    },
    "test_feature_flags": {
        "total_combinations": 6,
        "fail-fast": False,
    },
    "test_invalid_config": {
        "is_error": True,
        "error_contains": ["matrix"],
    },
    "test_include_extra_keys": {
        "total_combinations": 4,
    },
}


def test_workflow_structure():
    """Parse the workflow YAML and validate its structure."""
    print("--- Workflow Structure Tests ---")

    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    # PyYAML parses the bare key `on` as boolean True
    assert True in wf or "on" in wf, "Workflow must have 'on' trigger configuration"
    triggers = wf.get(True) or wf.get("on")
    assert "push" in triggers or triggers.get("push") is not None, "Workflow must trigger on push"
    print("  PASS: Workflow has push trigger")

    assert "jobs" in wf, "Workflow must have jobs"
    jobs = wf["jobs"]
    assert len(jobs) >= 1, "Workflow must have at least one job"
    print(f"  PASS: Workflow has {len(jobs)} job(s)")

    job = list(jobs.values())[0]
    assert "runs-on" in job, "Job must specify runs-on"
    assert "steps" in job, "Job must have steps"
    print(f"  PASS: Job has {len(job['steps'])} step(s)")

    has_checkout = any(
        step.get("uses", "").startswith("actions/checkout")
        for step in job["steps"]
    )
    assert has_checkout, "Workflow must use actions/checkout"
    print("  PASS: Workflow uses actions/checkout")

    has_run_step = any("run" in step for step in job["steps"])
    assert has_run_step, "Workflow must have a run step"
    print("  PASS: Workflow has run step(s)")


def test_file_references():
    """Verify that files referenced in the workflow exist."""
    print("\n--- File Reference Tests ---")

    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    job = list(wf["jobs"].values())[0]
    for step in job["steps"]:
        if "run" in step:
            run_cmd = step["run"]
            for token in run_cmd.split():
                if token.endswith(".py"):
                    filepath = os.path.join(WORK_DIR, token)
                    assert os.path.exists(filepath), f"Referenced file not found: {token}"
                    print(f"  PASS: Referenced file exists: {token}")

    assert os.path.exists(os.path.join(WORK_DIR, "matrix_generator.py")), \
        "matrix_generator.py must exist"
    print("  PASS: matrix_generator.py exists")

    assert os.path.exists(os.path.join(WORK_DIR, "run_workflow_tests.py")), \
        "run_workflow_tests.py must exist"
    print("  PASS: run_workflow_tests.py exists")

    assert os.path.isdir(os.path.join(WORK_DIR, "fixtures")), \
        "fixtures/ directory must exist"
    print("  PASS: fixtures/ directory exists")


def test_actionlint():
    """Verify actionlint passes on the workflow file."""
    print("\n--- actionlint Validation ---")
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    print("  PASS: actionlint passed with exit code 0")


def test_act_execution():
    """Run the workflow through act and validate output against expected values."""
    print("\n--- Act Execution Test ---")

    tmpdir = tempfile.mkdtemp(prefix="matrix-gen-test-")
    try:
        for item in os.listdir(WORK_DIR):
            if item.startswith(".") and item != ".github" and item != ".actrc":
                continue
            if item == "__pycache__" or item == "act-result.txt":
                continue
            src = os.path.join(WORK_DIR, item)
            dst = os.path.join(tmpdir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        actrc_src = os.path.join(WORK_DIR, ".actrc")
        if os.path.exists(actrc_src):
            shutil.copy2(actrc_src, os.path.join(tmpdir, ".actrc"))

        subprocess.run(
            ["git", "init"],
            cwd=tmpdir, capture_output=True, check=True
        )
        subprocess.run(
            ["git", "add", "-A"],
            cwd=tmpdir, capture_output=True, check=True
        )
        subprocess.run(
            ["git", "-c", "user.name=test", "-c", "user.email=test@test.com",
             "commit", "-m", "test"],
            cwd=tmpdir, capture_output=True, check=True
        )

        print("  Running act push --rm --pull=false ...")
        result = subprocess.run(
            ["act", "push", "--rm", "--pull=false"],
            cwd=tmpdir, capture_output=True, text=True,
            timeout=300
        )

        output = result.stdout + "\n" + result.stderr

        with open(ACT_RESULT_FILE, "w") as f:
            f.write("=== ACT RUN: environment-matrix-generator ===\n")
            f.write(f"Exit code: {result.returncode}\n")
            f.write(f"STDOUT:\n{result.stdout}\n")
            f.write(f"STDERR:\n{result.stderr}\n")
            f.write("=== END ACT RUN ===\n")

        print(f"  Act exit code: {result.returncode}")

        assert result.returncode == 0, \
            f"act push failed with code {result.returncode}:\n{output[-2000:]}"
        print("  PASS: act push exited with code 0")

        assert "Job succeeded" in output, \
            "Expected 'Job succeeded' in act output"
        print("  PASS: Job succeeded found in output")

        validate_test_results(output)

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def validate_test_results(output: str):
    """Parse act output and verify exact expected values for each test case."""
    print("\n--- Test Result Validation ---")

    for test_name, expected in EXPECTED_TESTS.items():
        pattern = rf"=== TEST: {test_name} ===(.*?)=== END TEST: {test_name} ==="
        match = re.search(pattern, output, re.DOTALL)
        assert match, f"Test block for {test_name} not found in act output"
        block = match.group(1)

        assert f"PASS: {test_name}" in block, \
            f"Expected PASS for {test_name}, got: {block.strip()}"

        if expected.get("is_error"):
            for needle in expected.get("error_contains", []):
                assert needle in block, \
                    f"Expected '{needle}' in error output for {test_name}"
            print(f"  PASS: {test_name} - error case validated")
            continue

        output_match = re.search(r"OUTPUT: (.+)", block)
        assert output_match, f"No OUTPUT line for {test_name}"
        result = json.loads(output_match.group(1))

        if "total_combinations" in expected:
            actual = result["total_combinations"]
            exp = expected["total_combinations"]
            assert actual == exp, \
                f"{test_name}: total_combinations={actual}, expected {exp}"

        if "fail-fast" in expected:
            actual = result["fail-fast"]
            exp = expected["fail-fast"]
            assert actual == exp, \
                f"{test_name}: fail-fast={actual}, expected {exp}"

        if expected.get("has_max_parallel"):
            assert "max-parallel" in result, \
                f"{test_name}: expected max-parallel in output"
            if "max-parallel" in expected:
                actual = result["max-parallel"]
                exp = expected["max-parallel"]
                assert actual == exp, \
                    f"{test_name}: max-parallel={actual}, expected {exp}"

        if expected.get("has_max_parallel") is False:
            assert "max-parallel" not in result, \
                f"{test_name}: unexpected max-parallel in output"

        print(f"  PASS: {test_name} - exact values verified")

    all_pass = re.search(r"RESULTS: (\d+) passed, (\d+) failed", output)
    assert all_pass, "Summary line not found in output"
    passed = int(all_pass.group(1))
    failed = int(all_pass.group(2))
    assert failed == 0, f"Expected 0 failures, got {failed}"
    assert passed == len(EXPECTED_TESTS), \
        f"Expected {len(EXPECTED_TESTS)} passes, got {passed}"
    print(f"  PASS: Summary shows {passed} passed, 0 failed")

    assert "ALL TESTS PASSED" in output, "Expected 'ALL TESTS PASSED' in output"
    print("  PASS: ALL TESTS PASSED found in output")


def main():
    print("=" * 60)
    print("Environment Matrix Generator - Test Harness")
    print("=" * 60)

    all_passed = True
    errors = []

    for test_fn in [test_workflow_structure, test_file_references,
                    test_actionlint, test_act_execution]:
        try:
            test_fn()
        except AssertionError as e:
            print(f"\n  FAIL: {test_fn.__name__} - {e}")
            all_passed = False
            errors.append(f"{test_fn.__name__}: {e}")
        except Exception as e:
            print(f"\n  ERROR: {test_fn.__name__} - {type(e).__name__}: {e}")
            all_passed = False
            errors.append(f"{test_fn.__name__}: {e}")

    print("\n" + "=" * 60)
    if all_passed:
        print("ALL HARNESS TESTS PASSED")
    else:
        print("HARNESS FAILURES:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    assert os.path.exists(ACT_RESULT_FILE), "act-result.txt was not created"
    print(f"act-result.txt saved to: {ACT_RESULT_FILE}")


if __name__ == "__main__":
    main()
