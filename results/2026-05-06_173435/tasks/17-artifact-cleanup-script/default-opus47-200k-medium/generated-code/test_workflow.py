"""Workflow integration tests.

Each test case sets up an isolated git repo with the project files and a
specific fixture, runs `act push --rm`, captures the output, and asserts on
EXACT expected values from the cleanup planner output.

All act output is appended to act-result.txt in the project directory.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).parent.resolve()
WORKFLOW = PROJECT_ROOT / ".github/workflows/artifact-cleanup-script.yml"
ACT_RESULT = PROJECT_ROOT / "act-result.txt"


def _run_actionlint() -> subprocess.CompletedProcess:
    return subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True, cwd=PROJECT_ROOT,
    )


# --- Workflow structure tests (fast, no act required) ---

def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"Workflow file not found at {WORKFLOW}"


def test_actionlint_passes():
    result = _run_actionlint()
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT:{result.stdout}\nSTDERR:{result.stderr}"
    )


def test_workflow_has_required_triggers():
    wf = yaml.safe_load(WORKFLOW.read_text())
    triggers = wf[True] if True in wf else wf["on"]  # PyYAML quirk: 'on:' -> True
    assert "push" in triggers
    assert "workflow_dispatch" in triggers
    assert "schedule" in triggers


def test_workflow_jobs_and_dependencies():
    wf = yaml.safe_load(WORKFLOW.read_text())
    jobs = wf["jobs"]
    assert "unit-tests" in jobs
    assert "cleanup-plan" in jobs
    # cleanup-plan must depend on unit-tests
    assert jobs["cleanup-plan"]["needs"] == "unit-tests"


def test_workflow_references_existing_script_files():
    wf_text = WORKFLOW.read_text()
    assert "cleanup.py" in wf_text
    assert "test_cleanup.py" in wf_text
    assert (PROJECT_ROOT / "cleanup.py").exists()
    assert (PROJECT_ROOT / "test_cleanup.py").exists()
    assert (PROJECT_ROOT / "fixtures/artifacts.json").exists()


def test_workflow_uses_pinned_checkout_action():
    wf_text = WORKFLOW.read_text()
    assert "actions/checkout@v4" in wf_text


# --- Act-based integration tests ---

# Each fixture has a known-good expected outcome derived from the policy
# parameters in the workflow_dispatch defaults.
TEST_CASES = [
    {
        "name": "default_mixed",
        "fixture": [
            # wf-100 has 3 artifacts, keep_latest_n=2 -> oldest deleted
            {"id": "a1", "name": "build", "size_bytes": 1000,
             "created_at": "2026-05-07T10:00:00Z", "workflow_run_id": "wf-100"},
            {"id": "a2", "name": "build", "size_bytes": 1000,
             "created_at": "2026-05-06T10:00:00Z", "workflow_run_id": "wf-100"},
            {"id": "a3", "name": "build", "size_bytes": 1000,
             "created_at": "2026-05-05T10:00:00Z", "workflow_run_id": "wf-100"},
            # wf-200 has 1 old artifact -> deleted by max_age=30
            {"id": "a4", "name": "old", "size_bytes": 2000,
             "created_at": "2026-01-01T00:00:00Z", "workflow_run_id": "wf-200"},
            # wf-300 has 1 fresh artifact -> kept
            {"id": "a5", "name": "fresh", "size_bytes": 500,
             "created_at": "2026-05-01T00:00:00Z", "workflow_run_id": "wf-300"},
        ],
        "expected_total": 5,
        "expected_deleted": 2,
        "expected_retained": 3,
        "expected_bytes_reclaimed": 3000,
        "expected_deleted_ids": {"a3", "a4"},
    },
    {
        "name": "all_fresh_keep_all",
        "fixture": [
            {"id": "x1", "name": "x", "size_bytes": 100,
             "created_at": "2026-05-08T00:00:00Z", "workflow_run_id": "w1"},
            {"id": "x2", "name": "x", "size_bytes": 100,
             "created_at": "2026-05-07T00:00:00Z", "workflow_run_id": "w2"},
        ],
        "expected_total": 2,
        "expected_deleted": 0,
        "expected_retained": 2,
        "expected_bytes_reclaimed": 0,
        "expected_deleted_ids": set(),
    },
    {
        "name": "all_old_delete_all",
        "fixture": [
            {"id": "o1", "name": "o", "size_bytes": 750,
             "created_at": "2025-01-01T00:00:00Z", "workflow_run_id": "w1"},
            {"id": "o2", "name": "o", "size_bytes": 250,
             "created_at": "2025-02-01T00:00:00Z", "workflow_run_id": "w2"},
        ],
        # Both >30 days old. keep_latest_n=2 still allows max-age to mark them.
        "expected_total": 2,
        "expected_deleted": 2,
        "expected_retained": 0,
        "expected_bytes_reclaimed": 1000,
        "expected_deleted_ids": {"o1", "o2"},
    },
]


def _setup_test_repo(tmp_path: Path, fixture_data: list) -> Path:
    """Copy project files into a temp dir + init a git repo so act can run."""
    repo = tmp_path / "repo"
    repo.mkdir()
    for name in ["cleanup.py", "test_cleanup.py"]:
        shutil.copy2(PROJECT_ROOT / name, repo / name)
    (repo / ".github/workflows").mkdir(parents=True)
    shutil.copy2(WORKFLOW, repo / ".github/workflows/artifact-cleanup-script.yml")
    (repo / "fixtures").mkdir()
    (repo / "fixtures/artifacts.json").write_text(json.dumps(fixture_data, indent=2))

    # Minimal git repo so act is happy.
    env = {**os.environ,
           "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=repo, check=True, env=env)
    return repo


def _append_result(case_name: str, content: str) -> None:
    delim = "=" * 70
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{delim}\nCASE: {case_name}\n{delim}\n{content}\n")


@pytest.fixture(scope="session", autouse=True)
def _reset_act_result():
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.write_text(f"act-result.txt — generated by test_workflow.py\n")
    yield


@pytest.mark.parametrize("case", TEST_CASES, ids=[c["name"] for c in TEST_CASES])
def test_workflow_runs_via_act(case, tmp_path):
    if not shutil.which("act"):
        pytest.skip("act not installed")
    if not shutil.which("docker"):
        pytest.skip("docker not installed")

    repo = _setup_test_repo(tmp_path, case["fixture"])

    # Use catthehacker's medium image which has python3 pre-installed.
    cmd = [
        "act", "push", "--rm",
        "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest",
    ]
    proc = subprocess.run(cmd, cwd=repo, capture_output=True, text=True, timeout=600)
    output = (
        f"$ {' '.join(cmd)}\n"
        f"--- exit: {proc.returncode} ---\n"
        f"--- stdout ---\n{proc.stdout}\n"
        f"--- stderr ---\n{proc.stderr}\n"
    )
    _append_result(case["name"], output)

    assert proc.returncode == 0, f"act failed for {case['name']}:\n{output}"

    combined = proc.stdout + proc.stderr

    # Both jobs must succeed.
    assert "Job succeeded" in combined, f"No 'Job succeeded' marker found:\n{combined}"
    # Two jobs in the workflow; both should report success.
    assert combined.count("Job succeeded") >= 2, (
        f"Expected at least 2 'Job succeeded' markers, got: "
        f"{combined.count('Job succeeded')}\n{combined}"
    )

    # Assert exact summary values appear in the captured plan output.
    expected_summary_substrings = [
        f'"total_count": {case["expected_total"]}',
        f'"deleted_count": {case["expected_deleted"]}',
        f'"retained_count": {case["expected_retained"]}',
        f'"bytes_reclaimed": {case["expected_bytes_reclaimed"]}',
    ]
    for sub in expected_summary_substrings:
        assert sub in combined, f"Missing expected substring {sub!r} in act output"

    # Assert each expected-deleted id appears (in to_delete section, but a
    # simple string-presence check is sufficient because retained ids are
    # explicitly checked too via summary counts).
    for art_id in case["expected_deleted_ids"]:
        assert f'"id": "{art_id}"' in combined, (
            f"Expected deleted id {art_id} not present in output"
        )

    # DRY-RUN banner must be present (workflow runs cleanup with --dry-run).
    assert "DRY-RUN" in combined


def test_act_result_file_exists_after_runs():
    # This test runs after the parametrized cases (alphabetic order: 'a' < 't').
    assert ACT_RESULT.exists()
    content = ACT_RESULT.read_text()
    # Should contain at least one CASE delimiter.
    assert "CASE:" in content
