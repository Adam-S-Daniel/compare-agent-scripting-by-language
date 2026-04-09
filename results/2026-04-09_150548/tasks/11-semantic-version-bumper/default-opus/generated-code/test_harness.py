#!/usr/bin/env python3
"""
Test Harness for Semantic Version Bumper

Runs all tests through the GitHub Actions workflow via `act`.
Each test case:
  1. Sets up a temp git repo with project files and fixture data
  2. Runs `act push --rm`
  3. Captures output to act-result.txt
  4. Asserts exit code 0 and verifies exact expected values

Also includes workflow structure tests (YAML parsing, actionlint, file refs).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import yaml


# --- Configuration ---

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")
WORKFLOW_PATH = os.path.join(SCRIPT_DIR, ".github", "workflows", "semantic-version-bumper.yml")

# Test cases: each defines a starting version, fixture file, and expected results
TEST_CASES = [
    {
        "name": "patch_bump_from_fix_commits",
        "version": "1.0.0",
        "fixture": "fix_commits.txt",
        "expected_version": "1.0.1",
        "expected_bump": "patch",
        "expected_changelog_sections": ["Bug Fixes"],
    },
    {
        "name": "minor_bump_from_feat_commits",
        "version": "1.1.0",
        "fixture": "feat_commits.txt",
        "expected_version": "1.2.0",
        "expected_bump": "minor",
        "expected_changelog_sections": ["Features", "Bug Fixes"],
    },
    {
        "name": "major_bump_from_breaking_bang",
        "version": "2.3.4",
        "fixture": "breaking_commits.txt",
        "expected_version": "3.0.0",
        "expected_bump": "major",
        "expected_changelog_sections": ["Breaking Changes", "Features", "Bug Fixes"],
    },
]


def setup_temp_repo(test_case):
    """Create a temporary git repo with project files and fixture data."""
    tmpdir = tempfile.mkdtemp(prefix="svb_test_")

    # Copy project files
    shutil.copy(os.path.join(SCRIPT_DIR, "version_bumper.py"), tmpdir)

    # Copy fixture file
    fixture_src = os.path.join(SCRIPT_DIR, "fixtures", test_case["fixture"])
    fixtures_dir = os.path.join(tmpdir, "fixtures")
    os.makedirs(fixtures_dir)
    shutil.copy(fixture_src, fixtures_dir)

    # Create VERSION file with starting version
    with open(os.path.join(tmpdir, "VERSION"), "w") as f:
        f.write(test_case["version"] + "\n")

    # Copy workflow
    wf_dir = os.path.join(tmpdir, ".github", "workflows")
    os.makedirs(wf_dir)
    shutil.copy(WORKFLOW_PATH, wf_dir)

    # Copy .actrc if it exists
    actrc_src = os.path.join(SCRIPT_DIR, ".actrc")
    if os.path.exists(actrc_src):
        shutil.copy(actrc_src, tmpdir)

    # Initialize git repo with a conventional commit
    subprocess.run(["git", "init", "-b", "main"], cwd=tmpdir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmpdir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmpdir, capture_output=True, check=True)
    subprocess.run(["git", "add", "."], cwd=tmpdir, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-m", "feat: initial commit"], cwd=tmpdir, capture_output=True, check=True)

    return tmpdir


def run_act(tmpdir, test_case):
    """Run act push in the temp repo, passing the fixture file as env."""
    # We pass the fixture file path via the COMMIT_FIXTURE env var
    fixture_path = f"fixtures/{test_case['fixture']}"

    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false", "--env", f"COMMIT_FIXTURE={fixture_path}"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=180,
    )
    return result


def run_workflow_structure_tests():
    """Test the workflow YAML structure, file references, and actionlint."""
    results = []

    # Test 1: Parse YAML and check structure
    test_name = "workflow_yaml_structure"
    try:
        with open(WORKFLOW_PATH, "r") as f:
            wf = yaml.safe_load(f)

        errors = []
        # Check triggers (PyYAML parses 'on' as True boolean key)
        trigger_key = "on" if "on" in wf else True if True in wf else None
        if trigger_key is None:
            errors.append("Missing 'on' trigger")
        else:
            triggers = wf[trigger_key]
            if "push" not in triggers:
                errors.append("Missing 'push' trigger")
            if "workflow_dispatch" not in triggers:
                errors.append("Missing 'workflow_dispatch' trigger")

        # Check jobs
        if "jobs" not in wf:
            errors.append("Missing 'jobs'")
        else:
            jobs = wf["jobs"]
            if "version-bump" not in jobs:
                errors.append("Missing 'version-bump' job")
            else:
                job = jobs["version-bump"]
                if "steps" not in job:
                    errors.append("Missing 'steps' in version-bump job")
                else:
                    step_names = [s.get("name", "") for s in job["steps"]]
                    if not any("checkout" in n.lower() for n in step_names):
                        errors.append("Missing checkout step")
                    if not any("version bumper" in n.lower() or "bump" in n.lower() for n in step_names):
                        errors.append("Missing version bumper step")

        # Check permissions
        if "permissions" not in wf:
            errors.append("Missing 'permissions'")

        if errors:
            results.append((test_name, False, "; ".join(errors)))
        else:
            results.append((test_name, True, "YAML structure valid: triggers, jobs, steps, permissions all present"))
    except Exception as e:
        results.append((test_name, False, str(e)))

    # Test 2: Verify script file references exist
    test_name = "workflow_file_references"
    try:
        with open(WORKFLOW_PATH, "r") as f:
            content = f.read()

        errors = []
        if "version_bumper.py" in content:
            if not os.path.exists(os.path.join(SCRIPT_DIR, "version_bumper.py")):
                errors.append("version_bumper.py referenced but not found")
        else:
            errors.append("version_bumper.py not referenced in workflow")

        if errors:
            results.append((test_name, False, "; ".join(errors)))
        else:
            results.append((test_name, True, "All referenced files exist"))
    except Exception as e:
        results.append((test_name, False, str(e)))

    # Test 3: actionlint passes
    test_name = "actionlint_passes"
    try:
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            results.append((test_name, True, "actionlint passed with exit code 0"))
        else:
            results.append((test_name, False, f"actionlint failed: {result.stdout}{result.stderr}"))
    except Exception as e:
        results.append((test_name, False, str(e)))

    return results


def assert_act_output(output, test_case):
    """Parse act output and assert exact expected values."""
    errors = []

    expected_ver = test_case["expected_version"]
    expected_bump = test_case["expected_bump"]

    # Check that the new version appears in output
    if f"New version: {expected_ver}" not in output:
        errors.append(f"Expected 'New version: {expected_ver}' in output")

    # Check bump type
    if f"Bump type: {expected_bump}" not in output:
        errors.append(f"Expected 'Bump type: {expected_bump}' in output")

    # Check the VERSION file was updated (shown in "Show results" step)
    if f"=== Updated VERSION ===" not in output:
        errors.append("Missing '=== Updated VERSION ===' section")

    # Check current version was read correctly
    if f"Current version: {test_case['version']}" not in output:
        errors.append(f"Expected 'Current version: {test_case['version']}' in output")

    # Check NEW_VERSION output
    if f"NEW_VERSION={expected_ver}" not in output:
        errors.append(f"Expected 'NEW_VERSION={expected_ver}' in output")

    # Check changelog sections
    for section in test_case["expected_changelog_sections"]:
        if f"### {section}" not in output:
            errors.append(f"Expected changelog section '### {section}' in output")

    # Check job succeeded
    if "Job succeeded" not in output:
        errors.append("Expected 'Job succeeded' in output")

    return errors


def main():
    """Run all tests and produce act-result.txt."""
    all_passed = True
    act_output_parts = []

    # --- Workflow Structure Tests ---
    print("=" * 60)
    print("WORKFLOW STRUCTURE TESTS")
    print("=" * 60)

    struct_results = run_workflow_structure_tests()
    act_output_parts.append("=" * 60)
    act_output_parts.append("WORKFLOW STRUCTURE TESTS")
    act_output_parts.append("=" * 60)

    for name, passed, detail in struct_results:
        status = "PASS" if passed else "FAIL"
        line = f"[{status}] {name}: {detail}"
        print(line)
        act_output_parts.append(line)
        if not passed:
            all_passed = False

    act_output_parts.append("")

    # --- Act Integration Tests ---
    print()
    print("=" * 60)
    print("ACT INTEGRATION TESTS")
    print("=" * 60)

    act_output_parts.append("=" * 60)
    act_output_parts.append("ACT INTEGRATION TESTS")
    act_output_parts.append("=" * 60)

    for i, tc in enumerate(TEST_CASES):
        print(f"\n--- Test Case {i+1}/{len(TEST_CASES)}: {tc['name']} ---")
        act_output_parts.append(f"\n{'=' * 40}")
        act_output_parts.append(f"TEST CASE: {tc['name']}")
        act_output_parts.append(f"  Start version: {tc['version']}")
        act_output_parts.append(f"  Fixture: {tc['fixture']}")
        act_output_parts.append(f"  Expected version: {tc['expected_version']}")
        act_output_parts.append(f"  Expected bump: {tc['expected_bump']}")
        act_output_parts.append(f"{'=' * 40}")

        tmpdir = None
        try:
            tmpdir = setup_temp_repo(tc)
            print(f"  Temp repo: {tmpdir}")

            result = run_act(tmpdir, tc)
            combined_output = result.stdout + "\n" + result.stderr

            act_output_parts.append("\n--- ACT OUTPUT ---")
            act_output_parts.append(combined_output)
            act_output_parts.append("--- END ACT OUTPUT ---\n")

            # Assert exit code 0
            if result.returncode != 0:
                msg = f"[FAIL] {tc['name']}: act exited with code {result.returncode}"
                print(msg)
                act_output_parts.append(msg)
                all_passed = False
                continue

            # Assert on exact expected values
            assertion_errors = assert_act_output(combined_output, tc)
            if assertion_errors:
                for err in assertion_errors:
                    msg = f"[FAIL] {tc['name']}: {err}"
                    print(msg)
                    act_output_parts.append(msg)
                all_passed = False
            else:
                msg = f"[PASS] {tc['name']}: All assertions passed (version={tc['expected_version']}, bump={tc['expected_bump']})"
                print(msg)
                act_output_parts.append(msg)

        except subprocess.TimeoutExpired:
            msg = f"[FAIL] {tc['name']}: act timed out after 180s"
            print(msg)
            act_output_parts.append(msg)
            all_passed = False
        except Exception as e:
            msg = f"[FAIL] {tc['name']}: {e}"
            print(msg)
            act_output_parts.append(msg)
            all_passed = False
        finally:
            if tmpdir and os.path.exists(tmpdir):
                shutil.rmtree(tmpdir, ignore_errors=True)

    # --- Write act-result.txt ---
    act_output_parts.append("\n" + "=" * 60)
    if all_passed:
        act_output_parts.append("ALL TESTS PASSED")
    else:
        act_output_parts.append("SOME TESTS FAILED")
    act_output_parts.append("=" * 60)

    with open(RESULT_FILE, "w") as f:
        f.write("\n".join(act_output_parts))

    print(f"\nResults saved to {RESULT_FILE}")

    if all_passed:
        print("\nALL TESTS PASSED")
        return 0
    else:
        print("\nSOME TESTS FAILED")
        return 1


if __name__ == "__main__":
    sys.exit(main())
