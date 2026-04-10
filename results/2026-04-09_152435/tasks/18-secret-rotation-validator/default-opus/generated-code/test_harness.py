#!/usr/bin/env python3
"""
Test harness for Secret Rotation Validator.

Runs all tests through the GitHub Actions workflow via `act`.
Creates a temporary git repo for each test case with the project files
and fixture data, runs `act push --rm`, captures output, and asserts on
exact expected values.

Also validates workflow YAML structure and actionlint compliance.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import yaml

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")
WORKFLOW_PATH = os.path.join(
    SCRIPT_DIR, ".github", "workflows", "secret-rotation-validator.yml"
)

# Files to copy into each temp repo
PROJECT_FILES = [
    "secret_rotation_validator.py",
    "test_secret_rotation_validator.py",
    ".github/workflows/secret-rotation-validator.yml",
]

FIXTURE_DIRS = ["fixtures"]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def setup_temp_repo(fixture_overrides=None):
    """Create a temp git repo with project files and optional fixture overrides."""
    tmp_dir = tempfile.mkdtemp(prefix="srv-test-")

    # Copy project files
    for f in PROJECT_FILES:
        src = os.path.join(SCRIPT_DIR, f)
        dst = os.path.join(tmp_dir, f)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)

    # Copy fixture directories
    for d in FIXTURE_DIRS:
        src = os.path.join(SCRIPT_DIR, d)
        dst = os.path.join(tmp_dir, d)
        if os.path.exists(src):
            shutil.copytree(src, dst)

    # Copy .actrc if it exists
    actrc_src = os.path.join(SCRIPT_DIR, ".actrc")
    if os.path.exists(actrc_src):
        shutil.copy2(actrc_src, os.path.join(tmp_dir, ".actrc"))

    # Apply fixture overrides (write custom fixture files)
    if fixture_overrides:
        for rel_path, content in fixture_overrides.items():
            dst = os.path.join(tmp_dir, rel_path)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "w") as f:
                if isinstance(content, dict):
                    json.dump(content, f, indent=2)
                else:
                    f.write(content)

    # Initialize git repo (act requires it)
    subprocess.run(
        ["git", "init", "-b", "master"],
        cwd=tmp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"],
        cwd=tmp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=tmp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "add", "-A"],
        cwd=tmp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "init"],
        cwd=tmp_dir, capture_output=True, check=True,
    )

    return tmp_dir


def run_act(repo_dir, label="test"):
    """Run act push --rm in the given repo dir, return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    output = result.stdout + "\n" + result.stderr
    return result.returncode, output


def cleanup_temp_repo(repo_dir):
    """Remove the temporary repo."""
    shutil.rmtree(repo_dir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Workflow structure tests (no act needed)
# ---------------------------------------------------------------------------

def test_workflow_structure():
    """Parse YAML and verify expected structure."""
    print("=== WORKFLOW STRUCTURE TESTS ===")
    errors = []

    with open(WORKFLOW_PATH, "r") as f:
        wf = yaml.safe_load(f)

    # PyYAML parses the YAML key `on:` as boolean True, not string "on"
    triggers = wf.get(True, wf.get("on", {}))
    if "push" not in triggers:
        errors.append("Missing 'push' trigger")
    if "pull_request" not in triggers:
        errors.append("Missing 'pull_request' trigger")
    if "schedule" not in triggers:
        errors.append("Missing 'schedule' trigger")
    if "workflow_dispatch" not in triggers:
        errors.append("Missing 'workflow_dispatch' trigger")

    # Check jobs
    jobs = wf.get("jobs", {})
    if "validate-secrets" not in jobs:
        errors.append("Missing 'validate-secrets' job")

    job = jobs.get("validate-secrets", {})
    steps = job.get("steps", [])
    step_names = [s.get("name", "") for s in steps]

    if not any("checkout" in n.lower() for n in step_names):
        errors.append("Missing checkout step")

    # Verify script file references exist
    for step in steps:
        run_cmd = step.get("run", "")
        if "secret_rotation_validator.py" in run_cmd:
            script_path = os.path.join(SCRIPT_DIR, "secret_rotation_validator.py")
            if not os.path.exists(script_path):
                errors.append(
                    f"Workflow references secret_rotation_validator.py but file not found"
                )
            break
    else:
        errors.append("No step references secret_rotation_validator.py")

    # Verify test file reference
    for step in steps:
        run_cmd = step.get("run", "")
        if "test_secret_rotation_validator.py" in run_cmd:
            test_path = os.path.join(SCRIPT_DIR, "test_secret_rotation_validator.py")
            if not os.path.exists(test_path):
                errors.append(
                    f"Workflow references test file but file not found"
                )
            break

    if errors:
        for e in errors:
            print(f"  FAIL: {e}")
        return False
    else:
        print("  PASS: All structure checks passed")
        return True


def test_actionlint():
    """Verify actionlint passes."""
    print("=== ACTIONLINT VALIDATION ===")
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        print("  PASS: actionlint passed (exit code 0)")
        return True
    else:
        print(f"  FAIL: actionlint errors:\n{result.stdout}\n{result.stderr}")
        return False


# ---------------------------------------------------------------------------
# Act-based integration tests
# ---------------------------------------------------------------------------

def test_case_mixed_secrets(result_file):
    """Test case 1: Mixed secrets — expired, warning, ok.
    Uses default fixtures. Validates JSON/markdown output and unit tests.
    """
    print("=== TEST CASE 1: Mixed secrets (expired/warning/ok) ===")
    repo_dir = setup_temp_repo()
    try:
        exit_code, output = run_act(repo_dir, "mixed")

        # Write to result file
        result_file.write("=" * 70 + "\n")
        result_file.write("TEST CASE 1: Mixed secrets\n")
        result_file.write("=" * 70 + "\n")
        result_file.write(output)
        result_file.write("\n\n")

        errors = []

        # Assert act exited with code 0
        if exit_code != 0:
            errors.append(f"act exited with code {exit_code}, expected 0")

        # Assert job succeeded
        if "Job succeeded" not in output:
            errors.append("'Job succeeded' not found in output")

        # Assert unit tests passed
        if "passed" not in output:
            errors.append("Unit test 'passed' not found in output")

        # Assert exact JSON values from mixed_secrets.json with date 2026-04-10
        # Expected: DB_PASSWORD=expired(-40), API_KEY=warning(4), TLS_CERT=ok(356)
        if '"expired": 1' not in output:
            errors.append('Expected JSON "expired": 1 not found')
        if '"warning": 1' not in output:
            errors.append('Expected JSON "warning": 1 not found')
        if '"ok": 1' not in output:
            errors.append('Expected JSON "ok": 1 not found')
        if '"total": 3' not in output:
            errors.append('Expected JSON "total": 3 not found')

        # Check exact days_until_expiry values
        if '"days_until_expiry": -40' not in output:
            errors.append("Expected DB_PASSWORD days_until_expiry=-40 not found")
        if '"days_until_expiry": 4' not in output:
            errors.append("Expected API_KEY days_until_expiry=4 not found")
        if '"days_until_expiry": 356' not in output:
            errors.append("Expected TLS_CERT days_until_expiry=356 not found")

        # Assert markdown output contains expected values
        if "**Expired:** 1" not in output:
            errors.append("Markdown '**Expired:** 1' not found")
        if "| DB_PASSWORD | EXPIRED |" not in output:
            errors.append("Markdown DB_PASSWORD EXPIRED row not found")
        if "| API_KEY | WARNING |" not in output:
            errors.append("Markdown API_KEY WARNING row not found")
        if "| TLS_CERT | OK |" not in output:
            errors.append("Markdown TLS_CERT OK row not found")

        if errors:
            for e in errors:
                print(f"  FAIL: {e}")
            return False
        else:
            print("  PASS: All assertions passed")
            return True
    finally:
        cleanup_temp_repo(repo_dir)


def test_case_all_expired(result_file):
    """Test case 2: All secrets expired with custom warning window.
    Uses all_expired.json fixture. Validates exact counts and values.
    """
    print("=== TEST CASE 2: All expired (custom warning window=7) ===")
    repo_dir = setup_temp_repo()
    try:
        exit_code, output = run_act(repo_dir, "all_expired")

        result_file.write("=" * 70 + "\n")
        result_file.write("TEST CASE 2: All expired\n")
        result_file.write("=" * 70 + "\n")
        result_file.write(output)
        result_file.write("\n\n")

        errors = []

        if exit_code != 0:
            errors.append(f"act exited with code {exit_code}, expected 0")

        if "Job succeeded" not in output:
            errors.append("'Job succeeded' not found in output")

        # all_expired.json: SECRET_A (days_until=-434), SECRET_B (days_until=-253)
        if '"days_until_expiry": -434' not in output:
            errors.append("Expected SECRET_A days_until_expiry=-434 not found")
        if '"days_until_expiry": -253' not in output:
            errors.append("Expected SECRET_B days_until_expiry=-253 not found")

        if errors:
            for e in errors:
                print(f"  FAIL: {e}")
            return False
        else:
            print("  PASS: All assertions passed")
            return True
    finally:
        cleanup_temp_repo(repo_dir)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("Secret Rotation Validator — Test Harness")
    print("=" * 50)

    all_passed = True

    # Workflow structure tests (no act)
    if not test_workflow_structure():
        all_passed = False
    if not test_actionlint():
        all_passed = False

    # Act-based tests (write output to act-result.txt)
    with open(RESULT_FILE, "w") as rf:
        if not test_case_mixed_secrets(rf):
            all_passed = False
        if not test_case_all_expired(rf):
            all_passed = False

    print()
    if all_passed:
        print("ALL TESTS PASSED")
    else:
        print("SOME TESTS FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
