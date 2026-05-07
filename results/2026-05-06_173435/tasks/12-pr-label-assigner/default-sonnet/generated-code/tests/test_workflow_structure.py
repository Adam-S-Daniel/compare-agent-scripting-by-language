"""
Workflow structure tests — verify the GitHub Actions YAML has the correct
structure and references real files.

These run inside the act container (via pytest in the workflow), where the
checked-out repo root is the working directory.

Note on pyyaml + YAML 1.1: pyyaml parses the unquoted key `on` as the
boolean value True. _get_triggers() handles both spellings transparently.
"""

import os
import shutil
import subprocess

import pytest
import yaml


WORKFLOW_PATH = '.github/workflows/pr-label-assigner.yml'


@pytest.fixture(scope='module')
def workflow() -> dict:
    """Load and parse the workflow YAML once for all tests in this module."""
    assert os.path.exists(WORKFLOW_PATH), f"Workflow file not found: {WORKFLOW_PATH}"
    with open(WORKFLOW_PATH) as f:
        return yaml.safe_load(f)


def _get_triggers(workflow: dict) -> dict:
    """Return the 'on' triggers dict.

    pyyaml (YAML 1.1) parses the bare key `on` as boolean True, so we check
    both the string key and the boolean key.
    """
    triggers = workflow.get('on') or workflow.get(True)
    return triggers if isinstance(triggers, dict) else {}


class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert os.path.exists(WORKFLOW_PATH)

    def test_workflow_has_on_triggers(self, workflow):
        """Workflow must declare at least push or pull_request triggers."""
        triggers = _get_triggers(workflow)
        assert triggers, "No 'on' triggers defined in workflow"
        assert 'push' in triggers or 'pull_request' in triggers, \
            f"Expected 'push' or 'pull_request' trigger; got: {list(triggers.keys())}"

    def test_workflow_has_jobs(self, workflow):
        assert 'jobs' in workflow, "No jobs defined"
        assert len(workflow['jobs']) >= 1

    def test_workflow_has_checkout_step(self, workflow):
        """Every job should checkout the code."""
        for job_name, job in workflow['jobs'].items():
            steps = job.get('steps', [])
            uses_list = [s.get('uses', '') for s in steps]
            assert any('actions/checkout' in u for u in uses_list), \
                f"Job '{job_name}' is missing actions/checkout step"

    def test_workflow_references_pr_label_assigner_script(self, workflow):
        """At least one step must reference pr_label_assigner.py."""
        found = False
        for job in workflow['jobs'].values():
            for step in job.get('steps', []):
                run_cmd = step.get('run', '')
                if 'pr_label_assigner' in run_cmd or 'run_fixture_tests' in run_cmd:
                    found = True
                    break
        assert found, "No step references pr_label_assigner.py or run_fixture_tests.py"

    def test_workflow_runs_pytest(self, workflow):
        """At least one step must run pytest."""
        found = False
        for job in workflow['jobs'].values():
            for step in job.get('steps', []):
                if 'pytest' in step.get('run', ''):
                    found = True
                    break
        assert found, "No step runs pytest"

    def test_script_files_exist(self):
        """All script files referenced by the workflow must exist."""
        required_files = [
            'pr_label_assigner.py',
            'label_config.json',
            'test_fixture.json',
            'run_fixture_tests.py',
            'tests/test_pr_label_assigner.py',
        ]
        for path in required_files:
            assert os.path.exists(path), f"Required file missing: {path}"

    def test_actionlint_passes(self):
        """actionlint must report no errors on the workflow file.

        Skipped when actionlint is not in the container PATH — the workflow
        itself has an explicit 'Validate workflow with actionlint' step that
        satisfies the structural check for act runs.
        """
        if shutil.which('actionlint') is None:
            pytest.skip("actionlint not found in container PATH (validated by workflow step)")
        result = subprocess.run(
            ['actionlint', WORKFLOW_PATH],
            capture_output=True, text=True
        )
        assert result.returncode == 0, \
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
