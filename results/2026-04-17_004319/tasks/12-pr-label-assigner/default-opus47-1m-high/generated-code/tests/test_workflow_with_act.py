"""End-to-end tests that exercise the workflow through `act`.

Per the benchmark rules every test case must run through the CI pipeline. Each
case sets up an isolated temp git repo with the project files + a fixture's
changed_files.txt, runs `act push --rm`, then parses the captured output and
asserts on exact expected label sequences.

All stdout/stderr from every case is appended to act-result.txt in the project
root, clearly delimited per case.
"""
from __future__ import annotations

import json
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
WORKFLOW = ROOT / ".github" / "workflows" / "pr-label-assigner.yml"

# Expected label sequences per fixture. These are the known-good results
# computed by hand from rules.json (see comments below).
EXPECTED_LABELS: dict[str, list[str]] = {
    # Case 1: docs only. `docs/**` + `**/*.md` both give "documentation" at
    # priority 1, so the only label is "documentation".
    "case1_docs.txt": ["documentation"],

    # Case 2: api source, api test, docs markdown, CI workflow.
    #   src/api/**        -> api, backend  (priority 20, group area)
    #   src/**            -> source        (priority 5,  group area)  (loses group)
    #   **/*.test.*       -> tests         (priority 10)
    #   docs/** + **/*.md -> documentation (priority 1)
    #   .github/**        -> ci            (priority 15)
    # Final order (desc priority, stable on ties, first-seen wins):
    #   api(20)-first-seen-first, backend(20), ci(15), tests(10), documentation(1)
    "case2_mixed.txt": ["api", "backend", "ci", "tests", "documentation"],

    # Case 3: frontend source + frontend spec.
    #   src/frontend/**   -> frontend (20, group area, wins)
    #   src/**            -> source   (5, loses group conflict)
    #   **/*.spec.*       -> tests    (10)
    "case3_frontend.txt": ["frontend", "tests"],
}

# Files / dirs copied into the temp repo for each act run.
PROJECT_FILES = [
    "pr_label_assigner.py",
    "rules.json",
    ".actrc",
    ".github",
    "tests",
]


def _have_docker() -> bool:
    return shutil.which("docker") is not None and subprocess.run(
        ["docker", "info"], capture_output=True,
    ).returncode == 0


pytestmark = pytest.mark.skipif(
    not _have_docker(), reason="docker unavailable; skipping act-based tests",
)


# --- Workflow structure tests ----------------------------------------------

def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"missing workflow {WORKFLOW}"


def test_workflow_yaml_is_parseable():
    # Basic guard: if YAML won't parse, act will choke too.
    yaml.safe_load(WORKFLOW.read_text())


def test_workflow_has_expected_triggers():
    data = yaml.safe_load(WORKFLOW.read_text())
    # PyYAML turns the bare word `on` into a boolean key `True`. Handle both.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None
    for trig in ("push", "pull_request", "workflow_dispatch"):
        assert trig in triggers, f"trigger {trig} missing"


def test_workflow_references_script_and_rules():
    raw = WORKFLOW.read_text()
    assert "pr_label_assigner.py" in raw
    assert "rules.json" in raw or "RULES_FILE" in raw
    # The files we reference from the workflow must actually exist.
    assert (ROOT / "pr_label_assigner.py").exists()
    assert (ROOT / "rules.json").exists()


def test_workflow_jobs_present():
    data = yaml.safe_load(WORKFLOW.read_text())
    jobs = data["jobs"]
    assert "test" in jobs
    assert "assign-labels" in jobs
    # assign-labels must depend on test so failing tests short-circuit the pipeline.
    assert jobs["assign-labels"].get("needs") == "test"


def test_actionlint_passes():
    # actionlint is pre-installed per the benchmark instructions.
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout={result.stdout}\nstderr={result.stderr}"
    )


# --- Act-based end-to-end tests --------------------------------------------

def _init_temp_repo(tmp_path: Path, fixture_name: str) -> Path:
    """Materialise a git repo in tmp_path with project files + the chosen fixture."""
    for name in PROJECT_FILES:
        src = ROOT / name
        dst = tmp_path / name
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Place the fixture as changed_files.txt (what the workflow reads).
    fixture = ROOT / "fixtures" / fixture_name
    shutil.copy2(fixture, tmp_path / "changed_files.txt")

    # Initialise the git repo — act insists on one for push events.
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@example.com",
        "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@example.com",
    }
    run = lambda *cmd: subprocess.run(cmd, cwd=tmp_path, env=env, check=True,
                                      capture_output=True)
    run("git", "init", "-q", "-b", "main")
    run("git", "add", "-A")
    run("git", "commit", "-q", "-m", "init")
    return tmp_path


def _append_act_result(case: str, output: str) -> None:
    """Append a clearly delimited section for this case to act-result.txt."""
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{'=' * 72}\n")
        f.write(f"CASE: {case}\n")
        f.write(f"{'=' * 72}\n")
        f.write(output)
        f.write("\n")


def _extract_labels_block(act_output: str) -> list[str]:
    """Pull the JSON label list from between our BEGIN/END markers."""
    start_tag = "---BEGIN_LABELS---"
    end_tag = "---END_LABELS---"
    start = act_output.find(start_tag)
    end = act_output.find(end_tag)
    assert start != -1 and end != -1 and end > start, (
        f"markers missing from act output:\n{act_output[-2000:]}"
    )
    block = act_output[start + len(start_tag):end]
    # Act prefixes every log line with job metadata like "| ". Find the JSON line.
    for line in block.splitlines():
        line = line.strip()
        # Strip any act log prefix up to the final `| `.
        if "| " in line:
            line = line.rsplit("| ", 1)[-1].strip()
        if line.startswith("["):
            return json.loads(line)
    raise AssertionError(f"no JSON array inside labels block:\n{block}")


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    # Wipe act-result.txt once at the start of the module so we capture a clean
    # record of this run, then let each case append to it.
    ACT_RESULT.write_text(
        f"act results for pr-label-assigner workflow\ngenerated by tests/test_workflow_with_act.py\n"
    )
    yield


@pytest.mark.parametrize("fixture", list(EXPECTED_LABELS.keys()))
def test_act_run_produces_expected_labels(fixture, tmp_path):
    repo = _init_temp_repo(tmp_path, fixture)

    # `act push --rm` — --rm cleans up containers even on failure.
    # Per instructions: allow at most 3 act runs total across this test suite,
    # which is exactly len(EXPECTED_LABELS). No retries.
    proc = subprocess.run(
        ["act", "push", "--rm"],
        cwd=repo, capture_output=True, text=True, timeout=600,
    )
    combined = f"--- STDOUT ---\n{proc.stdout}\n--- STDERR ---\n{proc.stderr}\n--- EXIT: {proc.returncode} ---"
    _append_act_result(fixture, combined)

    assert proc.returncode == 0, (
        f"act exited non-zero for {fixture}:\n{combined[-3000:]}"
    )
    assert "Job succeeded" in proc.stdout, (
        "expected 'Job succeeded' in act output"
    )
    # Both jobs (`test` and `assign-labels`) should report success — two successes.
    assert proc.stdout.count("Job succeeded") >= 2, (
        f"expected both jobs to succeed for {fixture}"
    )

    labels = _extract_labels_block(proc.stdout)
    expected = EXPECTED_LABELS[fixture]
    assert labels == expected, (
        f"fixture {fixture}: got {labels}, expected {expected}"
    )


def test_act_result_file_exists_after_run():
    # Sanity check that the artifact the benchmark requires is present.
    assert ACT_RESULT.exists()
    content = ACT_RESULT.read_text()
    for case in EXPECTED_LABELS:
        assert f"CASE: {case}" in content, f"missing section for {case}"
