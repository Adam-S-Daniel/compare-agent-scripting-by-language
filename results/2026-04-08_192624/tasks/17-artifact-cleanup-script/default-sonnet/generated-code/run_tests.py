#!/usr/bin/env python3
"""
Test harness for the artifact-cleanup-script GitHub Actions workflow.

Runs two categories of tests:

  STRUCTURE TESTS
    - Verify expected files exist
    - Parse the workflow YAML (text-based) and assert on triggers / jobs
    - Run actionlint and assert exit-code 0

  ACT-BASED TESTS (one act run per test case)
    - For each test case, copy project files into a fresh temp git repo
    - Run `act push --env FIXTURE_NAME=<name> --rm`
    - Append labelled output to act-result.txt
    - Assert exit code 0
    - Assert every job shows "Job succeeded"
    - Parse the ARTIFACT_CLEANUP_SUMMARY line and assert exact values

Exit code: 0 if all tests pass, 1 if any test fails.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────

REPO_ROOT    = Path(__file__).parent.resolve()
WORKFLOW_REL = ".github/workflows/artifact-cleanup-script.yml"
RESULT_FILE  = REPO_ROOT / "act-result.txt"
# Generous timeout: act must pull images on first run.
ACT_TIMEOUT  = 600  # seconds per test case

# Files / directories to copy into each temp git repo.
PROJECT_ITEMS = [
    "artifact_cleanup.py",
    "test_artifact_cleanup.py",
    ".github",
    "fixtures",
]

# ─────────────────────────────────────────────────────────────
# Test case definitions
#
# Each entry: (fixture_name, expected_summary_kv, extra_checks)
#   expected_summary_kv – dict of exact key=value pairs that must appear
#                         on the ARTIFACT_CLEANUP_SUMMARY line
#   extra_checks        – list of substrings that must appear anywhere in
#                         the act output (e.g. "DRY RUN")
# ─────────────────────────────────────────────────────────────

TEST_CASES = [
    (
        "age_retention",
        # 2 old artifacts deleted; 1 recent retained; 1 MB + 0.5 MB reclaimed.
        {"total": "3", "deleted": "2", "retained": "1",
         "space_bytes": "1572864", "space_mb": "1.5", "dry_run": "true"},
        [],
    ),
    (
        "size_retention",
        # Total 25 MB, limit 12 MB → 2 oldest deleted (7 MB + 8 MB = 15 MB).
        {"total": "3", "deleted": "2", "retained": "1",
         "space_bytes": "15728640", "space_mb": "15.0", "dry_run": "true"},
        [],
    ),
    (
        "keep_latest_n",
        # 4 CI runs, keep latest 2 → delete 2 oldest (500 + 500 = 1000 bytes).
        {"total": "4", "deleted": "2", "retained": "2",
         "space_bytes": "1000", "dry_run": "true"},
        [],
    ),
    (
        "combined",
        # age + size + keep-N applied: 3 deleted, 2 retained.
        {"total": "5", "deleted": "3", "retained": "2",
         "space_bytes": "1600", "dry_run": "true"},
        [],
    ),
    (
        "dry_run",
        # Same fixture as age_retention but verifies DRY RUN banner.
        {"total": "3", "deleted": "2", "retained": "1",
         "space_bytes": "1572864", "dry_run": "true"},
        ["DRY RUN"],
    ),
]

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

def banner(msg: str, width: int = 72) -> str:
    sep = "=" * width
    return f"\n{sep}\n{msg}\n{sep}"


def run(cmd, cwd=None, timeout=30, check=False, env=None):
    """Run a subprocess and return the CompletedProcess."""
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=check,
        env=env,
    )


def find_summary_values(output: str) -> dict:
    """Parse the ARTIFACT_CLEANUP_SUMMARY line from act output.

    The line looks like (possibly prefixed by act's '| '):
        ARTIFACT_CLEANUP_SUMMARY: total=3 deleted=2 retained=1 ...
    """
    for line in output.splitlines():
        if "ARTIFACT_CLEANUP_SUMMARY:" in line:
            # Grab everything after the colon
            idx = line.index("ARTIFACT_CLEANUP_SUMMARY:") + len("ARTIFACT_CLEANUP_SUMMARY:")
            kv_str = line[idx:].strip()
            result = {}
            for token in kv_str.split():
                if "=" in token:
                    k, v = token.split("=", 1)
                    result[k] = v
            return result
    return {}


def setup_temp_repo(fixture_name: str) -> Path:
    """Create a temporary git repository with the project files."""
    tmpdir = Path(tempfile.mkdtemp(prefix=f"artifact_cleanup_{fixture_name}_"))

    # Copy project files into the temp directory.
    for item in PROJECT_ITEMS:
        src = REPO_ROOT / item
        dst = tmpdir / item
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Initialise a fresh git repo so act can checkout the code.
    git_env = {**os.environ, "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "t@t.com",
               "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "t@t.com"}
    run(["git", "init", "-b", "main"], cwd=tmpdir, env=git_env)
    run(["git", "add", "."], cwd=tmpdir, env=git_env)
    run(["git", "commit", "-m", "test setup"], cwd=tmpdir, env=git_env)

    return tmpdir


def run_act(tmpdir: Path, fixture_name: str) -> subprocess.CompletedProcess:
    """Run `act push` in tmpdir with the given fixture name."""
    cmd = [
        "act", "push",
        "--rm",
        "-W", WORKFLOW_REL,
        "--env", f"FIXTURE_NAME={fixture_name}",
    ]
    return run(cmd, cwd=tmpdir, timeout=ACT_TIMEOUT)


# ─────────────────────────────────────────────────────────────
# Test categories
# ─────────────────────────────────────────────────────────────

def run_structure_tests(results: list) -> None:
    """Verify the workflow file and project structure without running act."""
    print("\n>>> STRUCTURE TESTS")

    # 1. Required files exist
    required = [
        "artifact_cleanup.py",
        "test_artifact_cleanup.py",
        WORKFLOW_REL,
        "fixtures/age_retention.json",
        "fixtures/size_retention.json",
        "fixtures/keep_latest_n.json",
        "fixtures/combined.json",
        "fixtures/dry_run.json",
    ]
    for rel_path in required:
        path = REPO_ROOT / rel_path
        ok = path.exists()
        status = "PASS" if ok else "FAIL"
        msg = f"  [{status}] file exists: {rel_path}"
        print(msg)
        results.append((f"file_exists:{rel_path}", ok, msg))

    # 2. Workflow YAML contains expected triggers and jobs
    workflow_text = (REPO_ROOT / WORKFLOW_REL).read_text()
    checks = [
        ("trigger:push",             "push:",              workflow_text),
        ("trigger:pull_request",     "pull_request:",      workflow_text),
        ("trigger:schedule",         "schedule:",          workflow_text),
        ("trigger:workflow_dispatch","workflow_dispatch:",  workflow_text),
        ("job:unit-tests",           "unit-tests:",        workflow_text),
        ("job:artifact-cleanup",     "artifact-cleanup:",  workflow_text),
        ("job_dep:unit-tests",       "needs: unit-tests",  workflow_text),
        ("checkout_action",          "actions/checkout@v4",workflow_text),
        ("script_ref:artifact_cleanup","artifact_cleanup.py",workflow_text),
    ]
    for name, needle, text in checks:
        ok = needle in text
        status = "PASS" if ok else "FAIL"
        msg = f"  [{status}] workflow contains '{needle}'"
        print(msg)
        results.append((f"workflow_contains:{name}", ok, msg))

    # 3. actionlint
    r = run(["actionlint", WORKFLOW_REL], cwd=REPO_ROOT)
    ok = r.returncode == 0
    status = "PASS" if ok else "FAIL"
    detail = r.stdout + r.stderr if not ok else ""
    msg = f"  [{status}] actionlint exit code 0"
    if detail:
        msg += f"\n    {detail.strip()}"
    print(msg)
    results.append(("actionlint", ok, msg))


def run_act_test_case(
    fixture_name: str,
    expected_kv: dict,
    extra_checks: list,
    result_file_handle,
    results: list,
) -> None:
    """Run one act-based test case and assert on output."""
    print(f"\n>>> ACT TEST: {fixture_name}")
    label = banner(f"TEST CASE: {fixture_name}")
    result_file_handle.write(label + "\n")

    # Build temp repo
    tmpdir = setup_temp_repo(fixture_name)
    try:
        proc = run_act(tmpdir, fixture_name)
    except subprocess.TimeoutExpired:
        msg = f"  [FAIL] act timed out after {ACT_TIMEOUT}s"
        print(msg)
        result_file_handle.write(msg + "\n")
        results.append((f"act_timeout:{fixture_name}", False, msg))
        shutil.rmtree(tmpdir, ignore_errors=True)
        return
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    combined = proc.stdout + proc.stderr
    result_file_handle.write(combined)
    result_file_handle.write(banner(f"RESULT: {'PASS' if proc.returncode == 0 else 'FAIL'}") + "\n\n")

    # ── Assert exit code ──────────────────────────────────────
    ok = proc.returncode == 0
    msg = f"  [{'PASS' if ok else 'FAIL'}] act exit code 0 (got {proc.returncode})"
    print(msg)
    results.append((f"act_exit:{fixture_name}", ok, msg))
    if not ok:
        # Print last 20 lines of output to help diagnose
        for line in combined.splitlines()[-20:]:
            print(f"    {line}")

    # ── Assert "Job succeeded" for every job ─────────────────
    for job_label in ("unit-tests", "artifact-cleanup"):
        # act emits something like "[job-name/...] Job succeeded"
        succeeded = "Job succeeded" in combined
        ok2 = succeeded
        msg2 = f"  [{'PASS' if ok2 else 'FAIL'}] '{job_label}' Job succeeded"
        print(msg2)
        results.append((f"job_succeeded:{fixture_name}:{job_label}", ok2, msg2))

    # ── Parse ARTIFACT_CLEANUP_SUMMARY and assert values ─────
    summary = find_summary_values(combined)
    if not summary:
        msg3 = f"  [FAIL] ARTIFACT_CLEANUP_SUMMARY line not found in output"
        print(msg3)
        results.append((f"summary_found:{fixture_name}", False, msg3))
    else:
        results.append((f"summary_found:{fixture_name}", True,
                        f"  [PASS] ARTIFACT_CLEANUP_SUMMARY found"))
        for key, expected_val in expected_kv.items():
            actual_val = summary.get(key, "<missing>")
            ok3 = actual_val == expected_val
            msg3 = (f"  [{'PASS' if ok3 else 'FAIL'}]"
                    f" {key}={actual_val!r} (expected {expected_val!r})")
            print(msg3)
            results.append((f"summary_{key}:{fixture_name}", ok3, msg3))

    # ── Extra substring checks ────────────────────────────────
    for substring in extra_checks:
        ok4 = substring in combined
        msg4 = (f"  [{'PASS' if ok4 else 'FAIL'}]"
                f" output contains {substring!r}")
        print(msg4)
        results.append((f"extra_check:{fixture_name}:{substring}", ok4, msg4))


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main() -> int:
    results: list = []  # list of (name, passed: bool, msg: str)

    # Truncate / create result file
    RESULT_FILE.write_text("")

    with RESULT_FILE.open("a") as fh:
        fh.write(banner("ARTIFACT CLEANUP SCRIPT — TEST HARNESS RESULTS") + "\n\n")

        # ── Structure tests ───────────────────────────────────
        fh.write(banner("STRUCTURE TESTS") + "\n")
        run_structure_tests(results)
        struct_msgs = [msg for (_, _, msg) in results]
        fh.write("\n".join(struct_msgs) + "\n\n")

        # ── Act-based tests ───────────────────────────────────
        fh.write(banner("ACT-BASED TESTS") + "\n")
        for fixture_name, expected_kv, extra_checks in TEST_CASES:
            run_act_test_case(fixture_name, expected_kv, extra_checks, fh, results)

        # ── Final summary ─────────────────────────────────────
        passed = sum(1 for (_, ok, _) in results if ok)
        failed = sum(1 for (_, ok, _) in results if not ok)
        total  = len(results)
        summary_line = f"\nFINAL: {passed}/{total} passed, {failed} failed\n"
        print(summary_line)
        fh.write(banner("FINAL SUMMARY") + "\n")
        fh.write(summary_line)
        if failed:
            fh.write("\nFailed tests:\n")
            for name, ok, msg in results:
                if not ok:
                    fh.write(f"  {name}\n")

    print(f"\nResults written to: {RESULT_FILE}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
