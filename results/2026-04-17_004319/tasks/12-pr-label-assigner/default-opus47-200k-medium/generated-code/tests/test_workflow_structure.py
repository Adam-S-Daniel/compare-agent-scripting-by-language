# Workflow-structure tests: verify the YAML, the steps, and that actionlint
# is happy. These are fast — they don't run act.
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
WF = ROOT / ".github" / "workflows" / "pr-label-assigner.yml"

# PyYAML may or may not be present; skip the parse tests if not.
yaml = pytest.importorskip("yaml") if shutil.which("python3") else None


def test_workflow_file_exists():
    assert WF.is_file(), f"missing workflow: {WF}"


def test_workflow_parses_and_has_expected_structure():
    import yaml as _yaml
    data = _yaml.safe_load(WF.read_text())
    # `on` becomes the boolean True after yaml load — check both.
    triggers = data.get("on") or data.get(True)
    assert triggers, "workflow missing triggers"
    for t in ("push", "pull_request", "workflow_dispatch"):
        assert t in triggers, f"trigger {t!r} missing"
    jobs = data["jobs"]
    assert "assign-labels" in jobs
    steps = jobs["assign-labels"]["steps"]
    step_names = [s.get("name", "") for s in steps]
    assert "Checkout" in step_names
    assert "Run unit tests" in step_names
    assert "Run label assigner" in step_names


def test_workflow_references_existing_files():
    # The "run label assigner" step calls label_assigner.py — make sure it exists.
    assert (ROOT / "label_assigner.py").is_file()
    assert (ROOT / "fixtures" / "rules.json").is_file()
    assert (ROOT / "fixtures" / "changed_files.txt").is_file()
    text = WF.read_text()
    assert "label_assigner.py" in text
    assert "actions/checkout@v4" in text


def test_actionlint_passes():
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    result = subprocess.run(
        ["actionlint", str(WF)], capture_output=True, text=True
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"
