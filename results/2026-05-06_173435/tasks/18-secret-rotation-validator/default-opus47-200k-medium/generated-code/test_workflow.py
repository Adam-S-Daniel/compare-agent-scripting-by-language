"""Workflow integration tests.

For each test case we:
  - copy project files into a temp git repo
  - swap in the case's fixture data and adjust workflow env defaults
  - run `act push --rm`
  - append the output to act-result.txt
  - assert exit code 0 and that exact expected values appear in the output

We also validate workflow structure (YAML parse + actionlint).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

HERE = Path(__file__).parent
WORKFLOW = HERE / ".github" / "workflows" / "secret-rotation-validator.yml"
ACT_RESULT = HERE / "act-result.txt"

# Fixture A: a typical mix — 1 expired, 1 warning, 1 ok.
FIXTURE_MIXED = {
    "secrets": [
        {"name": "prod-db-password", "last_rotated": "2026-01-01",
         "policy_days": 30, "services": ["api", "worker"]},
        {"name": "stripe-api-key", "last_rotated": "2026-04-13",
         "policy_days": 30, "services": ["api"]},
        {"name": "session-signing-key", "last_rotated": "2026-05-03",
         "policy_days": 30, "services": ["api", "web"]},
    ]
}

# Fixture B: everything healthy — all OK.
FIXTURE_ALL_OK = {
    "secrets": [
        {"name": "alpha", "last_rotated": "2026-05-01",
         "policy_days": 90, "services": ["svc"]},
        {"name": "beta", "last_rotated": "2026-04-20",
         "policy_days": 365, "services": ["svc"]},
    ]
}


# --- Workflow structure tests (no act) -------------------------------------

def test_workflow_yaml_is_well_formed():
    # PyYAML treats `on:` as Python True; load and check both keys.
    doc = yaml.safe_load(WORKFLOW.read_text())
    assert doc["name"] == "Secret Rotation Validator"
    triggers = doc.get("on") or doc.get(True)
    assert triggers is not None, "workflow must define triggers"
    assert {"push", "pull_request", "workflow_dispatch", "schedule"} <= set(triggers)
    assert {"unit-tests", "validate"} <= set(doc["jobs"])
    # validate depends on unit-tests
    assert doc["jobs"]["validate"]["needs"] == "unit-tests"


def test_workflow_references_existing_files():
    # Every script the workflow runs must exist on disk.
    assert (HERE / "validator.py").exists()
    assert (HERE / "test_validator.py").exists()
    assert (HERE / "fixtures" / "secrets.json").exists()


def test_actionlint_passes():
    r = subprocess.run(["actionlint", str(WORKFLOW)],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr


# --- act harness -----------------------------------------------------------

def _setup_repo(tmp_path: Path, fixture: dict, now: str, warn_days: int,
                fail_on_expired: bool) -> Path:
    """Copy project into tmp_path, write fixture + adjust workflow defaults."""
    repo = tmp_path / "repo"
    repo.mkdir()
    for name in ("validator.py", "test_validator.py"):
        shutil.copy(HERE / name, repo / name)
    (repo / "fixtures").mkdir()
    (repo / "fixtures" / "secrets.json").write_text(json.dumps(fixture, indent=2))
    wf_dst = repo / ".github" / "workflows"
    wf_dst.mkdir(parents=True)
    # Patch workflow defaults so each case gets distinct env without inputs.
    wf = WORKFLOW.read_text()
    wf = wf.replace("'2026-05-08'", repr(now))
    wf = wf.replace("default: \"2026-05-08\"", f'default: "{now}"')
    wf = wf.replace("|| '7'", f"|| '{warn_days}'")
    wf = wf.replace('default: "7"', f'default: "{warn_days}"')
    if fail_on_expired:
        wf = wf.replace("|| 'false'", "|| 'true'")
        wf = wf.replace('default: "false"', 'default: "true"')
    (wf_dst / "secret-rotation-validator.yml").write_text(wf)
    # Need a git repo for act.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    env = os.environ | {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=repo, check=True, env=env)
    return repo


def _run_act(repo: Path, label: str) -> subprocess.CompletedProcess:
    # `--pull=false` because the image is built locally and isn't on Docker Hub.
    args = ["act", "push", "--rm", "--pull=false",
            "-P", "ubuntu-latest=act-ubuntu-pwsh:latest"]
    r = subprocess.run(args, cwd=repo, capture_output=True, text=True, timeout=600)
    with ACT_RESULT.open("a") as f:
        f.write(f"\n===== CASE: {label} (exit={r.returncode}) =====\n")
        f.write(r.stdout)
        f.write("\n----- stderr -----\n")
        f.write(r.stderr)
        f.write("\n===== END CASE: " + label + " =====\n")
    return r


# Reset act-result.txt once before any act case runs.
@pytest.fixture(scope="module", autouse=True)
def _reset_results():
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.write_text("# act results — written by test_workflow.py\n")
    yield


def test_act_case_mixed(tmp_path):
    """Mixed fixture: should produce exactly 1 expired, 1 warning, 1 ok."""
    repo = _setup_repo(tmp_path, FIXTURE_MIXED, now="2026-05-08",
                       warn_days=7, fail_on_expired=False)
    r = _run_act(repo, "mixed")
    assert r.returncode == 0, "act failed; see act-result.txt"
    out = r.stdout
    # Both jobs report success.
    assert out.count("Job succeeded") >= 3, out  # unit-tests + 2 matrix legs
    # Unit tests passed
    assert "14 passed" in out
    # JSON matrix leg exact assertions
    assert '"name": "prod-db-password"' in out
    assert '"days_overdue": 97' in out  # 2026-01-01 -> 2026-05-08 = 127 days; policy 30 -> 97 overdue
    # Markdown matrix leg
    assert "## Expired (1)" in out
    assert "## Warning (1)" in out
    assert "## OK (1)" in out
    assert "| prod-db-password |" in out
    assert "| stripe-api-key |" in out
    assert "| session-signing-key |" in out
    # End-of-step marker for both matrix legs
    assert "VALIDATOR_RUN_OK format=json" in out
    assert "VALIDATOR_RUN_OK format=markdown" in out


def test_act_case_all_ok(tmp_path):
    """All-OK fixture with --fail-on-expired enabled: should still exit 0."""
    repo = _setup_repo(tmp_path, FIXTURE_ALL_OK, now="2026-05-08",
                       warn_days=7, fail_on_expired=True)
    r = _run_act(repo, "all-ok")
    assert r.returncode == 0, "act failed; see act-result.txt"
    out = r.stdout
    assert out.count("Job succeeded") >= 3
    # JSON: zero expired/warning, two ok
    assert '"expired": 0' in out
    assert '"warning": 0' in out
    assert '"ok": 2' in out
    # Markdown: empty sections render _none_
    assert "## Expired (0)" in out
    assert "## Warning (0)" in out
    assert "## OK (2)" in out
    assert "_none_" in out
    assert "| alpha |" in out
    assert "| beta |" in out
