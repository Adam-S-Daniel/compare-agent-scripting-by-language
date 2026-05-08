"""Workflow test harness.

For each test case:
1. Copy project files + the case's fixture data into a fresh temp git repo.
2. Run `act push --rm` from that repo.
3. Append the act output (clearly delimited) to act-result.txt.
4. Assert act exited 0, every job shows "Job succeeded", and the captured
   output contains the EXACT expected aggregate string for that case.

Also performs static workflow-structure checks (YAML parse, expected jobs/steps,
referenced script paths exist, actionlint passes).
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).parent
ACT_RESULT = ROOT / "act-result.txt"
WORKFLOW = ROOT / ".github/workflows/test-results-aggregator.yml"

# Files the workflow needs to find in the temp repo.
PROJECT_FILES = [
    "aggregator.py",
    "aggregate_cli.py",
    "tests/test_aggregator.py",
    ".github/workflows/test-results-aggregator.yml",
    ".actrc",
]

# Each test case = (name, dict of fixture path -> contents, expected substring in act output).
PASSING_FIXTURE = {
    "fixtures/run.json": (
        '{"tests":['
        '{"name":"a.t1","status":"passed","duration":0.1},'
        '{"name":"a.t2","status":"passed","duration":0.2}'
        ']}'
    ),
}
FLAKY_FIXTURE = {
    "fixtures/run1.xml": (ROOT / "fixtures/run1.xml").read_text(),
    "fixtures/run2.json": (ROOT / "fixtures/run2.json").read_text(),
}

CASES = [
    ("all-passing", PASSING_FIXTURE,
     "AGGREGATE_RESULT total=2 passed=2 failed=0 skipped=0 runs=1"),
    ("flaky-mix", FLAKY_FIXTURE,
     "AGGREGATE_RESULT total=10 passed=7 failed=1 skipped=2 runs=2"),
]


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def static_checks() -> None:
    print("== Static workflow checks ==")
    with WORKFLOW.open() as fh:
        wf = yaml.safe_load(fh)
    # PyYAML parses the bareword `on` as Python True; accept either key.
    triggers = wf.get("on") or wf.get(True)
    assert triggers, "workflow has no triggers"
    for t in ("push", "pull_request", "workflow_dispatch"):
        assert t in triggers, f"missing trigger: {t}"
    jobs = wf["jobs"]
    assert "unit-tests" in jobs and "aggregate" in jobs, "missing expected jobs"
    assert jobs["aggregate"].get("needs") == "unit-tests", "aggregate must depend on unit-tests"
    # Confirm referenced scripts exist.
    for f in ("aggregator.py", "aggregate_cli.py", "tests/test_aggregator.py"):
        assert (ROOT / f).exists(), f"missing referenced file: {f}"
    # actionlint must pass.
    rc = subprocess.run(["actionlint", str(WORKFLOW)], cwd=ROOT).returncode
    assert rc == 0, f"actionlint failed (exit {rc})"
    print("  static checks OK")


def setup_repo(workdir: Path, fixture: dict[str, str]) -> None:
    for rel in PROJECT_FILES:
        src = ROOT / rel
        dst = workdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, dst)
    # Wipe any default fixtures, then write only this case's fixture data.
    fdir = workdir / "fixtures"
    if fdir.exists():
        shutil.rmtree(fdir)
    for rel, content in fixture.items():
        p = workdir / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    # Init a real git repo so `act push` has something to react to.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.email", "t@example.com"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.name", "test"], cwd=workdir, check=True)
    subprocess.run(["git", "add", "-A"], cwd=workdir, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=workdir, check=True)


def run_act_case(name: str, fixture: dict[str, str], expected: str) -> None:
    print(f"\n== Case: {name} ==")
    workdir = ROOT / f".tmp-act-{name}"
    if workdir.exists():
        shutil.rmtree(workdir)
    workdir.mkdir()
    setup_repo(workdir, fixture)

    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=600,
    )
    output = (
        f"\n\n========== CASE: {name} ==========\n"
        f"Exit code: {proc.returncode}\n"
        f"-- STDOUT --\n{proc.stdout}\n"
        f"-- STDERR --\n{proc.stderr}\n"
    )
    with ACT_RESULT.open("a") as fh:
        fh.write(output)

    if proc.returncode != 0:
        fail(f"[{name}] act exited {proc.returncode}")

    combined = proc.stdout + proc.stderr
    if expected not in combined:
        fail(f"[{name}] expected substring not found: {expected!r}")
    # Each job should print "Job succeeded".
    succeeded = combined.count("Job succeeded")
    if succeeded < 2:
        fail(f"[{name}] expected >=2 'Job succeeded', found {succeeded}")
    print(f"  [{name}] OK (exit=0, {succeeded} jobs succeeded, expected output found)")

    shutil.rmtree(workdir, ignore_errors=True)


def main() -> int:
    # Truncate the artifact file so this run's output is self-contained.
    ACT_RESULT.write_text("")
    static_checks()
    for name, fixture, expected in CASES:
        run_act_case(name, fixture, expected)
    print("\nAll workflow tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
