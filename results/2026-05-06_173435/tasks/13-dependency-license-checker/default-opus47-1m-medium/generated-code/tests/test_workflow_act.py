"""End-to-end act-based tests for the GitHub Actions workflow.

Each case sets up an isolated temp git repo containing the project files plus
a per-case fixture pair (manifest + mock licenses), runs `act push --rm`, and
asserts on EXACT expected substrings of the captured output. All output is
appended to act-result.txt at the project root.

We invoke act at most three times across the entire suite (per task spec).
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "dependency-license-checker.yml"
ACT_RESULT = ROOT / "act-result.txt"


# --- Workflow structure tests (instant; no act run) ---------------------

def test_workflow_yaml_parses():
    with WORKFLOW.open() as f:
        data = yaml.safe_load(f)
    assert data["name"] == "Dependency License Checker"


def test_workflow_has_expected_triggers():
    with WORKFLOW.open() as f:
        data = yaml.safe_load(f)
    # PyYAML parses the bare `on:` key as the boolean True (YAML 1.1 quirk),
    # so accept either spelling.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None, "workflow must declare 'on' triggers"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "schedule" in triggers
    assert "workflow_dispatch" in triggers


def test_workflow_has_expected_jobs():
    with WORKFLOW.open() as f:
        data = yaml.safe_load(f)
    jobs = data["jobs"]
    assert "unit-tests" in jobs
    assert "license-check" in jobs
    # license-check must depend on unit-tests so a broken script can't ship.
    assert jobs["license-check"]["needs"] == "unit-tests"


def test_workflow_references_existing_script_paths():
    with WORKFLOW.open() as f:
        text = f.read()
    # Every path the workflow references must exist on disk.
    assert (ROOT / "license_checker.py").exists()
    assert (ROOT / "tests").is_dir()
    assert (ROOT / "fixtures" / "policy.json").exists()
    assert "license_checker.py" in text
    assert "tests/" in text


def test_actionlint_passes():
    actionlint = shutil.which("actionlint")
    if not actionlint:
        pytest.skip("actionlint not installed")
    proc = subprocess.run(
        [actionlint, str(WORKFLOW)], capture_output=True, text=True
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr


# --- act-based end-to-end cases -----------------------------------------

ACT_CASES = [
    {
        "id": "all-approved",
        "manifest": "fixtures/all-approved.package.json",
        "licenses": "fixtures/all-approved.licenses.json",
        "expect_success": True,
        "expect_substrings": [
            "left-pad@1.3.0",
            "react@18.2.0",
            "lodash@4.17.21",
            "approved: 3",
            "denied: 0",
            "unknown: 0",
            "All dependencies pass policy.",
        ],
        "forbid_substrings": ["DENIED"],
    },
    {
        "id": "has-denied",
        "manifest": "fixtures/has-denied.package.json",
        "licenses": "fixtures/has-denied.licenses.json",
        "expect_success": False,
        "expect_substrings": [
            "good-pkg@1.0.0",
            "evil-gpl@2.0.0",
            "status=DENIED",
            "mystery-pkg@0.1.0",
            "status=UNKNOWN",
            "approved: 1",
            "denied: 1",
            "unknown: 1",
            "License check failed with exit code 1",
        ],
        "forbid_substrings": [],
    },
    {
        "id": "python-requirements",
        "manifest": "fixtures/python-app.requirements.txt",
        "licenses": "fixtures/python-app.licenses.json",
        "expect_success": True,
        "expect_substrings": [
            "requests@2.31.0",
            "flask@>=2.0",
            "numpy@~=1.24",
            "approved: 3",
            "All dependencies pass policy.",
        ],
        "forbid_substrings": ["DENIED"],
    },
]


@pytest.fixture(scope="module", autouse=True)
def reset_act_result():
    # Truncate act-result.txt at the start of the module run; each case appends.
    ACT_RESULT.write_text("")
    yield


def _have_act_and_docker():
    if not shutil.which("act"):
        return False, "act not installed"
    if not shutil.which("docker"):
        return False, "docker not installed"
    proc = subprocess.run(
        ["docker", "info"], capture_output=True, text=True
    )
    if proc.returncode != 0:
        return False, "docker daemon not reachable"
    return True, ""


def _setup_temp_repo(tmp_path: Path, case: dict) -> Path:
    """Stage a minimal repo for `act` containing only the files we need.

    Copying just the project files (not the parent monorepo's .git) keeps act
    fast and reproducible. We initialize a fresh git repo so checkout@v4 has
    something to clone.
    """
    repo = tmp_path / "repo"
    repo.mkdir()
    # Copy required project files.
    for src_rel in [
        "license_checker.py",
        "fixtures",
        "tests",
        ".github",
        ".actrc",
    ]:
        src = ROOT / src_rel
        if not src.exists():
            continue
        dst = repo / src_rel
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Init git repo so actions/checkout has a HEAD to fetch.
    env = {**os.environ, "GIT_AUTHOR_NAME": "act", "GIT_AUTHOR_EMAIL": "a@b.c",
           "GIT_COMMITTER_NAME": "act", "GIT_COMMITTER_EMAIL": "a@b.c"}
    for cmd in [
        ["git", "init", "-q", "-b", "main"],
        ["git", "add", "-A"],
        ["git", "commit", "-q", "-m", f"case:{case['id']}"],
    ]:
        subprocess.run(cmd, cwd=repo, check=True, env=env)
    return repo


def _run_act(repo: Path, case: dict) -> subprocess.CompletedProcess:
    env = {
        **os.environ,
        # Pass the per-case fixture paths through the workflow's env override.
        "MANIFEST": case["manifest"],
        "LICENSES": case["licenses"],
    }
    # `act push` simulates the push trigger; `--rm` reaps containers; we pass
    # MANIFEST/LICENSES via -e so they reach the running step.
    cmd = [
        "act", "push", "--rm",
        # The custom act image is built locally; disable forced pull so act
        # uses the cached image rather than trying to pull from a registry.
        "--pull=false",
        "--env", f"MANIFEST={case['manifest']}",
        "--env", f"LICENSES={case['licenses']}",
        "-W", ".github/workflows/dependency-license-checker.yml",
    ]
    return subprocess.run(cmd, cwd=repo, capture_output=True, text=True, env=env, timeout=600)


def _append_result(case_id: str, proc: subprocess.CompletedProcess):
    sep = "=" * 72
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{sep}\nCASE: {case_id}\nEXIT: {proc.returncode}\n{sep}\n")
        f.write("--- STDOUT ---\n")
        f.write(proc.stdout)
        f.write("\n--- STDERR ---\n")
        f.write(proc.stderr)
        f.write("\n")


@pytest.mark.parametrize("case", ACT_CASES, ids=[c["id"] for c in ACT_CASES])
def test_workflow_via_act(tmp_path, case):
    ok, why = _have_act_and_docker()
    if not ok:
        pytest.skip(why)

    repo = _setup_temp_repo(tmp_path, case)
    proc = _run_act(repo, case)
    _append_result(case["id"], proc)

    output = proc.stdout + proc.stderr

    # Per spec: "all-approved" must exit 0; "has-denied" lets the policy gate
    # fail the job, so act exits non-zero. We still require all preceding
    # steps to print "Job succeeded" for unit-tests in every case.
    if case["expect_success"]:
        assert proc.returncode == 0, (
            f"act exited {proc.returncode} for {case['id']}\n--- output ---\n{output[-4000:]}"
        )
    else:
        assert proc.returncode != 0, "expected non-zero exit for denied case"

    # Every case must show the unit-tests job succeeding (license-check job
    # only succeeds when expect_success).
    job_succeeded_count = len(re.findall(r"Job succeeded", output))
    if case["expect_success"]:
        assert job_succeeded_count >= 2, (
            f"expected both jobs to succeed; saw {job_succeeded_count} 'Job succeeded' markers"
        )
    else:
        assert job_succeeded_count >= 1, (
            "expected unit-tests job to succeed even when license-check fails"
        )

    for needle in case["expect_substrings"]:
        assert needle in output, f"missing expected substring {needle!r} in act output for {case['id']}"
    for forbidden in case["forbid_substrings"]:
        assert forbidden not in output, f"unexpected substring {forbidden!r} in act output for {case['id']}"
