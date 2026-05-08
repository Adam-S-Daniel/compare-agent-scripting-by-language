"""End-to-end test harness driving the workflow through `act`.

For each fixture under ``fixtures/<name>/`` the harness:
    1. Builds an isolated temp git repo containing this project plus the
       fixture's ``rules.yaml`` / ``files.txt`` / ``expected.json``.
    2. Runs ``act push --rm`` against it.
    3. Appends the act stdout/stderr to ``act-result.txt`` (delimited).
    4. Asserts act exited 0, that every job reported "Job succeeded",
       and that the LABELS_JSON line printed by the workflow matches the
       fixture's known-good ``expected.json``.

Also performs static structure checks on the workflow file itself
(YAML parses, expected jobs/steps present, referenced script paths exist,
``actionlint`` passes).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).parent.resolve()
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "pr-label-assigner.yml"
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"

# Files that make up the project (everything except the fixtures dir and
# the harness itself, both of which we do NOT need inside the temp repo).
PROJECT_FILES = [
    "label_assigner.py",
    "tests",
    ".github",
    ".actrc",
]

FIXTURES = ["basic-docs", "priority-conflict", "multi-label-mixed"]


# ---------------------------------------------------------------------- #
# Static workflow-structure checks (no act needed)                        #
# ---------------------------------------------------------------------- #
def check_workflow_structure() -> None:
    """Parse the workflow YAML and assert expected shape."""
    print("=== Workflow structure checks ===")
    with WORKFLOW_PATH.open() as fh:
        wf = yaml.safe_load(fh)

    # PyYAML parses the bare `on:` key as the boolean True. Either form is
    # acceptable; we just need a triggers block.
    triggers = wf.get("on") or wf.get(True)
    assert triggers is not None, "workflow has no triggers"
    for trig in ("push", "pull_request", "workflow_dispatch"):
        assert trig in triggers, f"missing trigger: {trig}"

    jobs = wf.get("jobs", {})
    for job_name in ("unit-tests", "assign-labels"):
        assert job_name in jobs, f"missing job: {job_name}"

    # The assign-labels job must depend on unit-tests.
    assert jobs["assign-labels"].get("needs") == "unit-tests", \
        "assign-labels must declare needs: unit-tests"

    # Permissions should be locked down.
    assert wf.get("permissions", {}).get("contents") == "read", \
        "permissions.contents must be read"

    # Script files referenced by the workflow must exist on disk.
    assert (PROJECT_ROOT / "label_assigner.py").exists()
    assert (PROJECT_ROOT / "tests").is_dir()
    print("  workflow structure OK")


def check_actionlint() -> None:
    print("=== actionlint ===")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True, text=True,
    )
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    assert result.returncode == 0, "actionlint failed"
    print("  actionlint OK")


# ---------------------------------------------------------------------- #
# Per-fixture act runs                                                    #
# ---------------------------------------------------------------------- #
def stage_fixture(workdir: Path, fixture_name: str) -> None:
    """Copy project files + the fixture's rules/files/expected into workdir."""
    for entry in PROJECT_FILES:
        src = PROJECT_ROOT / entry
        dst = workdir / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    fixture_dir = PROJECT_ROOT / "fixtures" / fixture_name
    for fname in ("rules.yaml", "files.txt", "expected.json"):
        shutil.copy2(fixture_dir / fname, workdir / fname)

    # Initialize a git repo so act has a SHA to use for the push event.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(
        ["git", "-c", "user.email=test@example.com",
         "-c", "user.name=Harness", "add", "-A"],
        cwd=workdir, check=True,
    )
    subprocess.run(
        ["git", "-c", "user.email=test@example.com",
         "-c", "user.name=Harness", "commit", "-q", "-m", "fixture"],
        cwd=workdir, check=True,
    )


def run_act(workdir: Path) -> tuple[int, str]:
    """Run `act push --rm` in workdir; return (exit_code, combined_output)."""
    # `--pull=false` keeps act from forcing a re-pull of the local-only
    # custom image (act-ubuntu-pwsh:latest) on every run.
    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=600,
    )
    combined = proc.stdout + "\n--- STDERR ---\n" + proc.stderr
    return proc.returncode, combined


def parse_labels_from_output(output: str) -> list[str]:
    """Extract the LABELS_JSON=... payload printed by the workflow."""
    for raw_line in output.splitlines():
        # act prefixes lines like "| LABELS_JSON=..." — strip its decorations.
        line = raw_line
        if "LABELS_JSON=" in line:
            tail = line.split("LABELS_JSON=", 1)[1]
            # Trim any trailing decorations (act sometimes appends shell-job
            # markers after the raw output).
            return json.loads(tail)
    raise AssertionError("LABELS_JSON= line not found in act output")


def append_section(name: str, body: str) -> None:
    with ACT_RESULT_FILE.open("a") as fh:
        fh.write(f"\n{'=' * 70}\n")
        fh.write(f"FIXTURE: {name}\n")
        fh.write(f"{'=' * 70}\n")
        fh.write(body)
        fh.write("\n")


def run_fixture(name: str) -> None:
    print(f"\n=== Fixture: {name} ===")
    expected = json.loads(
        (PROJECT_ROOT / "fixtures" / name / "expected.json").read_text()
    )
    with tempfile.TemporaryDirectory(prefix=f"act-{name}-") as td:
        workdir = Path(td)
        stage_fixture(workdir, name)
        exit_code, output = run_act(workdir)

    append_section(name, output)
    print(f"  act exit code: {exit_code}")
    if exit_code != 0:
        print(output[-4000:])
    assert exit_code == 0, f"act failed for fixture {name} (exit={exit_code})"

    # Every job in this workflow must report success.
    job_succeeded_count = output.count("Job succeeded")
    assert job_succeeded_count >= 2, (
        f"expected both jobs to print 'Job succeeded' "
        f"(got {job_succeeded_count}) for fixture {name}"
    )

    actual = parse_labels_from_output(output)
    assert actual == expected, (
        f"fixture {name} label mismatch:\n  expected={expected}\n  actual  ={actual}"
    )
    print(f"  labels: {actual} (matches expected)")


# ---------------------------------------------------------------------- #
def main() -> int:
    # Truncate previous run output.
    ACT_RESULT_FILE.write_text("")

    check_workflow_structure()
    check_actionlint()

    for name in FIXTURES:
        run_fixture(name)

    print(f"\nAll {len(FIXTURES)} fixtures passed via act.")
    print(f"Output saved to: {ACT_RESULT_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
