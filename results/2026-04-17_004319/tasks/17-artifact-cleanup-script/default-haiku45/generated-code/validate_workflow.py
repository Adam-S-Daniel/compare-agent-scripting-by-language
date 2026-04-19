#!/usr/bin/env python3
"""
Validate GitHub Actions workflow structure and content.
"""
import yaml
import os
import sys
import json


def validate_workflow():
    """Validate the workflow file."""
    workflow_path = '.github/workflows/artifact-cleanup-script.yml'

    # Check file exists
    if not os.path.exists(workflow_path):
        print(f"❌ Workflow file not found: {workflow_path}")
        return False

    # Parse YAML
    with open(workflow_path) as f:
        workflow = yaml.safe_load(f)

    checks = []

    # Check workflow name
    if workflow.get('name') == 'Artifact Cleanup Script Tests':
        checks.append(('✓', 'Workflow name correct'))
    else:
        checks.append(('❌', f"Workflow name is '{workflow.get('name')}'"))

    # Check triggers (check raw content if YAML parsing issues)
    required_triggers = ['push', 'pull_request', 'workflow_dispatch', 'schedule']
    on_config = workflow.get('on', {})

    # Fallback to checking raw file content if YAML parsing didn't work
    if on_config is None or not on_config:
        with open(workflow_path) as f:
            raw_content = f.read()
        for trigger in required_triggers:
            if f"  {trigger}:" in raw_content:
                checks.append(('✓', f"Trigger '{trigger}' configured"))
            else:
                checks.append(('❌', f"Trigger '{trigger}' missing"))
    else:
        for trigger in required_triggers:
            if trigger in on_config:
                checks.append(('✓', f"Trigger '{trigger}' configured"))
            else:
                checks.append(('❌', f"Trigger '{trigger}' missing"))

    # Check permissions
    if workflow.get('permissions', {}).get('contents') == 'read':
        checks.append(('✓', 'Permissions set to read'))
    else:
        checks.append(('❌', 'Permissions not properly configured'))

    # Check job exists
    jobs = workflow.get('jobs', {})
    if 'test' in jobs:
        checks.append(('✓', 'Job "test" exists'))
    else:
        checks.append(('❌', 'Job "test" missing'))
        return False

    test_job = jobs['test']

    # Check runs-on
    if test_job.get('runs-on') == 'ubuntu-latest':
        checks.append(('✓', 'Runs on ubuntu-latest'))
    else:
        checks.append(('❌', f"runs-on is '{test_job.get('runs-on')}'"))

    # Check steps
    steps = test_job.get('steps', [])
    step_names = [s.get('name', '') for s in steps]

    required_steps = [
        'Checkout code',
        'Set up Python',
        'Install dependencies',
        'Run unit tests',
        'Generate test fixtures',
        'Test case 1: Basic age cleanup',
        'Test case 2: Multiple workflows',
        'Test case 3: Total size exceeded',
        'Test dry-run mode',
    ]

    for required_step in required_steps:
        if any(required_step in name for name in step_names):
            checks.append(('✓', f'Step "{required_step}" exists'))
        else:
            checks.append(('❌', f'Step "{required_step}" missing'))

    # Check script references
    for step in steps:
        if 'run' in step:
            run = step['run']
            if 'cleanup.py' in str(run):
                checks.append(('✓', 'cleanup.py is referenced'))
                break
    else:
        checks.append(('❌', 'cleanup.py not referenced'))

    # Check actions/checkout@v4
    for step in steps:
        if 'uses' in step and 'actions/checkout' in step['uses']:
            if '@v4' in step['uses']:
                checks.append(('✓', 'uses actions/checkout@v4'))
            break

    # Check for test assertions
    test_assertions_found = 0
    for step in steps:
        if 'run' in step and 'assert' in str(step.get('run', '')):
            test_assertions_found += 1

    if test_assertions_found >= 3:
        checks.append(('✓', f'Found {test_assertions_found} test assertions'))
    else:
        checks.append(('❌', f'Only {test_assertions_found} test assertions found'))

    # Print results
    print("Workflow Structure Validation")
    print("=" * 50)
    for status, message in checks:
        print(f"{status} {message}")

    # Summary
    passed = sum(1 for s, _ in checks if s == '✓')
    total = len(checks)
    print(f"\n{passed}/{total} checks passed")

    return passed == total


def validate_act_result():
    """Validate that act-result.txt contains expected content."""
    result_path = '../../act-result.txt'

    if not os.path.exists(result_path):
        print(f"❌ act-result.txt not found at {result_path}")
        return False

    with open(result_path) as f:
        content = f.read()

    checks = []

    # Check for successful job completion
    if 'Job succeeded' in content:
        checks.append(('✓', 'Job succeeded'))
    elif '🏁  Job succeeded' in content:
        checks.append(('✓', 'Job succeeded'))
    else:
        checks.append(('❌', 'Job did not succeed'))

    # Check for test results
    if 'PASSED' in content:
        count = content.count('PASSED')
        checks.append(('✓', f'{count} tests PASSED'))
    else:
        checks.append(('❌', 'No PASSED tests found'))

    # Check for test case results
    for tc in ['Test case 1', 'Test case 2', 'Test case 3']:
        if tc in content:
            checks.append(('✓', f'{tc} executed'))
        else:
            checks.append(('❌', f'{tc} not found'))

    # Check for summary
    if 'Summary' in content:
        checks.append(('✓', 'Summary section found'))
    else:
        checks.append(('❌', 'Summary section not found'))

    print("\nact-result.txt Content Validation")
    print("=" * 50)
    for status, message in checks:
        print(f"{status} {message}")

    return all(s == '✓' for s, _ in checks)


if __name__ == '__main__':
    os.chdir('/home/passp/repos/compare-agent-scripting-by-language/workspaces/2026-04-17_004319/17-artifact-cleanup-script/default-haiku45')

    wf_valid = validate_workflow()
    result_valid = validate_act_result()

    if wf_valid and result_valid:
        print("\n✅ All validations passed!")
        sys.exit(0)
    else:
        print("\n❌ Some validations failed")
        sys.exit(1)
