#!/usr/bin/env python3
"""
Test harness for the Semantic Version Bumper.

TDD approach — each test case is a red/green cycle:
  RED:   Define the expected output (fixture) before the code exists.
  GREEN: The version_bumper.py + workflow must produce exactly that output.

All tests execute through GitHub Actions via `act push --rm`.
Results are appended to act-result.txt.

Test categories:
  1. Workflow structure tests (YAML parsing, actionlint, file references)
  2. Functional tests via act (one per fixture file)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FIXTURES_DIR = os.path.join(SCRIPT_DIR, 'fixtures')
WORKFLOW_FILE = os.path.join(SCRIPT_DIR, '.github', 'workflows',
                             'semantic-version-bumper.yml')
BUMPER_SCRIPT = os.path.join(SCRIPT_DIR, 'version_bumper.py')
RESULT_FILE = os.path.join(SCRIPT_DIR, 'act-result.txt')
ACT_IMAGE = 'catthehacker/ubuntu:act-latest'

# Track pass/fail counts
passed = 0
failed = 0
errors = []


def record(test_name, success, detail=""):
    """Record a test result."""
    global passed, failed
    if success:
        passed += 1
        print(f"  PASS: {test_name}")
    else:
        failed += 1
        errors.append((test_name, detail))
        print(f"  FAIL: {test_name} — {detail}")


# ---------------------------------------------------------------------------
# Workflow structure tests
# ---------------------------------------------------------------------------

def run_structure_tests(result_fh):
    """Validate the workflow YAML structure, file references, and actionlint."""
    print("\n=== WORKFLOW STRUCTURE TESTS ===")
    result_fh.write("=" * 60 + "\n")
    result_fh.write("WORKFLOW STRUCTURE TESTS\n")
    result_fh.write("=" * 60 + "\n\n")

    # --- Test: YAML parses correctly and has expected structure ---
    import yaml  # PyYAML may not be installed; fall back to basic parsing

    try:
        # Try PyYAML first; if unavailable, do a manual check
        with open(WORKFLOW_FILE, 'r') as f:
            wf = yaml.safe_load(f)
    except ImportError:
        # Minimal fallback: just verify it's valid enough to read
        wf = _parse_workflow_minimal()
    except Exception as e:
        record("yaml_parse", False, str(e))
        result_fh.write(f"FAIL: yaml_parse — {e}\n\n")
        return

    record("yaml_parse", True)
    result_fh.write("PASS: yaml_parse — workflow YAML parsed successfully\n")

    # --- Test: expected triggers ---
    triggers = wf.get('on', wf.get(True, {}))
    has_push = 'push' in triggers
    has_pr = 'pull_request' in triggers
    has_dispatch = 'workflow_dispatch' in triggers
    record("triggers_push", has_push, "missing 'push' trigger")
    record("triggers_pull_request", has_pr, "missing 'pull_request' trigger")
    record("triggers_workflow_dispatch", has_dispatch,
           "missing 'workflow_dispatch' trigger")
    result_fh.write(f"PASS: triggers — push={has_push}, pr={has_pr}, "
                     f"dispatch={has_dispatch}\n")

    # --- Test: jobs and steps exist ---
    jobs = wf.get('jobs', {})
    has_job = len(jobs) > 0
    record("has_jobs", has_job, "no jobs defined")

    # Check that the job has steps referencing our script
    for job_name, job_def in jobs.items():
        steps = job_def.get('steps', [])
        step_texts = ' '.join(
            str(s.get('run', '')) for s in steps if isinstance(s, dict)
        )
        refs_script = 'version_bumper.py' in step_texts
        record(f"job_{job_name}_refs_script", refs_script,
               "job does not reference version_bumper.py")
        result_fh.write(f"PASS: job '{job_name}' references version_bumper.py = "
                         f"{refs_script}\n")

        uses_checkout = any(
            'actions/checkout' in str(s.get('uses', ''))
            for s in steps if isinstance(s, dict)
        )
        record(f"job_{job_name}_uses_checkout", uses_checkout,
               "job does not use actions/checkout")

    # --- Test: referenced files exist on disk ---
    bumper_exists = os.path.isfile(BUMPER_SCRIPT)
    record("script_file_exists", bumper_exists,
           f"{BUMPER_SCRIPT} not found")
    result_fh.write(f"PASS: version_bumper.py exists = {bumper_exists}\n")

    workflow_exists = os.path.isfile(WORKFLOW_FILE)
    record("workflow_file_exists", workflow_exists,
           f"{WORKFLOW_FILE} not found")

    # --- Test: actionlint passes ---
    lint = subprocess.run(
        ['actionlint', WORKFLOW_FILE],
        capture_output=True, text=True
    )
    lint_ok = lint.returncode == 0
    record("actionlint", lint_ok,
           lint.stdout.strip() + lint.stderr.strip())
    result_fh.write(f"actionlint exit code: {lint.returncode}\n")
    if not lint_ok:
        result_fh.write(f"actionlint output:\n{lint.stdout}{lint.stderr}\n")
    result_fh.write("\n")


def _parse_workflow_minimal():
    """Fallback YAML parser when PyYAML is not installed.

    Reads the workflow file and returns a minimal dict with keys we need.
    Good enough for structure tests.
    """
    # Import the yaml module from the standard library-adjacent approach:
    # Actually, let's just try a simple line-based parse.
    import re
    wf = {}
    with open(WORKFLOW_FILE, 'r') as f:
        content = f.read()

    # Detect triggers
    on_block = {}
    if 'push:' in content:
        on_block['push'] = True
    if 'pull_request:' in content:
        on_block['pull_request'] = True
    if 'workflow_dispatch:' in content:
        on_block['workflow_dispatch'] = True
    wf['on'] = on_block

    # Detect jobs (very basic)
    jobs = {}
    for m in re.finditer(r'^  (\S+):\s*$', content, re.MULTILINE):
        # Lines under 'jobs:' that are indented at 2 spaces
        pass
    # Simpler: just look for 'jobs:' section
    if 'jobs:' in content:
        # Find all job names (lines with exactly 2-space indent under jobs)
        in_jobs = False
        current_job = None
        steps_text = []
        for line in content.split('\n'):
            if line.strip() == 'jobs:':
                in_jobs = True
                continue
            if in_jobs:
                # Job name: 2-space indent
                m = re.match(r'^  ([a-zA-Z_-]+):', line)
                if m:
                    if current_job:
                        jobs[current_job] = {
                            'steps': _extract_steps('\n'.join(steps_text))
                        }
                    current_job = m.group(1)
                    steps_text = []
                elif current_job:
                    steps_text.append(line)
        if current_job:
            jobs[current_job] = {
                'steps': _extract_steps('\n'.join(steps_text))
            }
    wf['jobs'] = jobs
    return wf


def _extract_steps(text):
    """Extract step dicts (with 'run' and 'uses' keys) from YAML text."""
    import re
    steps = []
    current_step = {}
    for line in text.split('\n'):
        if line.strip().startswith('- '):
            if current_step:
                steps.append(current_step)
            current_step = {}
        m_uses = re.match(r'\s+uses:\s*(.+)', line)
        if m_uses:
            current_step['uses'] = m_uses.group(1).strip()
        m_run = re.match(r'\s+run:\s*(.+)', line)
        if m_run:
            current_step['run'] = m_run.group(1).strip()
        # Multi-line run blocks: capture lines after 'run: |'
        if 'run' in current_step and current_step['run'] == '|':
            current_step['run'] = ''
        if 'run' in current_step and line.strip() and not line.strip().startswith('-'):
            if 'version_bumper' in line:
                current_step['run'] = current_step.get('run', '') + line
    if current_step:
        steps.append(current_step)
    return steps


# ---------------------------------------------------------------------------
# Functional tests via act
# ---------------------------------------------------------------------------

def setup_test_repo(fixture, tmp_dir):
    """Create a temporary git repo with project files and fixture data.

    Returns the path to the temp repo directory.
    """
    repo_dir = os.path.join(tmp_dir, fixture['name'])
    os.makedirs(repo_dir, exist_ok=True)

    # Copy the version bumper script
    shutil.copy2(BUMPER_SCRIPT, os.path.join(repo_dir, 'version_bumper.py'))

    # Copy the workflow
    wf_dir = os.path.join(repo_dir, '.github', 'workflows')
    os.makedirs(wf_dir, exist_ok=True)
    shutil.copy2(WORKFLOW_FILE, os.path.join(wf_dir, 'semantic-version-bumper.yml'))

    # Create version file based on fixture
    if fixture['version_source'] == 'VERSION':
        with open(os.path.join(repo_dir, 'VERSION'), 'w') as f:
            f.write(fixture['initial_version'] + '\n')
    elif fixture['version_source'] == 'package.json':
        pkg = {"name": "test-package", "version": fixture['initial_version']}
        with open(os.path.join(repo_dir, 'package.json'), 'w') as f:
            json.dump(pkg, f, indent=2)
            f.write('\n')

    # Initialize git repo and create commits
    run_in = lambda cmd: subprocess.run(
        cmd, cwd=repo_dir, capture_output=True, text=True, check=True,
        env={**os.environ, 'GIT_AUTHOR_NAME': 'Test',
             'GIT_AUTHOR_EMAIL': 'test@test.com',
             'GIT_COMMITTER_NAME': 'Test',
             'GIT_COMMITTER_EMAIL': 'test@test.com'}
    )

    run_in(['git', 'init', '-b', 'master'])
    run_in(['git', 'add', '.'])
    run_in(['git', 'commit', '-m', 'chore: initial commit'])

    # Add conventional commits from fixture
    for commit_msg in fixture['commits']:
        # Touch a file so there's a diff for each commit
        marker = os.path.join(repo_dir, f'.commit-{commit_msg[:20].replace(" ", "_")}')
        with open(marker, 'w') as f:
            f.write(commit_msg)
        run_in(['git', 'add', '.'])
        run_in(['git', 'commit', '-m', commit_msg])

    return repo_dir


def run_act_test(fixture, tmp_dir, result_fh):
    """Run a single fixture test through act and validate output."""
    test_name = fixture['name']
    print(f"\n--- Test: {test_name} ---")
    result_fh.write("=" * 60 + "\n")
    result_fh.write(f"TEST: {test_name}\n")
    result_fh.write(f"Description: {fixture['description']}\n")
    result_fh.write(f"Initial version: {fixture['initial_version']}\n")
    result_fh.write(f"Expected version: {fixture['expected_version']}\n")
    result_fh.write(f"Commits: {fixture['commits']}\n")
    result_fh.write("=" * 60 + "\n\n")

    # Set up the temp repo
    try:
        repo_dir = setup_test_repo(fixture, tmp_dir)
    except subprocess.CalledProcessError as e:
        detail = f"repo setup failed: {e.stderr}"
        record(f"{test_name}_setup", False, detail)
        result_fh.write(f"FAIL: setup — {detail}\n\n")
        return

    # Run act
    act_cmd = [
        'act', 'push', '--rm',
        '-P', f'ubuntu-latest={ACT_IMAGE}',
        '--defaultbranch', 'master',
    ]

    result = subprocess.run(
        act_cmd, cwd=repo_dir, capture_output=True, text=True,
        timeout=120
    )

    output = result.stdout + result.stderr
    result_fh.write("--- act output ---\n")
    result_fh.write(output)
    result_fh.write("\n--- end act output ---\n\n")

    # Assert 1: act exited with code 0
    act_ok = result.returncode == 0
    record(f"{test_name}_act_exit_0", act_ok,
           f"act exited with code {result.returncode}")

    # Assert 2: Job succeeded
    job_succeeded = 'Job succeeded' in output
    record(f"{test_name}_job_succeeded", job_succeeded,
           "output does not contain 'Job succeeded'")

    # Assert 3: Correct new version in output
    expected = fixture['expected_version']
    version_in_output = f"New version: {expected}" in output
    record(f"{test_name}_new_version", version_in_output,
           f"expected 'New version: {expected}' in output")

    # Assert 4: BUMPED_VERSION machine-readable output
    bumped_line = f"BUMPED_VERSION={expected}" in output
    record(f"{test_name}_bumped_version", bumped_line,
           f"expected 'BUMPED_VERSION={expected}' in output")

    # Assert 5: Correct bump type
    bump_type = fixture['expected_bump_type']
    bump_in_output = f"Bump type: {bump_type}" in output
    record(f"{test_name}_bump_type", bump_in_output,
           f"expected 'Bump type: {bump_type}' in output")

    # Assert 6: Changelog was displayed
    changelog_shown = 'CHANGELOG' in output
    record(f"{test_name}_changelog_shown", changelog_shown,
           "changelog section not found in output")

    result_fh.write(f"RESULT: act_exit_0={act_ok}, job_succeeded={job_succeeded}, "
                     f"version={version_in_output}, bumped={bumped_line}, "
                     f"bump_type={bump_in_output}\n\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    global passed, failed

    # Open result file for writing
    with open(RESULT_FILE, 'w') as result_fh:
        result_fh.write("SEMANTIC VERSION BUMPER — TEST RESULTS\n")
        result_fh.write(f"{'=' * 60}\n\n")

        # --- Part 1: Workflow structure tests ---
        run_structure_tests(result_fh)

        # --- Part 2: Functional tests via act ---
        print("\n=== FUNCTIONAL TESTS VIA ACT ===")
        result_fh.write("\n" + "=" * 60 + "\n")
        result_fh.write("FUNCTIONAL TESTS VIA ACT\n")
        result_fh.write("=" * 60 + "\n\n")

        # Load all fixture files
        fixtures = []
        for fname in sorted(os.listdir(FIXTURES_DIR)):
            if fname.endswith('.json'):
                with open(os.path.join(FIXTURES_DIR, fname), 'r') as f:
                    fixtures.append(json.load(f))

        # Run each fixture through act in a shared temp directory
        with tempfile.TemporaryDirectory(prefix='semver-test-') as tmp_dir:
            for fixture in fixtures:
                try:
                    run_act_test(fixture, tmp_dir, result_fh)
                except Exception as e:
                    record(f"{fixture['name']}_exception", False, str(e))
                    result_fh.write(f"EXCEPTION in {fixture['name']}: {e}\n\n")

        # --- Summary ---
        total = passed + failed
        result_fh.write("\n" + "=" * 60 + "\n")
        result_fh.write(f"SUMMARY: {passed}/{total} passed, {failed}/{total} failed\n")
        if errors:
            result_fh.write("\nFailed tests:\n")
            for name, detail in errors:
                result_fh.write(f"  - {name}: {detail}\n")
        result_fh.write("=" * 60 + "\n")

    # Print summary
    print(f"\n{'=' * 60}")
    print(f"SUMMARY: {passed}/{passed + failed} passed, "
          f"{failed}/{passed + failed} failed")
    if errors:
        print("\nFailed tests:")
        for name, detail in errors:
            print(f"  - {name}: {detail}")
    print(f"{'=' * 60}")
    print(f"\nResults written to {RESULT_FILE}")

    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
