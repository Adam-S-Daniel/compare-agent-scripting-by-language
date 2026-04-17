"""
Workflow structure + act integration tests.

- Structure tests parse the workflow YAML and assert shape/paths/actionlint.
- The act integration test runs the workflow once per fixture scenario, captures
  output to act-result.txt, and asserts exact expected values in the output.

act runs are expensive (30-90s each), so we keep it to the three scenarios the
fixtures cover: basic (no flaky), flaky (1 flaky), mixed (skipped + failed).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

try:
    import yaml  # PyYAML
except ModuleNotFoundError:  # pragma: no cover
    yaml = None


ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "test-results-aggregator.yml"
ACT_RESULT = ROOT / "act-result.txt"


# ---------------- Structure tests ----------------

def test_workflow_file_exists():
    assert WORKFLOW.is_file()


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_has_expected_structure():
    data = yaml.safe_load(WORKFLOW.read_text())
    # YAML's `on` key is parsed as Python `True` by safe_load in some cases.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None, "workflow missing 'on' triggers"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers

    jobs = data["jobs"]
    assert "unit-tests" in jobs
    assert "aggregate" in jobs
    assert jobs["aggregate"].get("needs") == "unit-tests"

    # every job should use actions/checkout@v4 as first step
    for job_name, job in jobs.items():
        steps = job["steps"]
        assert any(s.get("uses") == "actions/checkout@v4" for s in steps), f"{job_name} missing checkout"


def test_workflow_references_existing_script():
    text = WORKFLOW.read_text()
    assert "aggregator.py" in text
    assert (ROOT / "aggregator.py").is_file()
    assert (ROOT / "tests" / "test_aggregator.py").is_file()


def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"


# ---------------- act integration test ----------------

SCENARIOS = [
    # (fixture_subdir, expected substrings in act output)
    ("basic", [
        "Runs: 2",
        "Total: 6",
        "Passed: 6",
        "Failed: 0",
        "Skipped: 0",
        "No flaky tests detected",
    ]),
    ("flaky", [
        "Runs: 3",
        "Total: 6",
        "Passed: 5",
        "Failed: 1",
        "Skipped: 0",
        "- net.test_timeout",
    ]),
    ("mixed", [
        "Runs: 1",
        "Total: 4",
        "Passed: 2",
        "Failed: 1",
        "Skipped: 1",
        "No flaky tests detected",
    ]),
]


def _have_act() -> bool:
    return shutil.which("act") is not None and shutil.which("docker") is not None


def _setup_temp_repo(fixture_subdir: str) -> Path:
    """Create a temp repo containing the project and a single fixture set."""
    tmp = Path(tempfile.mkdtemp(prefix=f"act-{fixture_subdir}-"))
    # Copy project files (keep it minimal to speed up act)
    for name in ("aggregator.py", "tests", ".github", ".actrc"):
        src = ROOT / name
        if not src.exists():
            continue
        dst = tmp / name
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    # Copy only the chosen fixture dir
    fx_dst = tmp / "fixtures" / fixture_subdir
    fx_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / "fixtures" / fixture_subdir, fx_dst)

    # Rewrite workflow env FIXTURE_DIR to point at this scenario
    wf = tmp / ".github" / "workflows" / "test-results-aggregator.yml"
    wf.write_text(wf.read_text().replace("FIXTURE_DIR: fixtures/basic",
                                          f"FIXTURE_DIR: fixtures/{fixture_subdir}"))

    # Init git repo (act needs a git context)
    env = {**os.environ,
           "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=tmp, check=True, env=env)
    return tmp


@pytest.mark.skipif(not _have_act(), reason="act or docker not available")
def test_act_runs_all_scenarios():
    # Reset aggregated log
    ACT_RESULT.write_text("")

    for scenario, expected in SCENARIOS:
        repo = _setup_temp_repo(scenario)
        try:
            proc = subprocess.run(
                ["act", "push", "--rm"],
                cwd=repo, capture_output=True, text=True, timeout=600,
            )
            combined = proc.stdout + "\n" + proc.stderr
            with ACT_RESULT.open("a") as f:
                f.write(f"\n========== scenario: {scenario} ==========\n")
                f.write(f"exit_code: {proc.returncode}\n")
                f.write(combined)
                f.write("\n========== end scenario: {} ==========\n".format(scenario))

            assert proc.returncode == 0, f"act failed for {scenario}:\n{combined[-2000:]}"
            # Both jobs must succeed
            assert combined.count("Job succeeded") >= 2, \
                f"expected 2+ 'Job succeeded' in {scenario}, got:\n{combined[-2000:]}"
            # Exact expected values
            for needle in expected:
                assert needle in combined, f"missing '{needle}' in {scenario} output"
        finally:
            shutil.rmtree(repo, ignore_errors=True)
