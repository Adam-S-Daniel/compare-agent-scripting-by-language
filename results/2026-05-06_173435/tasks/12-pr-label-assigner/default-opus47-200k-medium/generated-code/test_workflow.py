"""Act-driven workflow tests.

For each test case we materialize a temp git repo with the project files plus
a fixture changed-files list, run `act push --rm`, and assert on exact output.

We aim for at most one act run per case, and we keep the case count to 3 so
the total budget stays within the limit specified by the task.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml as _yaml_optional  # noqa: F401  pytest will skip elegantly if missing


HERE = Path(__file__).parent.resolve()
ACT_RESULT = HERE / "act-result.txt"
PROJECT_FILES = [
    "label_assigner.py",
    "test_label_assigner.py",
    "rules.yml",
    ".github/workflows/pr-label-assigner.yml",
    ".actrc",
]


CASES = [
    {
        "name": "docs_only",
        "files": ["docs/intro.md", "README.md"],
        "expected_labels": ["documentation"],
    },
    {
        "name": "api_test_mix",
        # Matches: tests (30), api (20), backend (5)
        "files": ["src/api/users.test.py", "src/api/v1/orders.py"],
        "expected_labels": ["tests", "api", "backend"],
    },
    {
        "name": "ci_and_docs",
        "files": [".github/workflows/foo.yml", "docs/howto.md"],
        "expected_labels": ["ci", "documentation"],
    },
]


def _have_tools() -> bool:
    return shutil.which("act") is not None and shutil.which("docker") is not None


pytestmark = pytest.mark.skipif(not _have_tools(), reason="act/docker not installed")


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    ACT_RESULT.write_text("")  # truncate at the start of the run
    yield


def _setup_repo(workdir: Path, fixture_files: list[str]) -> None:
    workdir.mkdir(parents=True, exist_ok=True)
    for rel in PROJECT_FILES:
        src = HERE / rel
        dst = workdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    (workdir / "changed-files.txt").write_text("\n".join(fixture_files) + "\n")
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "add", "."], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=workdir, check=True, env=env)


def _append_result(case_name: str, header: str, body: str) -> None:
    with ACT_RESULT.open("a") as fh:
        fh.write(f"\n===== CASE: {case_name} =====\n")
        fh.write(header + "\n")
        fh.write(body)
        fh.write(f"\n===== END CASE: {case_name} =====\n")


@pytest.mark.parametrize("case", CASES, ids=[c["name"] for c in CASES])
def test_workflow_case(case, tmp_path):
    repo = tmp_path / "repo"
    _setup_repo(repo, case["files"])

    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = proc.stdout + "\n--- STDERR ---\n" + proc.stderr
    _append_result(case["name"], f"exit={proc.returncode}", combined)

    assert proc.returncode == 0, f"act exited {proc.returncode}; see act-result.txt"
    assert "Job succeeded" in combined, "expected 'Job succeeded' in act output"

    # Exact-value assertion on the script output. The workflow prints a line
    # of the form "ASSIGN_RESULT::{json}" — extract and compare.
    m = re.search(r"ASSIGN_RESULT::(\{[^}]*\})", combined)
    assert m, "ASSIGN_RESULT not found in workflow output"
    payload = json.loads(m.group(1))
    assert payload["labels"] == case["expected_labels"], (
        f"labels mismatch: got {payload['labels']!r} expected {case['expected_labels']!r}"
    )
    assert payload["count"] == len(case["expected_labels"])


def test_actionlint_passes():
    res = subprocess.run(
        ["actionlint", str(HERE / ".github/workflows/pr-label-assigner.yml")],
        capture_output=True, text=True,
    )
    assert res.returncode == 0, res.stdout + res.stderr


def test_workflow_structure():
    import yaml
    wf = yaml.safe_load((HERE / ".github/workflows/pr-label-assigner.yml").read_text())
    triggers = wf[True] if True in wf else wf["on"]  # PyYAML quirk: 'on' parses to True
    assert "push" in triggers and "pull_request" in triggers and "workflow_dispatch" in triggers
    job = wf["jobs"]["assign-labels"]
    step_names = [s.get("name") for s in job["steps"]]
    assert "Checkout" in step_names
    assert "Run unit tests" in step_names
    # Verify every script the workflow refers to actually exists.
    for ref in ("label_assigner.py", "test_label_assigner.py", "rules.yml"):
        assert (HERE / ref).exists(), f"missing referenced file: {ref}"


def test_act_result_file_exists_and_nonempty():
    # Ordered to run after the parametrized cases populate the file.
    assert ACT_RESULT.exists()
    assert ACT_RESULT.stat().st_size > 0
