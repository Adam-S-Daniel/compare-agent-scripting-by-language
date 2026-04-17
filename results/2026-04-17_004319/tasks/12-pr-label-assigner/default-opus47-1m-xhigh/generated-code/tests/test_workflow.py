"""Workflow-level tests.

Two categories:

  1) Structural tests: parse the YAML, verify triggers/jobs/steps and that the
     workflow references files that actually exist in the repo. Also run
     `actionlint` and assert exit 0.

  2) act-based integration tests: for each fixture, build a temp git repo
     containing the project + that fixture's data, run `act push --rm`, append
     the full output to ``act-result.txt`` at the project root, and assert on
     the exact label set emitted.

Per the task spec, *all* label assertions go through `act` — the in-pytest
`test_label_assigner.py` tests drive the pure Python logic, but the label
output itself is checked via the pipeline.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

# YAML parsing: we prefer stdlib-only but PyYAML is universally available in
# CI. We only use it for the structure test.
yaml = pytest.importorskip("yaml")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "pr-label-assigner.yml"
FIXTURES_DIR = PROJECT_ROOT / "fixtures"
ACT_RESULT = PROJECT_ROOT / "act-result.txt"

# Limit to at most 3 act runs per the task constraints.
FIXTURE_CASES = [
    "case1_basic",
    "case2_priority_conflict",
    "case3_no_matches",
]


# --- Structural tests -------------------------------------------------------


def _load_workflow() -> dict:
    with WORKFLOW_PATH.open() as f:
        return yaml.safe_load(f)


def test_workflow_file_exists():
    assert WORKFLOW_PATH.exists(), f"missing workflow: {WORKFLOW_PATH}"


def test_workflow_triggers():
    wf = _load_workflow()
    # PyYAML parses the YAML key `on` as the boolean True unless quoted. We
    # accept either form.
    on = wf.get("on", wf.get(True))
    assert on is not None, "workflow must declare an 'on' trigger"
    assert "push" in on
    assert "pull_request" in on
    assert "workflow_dispatch" in on


def test_workflow_has_expected_jobs():
    wf = _load_workflow()
    jobs = wf["jobs"]
    assert "unit-tests" in jobs
    assert "assign-labels" in jobs
    # assign-labels must depend on unit-tests so label emission only runs if
    # the pure-Python logic is still green.
    assert jobs["assign-labels"].get("needs") == "unit-tests"


def test_workflow_references_real_files():
    # Every `run:` step that mentions label_assigner.py should resolve to the
    # file we ship at the project root.
    wf = _load_workflow()
    assert (PROJECT_ROOT / "label_assigner.py").exists()
    # And every env var should point at a real file (or be overridable).
    env = wf["env"]
    assert (PROJECT_ROOT / env["RULES_PATH"]).exists()
    assert (PROJECT_ROOT / env["FILES_PATH"]).exists()


def test_actionlint_passes():
    # actionlint is pre-installed. Must exit 0.
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )


# --- act integration tests --------------------------------------------------


def _act_available() -> bool:
    return shutil.which("act") is not None and shutil.which("docker") is not None


act_required = pytest.mark.skipif(
    not _act_available(),
    reason="act and docker must be installed",
)


def _build_temp_repo(dest: Path, fixture_name: str) -> None:
    """Copy the project into ``dest`` and overlay the fixture's data."""
    fixture = FIXTURES_DIR / fixture_name

    # Copy everything except throwaway dirs (and act-result.txt itself so
    # runs don't snowball). Use a denylist to keep the repo lean inside act.
    deny = {
        ".git",
        "__pycache__",
        ".pytest_cache",
        "act-result.txt",
    }

    def ignore(src: str, names: list[str]) -> list[str]:
        return [n for n in names if n in deny]

    shutil.copytree(PROJECT_ROOT, dest, ignore=ignore)

    # Overlay fixture rules/files into the repo root so the workflow picks
    # them up via the default RULES_PATH / FILES_PATH env.
    shutil.copy2(fixture / "rules.json", dest / "rules.json")
    shutil.copy2(fixture / "changed_files.txt", dest / "changed_files.txt")

    # `act` needs an initialized git repo so `actions/checkout@v4` has
    # something to materialize.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=dest, check=True)
    subprocess.run(["git", "add", "-A"], cwd=dest, check=True)
    subprocess.run(
        ["git", "-c", "user.email=test@example.com", "-c", "user.name=test",
         "commit", "-q", "-m", f"fixture {fixture_name}"],
        cwd=dest,
        check=True,
    )


def _run_act(cwd: Path) -> subprocess.CompletedProcess[str]:
    # --pull=false: the custom act-ubuntu-pwsh image is local only; without
    # this flag act tries (and fails) to pull it from a registry.
    return subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=600,
    )


def _extract_labels(act_output: str) -> list[str]:
    """Pull labels out of the act log between our markers.

    The workflow prints `=== LABELS BEGIN ===` and `=== LABELS END ===`
    around the plain-text label output.
    """
    # Each line in `act` output is prefixed with a per-job tag, e.g.
    #   | api
    # so we strip everything up to the first pipe.
    match = re.search(
        r"=== LABELS BEGIN ===(.*?)=== LABELS END ===",
        act_output,
        re.DOTALL,
    )
    assert match, (
        "could not find label markers in act output. Full output:\n" + act_output
    )
    body = match.group(1)
    labels = []
    for raw in body.splitlines():
        # Lines look like "| api" or "[Assign labels/...] | api". Take text
        # after the last '|' and strip it.
        text = raw.split("|")[-1].strip() if "|" in raw else raw.strip()
        # Skip empty lines and the marker echo lines themselves.
        if not text or "===" in text:
            continue
        labels.append(text)
    return labels


def _append_act_result(fixture_name: str, proc: subprocess.CompletedProcess[str]) -> None:
    with ACT_RESULT.open("a") as f:
        f.write(f"\n\n========== FIXTURE: {fixture_name} ==========\n")
        f.write(f"exit_code={proc.returncode}\n")
        f.write("--- stdout ---\n")
        f.write(proc.stdout)
        f.write("\n--- stderr ---\n")
        f.write(proc.stderr)
        f.write("\n========== END FIXTURE ==========\n")


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    # Clear the result file at the start of the module so each run produces
    # a fresh, self-contained artifact.
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.touch()
    yield


@act_required
@pytest.mark.parametrize("fixture_name", FIXTURE_CASES)
def test_act_pipeline_produces_expected_labels(
    fixture_name: str, tmp_path_factory: pytest.TempPathFactory
):
    fixture = FIXTURES_DIR / fixture_name
    expected = [
        l.strip()
        for l in (fixture / "expected_labels.txt").read_text().splitlines()
        if l.strip()
    ]

    work = tmp_path_factory.mktemp(f"repo-{fixture_name}")
    repo = work / "repo"
    _build_temp_repo(repo, fixture_name)

    # Ensure act uses the same .actrc (custom Ubuntu image w/ pwsh) that the
    # workspace is configured with — the copy already carried .actrc across.
    env = os.environ.copy()
    proc = _run_act(repo)

    _append_act_result(fixture_name, proc)

    assert proc.returncode == 0, (
        f"act exited {proc.returncode} for {fixture_name}. See act-result.txt."
    )

    # Every job must report success.
    # act prints lines like `[PR Label Assigner/Unit tests] ... Job succeeded`.
    assert "Job succeeded" in proc.stdout, (
        f"no 'Job succeeded' line for {fixture_name}"
    )
    # Both jobs ran (unit-tests + assign-labels) -> expect at least two
    # success lines.
    success_count = proc.stdout.count("Job succeeded")
    assert success_count >= 2, (
        f"expected at least 2 successful jobs, saw {success_count}"
    )

    labels = _extract_labels(proc.stdout)
    assert labels == expected, (
        f"label mismatch for {fixture_name}:\n"
        f"  expected: {expected}\n  got:      {labels}"
    )
