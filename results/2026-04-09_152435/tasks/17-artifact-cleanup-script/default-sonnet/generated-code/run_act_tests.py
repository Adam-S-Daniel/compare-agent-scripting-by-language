#!/usr/bin/env python3
# run_act_tests.py
#
# Test harness that:
#   1. Validates the workflow YAML structure (no Docker/act required)
#   2. Checks file paths referenced in the workflow exist
#   3. Asserts actionlint passes
#   4. Sets up a temp git repo, runs `act push --rm`, saves output to act-result.txt
#   5. Asserts exact expected values in the act output
#
# Usage:
#   python3 run_act_tests.py
#
# All test cases execute through the GitHub Actions pipeline via `act`.

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────

HERE = Path(__file__).parent.resolve()
WORKFLOW_PATH = HERE / ".github" / "workflows" / "artifact-cleanup-script.yml"
ACT_RESULT_FILE = HERE / "act-result.txt"

# Project files that must be present inside the temp git repo
PROJECT_FILES = [
    "artifact_cleanup.py",
    "test_artifact_cleanup.py",
    "fixtures/ci_fixture.json",
    ".github/workflows/artifact-cleanup-script.yml",
    ".actrc",
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def fail(msg: str) -> None:
    print(f"\nFAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def run(cmd: list[str], cwd: Path, timeout: int = 300) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def append_to_result(header: str, text: str) -> None:
    with open(ACT_RESULT_FILE, "a") as fh:
        fh.write(f"\n{'=' * 72}\n")
        fh.write(f"TEST CASE: {header}\n")
        fh.write(f"{'=' * 72}\n")
        fh.write(text)
        fh.write("\n")


# ── Section 1: Workflow structure tests (no act required) ─────────────────────

def test_workflow_structure() -> None:
    print("-- Workflow structure tests --")

    import yaml  # installed as pyyaml if available; use basic check if not

    with open(WORKFLOW_PATH) as fh:
        wf = yaml.safe_load(fh)

    # Trigger events
    # Note: YAML parses bare `on:` as the Python boolean True, not the string "on".
    on_value = wf.get("on") or wf.get(True, {})
    triggers = set(on_value.keys() if isinstance(on_value, dict) else [])
    for expected in ("push", "pull_request", "workflow_dispatch", "schedule"):
        if expected not in triggers:
            fail(f"Workflow missing trigger: {expected}")
    print(f"  triggers present: {sorted(triggers)}")

    # Jobs
    jobs = wf.get("jobs", {})
    for expected_job in ("test", "cleanup-dry-run"):
        if expected_job not in jobs:
            fail(f"Workflow missing job: {expected_job}")
    print(f"  jobs present: {sorted(jobs.keys())}")

    # job dependency
    cleanup_job = jobs["cleanup-dry-run"]
    needs = cleanup_job.get("needs", [])
    if isinstance(needs, str):
        needs = [needs]
    if "test" not in needs:
        fail("cleanup-dry-run job does not depend on 'test' job")
    print("  job dependency: cleanup-dry-run needs test")

    # The cleanup job should call artifact_cleanup.py with the fixture
    cleanup_steps = jobs["cleanup-dry-run"].get("steps", [])
    cleanup_runs = " ".join(s.get("run", "") for s in cleanup_steps)
    if "artifact_cleanup.py" not in cleanup_runs:
        fail("cleanup-dry-run job does not call artifact_cleanup.py")
    if "fixtures/ci_fixture.json" not in cleanup_runs:
        fail("cleanup-dry-run job does not pass fixtures/ci_fixture.json")
    print("  script references look correct")

    # permissions
    perms = wf.get("permissions", {})
    if perms.get("contents") != "read":
        fail("Workflow permissions.contents should be 'read'")
    print("  permissions: contents=read")

    print("  PASS: all structure checks")


def test_file_paths_exist() -> None:
    print("-- File path existence tests --")
    for rel_path in [
        "artifact_cleanup.py",
        "test_artifact_cleanup.py",
        "fixtures/ci_fixture.json",
        ".github/workflows/artifact-cleanup-script.yml",
    ]:
        full = HERE / rel_path
        if not full.exists():
            fail(f"Required file missing: {rel_path}")
        print(f"  exists: {rel_path}")
    print("  PASS: all referenced files exist")


def test_actionlint() -> None:
    print("-- actionlint validation --")
    result = run(["actionlint", str(WORKFLOW_PATH)], cwd=HERE)
    if result.returncode != 0:
        fail(f"actionlint failed:\n{result.stdout}\n{result.stderr}")
    print("  PASS: actionlint exit 0, no errors")


# ── Section 2: act-based integration tests ────────────────────────────────────

def setup_temp_repo() -> Path:
    """Copy project files into a fresh git repo so act can checkout them."""
    tmpdir = Path(tempfile.mkdtemp(prefix="artifact-cleanup-act-"))

    # Copy project files
    dirs_to_create = [
        tmpdir / ".github" / "workflows",
        tmpdir / "fixtures",
    ]
    for d in dirs_to_create:
        d.mkdir(parents=True, exist_ok=True)

    files_to_copy = [
        ("artifact_cleanup.py", "artifact_cleanup.py"),
        ("test_artifact_cleanup.py", "test_artifact_cleanup.py"),
        ("fixtures/ci_fixture.json", "fixtures/ci_fixture.json"),
        (".github/workflows/artifact-cleanup-script.yml",
         ".github/workflows/artifact-cleanup-script.yml"),
        (".actrc", ".actrc"),
    ]
    for src_rel, dst_rel in files_to_copy:
        src = HERE / src_rel
        dst = tmpdir / dst_rel
        if src.exists():
            shutil.copy2(src, dst)

    # Initialise git repo with all files committed (act checkout needs HEAD)
    for cmd in [
        ["git", "init", "-b", "main"],
        ["git", "config", "user.email", "ci@example.com"],
        ["git", "config", "user.name", "CI"],
        ["git", "add", "."],
        ["git", "commit", "-m", "chore: add artifact cleanup script"],
    ]:
        result = run(cmd, cwd=tmpdir)
        if result.returncode != 0:
            fail(f"git setup failed ({cmd}): {result.stderr}")

    return tmpdir


def run_act(tmpdir: Path, case_name: str) -> tuple[int, str]:
    """Run `act push --rm` in tmpdir and return (exit_code, combined_output)."""
    print(f"  Running act push --rm in {tmpdir} ...")
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    append_to_result(case_name, combined)
    return result.returncode, combined


def assert_in(text: str, expected: str, label: str) -> None:
    if expected not in text:
        fail(f"Expected to find {label!r} in act output, but not found.\nSearched for: {expected!r}")
    print(f"  ASSERT OK: found {label!r}")


def test_case_max_age_dry_run() -> None:
    """
    Test case: max_age=20d applied to ci_fixture.json with --today 2026-04-10.

    Expected output (exact values):
      Deleted: 2       (logs-v1 at 40d, logs-v2 at 26d)
      Retained: 2      (build-v1 at 9d, build-v2 at 2d)
      Space reclaimed: 30.0 MB  (10 MB + 20 MB)
    """
    print("\n-- act test: max_age dry-run --")
    tmpdir = setup_temp_repo()
    try:
        rc, output = run_act(tmpdir, "max_age_dry_run")

        if rc != 0:
            fail(f"act exited with code {rc}. Output:\n{output}")
        print("  act exit code: 0")

        # Verify every job succeeded
        assert_in(output, "Job succeeded", "Job succeeded")

        # Verify pytest ran and all tests passed
        assert_in(output, "30 passed", "pytest 30 passed")

        # Verify exact cleanup report values
        assert_in(output, "DRY RUN", "DRY RUN mode")
        assert_in(output, "max_age=20d", "policy: max_age=20d")
        assert_in(output, "Deleted: 2", "Deleted: 2")
        assert_in(output, "Retained: 2", "Retained: 2")
        assert_in(output, "Space reclaimed: 30.0 MB", "Space reclaimed: 30.0 MB")
        assert_in(output, "Total artifacts: 4", "Total artifacts: 4")

        print("  PASS: max_age dry-run test")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    # Clear/create the result file
    ACT_RESULT_FILE.write_text("Artifact Cleanup Script — act Test Results\n")

    # ── Structure / static tests ──────────────────────────────────────────────
    try:
        import yaml
        yaml_available = True
    except ImportError:
        yaml_available = False
        print("WARNING: pyyaml not installed; skipping YAML structure tests")

    if yaml_available:
        test_workflow_structure()
    test_file_paths_exist()
    test_actionlint()

    # ── act integration test ──────────────────────────────────────────────────
    test_case_max_age_dry_run()

    print("\nAll tests passed. Results written to act-result.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
