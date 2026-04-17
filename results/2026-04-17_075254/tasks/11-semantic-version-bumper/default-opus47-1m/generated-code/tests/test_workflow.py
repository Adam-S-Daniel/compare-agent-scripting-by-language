"""End-to-end workflow tests through `act`.

Each test case:
  1. Builds a temp git repo containing the script, workflow, and a fixture.
  2. Runs `act push --rm` inside it.
  3. Appends output to act-result.txt (at the project root).
  4. Asserts exit code 0, exact expected new version, and "Job succeeded".

Also validates workflow YAML structure and runs actionlint.
"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[1]
FIXTURES = PROJECT_ROOT / "fixtures"
WORKFLOW = PROJECT_ROOT / ".github/workflows/semantic-version-bumper.yml"
ACT_RESULT = PROJECT_ROOT / "act-result.txt"


# ---------- structural tests (fast, no docker) ----------

def test_workflow_yaml_parses_and_has_expected_structure():
    data = yaml.safe_load(WORKFLOW.read_text())
    # `on:` is parsed as True by PyYAML (YAML 1.1 boolean). Accept either key.
    triggers = data.get("on", data.get(True))
    assert triggers is not None
    for t in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert t in triggers, f"missing trigger: {t}"
    assert "bump" in data["jobs"]
    steps = data["jobs"]["bump"]["steps"]
    uses = [s.get("uses") for s in steps if s.get("uses")]
    assert "actions/checkout@v4" in uses
    assert any(u.startswith("actions/setup-python@") for u in uses)


def test_workflow_references_existing_script():
    text = WORKFLOW.read_text()
    assert "bumper.py" in text
    assert (PROJECT_ROOT / "bumper.py").exists()


def test_actionlint_passes():
    r = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert r.returncode == 0, f"actionlint failed:\n{r.stdout}\n{r.stderr}"


# ---------- act-based e2e tests ----------

CASES = [
    # (name, fixture_dir, expected_new_version, verify_file_name)
    ("feat_minor_bump", "feat", "1.2.0", "version.txt"),
    ("breaking_major_bump", "breaking", "1.0.0", "version.txt"),
    ("package_json_feat", "pkgjson", "3.5.0", "package.json"),
]


def _have_docker() -> bool:
    try:
        r = subprocess.run(["docker", "info"], capture_output=True, timeout=10)
        return r.returncode == 0
    except Exception:
        return False


def _build_repo(dest: Path, fixture: str) -> None:
    """Assemble a temp workspace: script + workflow + fixture files."""
    # Script and workflow
    shutil.copy(PROJECT_ROOT / "bumper.py", dest / "bumper.py")
    wf_dir = dest / ".github" / "workflows"
    wf_dir.mkdir(parents=True)
    shutil.copy(WORKFLOW, wf_dir / WORKFLOW.name)
    # Use custom act image pre-cached on this machine
    (dest / ".actrc").write_text(
        "-P ubuntu-latest=act-ubuntu-pwsh:latest\n--pull=false\n"
    )
    # Fixture files copied to repo root
    src = FIXTURES / fixture
    for item in src.iterdir():
        shutil.copy(item, dest / item.name)
    # `act` requires a git repo to run `push` events
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=dest, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=dest, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=dest, check=True)
    subprocess.run(["git", "add", "-A"], cwd=dest, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "init"], cwd=dest, check=True,
    )


def _append_result(name: str, rc: int, stdout: str, stderr: str) -> None:
    sep = "=" * 72
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{sep}\nCASE: {name}  exit={rc}\n{sep}\n")
        f.write("--- STDOUT ---\n")
        f.write(stdout)
        f.write("\n--- STDERR ---\n")
        f.write(stderr)
        f.write("\n")


@pytest.fixture(scope="session", autouse=True)
def _reset_act_result():
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    yield


@pytest.mark.skipif(not _have_docker(), reason="docker/act unavailable")
@pytest.mark.parametrize("name,fixture,expected,vfile", CASES)
def test_act_pipeline_case(tmp_path, name, fixture, expected, vfile):
    repo = tmp_path / "repo"
    repo.mkdir()
    _build_repo(repo, fixture)

    r = subprocess.run(
        ["act", "push", "--rm"],
        cwd=repo, capture_output=True, text=True, timeout=300,
    )
    _append_result(name, r.returncode, r.stdout, r.stderr)

    assert r.returncode == 0, f"act failed for {name} (see act-result.txt)"
    assert "Job succeeded" in r.stdout, f"no 'Job succeeded' for {name}"
    # Exact expected version must appear in the RESULT line the workflow prints
    assert f"RESULT_VERSION={expected}" in r.stdout, (
        f"expected RESULT_VERSION={expected} for {name}"
    )
    # The printed NEW_VERSION= line from the script also must match exactly
    assert f"NEW_VERSION={expected}" in r.stdout
