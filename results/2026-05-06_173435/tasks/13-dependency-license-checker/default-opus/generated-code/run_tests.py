"""
Test harness that runs all tests through GitHub Actions via act.

This script:
1. Sets up a temp git repo with project files and test fixtures
2. Runs act push --rm and captures output
3. Asserts on exit codes and expected output values
4. Validates workflow YAML structure
5. Saves all output to act-result.txt
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Files to copy into the test repo
PROJECT_FILES = [
    "license_checker.py",
    "test_license_checker.py",
    "license-config.json",
    ".actrc",
]
PROJECT_DIRS = [
    "test_fixtures",
    ".github",
]


def setup_test_repo(tmp_dir, extra_files=None):
    """Create a git repo with project files for act to run against."""
    for f in PROJECT_FILES:
        src = os.path.join(SCRIPT_DIR, f)
        dst = os.path.join(tmp_dir, f)
        shutil.copy2(src, dst)

    for d in PROJECT_DIRS:
        src = os.path.join(SCRIPT_DIR, d)
        dst = os.path.join(tmp_dir, d)
        if os.path.exists(src):
            shutil.copytree(src, dst)

    if extra_files:
        for path, content in extra_files.items():
            full_path = os.path.join(tmp_dir, path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w") as f:
                f.write(content)

    subprocess.run(["git", "init"], cwd=tmp_dir, capture_output=True)
    subprocess.run(["git", "add", "."], cwd=tmp_dir, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "initial"],
        cwd=tmp_dir,
        capture_output=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@test.com",
             "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@test.com"},
    )


def run_act(tmp_dir):
    """Run act push --rm in the given directory and return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + "\n" + result.stderr
    return result.returncode, combined


def test_workflow_structure():
    """Parse the YAML and verify expected structure."""
    print("=" * 60)
    print("TEST: Workflow Structure Validation")
    print("=" * 60)

    workflow_path = os.path.join(SCRIPT_DIR, ".github", "workflows", "dependency-license-checker.yml")
    assert os.path.exists(workflow_path), f"Workflow file not found: {workflow_path}"

    with open(workflow_path) as f:
        wf = yaml.safe_load(f)

    # Check triggers - PyYAML parses 'on' as True (boolean)
    triggers = wf.get("on") or wf.get(True)
    assert triggers is not None, "Missing triggers section"
    assert "push" in triggers, "Missing push trigger"
    assert "workflow_dispatch" in triggers, "Missing workflow_dispatch trigger"
    print("  PASS: Triggers include push and workflow_dispatch")

    # Check jobs
    assert "license-check" in wf["jobs"], "Missing license-check job"
    job = wf["jobs"]["license-check"]
    assert job["runs-on"] == "ubuntu-latest", "Job must run on ubuntu-latest"
    print("  PASS: license-check job exists on ubuntu-latest")

    # Check steps reference correct files
    steps = job["steps"]
    step_texts = [str(s.get("run", "")) for s in steps]
    all_steps_text = " ".join(step_texts)
    assert "license_checker.py" in all_steps_text, "Workflow must reference license_checker.py"
    assert "test_license_checker.py" in all_steps_text, "Workflow must reference test_license_checker.py"
    print("  PASS: Workflow references license_checker.py and test_license_checker.py")

    # Verify script files exist
    assert os.path.exists(os.path.join(SCRIPT_DIR, "license_checker.py"))
    assert os.path.exists(os.path.join(SCRIPT_DIR, "test_license_checker.py"))
    print("  PASS: Referenced script files exist")

    print("  ALL STRUCTURE TESTS PASSED")
    return True


def test_actionlint():
    """Verify actionlint passes with exit code 0."""
    print("\n" + "=" * 60)
    print("TEST: actionlint Validation")
    print("=" * 60)

    workflow_path = os.path.join(SCRIPT_DIR, ".github", "workflows", "dependency-license-checker.yml")
    result = subprocess.run(
        ["actionlint", workflow_path],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    print("  PASS: actionlint exit code 0")
    print("  ALL ACTIONLINT TESTS PASSED")
    return True


def test_act_execution():
    """Run act and verify outputs match expected values."""
    print("\n" + "=" * 60)
    print("TEST: Act Execution - Full Pipeline")
    print("=" * 60)

    with tempfile.TemporaryDirectory() as tmp_dir:
        setup_test_repo(tmp_dir)
        print(f"  Test repo created at: {tmp_dir}")
        print("  Running act push --rm ...")

        exit_code, output = run_act(tmp_dir)

        # Write output to result file
        with open(ACT_RESULT_FILE, "w") as f:
            f.write("=" * 60 + "\n")
            f.write("ACT EXECUTION OUTPUT - Full Pipeline Test\n")
            f.write("=" * 60 + "\n\n")
            f.write(output)

        print(f"  Act exit code: {exit_code}")

        # Assert act succeeded
        assert exit_code == 0, f"Act failed with exit code {exit_code}.\nOutput:\n{output[-2000:]}"
        print("  PASS: act exited with code 0")

        # Assert job succeeded
        assert "Job succeeded" in output, f"Job did not succeed.\nOutput:\n{output[-2000:]}"
        print("  PASS: Job succeeded message found")

        # Assert pytest ran and all 9 tests passed
        assert "9 passed" in output, f"Expected 9 tests to pass.\nOutput:\n{output[-2000:]}"
        print("  PASS: All 9 pytest tests passed in CI")

        # Assert specific test names appeared
        assert "test_parse_package_json" in output, "Missing test_parse_package_json in output"
        assert "test_parse_requirements_txt" in output, "Missing test_parse_requirements_txt in output"
        assert "test_check_compliance" in output, "Missing test_check_compliance in output"
        assert "test_generate_report" in output, "Missing test_generate_report in output"
        assert "test_format_report" in output, "Missing test_format_report in output"
        print("  PASS: All expected test names found in output")

        # Assert license checker ran and produced expected output for package.json
        assert "DEPENDENCY LICENSE COMPLIANCE REPORT" in output, "Missing report header"
        assert "APPROVED: express@^4.18.0 (MIT)" in output, "Missing express approval"
        assert "APPROVED: lodash@~4.17.21 (MIT)" in output, "Missing lodash approval"
        assert "DENIED: redis@^4.0.0 (GPL-3.0)" in output, "Missing redis denial"
        assert "APPROVED: jest@^29.0.0 (MIT)" in output, "Missing jest approval"
        print("  PASS: Package.json license report matches expected values")

        # Assert requirements.txt output
        assert "APPROVED: requests@==2.31.0 (Apache-2.0)" in output, "Missing requests approval"
        assert "APPROVED: flask@>=2.0.0 (BSD-3-Clause)" in output, "Missing flask approval"
        assert "APPROVED: numpy@" in output and "BSD-3-Clause" in output, "Missing numpy approval"
        assert "APPROVED: django@==4.2.0 (BSD-3-Clause)" in output, "Missing django approval"
        print("  PASS: Requirements.txt license report matches expected values")

        # Assert summary counts
        assert "3 approved, 1 denied, 0 unknown" in output, "Missing package.json summary (3 approved, 1 denied)"
        assert "4 approved, 0 denied, 0 unknown" in output, "Missing requirements.txt summary (4 approved)"
        print("  PASS: Summary counts match expected values")

        # Assert denied license warning
        assert "ERROR: Denied licenses found!" in output, "Missing denied license error"
        print("  PASS: Denied license error message present")

        print("  ALL ACT EXECUTION TESTS PASSED")
    return True


def main():
    results = []
    all_passed = True

    # Workflow structure tests
    try:
        test_workflow_structure()
        results.append(("Workflow Structure", "PASSED"))
    except AssertionError as e:
        results.append(("Workflow Structure", f"FAILED: {e}"))
        all_passed = False

    # Actionlint tests
    try:
        test_actionlint()
        results.append(("Actionlint", "PASSED"))
    except AssertionError as e:
        results.append(("Actionlint", f"FAILED: {e}"))
        all_passed = False

    # Act execution tests
    try:
        test_act_execution()
        results.append(("Act Execution", "PASSED"))
    except (AssertionError, subprocess.TimeoutExpired) as e:
        results.append(("Act Execution", f"FAILED: {e}"))
        all_passed = False

    # Print summary
    print("\n" + "=" * 60)
    print("FINAL SUMMARY")
    print("=" * 60)
    for name, status in results:
        print(f"  {name}: {status}")

    if all_passed:
        print("\nALL TESTS PASSED")
    else:
        print("\nSOME TESTS FAILED")

    # Ensure act-result.txt exists
    if not os.path.exists(ACT_RESULT_FILE):
        with open(ACT_RESULT_FILE, "w") as f:
            f.write("No act output captured - tests may have failed before execution.\n")
            for name, status in results:
                f.write(f"{name}: {status}\n")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
