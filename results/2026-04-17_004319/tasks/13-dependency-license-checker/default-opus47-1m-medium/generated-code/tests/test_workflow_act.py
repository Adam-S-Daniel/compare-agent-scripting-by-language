"""End-to-end test harness: every case runs through the GitHub Actions workflow
via `act`. For each case we build a temp git repo with the project files + that
case's fixtures, invoke `act push --rm`, capture combined stdout/stderr into
`act-result.txt`, and assert on exact values in the captured output.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
ACT_RESULT = ROOT / "act-result.txt"
WORKFLOW = ROOT / ".github/workflows/dependency-license-checker.yml"


# -------- workflow structure tests (fast, no Docker) --------

def test_actionlint_passes():
    """actionlint must pass cleanly on the workflow file."""
    rc = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert rc.returncode == 0, rc.stdout + rc.stderr


def test_workflow_yaml_structure():
    data = yaml.safe_load(WORKFLOW.read_text())
    # 'on' gets parsed by yaml as True (the bareword) — account for both keys.
    on_key = True if True in data else "on"
    triggers = data[on_key]
    for t in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert t in triggers, f"missing trigger: {t}"
    assert "license-check" in data["jobs"]
    steps = data["jobs"]["license-check"]["steps"]
    step_names = [s.get("name") for s in steps]
    assert "Checkout" in step_names
    assert "Run unit tests" in step_names
    assert "Run license compliance check" in step_names
    assert any("actions/checkout@v4" == s.get("uses") for s in steps)
    assert data["permissions"]["contents"] == "read"


def test_workflow_references_existing_script_files():
    """Every file the workflow steps reference must exist in the repo."""
    for rel in ("license_checker.py", "tests", "fixtures/package.json",
                "fixtures/config.json", "fixtures/licenses.json",
                "fixtures/expected.txt"):
        assert (ROOT / rel).exists(), f"missing referenced file: {rel}"


# -------- act-driven end-to-end tests --------

def _have_act_and_docker() -> bool:
    if not shutil.which("act") or not shutil.which("docker"):
        return False
    rc = subprocess.run(["docker", "info"], capture_output=True)
    return rc.returncode == 0


CASES = [
    {
        "id": "mixed-noncompliant",
        "description": "approved+denied+unknown -> not compliant",
        "package_json": {
            "name": "demo", "version": "1.0.0",
            "dependencies": {"lodash": "4.17.21", "mystery-lib": "0.1.0"},
            "devDependencies": {"badlib": "2.0.0"},
        },
        "config": {"allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"]},
        "licenses": {"lodash": "MIT", "badlib": "GPL-3.0"},
        "expected_compliant": "false",
        "expected_approved": 1,
        "expected_denied": 1,
        "expected_unknown": 1,
    },
    {
        "id": "all-approved",
        "description": "all MIT -> compliant",
        "package_json": {
            "name": "demo", "version": "1.0.0",
            "dependencies": {"lodash": "4.17.21", "left-pad": "1.3.0"},
        },
        "config": {"allow": ["MIT"], "deny": ["GPL-3.0"]},
        "licenses": {"lodash": "MIT", "left-pad": "MIT"},
        "expected_compliant": "true",
        "expected_approved": 2,
        "expected_denied": 0,
        "expected_unknown": 0,
    },
    {
        "id": "unknown-only-compliant",
        "description": "all unknowns, but no denied -> still compliant",
        "package_json": {
            "name": "demo", "version": "1.0.0",
            "dependencies": {"mystery-a": "1.0.0", "mystery-b": "2.0.0"},
        },
        "config": {"allow": ["MIT"], "deny": ["GPL-3.0"]},
        "licenses": {},
        "expected_compliant": "true",
        "expected_approved": 0,
        "expected_denied": 0,
        "expected_unknown": 2,
    },
]


def _prepare_case_repo(tmp: Path, case: dict) -> None:
    """Copy project files, then overlay this case's fixtures + init a git repo."""
    import json as _json

    # Copy everything we need from the real project into tmp.
    for item in ("license_checker.py", "tests", ".github", ".actrc"):
        src = ROOT / item
        if not src.exists():
            continue
        dst = tmp / item
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Overlay fixtures for this case.
    fixtures = tmp / "fixtures"
    fixtures.mkdir(parents=True, exist_ok=True)
    (fixtures / "package.json").write_text(_json.dumps(case["package_json"], indent=2))
    (fixtures / "config.json").write_text(_json.dumps(case["config"], indent=2))
    (fixtures / "licenses.json").write_text(_json.dumps(case["licenses"], indent=2))
    (fixtures / "expected.txt").write_text(case["expected_compliant"] + "\n")

    # act requires a git repo at workspace root.
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=tmp, check=True, env=env)


def _append_result(case_id: str, header: str, body: str) -> None:
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{'='*72}\n")
        f.write(f"CASE: {case_id}\n")
        f.write(f"{header}\n")
        f.write(f"{'='*72}\n")
        f.write(body)
        f.write("\n")


# Clear act-result.txt once per test session, before any act runs.
@pytest.fixture(scope="session", autouse=True)
def _reset_act_result():
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.write_text(f"act results for dependency-license-checker\n")


@pytest.mark.skipif(not _have_act_and_docker(), reason="act or docker not available")
@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_act_case(tmp_path, case):
    _prepare_case_repo(tmp_path, case)
    proc = subprocess.run(
        ["act", "push", "--rm"],
        cwd=tmp_path,
        capture_output=True, text=True,
        timeout=600,
    )
    combined = proc.stdout + "\n--- STDERR ---\n" + proc.stderr
    _append_result(case["id"], f"exit_code={proc.returncode}", combined)

    # 1. act must exit zero
    assert proc.returncode == 0, f"act exited {proc.returncode}. Output saved."

    # 2. Every job must report success.
    assert "Job succeeded" in combined, "Job did not succeed"

    # 3. Exact expected values in workflow output.
    expected_line = (
        f"RESULT compliant={case['expected_compliant']} "
        f"approved={case['expected_approved']} "
        f"denied={case['expected_denied']} "
        f"unknown={case['expected_unknown']}"
    )
    assert expected_line in combined, (
        f"Expected line not found:\n  {expected_line}\n"
        f"(see act-result.txt)"
    )
