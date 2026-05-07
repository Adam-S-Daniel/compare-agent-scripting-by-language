"""End-to-end workflow tests.

Each test case spins up a temporary git repo containing the project files
plus that case's fixture, runs `act push --rm`, captures all output to
``act-result.txt``, and asserts on EXACT expected values parsed from the
output. Per the task spec, every test case must execute through the GHA
workflow via act -- we don't shortcut by invoking the script directly.

To stay within the "at most 3 act push runs" budget, the runner does ONE
`act push` per fixture and two fixtures (`simple.json`, `with_excludes.json`)
are exercised. Workflow-structure tests are static and use no act runs.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "environment-matrix-generator.yml"
ACT_RESULT = ROOT / "act-result.txt"


# ---------- Static workflow-structure tests (no act) ------------------------

def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"workflow not found at {WORKFLOW}"


def test_workflow_yaml_parses_and_has_expected_structure():
    with WORKFLOW.open() as fh:
        data = yaml.safe_load(fh)
    # PyYAML sometimes parses `on:` as bool True. Accept either.
    triggers = data.get("on") if "on" in data else data.get(True)
    assert triggers is not None, "workflow has no triggers"
    for t in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert t in triggers, f"missing trigger: {t}"
    jobs = data["jobs"]
    for job in ("unit-tests", "generate-matrix", "summary"):
        assert job in jobs, f"missing job: {job}"
    # generate-matrix and summary should chain
    assert jobs["generate-matrix"]["needs"] == "unit-tests"
    assert jobs["summary"]["needs"] == "generate-matrix"


def test_workflow_references_real_script_paths():
    text = WORKFLOW.read_text()
    assert "matrix_generator.py" in text
    assert (ROOT / "matrix_generator.py").exists()
    assert (ROOT / "tests").is_dir()
    assert (ROOT / "fixtures" / "simple.json").exists()


def test_actionlint_passes():
    rc = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
    )
    assert rc.returncode == 0, (
        f"actionlint failed:\nstdout={rc.stdout}\nstderr={rc.stderr}"
    )


# ---------- act runner ------------------------------------------------------

def _have_act() -> bool:
    return shutil.which("act") is not None and shutil.which("docker") is not None


def _run_act_for_fixture(fixture: str, tmp_path: Path) -> tuple[int, str]:
    """Build an isolated git repo, run `act push --rm`, return (rc, output)."""
    workdir = tmp_path / fixture.replace(".json", "")
    workdir.mkdir()
    # Copy required project files into the isolated workdir.
    for rel in [
        "matrix_generator.py",
        "tests",
        "fixtures",
        ".github",
        ".actrc",
    ]:
        src = ROOT / rel
        if not src.exists():
            continue
        dst = workdir / rel
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    # Write a tiny fixture-selector file that the workflow reads via env.
    # We instead set FIXTURE through a per-run env file for `act`.
    env_file = workdir / "act.env"
    env_file.write_text(f"FIXTURE={fixture}\n")

    # init a git repo (act requires one)
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(
        ["git", "-c", "user.email=t@e", "-c", "user.name=t", "add", "-A"],
        cwd=workdir, check=True,
    )
    subprocess.run(
        ["git", "-c", "user.email=t@e", "-c", "user.name=t",
         "commit", "-q", "-m", "init"],
        cwd=workdir, check=True,
    )

    cmd = [
        "act", "push", "--rm",
        "--pull=false",
        "--env-file", str(env_file),
    ]
    proc = subprocess.run(
        cmd, cwd=workdir, capture_output=True, text=True, timeout=600,
    )
    output = (
        f"===== ACT RUN: fixture={fixture} =====\n"
        f"--- cmd: {' '.join(cmd)}\n"
        f"--- stdout ---\n{proc.stdout}\n"
        f"--- stderr ---\n{proc.stderr}\n"
        f"--- rc: {proc.returncode}\n"
        f"===== END: fixture={fixture} =====\n\n"
    )
    return proc.returncode, output


def _append_act_result(text: str) -> None:
    with ACT_RESULT.open("a") as fh:
        fh.write(text)


@pytest.fixture(scope="session", autouse=True)
def _truncate_act_result():
    # Start fresh each session so the file represents the latest run.
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.touch()
    yield


@pytest.mark.skipif(not _have_act(), reason="act / docker not available")
@pytest.mark.parametrize(
    "fixture,expected_count,expected_max_parallel,expected_fail_fast",
    [
        # simple.json: 2 OS x 2 python = 4 entries, max-parallel=4, fail-fast=true
        ("simple.json", 4, 4, True),
        # with_excludes.json:
        #   3 OS x 2 node x 2 feature = 12 base
        #   - exclude windows+minimal (2 entries)
        #   - exclude macos+node18 (2 entries)
        #   + include 1 extra
        #   = 12 - 4 + 1 = 9
        ("with_excludes.json", 9, 6, False),
    ],
)
def test_act_run_produces_expected_matrix(
    fixture, expected_count, expected_max_parallel,
    expected_fail_fast, tmp_path,
):
    rc, output = _run_act_for_fixture(fixture, tmp_path)
    _append_act_result(output)

    assert rc == 0, f"act exited with rc={rc} for {fixture}"

    # Every job must report success.
    assert "Job succeeded" in output, "no 'Job succeeded' marker found"
    # Three jobs should have succeeded -> three success markers.
    success_count = output.count("Job succeeded")
    assert success_count >= 3, (
        f"expected >=3 'Job succeeded' markers, got {success_count}"
    )

    # The verify job prints VERIFY_OK on success.
    assert "VERIFY_OK" in output, "summary job did not print VERIFY_OK"

    # Extract the printed matrix JSON. act prefixes every step-output line
    # with "[workflow/job-name]   | ", so strip that before parsing. We
    # walk the lines, find the BEGIN marker, then the next line containing
    # JSON ('{') is the matrix payload.
    lines = output.splitlines()
    matrix_line = None
    in_block = False
    for line in lines:
        # Drop the act log prefix "[...] " and pipe " | " if present.
        stripped = re.sub(r"^\[[^\]]+\]\s*\|?\s*", "", line).strip()
        if "MATRIX_OUTPUT_BEGIN" in stripped:
            in_block = True
            continue
        if "MATRIX_OUTPUT_END" in stripped:
            in_block = False
            continue
        if in_block and stripped.startswith("{"):
            matrix_line = stripped
            break
    assert matrix_line, "matrix JSON not found between BEGIN/END markers"
    matrix = json.loads(matrix_line)

    # Exact-value assertions.
    assert len(matrix["include"]) == expected_count, (
        f"{fixture}: expected {expected_count} entries, got "
        f"{len(matrix['include'])}: {matrix['include']}"
    )
    assert matrix["fail-fast"] is expected_fail_fast
    assert matrix["max-parallel"] == expected_max_parallel

    # Also assert we see the explicit INCLUDE_COUNT marker matching.
    count_match = re.search(r"INCLUDE_COUNT=(\d+)", output)
    assert count_match, "INCLUDE_COUNT marker missing"
    assert int(count_match.group(1)) == expected_count
