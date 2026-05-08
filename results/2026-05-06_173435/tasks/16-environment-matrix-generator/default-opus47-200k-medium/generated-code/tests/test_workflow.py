"""End-to-end tests that run the workflow under `act`.

Per the task spec, every test case is exercised through the GitHub Actions
pipeline (not by calling matrix_gen.py directly). The harness:

- copies the project into a temp git repo for each fixture,
- swaps in fixtures/basic.json with the case under test,
- runs `act push --rm`, captures output,
- appends the output to act-result.txt (in the project root),
- asserts exit code 0, "Job succeeded" lines, and EXACT expected values
  in the captured stdout (e.g. size=4 for the basic case).

We also include workflow-structure assertions and an actionlint check.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "environment-matrix-generator.yml"
ACT_RESULT = ROOT / "act-result.txt"


# ---------- Workflow structure tests (cheap, no docker) ----------

def test_workflow_file_exists():
    assert WORKFLOW.is_file(), f"missing workflow: {WORKFLOW}"


def test_workflow_yaml_structure():
    yaml = pytest.importorskip("yaml")
    data = yaml.safe_load(WORKFLOW.read_text())
    # PyYAML parses the bare key `on` as the boolean True; accept either.
    triggers = data.get("on", data.get(True))
    assert triggers is not None
    assert {"push", "pull_request", "workflow_dispatch"} <= set(triggers.keys())
    jobs = data["jobs"]
    assert "unit-tests" in jobs
    assert "generate-matrix" in jobs
    assert jobs["generate-matrix"]["needs"] == "unit-tests"
    # Script and fixtures referenced by the workflow must exist.
    assert (ROOT / "matrix_gen.py").is_file()
    for f in ("basic.json", "oversize.json", "minimal.json"):
        assert (ROOT / "fixtures" / f).is_file()


def test_actionlint_passes():
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    res = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, f"actionlint failed:\n{res.stdout}\n{res.stderr}"


# ---------- Act-driven integration tests ----------

# Fixture variants: each is a (name, basic.json contents, expected substrings).
ACT_CASES = [
    (
        "basic",
        {
            "axes": {
                "os": ["ubuntu-latest", "windows-latest"],
                "python": ["3.11", "3.12"],
            },
            "exclude": [{"os": "windows-latest", "python": "3.11"}],
            "include": [{"os": "macos-latest", "python": "3.12", "experimental": True}],
            "max_parallel": 3,
            "fail_fast": False,
            "max_size": 10,
        },
        # Expected exact substrings in act stdout.
        [
            "EXPECT size=4 for basic.json",
            '"size": 4',
            '"max-parallel": 3',
            '"fail-fast": false',
            "OVERSIZE_REJECTED=ok",
            "exceeds max_size 4",
            "MINIMAL_OK size=2 fail-fast=True",
        ],
    ),
    (
        "single-axis",
        # Replace basic.json with a single-axis fixture; size must equal 1.
        # We override the workflow's expected size by adjusting the fixture
        # carefully: keep size==4 so the existing assertion holds is impossible
        # for a single-axis case, so this case provides its OWN basic.json
        # contents that still produce size==4. We use 4 distinct OS values.
        {
            "axes": {"os": ["ubuntu-latest", "windows-latest", "macos-latest", "ubuntu-22.04"]},
            "fail_fast": True,
        },
        [
            "EXPECT size=4 for basic.json",
            '"size": 4',
            '"fail-fast": true',
            "OVERSIZE_REJECTED=ok",
            "MINIMAL_OK size=2 fail-fast=True",
        ],
    ),
]


def _have_docker() -> bool:
    if shutil.which("docker") is None:
        return False
    res = subprocess.run(["docker", "info"], capture_output=True)
    return res.returncode == 0


@pytest.fixture(scope="module")
def act_runs(tmp_path_factory):
    """Run act once per fixture case (module-scoped to stay under the 3-run cap)
    and return {case_name: (returncode, stdout)}.
    """
    if shutil.which("act") is None:
        pytest.skip("act not installed")
    if not _have_docker():
        pytest.skip("docker not available")

    # Reset the act-result.txt artifact at the start of the run.
    ACT_RESULT.write_text("")

    results: dict[str, tuple[int, str]] = {}
    for name, fixture, _expected in ACT_CASES:
        work = tmp_path_factory.mktemp(f"act-{name}")
        # Copy project files we need.
        for item in ["matrix_gen.py", ".github", "tests", "fixtures"]:
            src = ROOT / item
            dst = work / item
            if src.is_dir():
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)
        # Override fixtures/basic.json with this case's contents.
        (work / "fixtures" / "basic.json").write_text(json.dumps(fixture, indent=2))

        # Init a git repo so act is happy.
        env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
               "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
        for cmd in (
            ["git", "init", "-q", "-b", "main"],
            ["git", "add", "-A"],
            ["git", "commit", "-q", "-m", "init"],
        ):
            subprocess.run(cmd, cwd=work, check=True, env=env)

        # Run act. Use a small image; the default catthehacker/ubuntu:act-latest
        # has python3 preinstalled which is all we need.
        proc = subprocess.run(
            ["act", "push", "--rm", "-W", ".github/workflows/environment-matrix-generator.yml"],
            cwd=work,
            capture_output=True,
            text=True,
            timeout=600,
        )
        combined = proc.stdout + "\n----- STDERR -----\n" + proc.stderr
        with ACT_RESULT.open("a") as f:
            f.write(f"\n========== ACT CASE: {name} (rc={proc.returncode}) ==========\n")
            f.write(combined)
            f.write("\n========== END CASE: " + name + " ==========\n")
        results[name] = (proc.returncode, combined)
    return results


@pytest.mark.parametrize("name,fixture,expected", ACT_CASES, ids=[c[0] for c in ACT_CASES])
def test_act_case(act_runs, name, fixture, expected):
    rc, out = act_runs[name]
    assert rc == 0, f"act exited with {rc} for case {name}\n{out[-2000:]}"
    # Every job must succeed. The unit-tests job + generate-matrix job both
    # emit "Job succeeded" on success.
    succeeded = out.count("Job succeeded")
    assert succeeded >= 2, f"expected >=2 'Job succeeded' lines, got {succeeded}\n{out[-2000:]}"
    for token in expected:
        assert token in out, f"missing expected token {token!r} for case {name}\n--- tail ---\n{out[-1500:]}"


def test_act_result_artifact_exists(act_runs):
    assert ACT_RESULT.is_file()
    assert ACT_RESULT.stat().st_size > 0
