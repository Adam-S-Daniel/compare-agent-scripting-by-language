"""
Workflow structure tests - validate YAML structure, file references, and actionlint.
These tests verify the workflow is well-formed before running through act.

TDD: Written FIRST as failing tests, then implementation follows.
"""
import subprocess
import yaml
import os
import sys

WORKFLOW_PATH = ".github/workflows/semantic-version-bumper.yml"
SCRIPT_PATH = "version_bumper.py"

def test_workflow_file_exists():
    assert os.path.isfile(WORKFLOW_PATH), f"Workflow file not found at {WORKFLOW_PATH}"

def test_script_file_exists():
    assert os.path.isfile(SCRIPT_PATH), f"Script file not found at {SCRIPT_PATH}"

def test_workflow_valid_yaml():
    with open(WORKFLOW_PATH) as f:
        data = yaml.safe_load(f)
    assert data is not None, "Workflow YAML is empty"
    assert isinstance(data, dict), "Workflow YAML root is not a mapping"

def test_workflow_has_triggers():
    with open(WORKFLOW_PATH) as f:
        data = yaml.safe_load(f)
    assert "on" in data or True in data, "Workflow missing 'on' trigger section"
    triggers = data.get("on") or data.get(True)
    assert "push" in triggers or "workflow_dispatch" in triggers, \
        "Workflow should have push or workflow_dispatch trigger"

def test_workflow_has_jobs():
    with open(WORKFLOW_PATH) as f:
        data = yaml.safe_load(f)
    assert "jobs" in data, "Workflow missing 'jobs' section"
    assert len(data["jobs"]) > 0, "Workflow has no jobs defined"

def test_workflow_references_script():
    with open(WORKFLOW_PATH) as f:
        content = f.read()
    assert SCRIPT_PATH in content, \
        f"Workflow does not reference {SCRIPT_PATH}"

def test_workflow_has_checkout_step():
    with open(WORKFLOW_PATH) as f:
        data = yaml.safe_load(f)
    jobs = data["jobs"]
    found_checkout = False
    for job_name, job in jobs.items():
        for step in job.get("steps", []):
            if "actions/checkout" in step.get("uses", ""):
                found_checkout = True
                break
    assert found_checkout, "Workflow must include actions/checkout step"

def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True, text=True
    )
    assert result.returncode == 0, \
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"

def run_all():
    tests = [
        test_workflow_file_exists,
        test_script_file_exists,
        test_workflow_valid_yaml,
        test_workflow_has_triggers,
        test_workflow_has_jobs,
        test_workflow_references_script,
        test_workflow_has_checkout_step,
        test_actionlint_passes,
    ]
    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            print(f"  PASS: {test.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"  FAIL: {test.__name__} - {e}")
            failed += 1
        except Exception as e:
            print(f"  ERROR: {test.__name__} - {type(e).__name__}: {e}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    return failed == 0

if __name__ == "__main__":
    print("=== Workflow Structure Tests ===")
    success = run_all()
    sys.exit(0 if success else 1)
