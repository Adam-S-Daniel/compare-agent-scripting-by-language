"""
Workflow structure tests (no act needed).
Verify YAML structure, file references, actionlint pass.
"""
import os
import subprocess
import sys

import pytest
import yaml

WORKSPACE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW_PATH = os.path.join(WORKSPACE, ".github", "workflows", "semantic-version-bumper.yml")


def _load_workflow():
    with open(WORKFLOW_PATH) as f:
        return yaml.safe_load(f)


def _get_triggers(wf: dict) -> dict:
    # PyYAML parses the bare word `on` as boolean True in YAML 1.1
    triggers = wf.get("on") or wf.get(True) or {}
    return triggers if isinstance(triggers, dict) else {}


class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert os.path.exists(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"

    def test_has_push_trigger(self):
        wf = _load_workflow()
        assert "push" in _get_triggers(wf)

    def test_has_pull_request_trigger(self):
        wf = _load_workflow()
        assert "pull_request" in _get_triggers(wf)

    def test_has_workflow_dispatch_trigger(self):
        wf = _load_workflow()
        assert "workflow_dispatch" in _get_triggers(wf)

    def test_has_test_job(self):
        wf = _load_workflow()
        assert "test" in wf["jobs"]

    def test_has_bump_version_job(self):
        wf = _load_workflow()
        assert "bump-version" in wf["jobs"]

    def test_bump_depends_on_test(self):
        wf = _load_workflow()
        needs = wf["jobs"]["bump-version"].get("needs", [])
        assert "test" in needs

    def test_uses_checkout_v4(self):
        wf = _load_workflow()
        steps = wf["jobs"]["test"]["steps"]
        uses = [s.get("uses", "") for s in steps]
        assert any("actions/checkout@v4" in u for u in uses)

    def test_script_file_exists(self):
        script = os.path.join(WORKSPACE, "version_bumper.py")
        assert os.path.exists(script)

    def test_fixture_files_exist(self):
        for name in ("commits_patch.txt", "commits_minor.txt",
                     "commits_major.txt", "commits_none.txt"):
            path = os.path.join(WORKSPACE, "fixtures", name)
            assert os.path.exists(path), f"Missing fixture: {path}"

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True, text=True
        )
        assert result.returncode == 0, (
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )
