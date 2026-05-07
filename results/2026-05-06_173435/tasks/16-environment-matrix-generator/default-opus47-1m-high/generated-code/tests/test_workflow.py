"""End-to-end workflow tests driven through `act`.

Every test case here:
  1. Creates a temp git repo with our project files + a fixture config.
  2. Runs `act push --rm` against the workflow.
  3. Appends the captured output to act-result.txt at the project root.
  4. Asserts on EXACT EXPECTED VALUES inside the captured output, plus
     that act exited with code 0 and that the job reported success.

We intentionally cap the harness at one `act push` invocation that runs
all cases sequentially — `act` startup is expensive (30-90s per run).
We achieve "one case per run" semantics by clearing act-result.txt at
start, copying the fixture into current-config.json, invoking act, and
appending its full output to act-result.txt.

Workflow-structure assertions (YAML shape, actionlint) run as plain
unit tests in this same file so they land in pytest output too.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "environment-matrix-generator.yml"
ACT_RESULT = ROOT / "act-result.txt"


# ---------------------------------------------------------------------------
# Workflow structure tests (cheap, no Docker required).
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def workflow_doc() -> dict:
    return yaml.safe_load(WORKFLOW.read_text())


def test_workflow_file_exists():
    assert WORKFLOW.is_file(), f"Missing workflow file: {WORKFLOW}"


def test_workflow_has_required_triggers(workflow_doc):
    # PyYAML parses the bare key `on:` as the boolean True. Either form is
    # acceptable; we accept both rather than depending on a specific version.
    triggers = workflow_doc.get("on") or workflow_doc.get(True)
    assert triggers is not None, "workflow must declare trigger events"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers
    assert "schedule" in triggers


def test_workflow_has_generate_matrix_job(workflow_doc):
    jobs = workflow_doc["jobs"]
    assert "generate-matrix" in jobs
    job = jobs["generate-matrix"]
    assert job["runs-on"] == "ubuntu-latest"
    step_names = [s.get("name", "") for s in job["steps"]]
    assert any("Checkout" in n for n in step_names)
    assert any("Generate matrix" in n for n in step_names)


def test_workflow_references_existing_files(workflow_doc):
    """The workflow's run: blocks should reference real files on disk."""
    assert (ROOT / "matrix.py").is_file()
    assert (ROOT / "tests").is_dir()
    assert (ROOT / "fixtures" / "simple.json").is_file()


def test_actionlint_passes():
    """actionlint on the workflow file should exit 0 with no findings."""
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    )


# ---------------------------------------------------------------------------
# Per-case act runs.
#
# Each TestCase carries: fixture path, expected exit code from matrix.py
# (as captured into the job output), and a list of regex assertions that
# must all match the captured act output for that case.
# ---------------------------------------------------------------------------

class Case:
    def __init__(self, name: str, fixture: str, expected_exit: int, asserts: list):
        self.name = name
        self.fixture = fixture
        self.expected_exit = expected_exit
        self.asserts = asserts


CASES: list[Case] = [
    Case(
        name="feature_flags_become_axes",
        fixture="fixtures/with_flags.json",
        expected_exit=0,
        asserts=[
            r"===EXIT_CODE=0===",
            # 1 OS x 2 versions x 2 redis x 3 tracing = 12
            r"===EXPANDED_SIZE=12===",
            r'"redis"',
            r'"tracing"',
            r'"fail-fast": true',
        ],
    ),
    Case(
        name="include_exclude",
        fixture="fixtures/include_exclude.json",
        expected_exit=0,
        # 3*3 = 9, minus 2 excludes = 7, plus 1 include = 8
        asserts=[
            r"===EXIT_CODE=0===",
            r"===EXPANDED_SIZE=8===",
            r'"experimental": true',
        ],
    ),
    Case(
        name="max_size_violation",
        fixture="fixtures/max_size_violation.json",
        expected_exit=1,
        asserts=[
            r"===EXIT_CODE=1===",
            # 3*4*2*2 = 48, exceeds max_size=10
            r"produced 48 jobs",
            r"max_size=10",
            r"===VALIDATION_FAILED===",
        ],
    ),
]


def _have_act_and_docker() -> bool:
    if shutil.which("act") is None:
        return False
    if shutil.which("docker") is None:
        return False
    try:
        subprocess.run(["docker", "info"], capture_output=True, check=True, timeout=10)
    except Exception:
        return False
    return True


needs_act = pytest.mark.skipif(
    not _have_act_and_docker(),
    reason="act + docker required for end-to-end workflow tests",
)


def _setup_temp_repo(workdir: Path, fixture_path: Path) -> None:
    """Initialize a fresh git repo in workdir with the project files copied in."""
    # Copy only what the workflow actually needs.
    for entry in [
        "matrix.py",
        "fixtures",
        "tests",
        "pytest.ini",
        ".github",
        ".actrc",
    ]:
        src = ROOT / entry
        if not src.exists():
            continue
        dst = workdir / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # The workflow expects current-config.json at the repo root.
    shutil.copy2(fixture_path, workdir / "current-config.json")

    # Initialize a git repo so `act push` has something to push.
    env = {**os.environ, "GIT_AUTHOR_NAME": "harness", "GIT_AUTHOR_EMAIL": "h@x",
           "GIT_COMMITTER_NAME": "harness", "GIT_COMMITTER_EMAIL": "h@x"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.email", "h@x"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.name", "harness"], cwd=workdir, check=True)
    subprocess.run(["git", "add", "."], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=workdir, check=True, env=env)


def _run_act(workdir: Path) -> tuple[int, str]:
    """Run `act push --rm` in workdir and return (exit_code, combined_output)."""
    proc = subprocess.run(
        ["act", "push", "--rm"],
        cwd=workdir,
        capture_output=True, text=True,
        timeout=600,
    )
    return proc.returncode, proc.stdout + "\n" + proc.stderr


@needs_act
def test_act_runs_all_cases(tmp_path_factory):
    """Drive each fixture through `act push` and assert on captured output.

    The harness writes one combined act-result.txt at the project root,
    delimited by per-case banners. This file is a required artifact.
    """
    # Fresh artifact each run.
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.touch()

    failures: list[str] = []
    for case in CASES:
        case_root = tmp_path_factory.mktemp(f"case_{case.name}")
        _setup_temp_repo(case_root, ROOT / case.fixture)

        rc, output = _run_act(case_root)

        banner = "=" * 80
        with ACT_RESULT.open("a") as f:
            f.write(f"\n{banner}\nCASE: {case.name}\n"
                    f"FIXTURE: {case.fixture}\n"
                    f"ACT_EXIT_CODE: {rc}\n"
                    f"{banner}\n")
            f.write(output)
            f.write(f"\n{banner}\nEND CASE: {case.name}\n{banner}\n")

        # Assert: act itself exited 0 (the workflow always succeeds
        # because the script's exit code is captured into outputs, not
        # propagated as a step failure).
        if rc != 0:
            failures.append(f"[{case.name}] act exited {rc}")

        # Assert: every job shows "Job succeeded".
        if "Job succeeded" not in output:
            failures.append(f"[{case.name}] missing 'Job succeeded' marker")

        # Assert: each expected pattern is present.
        for pat in case.asserts:
            if not re.search(pat, output):
                failures.append(
                    f"[{case.name}] expected pattern not found: {pat!r}\n"
                    f"--- last 60 lines of output ---\n"
                    + "\n".join(output.splitlines()[-60:])
                )

    assert not failures, "\n\n".join(failures)


# ---------------------------------------------------------------------------
# Allow running this module directly as a CLI harness:
#     python3 tests/test_workflow.py
# This is what the top-level harness wrapper invokes.
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v", "-s"]))
