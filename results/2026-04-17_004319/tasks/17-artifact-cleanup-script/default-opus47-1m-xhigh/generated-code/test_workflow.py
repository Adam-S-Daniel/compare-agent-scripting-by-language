"""
Workflow integration tests.

For each policy scenario, this harness:
  1. Builds a throwaway git repo containing the project files and the
     scenario's fixture + inputs (passed through a GITHUB_EVENT_PATH file
     so workflow_dispatch inputs are honoured).
  2. Runs `act push --rm --eventpath <event.json>`.
  3. Appends the full act output, delimited, to ``act-result.txt``.
  4. Asserts exit code 0, "Job succeeded" for every job, and an exact
     ``CLEANUP_RESULT`` line that matches the known-good values for that
     fixture + policy.

We also parse the workflow YAML itself to check shape (triggers, jobs,
script references) and confirm ``actionlint`` accepts it cleanly.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

try:
    import yaml  # PyYAML
except ImportError:  # pragma: no cover - defensive
    yaml = None  # type: ignore[assignment]


HERE = Path(__file__).parent.resolve()
WORKFLOW = HERE / ".github" / "workflows" / "artifact-cleanup-script.yml"
ACT_RESULT_FILE = HERE / "act-result.txt"

PROJECT_FILES = [
    "artifact_cleanup.py",
    "test_artifact_cleanup.py",
    ".actrc",
    ".github",
    "fixtures",
]


# ---------------------------------------------------------------------------
# Scenarios: (case_id, fixture, policy_inputs, expected_CLEANUP_RESULT_fields)
# ---------------------------------------------------------------------------
#
# The expected fields are a dict of exact key=value assertions checked
# against the ``CLEANUP_RESULT`` line emitted by the workflow.
SCENARIOS = [
    (
        "mixed_max_age_30d",
        "fixtures/mixed.json",
        {"max_age_days": "30", "keep_latest_n": "", "max_total_size_bytes": ""},
        {
            "total": "5",
            "retained": "4",
            "deleted": "1",
            "reclaimed": "3000000",
            "dry_run": "true",
        },
    ),
    (
        "all_fresh_no_deletions",
        "fixtures/all-fresh.json",
        {"max_age_days": "30", "keep_latest_n": "", "max_total_size_bytes": ""},
        {
            "total": "2",
            "retained": "2",
            "deleted": "0",
            "reclaimed": "0",
            "dry_run": "true",
        },
    ),
    (
        "keep_latest_1_per_workflow",
        "fixtures/mixed.json",
        {"max_age_days": "", "keep_latest_n": "1", "max_total_size_bytes": ""},
        {
            "total": "5",
            "retained": "2",
            "deleted": "3",
            "reclaimed": "5600000",  # 2M + 3M + 600K
            "dry_run": "true",
        },
    ),
    (
        "oversized_size_cap",
        "fixtures/oversized.json",
        {"max_age_days": "", "keep_latest_n": "", "max_total_size_bytes": "10000000"},
        {
            "total": "3",
            "retained": "2",
            "deleted": "1",
            "reclaimed": "5000000",
            "dry_run": "true",
        },
    ),
]


# ---------------------------------------------------------------------------
# YAML structural tests
# ---------------------------------------------------------------------------


def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"workflow not found at {WORKFLOW}"


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_has_expected_shape():
    data = yaml.safe_load(WORKFLOW.read_text())
    # `on:` is parsed by PyYAML as Python True when unquoted, so accept both.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None, "workflow missing 'on' key"
    for name in ("push", "pull_request", "schedule", "workflow_dispatch"):
        assert name in triggers, f"missing trigger {name}"
    jobs = data["jobs"]
    assert "unit-tests" in jobs
    assert "cleanup-plan" in jobs
    assert jobs["cleanup-plan"]["needs"] == "unit-tests"
    assert data["permissions"] == {"contents": "read"}


def test_workflow_references_existing_script_files():
    text = WORKFLOW.read_text()
    assert "artifact_cleanup.py" in text
    assert "test_artifact_cleanup.py" in text
    assert (HERE / "artifact_cleanup.py").exists()
    assert (HERE / "test_artifact_cleanup.py").exists()


def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)], capture_output=True, text=True
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )


# ---------------------------------------------------------------------------
# act integration — run every scenario through a real workflow execution.
# ---------------------------------------------------------------------------


def _build_sandbox(tmp: Path) -> Path:
    """Copy the project into a fresh git repo rooted at `tmp`."""
    for name in PROJECT_FILES:
        src = HERE / name
        dst = tmp / name
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init"],
        cwd=tmp,
        check=True,
    )
    return tmp


def _scenario_env(scenario_inputs: dict) -> list[str]:
    """
    Translate a scenario's policy overrides into `act --env KEY=VAL` args.

    The workflow reads these env vars first (falling back to
    workflow_dispatch inputs, then defaults), so push events triggered by
    `act push` can still parameterise the plan.
    """
    pairs = {
        "FIXTURE": scenario_inputs.get("fixture", "fixtures/mixed.json"),
        "MAX_AGE_DAYS": scenario_inputs.get("max_age_days", ""),
        "KEEP_LATEST_N": scenario_inputs.get("keep_latest_n", ""),
        "MAX_TOTAL_SIZE": scenario_inputs.get("max_total_size_bytes", ""),
        "NOW": scenario_inputs.get("now", "2026-04-17T12:00:00+00:00"),
    }
    args: list[str] = []
    for k, v in pairs.items():
        args.extend(["--env", f"{k}={v}"])
    return args


def _parse_cleanup_result(stdout: str) -> dict[str, str]:
    """Extract the last ``CLEANUP_RESULT ...`` line into a k=v dict."""
    result: dict[str, str] = {}
    for line in stdout.splitlines():
        # act prefixes step stdout with " | "; strip that prefix.
        bare = line.split("|", 1)[-1].strip() if "|" in line else line.strip()
        if "CLEANUP_RESULT" in bare:
            # the marker can be preceded by log decoration
            idx = bare.index("CLEANUP_RESULT")
            payload = bare[idx + len("CLEANUP_RESULT"):].strip()
            result = {}
            for tok in payload.split():
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    result[k] = v
    return result


def _run_act(sandbox: Path, extra_env: list[str]) -> subprocess.CompletedProcess:
    # `--rm` cleans the container after the run. `--pull=false` avoids a
    # network dependency when the image is already local.
    env = os.environ.copy()
    env.setdefault("ACT_LOG", "info")
    cmd = [
        "act",
        "push",
        "--rm",
        "--pull=false",
        "-W",
        ".github/workflows/artifact-cleanup-script.yml",
        *extra_env,
    ]
    return subprocess.run(
        cmd,
        cwd=sandbox,
        capture_output=True,
        text=True,
        env=env,
        timeout=600,
    )


@pytest.fixture(scope="module")
def act_results():
    """
    Run every scenario through `act` exactly once; reuse the outputs across
    per-scenario tests. Writing ``act-result.txt`` happens here as a side
    effect so the file is produced even if later assertions fail — the
    assertions can then reference the on-disk log for debugging.
    """
    # Truncate act-result.txt at the start of the module run.
    ACT_RESULT_FILE.write_text("")
    collected: dict[str, subprocess.CompletedProcess] = {}
    for case_id, fixture, policy, _expected in SCENARIOS:
        with tempfile.TemporaryDirectory(prefix=f"act-{case_id}-") as tmp_str:
            tmp = Path(tmp_str)
            _build_sandbox(tmp)
            env_args = _scenario_env({"fixture": fixture, **policy})
            proc = _run_act(tmp, env_args)
            with ACT_RESULT_FILE.open("a", encoding="utf-8") as fh:
                fh.write(f"\n===== CASE: {case_id} =====\n")
                fh.write(f"CMD: act push --rm {' '.join(env_args)}\n")
                fh.write(f"INPUTS: fixture={fixture} policy={policy}\n")
                fh.write(f"EXIT: {proc.returncode}\n")
                fh.write("----- STDOUT -----\n")
                fh.write(proc.stdout)
                fh.write("\n----- STDERR -----\n")
                fh.write(proc.stderr)
                fh.write("\n===== END =====\n")
            collected[case_id] = proc
    return collected


@pytest.mark.parametrize(
    "case_id,fixture,policy,expected",
    SCENARIOS,
    ids=[s[0] for s in SCENARIOS],
)
def test_act_scenario(act_results, case_id, fixture, policy, expected):
    proc = act_results[case_id]
    assert proc.returncode == 0, (
        f"act failed for {case_id}\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
    )
    combined = proc.stdout + "\n" + proc.stderr
    # Every job must report success
    assert "Job succeeded" in combined, (
        f"no 'Job succeeded' in act output for {case_id}"
    )
    # Expect BOTH jobs (unit-tests + cleanup-plan) to report success
    assert combined.count("Job succeeded") >= 2, (
        f"expected >=2 'Job succeeded' (unit-tests + cleanup-plan), "
        f"got {combined.count('Job succeeded')} for {case_id}"
    )
    result = _parse_cleanup_result(combined)
    assert result, (
        f"CLEANUP_RESULT marker not found for {case_id}\n"
        f"STDOUT:\n{proc.stdout}"
    )
    for key, want in expected.items():
        assert result.get(key) == want, (
            f"{case_id}: expected {key}={want}, got {key}={result.get(key)}\n"
            f"Full result: {result}"
        )


def test_act_result_file_exists(act_results):
    assert ACT_RESULT_FILE.exists()
    assert ACT_RESULT_FILE.stat().st_size > 0
