"""Workflow structure tests + act harness.

These tests exercise the .github/workflows/pr-label-assigner.yml workflow
two ways:

1. Static structure checks (no Docker required) — parse the YAML and
   confirm the expected triggers, jobs, steps, file references, and that
   `actionlint` accepts it.

2. Runtime checks via `act push --rm` — for each of three integration
   test cases, the harness creates a fresh temp git repo, drops in the
   project files plus that case's fixture data, runs act, and asserts:
     - exit code 0
     - the script's exact-known-good output appears in act's log
     - every job logs "Job succeeded"

   All three act runs' stdout+stderr are appended to `act-result.txt`
   (in the original cwd) with clear delimiters.

Total act invocations: 3 (the per-task limit).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml


ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "pr-label-assigner.yml"
ACT_RESULT_PATH = ROOT / "act-result.txt"


# ===========================================================================
# Section 1: Workflow structure tests (run locally; no Docker).
# ===========================================================================
@pytest.fixture(scope="module")
def workflow():
    """Parse the workflow YAML once for the structure tests."""
    with open(WORKFLOW_PATH) as fh:
        return yaml.safe_load(fh)


def test_workflow_file_exists():
    assert WORKFLOW_PATH.exists(), f"missing workflow file at {WORKFLOW_PATH}"


def test_workflow_has_expected_triggers(workflow):
    # PyYAML parses YAML 1.1 `on:` as the boolean True, so accept either key.
    triggers = workflow.get("on") or workflow.get(True)
    assert triggers is not None, "no triggers configured"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers


def test_workflow_declares_minimal_permissions(workflow):
    perms = workflow.get("permissions")
    assert perms == {"contents": "read"}, perms


def test_workflow_has_test_and_run_job(workflow):
    jobs = workflow.get("jobs", {})
    assert "test-and-run" in jobs, jobs.keys()
    job = jobs["test-and-run"]
    assert job.get("runs-on") == "ubuntu-latest"


def test_workflow_uses_checkout_action(workflow):
    steps = workflow["jobs"]["test-and-run"]["steps"]
    uses = [s.get("uses") for s in steps if "uses" in s]
    assert "actions/checkout@v4" in uses, uses


def test_workflow_runs_pytest(workflow):
    steps = workflow["jobs"]["test-and-run"]["steps"]
    run_blocks = "\n".join(s.get("run", "") for s in steps if "run" in s)
    assert "pytest tests/" in run_blocks


def test_workflow_invokes_the_script(workflow):
    steps = workflow["jobs"]["test-and-run"]["steps"]
    run_blocks = "\n".join(s.get("run", "") for s in steps if "run" in s)
    assert "pr_label_assigner.py" in run_blocks


def test_referenced_files_exist():
    """Every script and fixture path the workflow names must exist on disk."""
    expected = [
        ROOT / "pr_label_assigner.py",
        ROOT / "tests",
        ROOT / "fixtures" / "current_files.json",
        ROOT / "fixtures" / "current_rules.json",
        ROOT / "fixtures" / "current_expected.txt",
        ROOT / "fixtures" / "current_case_name.txt",
    ]
    for p in expected:
        assert p.exists(), f"workflow references missing path: {p}"


def test_actionlint_passes():
    """actionlint must accept the workflow with exit code 0."""
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
    )


# ===========================================================================
# Section 2: Runtime checks via `act push --rm`.
# ===========================================================================
# Each case: (name, rules-fixture, files-fixture, expected-stdout, expected-marker)
# `expected-stdout` is the exact text the script must emit (newline-terminated).
# `expected-marker` is a deterministic substring proving this case ran (the
# workflow logs CASE_OK_<name> on success).
CASES = [
    (
        "multi_area",
        "rules_default.json",
        "case2_multi_area.json",
        "tests\napi\ndocumentation\n",
    ),
    (
        "grouped_priority",
        "rules_grouped.json",
        "case3_grouped.json",
        "size/large\nlang/python\n",
    ),
    (
        "no_match",
        "rules_default.json",
        "case4_no_match.json",
        "",
    ),
]


def _files_to_copy() -> list[Path]:
    """Files/dirs the temp repo needs to mirror the project."""
    keep = [
        ROOT / "pr_label_assigner.py",
        ROOT / "tests",
        ROOT / "fixtures",
        ROOT / ".github",
        ROOT / ".actrc",
    ]
    return [p for p in keep if p.exists()]


def _stage_temp_repo(tmpdir: Path) -> None:
    """Copy project files into tmpdir and init a fresh git repo there."""
    for src in _files_to_copy():
        dst = tmpdir / src.name
        if src.is_dir():
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns(
                "__pycache__", ".pytest_cache", "*.pyc",
            ))
        else:
            shutil.copy2(src, dst)

    # act push needs a real git repo with at least one commit.
    env = {**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmpdir,
                   check=True, env=env)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tmpdir,
                   check=True, env=env)
    subprocess.run(["git", "config", "user.name", "test"], cwd=tmpdir,
                   check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=tmpdir, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "initial"], cwd=tmpdir,
                   check=True, env=env)


def _write_case_files(tmpdir: Path, case_name: str, rules_fixture: str,
                       files_fixture: str, expected: str) -> None:
    """Overwrite the `current_*` fixtures the workflow reads."""
    fx = tmpdir / "fixtures"
    shutil.copy2(ROOT / "fixtures" / rules_fixture, fx / "current_rules.json")
    shutil.copy2(ROOT / "fixtures" / files_fixture, fx / "current_files.json")
    (fx / "current_expected.txt").write_text(expected)
    (fx / "current_case_name.txt").write_text(case_name + "\n")
    # Re-commit so act sees a clean working tree (GITHUB_SHA needs HEAD).
    env = {**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "add", "-A"], cwd=tmpdir, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "--allow-empty",
                    "-m", f"case:{case_name}"], cwd=tmpdir, check=True, env=env)


def _append_to_act_result(case_name: str, returncode: int, output: str) -> None:
    """Append this case's act invocation to act-result.txt with delimiters."""
    delim = "=" * 78
    block = (
        f"\n{delim}\n"
        f"# CASE: {case_name}\n"
        f"# act exit code: {returncode}\n"
        f"{delim}\n"
        f"{output}"
        f"{delim}\n"
        f"# END CASE: {case_name}\n"
        f"{delim}\n"
    )
    with open(ACT_RESULT_PATH, "a") as fh:
        fh.write(block)


@pytest.fixture(scope="session", autouse=True)
def _truncate_act_result_at_start():
    """Start each test session with a fresh act-result.txt."""
    if ACT_RESULT_PATH.exists():
        ACT_RESULT_PATH.unlink()
    ACT_RESULT_PATH.write_text(
        "# act-result.txt — output of `act push --rm` per integration test case.\n"
    )
    yield


@pytest.mark.parametrize("case", CASES, ids=[c[0] for c in CASES])
def test_act_runs_each_case_successfully(tmp_path, case):
    """Run act for one test case; assert exit 0, exact output, and Job succeeded."""
    if shutil.which("act") is None:
        pytest.skip("act not installed")

    case_name, rules_fixture, files_fixture, expected = case

    # Build a fresh temp git repo per case (instructions: "set up a temp git
    # repo with your project files + that case's fixture data").
    _stage_temp_repo(tmp_path)
    _write_case_files(tmp_path, case_name, rules_fixture, files_fixture, expected)

    # Run act. We use --rm to clean up the container after each run, and
    # forward both stdout and stderr so failures (e.g. assertion diffs) are
    # captured into act-result.txt for postmortem.
    proc = subprocess.run(
        ["act", "push", "--rm"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        timeout=600,
    )
    combined = (
        f"--- act stdout ---\n{proc.stdout}\n"
        f"--- act stderr ---\n{proc.stderr}\n"
    )
    _append_to_act_result(case_name, proc.returncode, combined)

    # Assertion 1: act exited 0 (workflow reached the final step).
    assert proc.returncode == 0, (
        f"act exited {proc.returncode} for case {case_name}; "
        f"see act-result.txt for output"
    )

    # Assertion 2: the workflow's case-success marker is in the log. This is
    # logged AFTER `diff -u current_expected.txt actual.txt` succeeds, so it
    # only appears when the script's output matched the known-good expected.
    expected_marker = f"CASE_OK_{case_name}"
    assert expected_marker in combined, (
        f"expected marker {expected_marker!r} not found in act output"
    )

    # Assertion 3: each non-empty expected label appears verbatim in the log
    # (CASE OUTPUT block). Empty-output case (no_match) is covered by
    # the marker check above.
    for line in expected.splitlines():
        if line.strip():
            assert line in combined, (
                f"expected label {line!r} not in act output for {case_name}"
            )

    # Assertion 4: every job logged "Job succeeded".
    assert "Job succeeded" in combined, (
        f"no 'Job succeeded' line found in act output for {case_name}"
    )

    # Assertion 5: the JSON-mode step printed JSON_OK.
    assert "JSON_OK" in combined, (
        f"JSON-mode validation step did not print JSON_OK for {case_name}"
    )


def test_act_result_file_exists_after_run():
    """Sanity: the artifact required by the spec is on disk."""
    assert ACT_RESULT_PATH.exists()
    text = ACT_RESULT_PATH.read_text()
    for case_name, *_ in CASES:
        assert f"CASE: {case_name}" in text
