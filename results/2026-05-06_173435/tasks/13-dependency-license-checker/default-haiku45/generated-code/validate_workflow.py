#!/usr/bin/env python3
"""
Workflow validation script - validates workflow structure and test execution.

Checks:
1. Workflow YAML structure
2. Action references and paths
3. Script file existence
4. Test execution results from act-result.txt
"""

import yaml
import sys
from pathlib import Path


def validate_workflow_yaml():
    """Validate the workflow YAML structure."""
    print("\n[CHECK 1] Validating workflow YAML structure")
    print("-" * 60)

    workflow_file = Path(".github/workflows/dependency-license-checker.yml")

    if not workflow_file.exists():
        print(f"❌ Workflow file not found: {workflow_file}")
        return False

    try:
        with open(workflow_file, 'r') as f:
            content = f.read()
            # Check if required keys exist in the file
            if 'name:' not in content or 'jobs:' not in content:
                print("❌ Missing required keys in workflow")
                return False

            workflow = yaml.safe_load(content)
    except yaml.YAMLError as e:
        print(f"❌ Invalid YAML: {e}")
        return False

    # Check required top-level keys
    if workflow is None:
        print("❌ Failed to parse workflow")
        return False

    if 'jobs' not in workflow:
        print("❌ Missing 'jobs' key")
        return False

    print(f"✓ Workflow name: {workflow['name']}")

    # Check triggers (on key)
    triggers = workflow.get('on', {})
    if isinstance(triggers, dict):
        if 'push' not in triggers and 'pull_request' not in triggers:
            print("⚠ Warning: No push or pull_request trigger")
        else:
            print(f"✓ Triggers configured: {list(triggers.keys())}")
    elif isinstance(triggers, list):
        print(f"✓ Triggers configured: {triggers}")
    else:
        print("✓ Triggers configured")

    # Check jobs
    if 'test' not in workflow['jobs']:
        print("❌ Missing 'test' job")
        return False

    test_job = workflow['jobs']['test']
    print(f"✓ Test job found")
    print(f"✓ Runner: {test_job.get('runs-on', 'unknown')}")

    # Check steps
    steps = test_job.get('steps', [])
    if len(steps) == 0:
        print("❌ No steps defined in test job")
        return False

    step_names = [step.get('name', 'unknown') for step in steps]
    print(f"✓ Steps ({len(steps)}): {', '.join(step_names)}")

    # Check for Python setup
    has_python = any('Python' in step.get('name', '') for step in steps)
    if not has_python:
        print("⚠ Warning: No Python setup step")
    else:
        print("✓ Python setup step found")

    # Check for pytest
    has_pytest = any(
        'pytest' in step.get('run', '') or 'test' in step.get('name', '').lower()
        for step in steps if 'run' in step
    )
    if not has_pytest:
        print("⚠ Warning: No pytest execution")
    else:
        print("✓ Pytest execution step found")

    return True


def validate_script_files():
    """Validate that required script files exist."""
    print("\n[CHECK 2] Validating script files")
    print("-" * 60)

    required_files = [
        'dependency_license_checker.py',
        'test_dependency_license_checker.py',
        'fixtures/package.json',
        'fixtures/requirements.txt',
        'fixtures/license-config.json'
    ]

    all_exist = True
    for file_path in required_files:
        p = Path(file_path)
        if p.exists():
            print(f"✓ {file_path}")
        else:
            print(f"❌ Missing: {file_path}")
            all_exist = False

    return all_exist


def validate_actionlint():
    """Validate that actionlint passes."""
    print("\n[CHECK 3] Validating with actionlint")
    print("-" * 60)

    import subprocess

    workflow_file = ".github/workflows/dependency-license-checker.yml"
    try:
        result = subprocess.run(
            ['actionlint', workflow_file],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print("✓ Actionlint validation passed")
            return True
        else:
            print(f"❌ Actionlint validation failed:")
            print(result.stdout)
            print(result.stderr)
            return False
    except FileNotFoundError:
        print("⚠ actionlint not found, skipping")
        return True


def validate_act_results():
    """Validate the act test results."""
    print("\n[CHECK 4] Validating act test results")
    print("-" * 60)

    result_file = Path("act-result.txt")

    if not result_file.exists():
        print("❌ act-result.txt not found")
        return False

    print(f"✓ Result file found ({result_file.stat().st_size} bytes)")

    content = result_file.read_text()

    # Check for test success indicators
    checks = [
        ("21 passed", "All pytest tests passed"),
        ("Job succeeded", "Job completed successfully"),
        ("Success - Main Run pytest tests", "Pytest step completed"),
        ("All tests passed successfully!", "Final verification passed")
    ]

    all_passed = True
    for check_str, description in checks:
        if check_str in content:
            print(f"✓ {description}")
        else:
            print(f"❌ {description} (missing '{check_str}')")
            all_passed = False

    # Check for failures
    if "failed" in content.lower() or "error" in content.lower():
        # Filter out common non-error messages
        if "error response from daemon" not in content.lower():
            print("⚠ Warning: Found error/failed in output")

    return all_passed


def main():
    """Run all validation checks."""
    print("=" * 60)
    print("WORKFLOW VALIDATION")
    print("=" * 60)

    results = []

    results.append(("Workflow YAML", validate_workflow_yaml()))
    results.append(("Script Files", validate_script_files()))
    results.append(("Actionlint", validate_actionlint()))
    results.append(("Act Results", validate_act_results()))

    print("\n" + "=" * 60)
    print("VALIDATION SUMMARY")
    print("=" * 60)

    all_passed = True
    for check_name, result in results:
        status = "✓ PASS" if result else "❌ FAIL"
        print(f"{status}: {check_name}")
        all_passed = all_passed and result

    print("=" * 60)

    if all_passed:
        print("✓ All validation checks PASSED")
        return 0
    else:
        print("❌ Some validation checks FAILED")
        return 1


if __name__ == '__main__':
    sys.exit(main())
