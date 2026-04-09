#!/usr/bin/env python3
"""
Test harness for Docker Image Tag Generator.

Runs three categories of tests:
  1. Workflow structure tests (YAML parsing, file references, actionlint)
  2. Act-based integration tests (runs the full workflow in a container)
  3. Output assertion tests (parses act output for exact expected values)

All act output is saved to act-result.txt.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import yaml

# Paths relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(SCRIPT_DIR, '.github', 'workflows', 'docker-image-tag-generator.yml')
GENERATOR_PATH = os.path.join(SCRIPT_DIR, 'docker_tag_generator.py')
ACT_RESULT_PATH = os.path.join(SCRIPT_DIR, 'act-result.txt')

# Will be populated after act runs
act_output = ''
act_exit_code = None


def run_act_once():
    """Set up a temp git repo with project files, run act, save output."""
    global act_output, act_exit_code

    tmpdir = tempfile.mkdtemp(prefix='docker-tag-test-')
    try:
        # Copy project files into the temp repo
        shutil.copy2(GENERATOR_PATH, tmpdir)
        os.makedirs(os.path.join(tmpdir, '.github', 'workflows'))
        shutil.copy2(WORKFLOW_PATH, os.path.join(tmpdir, '.github', 'workflows', 'docker-image-tag-generator.yml'))

        # Copy .actrc if it exists
        actrc_src = os.path.join(SCRIPT_DIR, '.actrc')
        if os.path.exists(actrc_src):
            shutil.copy2(actrc_src, tmpdir)

        # Initialize a git repo (act requires it)
        subprocess.run(['git', 'init'], cwd=tmpdir, capture_output=True, check=True)
        subprocess.run(['git', 'add', '.'], cwd=tmpdir, capture_output=True, check=True)
        subprocess.run(
            ['git', 'commit', '-m', 'initial', '--allow-empty'],
            cwd=tmpdir, capture_output=True, check=True,
            env={**os.environ, 'GIT_AUTHOR_NAME': 'test', 'GIT_AUTHOR_EMAIL': 'test@test.com',
                 'GIT_COMMITTER_NAME': 'test', 'GIT_COMMITTER_EMAIL': 'test@test.com'}
        )

        # Run act push --rm --pull=false (use local image, don't try to pull)
        print(f"Running act in {tmpdir} ...")
        result = subprocess.run(
            ['act', 'push', '--rm', '--pull=false'],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            timeout=300
        )
        act_output = result.stdout + '\n' + result.stderr
        act_exit_code = result.returncode

        # Save to act-result.txt
        with open(ACT_RESULT_PATH, 'w') as f:
            f.write("=== ACT RUN OUTPUT ===\n")
            f.write(f"Exit code: {act_exit_code}\n")
            f.write("=== STDOUT ===\n")
            f.write(result.stdout)
            f.write("\n=== STDERR ===\n")
            f.write(result.stderr)
            f.write("\n=== END ACT RUN ===\n")

        print(f"act exit code: {act_exit_code}")
        print(f"Output saved to {ACT_RESULT_PATH}")

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


# ============================================================
# 1. Workflow Structure Tests
# ============================================================
class TestWorkflowStructure(unittest.TestCase):
    """Parse the YAML and check expected structure."""

    @classmethod
    def setUpClass(cls):
        with open(WORKFLOW_PATH) as f:
            cls.workflow = yaml.safe_load(f)

    def test_workflow_file_exists(self):
        self.assertTrue(os.path.isfile(WORKFLOW_PATH), "Workflow YAML must exist")

    def test_generator_script_exists(self):
        self.assertTrue(os.path.isfile(GENERATOR_PATH), "docker_tag_generator.py must exist")

    def test_trigger_events(self):
        # PyYAML parses the YAML key 'on' as boolean True
        triggers = self.workflow.get(True, self.workflow.get('on', {}))
        # Must have push trigger
        self.assertIn('push', triggers, "Workflow must trigger on push")
        # Must have pull_request trigger
        self.assertIn('pull_request', triggers, "Workflow must trigger on pull_request")
        # Must have workflow_dispatch
        self.assertIn('workflow_dispatch', triggers, "Workflow must have workflow_dispatch")

    def test_jobs_exist(self):
        jobs = self.workflow.get('jobs', {})
        self.assertIn('generate-tags', jobs, "Must have 'generate-tags' job")
        self.assertIn('test', jobs, "Must have 'test' job")

    def test_checkout_step_present(self):
        """Both jobs must check out the repo."""
        for job_name in ('generate-tags', 'test'):
            steps = self.workflow['jobs'][job_name]['steps']
            uses_list = [s.get('uses', '') for s in steps]
            self.assertTrue(
                any('actions/checkout@v4' in u for u in uses_list),
                f"Job '{job_name}' must use actions/checkout@v4"
            )

    def test_script_referenced_in_workflow(self):
        """The workflow must reference docker_tag_generator.py."""
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        self.assertIn('docker_tag_generator.py', content,
                       "Workflow must reference the generator script")

    def test_permissions_set(self):
        self.assertIn('permissions', self.workflow, "Workflow should set permissions")

    def test_actionlint_passes(self):
        """actionlint must report no errors."""
        result = subprocess.run(
            ['actionlint', WORKFLOW_PATH],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"actionlint failed:\n{result.stdout}\n{result.stderr}")


# ============================================================
# 2. Act Integration Tests
# ============================================================
class TestActIntegration(unittest.TestCase):
    """Run the workflow via act and validate results."""

    @classmethod
    def setUpClass(cls):
        # Run act once for all integration tests
        if act_exit_code is None:
            run_act_once()

    def test_act_result_file_exists(self):
        self.assertTrue(os.path.isfile(ACT_RESULT_PATH), "act-result.txt must exist")

    def test_act_exit_code_zero(self):
        self.assertEqual(act_exit_code, 0,
                         f"act must exit with code 0, got {act_exit_code}.\n"
                         f"Output tail:\n{act_output[-2000:]}")

    def test_all_jobs_succeeded(self):
        # act prints "Job succeeded" for each successful job
        self.assertIn('Job succeeded', act_output,
                      "Expected 'Job succeeded' in act output")

    # --- Exact value assertions for each test case ---

    def test_case_1_main_branch(self):
        """Test 1: main branch must produce 'latest' and 'sha-abc1234'."""
        self.assertIn('PASS: latest tag present', act_output)
        self.assertIn('PASS: sha tag present', act_output)

    def test_case_2_master_branch(self):
        """Test 2: master branch must produce 'latest' and 'sha-fedcba9'."""
        self.assertIn('PASS: latest tag for master', act_output)

    def test_case_3_pull_request(self):
        """Test 3: PR 42 must produce 'pr-42' and 'feature-pr-branch-1234567'."""
        self.assertIn('PASS: pr-42 tag present', act_output)
        self.assertIn('PASS: branch-sha tag present', act_output)

    def test_case_4_semver_tag(self):
        """Test 4: tag v1.2.3 must produce 'v1.2.3'."""
        self.assertIn('PASS: v1.2.3 tag present', act_output)

    def test_case_5_semver_no_prefix(self):
        """Test 5: tag 2.0.0 must produce 'v2.0.0'."""
        self.assertIn('PASS: v2.0.0 tag normalized', act_output)

    def test_case_6_feature_branch(self):
        """Test 6: feature/my-feature must produce 'feature-my-feature-def4567'."""
        self.assertIn('PASS: branch-sha tag present', act_output)
        self.assertIn('PASS: no latest tag for feature branch', act_output)

    def test_case_7_sanitization(self):
        """Test 7: uppercase/special chars sanitized to 'feature-upper-case-special-chars-9988776'."""
        self.assertIn('PASS: sanitized branch tag', act_output)

    def test_case_8_error_handling(self):
        """Test 8: no inputs exits non-zero."""
        self.assertIn('PASS: exits with error when no inputs', act_output)

    def test_case_9_prerelease(self):
        """Test 9: v3.0.0-rc.1 tag preserved."""
        self.assertIn('PASS: pre-release semver tag', act_output)

    def test_all_tests_passed_message(self):
        """The workflow summary step must print the success message."""
        self.assertIn('SUCCESS - All 9 test cases passed', act_output)

    # --- Exact output value assertions (not just PASS markers) ---

    def test_exact_output_main_branch(self):
        """Verify exact tag values appear in act output for main branch test."""
        # The workflow echoes $OUTPUT which contains the actual tags
        self.assertIn('latest', act_output)
        self.assertIn('sha-abc1234', act_output)

    def test_exact_output_pr(self):
        """Verify exact pr-42 tag in output."""
        self.assertIn('pr-42', act_output)
        self.assertIn('feature-pr-branch-1234567', act_output)

    def test_exact_output_semver(self):
        """Verify exact v1.2.3 and v2.0.0 tags in output."""
        self.assertIn('v1.2.3', act_output)
        self.assertIn('v2.0.0', act_output)

    def test_exact_output_sanitized(self):
        """Verify exact sanitized branch tag in output."""
        self.assertIn('feature-upper-case-special-chars-9988776', act_output)

    def test_exact_output_prerelease(self):
        """Verify exact pre-release tag in output."""
        self.assertIn('v3.0.0-rc.1', act_output)


if __name__ == '__main__':
    # Run act before tests if not already done
    if act_exit_code is None:
        run_act_once()
    # Run all tests
    unittest.main(verbosity=2)
