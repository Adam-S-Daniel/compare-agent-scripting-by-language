"""End-to-end tests that execute the workflow under act.

This is the required integration layer: every test case runs through the
real pipeline via `act push --rm`, and we assert on EXACT expected values
parsed out of the VERIFY: line the workflow prints.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "semantic-version-bumper.yml"
ACT_RESULT_FILE = ROOT / "act-result.txt"

# Each test case specifies a fixture name and the exact expected outputs.
# The harness runs all three in a single `act push` invocation per case.
@dataclass(frozen=True)
class Case:
    name: str
    fixture: str
    expected_bump: str
    expected_new_version: str


CASES = [
    Case("minor", "minor-bump", "minor", "1.2.0"),
    Case("patch", "patch-bump", "patch", "2.4.8"),
    Case("major", "major-bump", "major", "2.0.0"),
    Case("none",  "no-bump",    "none",  "3.0.0"),
]


# --- Workflow-structure tests (no docker required) --------------------------

def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True, cwd=ROOT,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout={result.stdout}\nstderr={result.stderr}"
    )


def test_workflow_has_expected_structure():
    data = yaml.safe_load(WORKFLOW.read_text())
    # PyYAML parses `on` as Python True because YAML 1.1 booleans — accept either.
    on = data.get("on") or data.get(True)
    assert on is not None, "workflow missing 'on' section"
    assert set(on.keys()) >= {"push", "pull_request", "workflow_dispatch"}

    assert "bump" in data["jobs"]
    steps = data["jobs"]["bump"]["steps"]
    uses = [s.get("uses") for s in steps if "uses" in s]
    assert "actions/checkout@v4" in uses

    step_names = [s.get("name", "") for s in steps]
    assert any("Run bumper" in n for n in step_names)

    # Validate the run scripts reference files that actually exist on disk.
    full_text = WORKFLOW.read_text()
    assert "bumper.py" in full_text
    assert (ROOT / "bumper.py").exists()
    assert "fixtures/${FIXTURE_NAME}" in full_text
    for case in CASES:
        assert (ROOT / "fixtures" / case.fixture).is_dir(), (
            f"fixture dir missing: {case.fixture}"
        )


# --- act integration --------------------------------------------------------

def _have_docker() -> bool:
    return shutil.which("docker") is not None and subprocess.run(
        ["docker", "info"], capture_output=True
    ).returncode == 0


def _have_act() -> bool:
    return shutil.which("act") is not None


@pytest.fixture(scope="module")
def act_results() -> dict[str, tuple[int, str]]:
    """Run the workflow under act once per fixture and return raw outputs.

    Module-scoped so we only pay the container startup cost four times total.
    Writes every run's output to act-result.txt (required artifact).
    """
    if not _have_act():
        pytest.skip("act is not installed")
    if not _have_docker():
        pytest.skip("docker is not available")

    # Start with an empty act-result.txt — we APPEND each case delimited.
    ACT_RESULT_FILE.write_text("")
    results: dict[str, tuple[int, str]] = {}

    for case in CASES:
        workdir = _make_temp_repo(case)
        try:
            completed = subprocess.run(
                ["act", "push", "--rm",
                 "--pull=false",
                 "-P", "ubuntu-latest=act-ubuntu-pwsh:latest",
                 "--env", f"FIXTURE={case.fixture}",
                 "-W", ".github/workflows/semantic-version-bumper.yml"],
                cwd=workdir,
                capture_output=True, text=True,
                timeout=300,
            )
            combined = (
                f"=== CASE: {case.name} (fixture={case.fixture}) ===\n"
                f"--- exit_code: {completed.returncode} ---\n"
                f"--- stdout ---\n{completed.stdout}\n"
                f"--- stderr ---\n{completed.stderr}\n"
                f"=== END CASE: {case.name} ===\n\n"
            )
            # APPEND — we want every case's output visible in the artifact.
            with ACT_RESULT_FILE.open("a") as f:
                f.write(combined)
            results[case.name] = (completed.returncode, completed.stdout + completed.stderr)
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    return results


def _make_temp_repo(case: Case) -> Path:
    """Materialize a temp git repo containing only what this case needs."""
    import tempfile
    workdir = Path(tempfile.mkdtemp(prefix=f"act-{case.name}-"))

    # Ship bumper.py, the workflow, the test fixtures, and the .actrc pin.
    (workdir / ".github" / "workflows").mkdir(parents=True)
    shutil.copy2(WORKFLOW, workdir / ".github" / "workflows" / WORKFLOW.name)
    shutil.copy2(ROOT / "bumper.py", workdir / "bumper.py")
    shutil.copy2(ROOT / ".actrc", workdir / ".actrc")

    # Copy ALL fixtures so any FIXTURE value resolves; keeps the workflow generic.
    shutil.copytree(ROOT / "fixtures", workdir / "fixtures")
    # Tests dir (for the inline pytest step in the workflow).
    shutil.copytree(ROOT / "tests", workdir / "tests",
                    ignore=shutil.ignore_patterns("test_workflow_act.py", "__pycache__"))

    # Initialize a minimal git repo so act has push context.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=workdir, check=True)
    subprocess.run(["git", "add", "."], cwd=workdir, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "fixture"], cwd=workdir, check=True)
    return workdir


@pytest.mark.parametrize("case", CASES, ids=[c.name for c in CASES])
def test_act_run_produces_expected_version(act_results, case: Case):
    rc, combined = act_results[case.name]
    assert rc == 0, f"act exit code {rc} for case {case.name}:\n{combined[-2000:]}"

    # Every job in the workflow must report success.
    assert "Job succeeded" in combined, (
        f"no 'Job succeeded' marker for case {case.name}"
    )

    # Parse the VERIFY: line and assert EXACT expected values.
    pat = re.compile(
        r"VERIFY:\s+fixture=(\S+)\s+bump_type=(\S+)\s+new_version=(\S+)"
    )
    match = None
    for line in combined.splitlines():
        m = pat.search(line)
        if m:
            match = m
            break
    assert match is not None, (
        f"no VERIFY: line in act output for case {case.name}"
    )
    assert match.group(1) == case.fixture
    assert match.group(2) == case.expected_bump
    assert match.group(3) == case.expected_new_version


def test_act_result_file_exists():
    assert ACT_RESULT_FILE.exists(), "act-result.txt must exist after the suite"
    content = ACT_RESULT_FILE.read_text()
    # Every case should have a section in the file.
    for case in CASES:
        assert f"CASE: {case.name}" in content, (
            f"act-result.txt missing section for case {case.name}"
        )
