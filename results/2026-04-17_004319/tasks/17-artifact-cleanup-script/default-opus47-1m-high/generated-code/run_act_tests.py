#!/usr/bin/env python3
"""
Act test harness.

For each scenario fixture under ./fixtures/scenario_*/:
  1. Build an isolated git repo in a temp directory containing the project.
  2. Install the scenario's artifacts.json / policy.json / expected.json as
     fixtures/current/*.
  3. Run `act push --rm` and capture the combined output.
  4. Append the output to act-result.txt (in the project dir, with delimiters).
  5. Assert that act exited 0, each job says "Job succeeded", and the workflow's
     own assertion step confirmed the exact expected summary values.

Also performs workflow-structure assertions (parse YAML, verify triggers, jobs,
step references, file existence, actionlint exit code).

This harness is invoked by the human operator / benchmarks to verify the entire
pipeline end-to-end.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULT_PATH = ROOT / "act-result.txt"
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "artifact-cleanup-script.yml"

PROJECT_FILES = [
    "cleanup.py",
    "assert_plan.py",
    "tests",
    ".github",
    ".actrc",
]


def log(msg: str) -> None:
    print(f"[harness] {msg}", flush=True)


def run(cmd: list[str], cwd: Path | None = None, env: dict | None = None) -> subprocess.CompletedProcess:
    log("$ " + " ".join(cmd))
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=env)


def structure_checks() -> None:
    """Validate workflow structure and actionlint before running act."""
    log("Workflow structure checks ...")
    assert WORKFLOW_PATH.exists(), f"workflow missing: {WORKFLOW_PATH}"

    # Minimal YAML parse without yaml dependency: use json-via-python-yaml if
    # available; otherwise do text-level sanity checks.
    try:
        import yaml  # type: ignore
        doc = yaml.safe_load(WORKFLOW_PATH.read_text())
    except ImportError:
        doc = None

    text = WORKFLOW_PATH.read_text()
    for required in ("on:", "push:", "pull_request:", "workflow_dispatch:", "schedule:"):
        assert required in text, f"workflow missing trigger snippet: {required}"

    for referenced_file in ("cleanup.py", "assert_plan.py", "tests/", "fixtures/current/"):
        assert referenced_file in text, f"workflow does not reference {referenced_file}"

    if doc is not None:
        jobs = doc.get("jobs", {})
        assert "unit-tests" in jobs, "missing 'unit-tests' job"
        assert "scenario" in jobs, "missing 'scenario' job"
        assert jobs["scenario"].get("needs") == "unit-tests", "scenario must need unit-tests"

    # Paths referenced by the workflow must exist on disk.
    for path in (ROOT / "cleanup.py", ROOT / "assert_plan.py", ROOT / "tests",
                 ROOT / "fixtures" / "scenario_age" / "artifacts.json"):
        assert path.exists(), f"missing referenced path: {path}"

    r = run(["actionlint", str(WORKFLOW_PATH)])
    assert r.returncode == 0, f"actionlint failed:\n{r.stdout}\n{r.stderr}"
    log("Workflow structure: OK")


def copy_project(dest: Path) -> None:
    for entry in PROJECT_FILES:
        src = ROOT / entry
        if not src.exists():
            continue
        dst = dest / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)


def install_scenario(dest: Path, scenario_dir: Path) -> dict:
    current = dest / "fixtures" / "current"
    current.mkdir(parents=True, exist_ok=True)
    for name in ("artifacts.json", "policy.json", "expected.json"):
        shutil.copy2(scenario_dir / name, current / name)
    return json.loads((scenario_dir / "expected.json").read_text())


def init_git(repo: Path) -> None:
    env = dict(os.environ)
    env.update({
        "GIT_AUTHOR_NAME": "harness", "GIT_AUTHOR_EMAIL": "h@x",
        "GIT_COMMITTER_NAME": "harness", "GIT_COMMITTER_EMAIL": "h@x",
    })
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "fixture"], cwd=repo, check=True, env=env)


def assert_act_output(output: str, scenario: str, expected: dict) -> None:
    # Job success markers: act prints "Job succeeded" once per job.
    succeeded_count = output.count("Job succeeded")
    assert succeeded_count >= 2, (
        f"[{scenario}] expected >= 2 'Job succeeded' lines (unit-tests + scenario), "
        f"got {succeeded_count}"
    )
    # Our assertion step prints this exact line on success.
    assert "ASSERTION PASSED: plan summary matches expected." in output, (
        f"[{scenario}] missing PASSED assertion line"
    )
    # Exact summary values must appear in logged summary.
    for key, value in expected.items():
        needle = f'"{key}": {value}'
        assert needle in output, f"[{scenario}] expected summary to contain {needle!r}"


def run_scenario(scenario_dir: Path, workdir: Path) -> tuple[int, str]:
    expected = install_scenario(workdir, scenario_dir)
    init_git(workdir)
    log(f"Running act for scenario: {scenario_dir.name}")
    r = subprocess.run(
        ["act", "push", "--rm"],
        cwd=workdir,
        capture_output=True,
        text=True,
    )
    output = (r.stdout or "") + "\n" + (r.stderr or "")
    return r.returncode, output, expected  # type: ignore


def main() -> int:
    structure_checks()

    # Fresh result file; each scenario appends its block.
    RESULT_PATH.write_text("")

    scenarios = sorted((ROOT / "fixtures").glob("scenario_*"))
    assert scenarios, "no scenario_* fixture directories found"

    overall_ok = True
    for scen in scenarios:
        import tempfile
        with tempfile.TemporaryDirectory(prefix=f"act-{scen.name}-") as tmp:
            workdir = Path(tmp) / "repo"
            workdir.mkdir()
            copy_project(workdir)
            rc, output, expected = run_scenario(scen, workdir)

            header = f"\n========== SCENARIO: {scen.name} (exit={rc}) ==========\n"
            with RESULT_PATH.open("a") as f:
                f.write(header)
                f.write(output)
                f.write(f"\n========== END: {scen.name} ==========\n")

            if rc != 0:
                log(f"[{scen.name}] act FAILED (exit {rc})")
                overall_ok = False
                continue

            try:
                assert_act_output(output, scen.name, expected)
                log(f"[{scen.name}] PASSED")
            except AssertionError as e:
                log(f"[{scen.name}] FAILED: {e}")
                overall_ok = False

    log(f"Wrote {RESULT_PATH} ({RESULT_PATH.stat().st_size} bytes)")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    sys.exit(main())
