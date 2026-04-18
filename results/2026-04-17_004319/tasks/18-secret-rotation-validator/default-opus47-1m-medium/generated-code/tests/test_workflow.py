"""End-to-end tests that exercise the script *through* the GitHub Actions
workflow via `act`, plus structural checks on the workflow YAML itself.

The harness builds a fresh temp git repo for each test case, drops in a
fixture, runs `act push --rm`, captures the output, and asserts on exact
expected values. Each run's output is appended to act-result.txt so the
final artifact contains every case clearly delimited.
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

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "secret-rotation-validator.yml"
ACT_RESULT = REPO_ROOT / "act-result.txt"


# --- Workflow structure tests ----------------------------------------------

def test_workflow_file_exists():
    assert WORKFLOW.is_file(), f"Missing workflow at {WORKFLOW}"


def test_workflow_yaml_valid_and_has_expected_structure():
    """Parse the YAML and verify triggers/jobs/steps line up with the spec."""
    with open(WORKFLOW) as f:
        data = yaml.safe_load(f)
    # PyYAML parses the `on:` key as the boolean True — accept either.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None
    for trig in ("push", "pull_request", "schedule", "workflow_dispatch"):
        assert trig in triggers, f"Missing trigger: {trig}"

    assert "validate" in data["jobs"]
    steps = data["jobs"]["validate"]["steps"]
    step_names = [s.get("name", "") for s in steps]
    assert "Checkout" in step_names
    assert any("Python" in n for n in step_names)
    assert any("Run validator" in n for n in step_names)


def test_workflow_references_existing_files():
    """Files referenced by the workflow must actually exist in the repo."""
    assert (REPO_ROOT / "secret_validator.py").is_file()
    assert (REPO_ROOT / "tests").is_dir()
    assert (REPO_ROOT / "fixtures" / "sample-secrets.json").is_file()


def test_actionlint_passes():
    """actionlint must accept the workflow with exit code 0."""
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )


# --- act-based end-to-end tests --------------------------------------------

# Each case: name, secrets fixture, expected substrings in act output,
# expected substrings that must NOT appear, and whether to expect "Job succeeded".
CASES = [
    {
        "name": "expired-secret-fails-build",
        "fixture": {
            "secrets": [
                {"name": "very-old-key", "last_rotated": "2026-01-01",
                 "rotation_days": 30, "services": ["api"]},
            ]
        },
        # The validator exits 1 on expired, but the workflow swallows it
        # ("|| EXIT=$?") so the job still succeeds and reports the exit.
        "must_contain": [
            "very-old-key",
            "## Expired",
            "validator exited with: 1",
            '"expired": 1',
            "Job succeeded",
        ],
        "must_not_contain": ["## OK"],
    },
    {
        "name": "all-ok",
        "fixture": {
            "secrets": [
                {"name": "fresh-key", "last_rotated": "2026-04-15",
                 "rotation_days": 90, "services": ["web"]},
            ]
        },
        "must_contain": [
            "fresh-key",
            "## OK",
            "validator exited with: 0",
            '"ok": 1',
            "Job succeeded",
        ],
        "must_not_contain": ["## Expired", "## Warning"],
    },
    {
        "name": "warning-window",
        "fixture": {
            "secrets": [
                {"name": "due-soon", "last_rotated": "2026-03-23",
                 "rotation_days": 30, "services": ["billing"]},
            ]
        },
        "must_contain": [
            "due-soon",
            "## Warning",
            "5d remaining",
            '"warning": 1',
            "Job succeeded",
        ],
        "must_not_contain": ["## Expired"],
    },
]


def _run_act_for_case(case: dict, tmp_path: Path) -> tuple[int, str]:
    """Build an isolated git repo containing the project + this case's fixture,
    run `act push --rm`, and return (exit_code, combined_output)."""
    # Stage project files into a temp dir.
    work = tmp_path / case["name"]
    work.mkdir()
    for item in ["secret_validator.py", "tests", ".github"]:
        src = REPO_ROOT / item
        dst = work / item
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    # Fixture for this case.
    (work / "fixtures").mkdir()
    fixture_path = work / "fixtures" / "sample-secrets.json"
    fixture_path.write_text(json.dumps(case["fixture"], indent=2))
    # Copy .actrc if present so we use the same image config.
    actrc = REPO_ROOT / ".actrc"
    if actrc.is_file():
        shutil.copy2(actrc, work / ".actrc")

    # Initialize a minimal git repo (act expects one).
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=work, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=work, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=work, check=True, env=env)

    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=work, capture_output=True, text=True, env=env, timeout=600,
    )
    return proc.returncode, proc.stdout + "\n" + proc.stderr


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    """Truncate act-result.txt at the start of the module run."""
    ACT_RESULT.write_text("")
    yield


@pytest.mark.skipif(shutil.which("act") is None, reason="act not installed")
@pytest.mark.parametrize("case", CASES, ids=[c["name"] for c in CASES])
def test_act_runs_workflow(case, tmp_path):
    rc, output = _run_act_for_case(case, tmp_path)

    # Always append, even on failure, so the artifact captures everything.
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{'=' * 70}\n=== CASE: {case['name']}\n{'=' * 70}\n")
        f.write(output)
        f.write(f"\n[exit code: {rc}]\n")

    assert rc == 0, f"act exited {rc} for {case['name']}\n{output[-2000:]}"
    for needle in case["must_contain"]:
        assert needle in output, (
            f"Expected substring not found for {case['name']}: {needle!r}\n"
            f"--- output tail ---\n{output[-2000:]}"
        )
    for needle in case["must_not_contain"]:
        assert needle not in output, (
            f"Forbidden substring present for {case['name']}: {needle!r}"
        )


def test_act_result_file_exists_after_runs():
    """Sanity check that the required artifact exists."""
    assert ACT_RESULT.is_file()
    assert ACT_RESULT.stat().st_size > 0
