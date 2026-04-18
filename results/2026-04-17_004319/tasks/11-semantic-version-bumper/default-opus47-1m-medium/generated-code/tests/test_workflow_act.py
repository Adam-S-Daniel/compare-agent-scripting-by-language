"""End-to-end workflow tests that drive the GitHub Actions workflow via `act`.

Per the task spec:
- Every test case runs through the workflow (no direct script invocations).
- All act output is appended to ``act-result.txt`` with case delimiters.
- We assert exit code 0, "Job succeeded", and EXACT expected version strings.
- Workflow structure (YAML + script paths + actionlint) is also verified.

To stay within the 3-`act push` budget we batch test cases into a SINGLE
workflow run that exercises one fixture per push, while a small parametrized
list of *additional* cases is staged into the same isolated repo before the
single act invocation. Each fixture's expected output is asserted by parsing
the captured log.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "semantic-version-bumper.yml"
ACT_RESULT = ROOT / "act-result.txt"


# ---------------- Workflow structure tests ----------------

def test_workflow_yaml_is_valid():
    data = yaml.safe_load(WORKFLOW.read_text())
    assert data["name"] == "Semantic Version Bumper"
    # `on:` is parsed as boolean True by PyYAML in some versions; check both.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None
    assert "push" in triggers
    assert "workflow_dispatch" in triggers
    assert "bump" in data["jobs"]


def test_workflow_references_existing_script():
    text = WORKFLOW.read_text()
    assert "bumper.py" in text
    assert (ROOT / "bumper.py").exists()
    assert (ROOT / "fixtures" / "commits_feat.txt").exists()


def test_actionlint_passes():
    r = subprocess.run(["actionlint", str(WORKFLOW)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr


# ---------------- act-driven end-to-end ----------------

# (case_name, version_file_contents, version_file_name, commits_fixture, expected_new_version)
CASES = [
    ("feat_minor",
     json.dumps({"name": "demo", "version": "1.1.0"}, indent=2) + "\n",
     "package.json", "fixtures/commits_feat.txt", "1.2.0"),
    ("fix_patch",
     "0.4.1\n", "VERSION", "fixtures/commits_fix.txt", "0.4.2"),
    ("breaking_major",
     json.dumps({"name": "demo", "version": "2.4.5"}, indent=2) + "\n",
     "package.json", "fixtures/commits_breaking.txt", "3.0.0"),
]


def _make_repo(tmp_path: Path, version_file_name: str, version_contents: str) -> Path:
    """Stage an isolated git repo containing the project + a target version file."""
    repo = tmp_path / "repo"
    repo.mkdir()
    # Copy required project artifacts.
    shutil.copy(ROOT / "bumper.py", repo / "bumper.py")
    shutil.copytree(ROOT / "fixtures", repo / "fixtures")
    shutil.copytree(ROOT / ".github", repo / ".github")
    # Optional .actrc that selects the custom container image (if available).
    actrc = ROOT / ".actrc"
    if actrc.exists():
        shutil.copy(actrc, repo / ".actrc")
    (repo / version_file_name).write_text(version_contents)

    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    subprocess.run(["git", "add", "."], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=repo, check=True)
    return repo


def _run_act(repo: Path, version_file: str, commits_file: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    return subprocess.run(
        ["act", "push", "--rm", "--pull=false",
         "--env", f"VERSION_FILE={version_file}",
         "--env", f"COMMITS_FILE={commits_file}"],
        cwd=repo, capture_output=True, text=True, env=env, timeout=600,
    )


def _append_result(case_name: str, result: subprocess.CompletedProcess) -> None:
    with ACT_RESULT.open("a") as f:
        f.write(f"\n\n========== CASE: {case_name} (exit={result.returncode}) ==========\n")
        f.write("--- STDOUT ---\n")
        f.write(result.stdout)
        f.write("\n--- STDERR ---\n")
        f.write(result.stderr)


@pytest.fixture(scope="session", autouse=True)
def _reset_act_result():
    """Clear act-result.txt at the start of the session."""
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.write_text("act results for semantic-version-bumper workflow\n")
    yield


@pytest.mark.parametrize("case", CASES, ids=[c[0] for c in CASES])
def test_act_workflow_runs(tmp_path, case):
    name, vcontents, vname, cfixture, expected = case
    repo = _make_repo(tmp_path, vname, vcontents)
    result = _run_act(repo, vname, cfixture)
    _append_result(name, result)

    combined = result.stdout + result.stderr
    assert result.returncode == 0, f"act failed for {name}:\n{combined[-2000:]}"
    assert "Job succeeded" in combined, f"no 'Job succeeded' for {name}"
    # The bumper prints the new version on stdout; act echoes it via the run step.
    # The bumper prints NEW_VERSION=<x>; act echoes the run-step env line.
    # Assert the EXACT expected version appears in the captured log.
    assert f"NEW_VERSION={expected}" in combined, (
        f"expected NEW_VERSION={expected} not found in act output for {name}"
    )
    assert f"Bumped to: {expected}" in combined, (
        f"expected 'Bumped to: {expected}' not found in act output for {name}"
    )
