#!/usr/bin/env python3
"""
run_act_tests.py - Test harness for Docker Image Tag Generator.

Runs every test case through the GitHub Actions workflow using 'act'.

Test strategy:
  1. Structure tests  – parse YAML, check file existence, run actionlint.
  2. Functional tests – for each test case:
       a. Create an isolated temp git repo with project files + fixture env.
       b. Run 'act push --rm' in that repo.
       c. Parse output for 'DOCKER_TAGS_OUTPUT:' marker.
       d. Assert exact expected tags AND exit-code-0 AND 'Job succeeded'.

Outputs:
  act-result.txt  – full act stdout/stderr for every test case, delimited.
  Exit code 0     – all tests passed.
  Exit code 1     – at least one test failed.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Auto-install pyyaml if not present (needed for YAML structure tests).
try:
    import yaml
except ImportError:
    subprocess.run(
        [sys.executable, "-m", "pip", "install", "pyyaml", "--quiet"], check=True
    )
    import yaml


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).parent.resolve()
WORKFLOW_FILE = PROJECT_ROOT / ".github" / "workflows" / "docker-image-tag-generator.yml"
SCRIPT_FILE = PROJECT_ROOT / "docker_tag_generator.py"
TEST_FILE = PROJECT_ROOT / "test_docker_tag_generator.py"
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"

# Files copied into each temp git repo for act to use
PROJECT_FILES = ["docker_tag_generator.py", "test_docker_tag_generator.py"]


# ---------------------------------------------------------------------------
# Fixture-driven test cases
# Each case describes input env vars → exact expected Docker tags.
# ---------------------------------------------------------------------------
TEST_CASES = [
    {
        "name": "main-branch",
        "description": "main branch → only 'latest'",
        "env": {
            "TEST_BRANCH": "main",
            "TEST_SHA": "abc1234def5678",
            "TEST_TAGS": "",
            "TEST_PR_NUMBER": "",
        },
        "expected_tags": ["latest"],
    },
    {
        "name": "master-branch",
        "description": "master branch → only 'latest'",
        "env": {
            "TEST_BRANCH": "master",
            "TEST_SHA": "abc1234def5678",
            "TEST_TAGS": "",
            "TEST_PR_NUMBER": "",
        },
        "expected_tags": ["latest"],
    },
    {
        "name": "pull-request",
        "description": "PR #42 → only 'pr-42'",
        "env": {
            "TEST_BRANCH": "feature/my-feature",
            "TEST_SHA": "abc1234def5678",
            "TEST_TAGS": "",
            "TEST_PR_NUMBER": "42",
        },
        "expected_tags": ["pr-42"],
    },
    {
        "name": "semver-tag",
        "description": "git tag v1.2.3 on main → 'latest' and 'v1.2.3'",
        "env": {
            "TEST_BRANCH": "main",
            "TEST_SHA": "abc1234def5678",
            "TEST_TAGS": "v1.2.3",
            "TEST_PR_NUMBER": "",
        },
        "expected_tags": ["latest", "v1.2.3"],
    },
    {
        "name": "feature-branch",
        "description": "feature/my-feature → 'feature-my-feature-abc1234'",
        "env": {
            "TEST_BRANCH": "feature/my-feature",
            "TEST_SHA": "abc1234def5678",
            "TEST_TAGS": "",
            "TEST_PR_NUMBER": "",
        },
        "expected_tags": ["feature-my-feature-abc1234"],
    },
    {
        "name": "branch-special-chars",
        "description": "Feature/My_Branch → sanitized 'feature-my-branch-abc1234'",
        "env": {
            "TEST_BRANCH": "Feature/My_Branch",
            "TEST_SHA": "abc1234def5678",
            "TEST_TAGS": "",
            "TEST_PR_NUMBER": "",
        },
        "expected_tags": ["feature-my-branch-abc1234"],
    },
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_tags_from_output(output: str) -> list:
    """Extract the tag list from the 'DOCKER_TAGS_OUTPUT: ...' marker line."""
    for line in output.splitlines():
        if "DOCKER_TAGS_OUTPUT:" in line:
            _, _, rest = line.partition("DOCKER_TAGS_OUTPUT:")
            return sorted(t.strip() for t in rest.split(",") if t.strip())
    return []


def job_succeeded(output: str) -> bool:
    """Return True if act output contains the 'Job succeeded' indicator."""
    return "Job succeeded" in output


def setup_temp_repo(test_case: dict) -> str:
    """
    Create a temp git repo containing project files + the workflow.
    Returns the path to the temp directory.
    """
    tmpdir = tempfile.mkdtemp(prefix=f"act-{test_case['name']}-")
    try:
        # Copy Python scripts
        for fname in PROJECT_FILES:
            src = PROJECT_ROOT / fname
            if src.exists():
                shutil.copy2(src, tmpdir)

        # Copy workflow
        wf_dst = os.path.join(tmpdir, ".github", "workflows")
        os.makedirs(wf_dst, exist_ok=True)
        shutil.copy2(WORKFLOW_FILE, wf_dst)

        # Initialise git repo
        for cmd in [
            ["git", "init"],
            ["git", "config", "user.email", "test@benchmark.local"],
            ["git", "config", "user.name", "Benchmark"],
            ["git", "add", "."],
            ["git", "commit", "-m", f"fixture: {test_case['name']}"],
        ]:
            r = subprocess.run(cmd, cwd=tmpdir, capture_output=True, text=True)
            if r.returncode != 0:
                raise RuntimeError(
                    f"git command failed: {cmd}\n{r.stdout}\n{r.stderr}"
                )
        return tmpdir
    except Exception:
        shutil.rmtree(tmpdir, ignore_errors=True)
        raise


def run_act_case(test_case: dict):
    """
    Run one test case via 'act push --rm'.
    Returns (passed: bool, output: str, details: dict).
    """
    tmpdir = setup_temp_repo(test_case)
    try:
        cmd = ["act", "push", "--rm"]
        for k, v in test_case["env"].items():
            cmd += ["--env", f"{k}={v}"]

        r = subprocess.run(
            cmd,
            cwd=tmpdir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=360,
        )
        output = r.stdout

        actual = parse_tags_from_output(output)
        expected = sorted(test_case["expected_tags"])
        ok_exit = r.returncode == 0
        ok_job = job_succeeded(output)
        ok_tags = actual == expected
        passed = ok_exit and ok_job and ok_tags

        details = {
            "act_exit_code": r.returncode,
            "job_succeeded": ok_job,
            "actual_tags": actual,
            "expected_tags": expected,
            "tags_match": ok_tags,
        }
        return passed, output, details
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Structure tests (no act needed)
# ---------------------------------------------------------------------------

def run_structure_tests(result_fh) -> bool:
    """
    Validate workflow YAML structure, file existence, and actionlint.
    Writes results to result_fh. Returns True if all checks pass.
    """
    all_ok = True
    lines = []

    def check(label: str, ok: bool, detail: str = "") -> bool:
        nonlocal all_ok
        if not ok:
            all_ok = False
        status = "PASS" if ok else "FAIL"
        msg = f"  [{status}] {label}"
        if detail:
            msg += f"\n         {detail}"
        lines.append(msg)
        print(msg)
        return ok

    # File existence
    check("Script file exists", SCRIPT_FILE.exists(), str(SCRIPT_FILE))
    check("Test file exists", TEST_FILE.exists(), str(TEST_FILE))
    check("Workflow file exists", WORKFLOW_FILE.exists(), str(WORKFLOW_FILE))

    if WORKFLOW_FILE.exists():
        wf_text = WORKFLOW_FILE.read_text()
        wf = yaml.safe_load(wf_text)

        # PyYAML (YAML 1.1) parses the bare word 'on' as boolean True.
        # GitHub Actions uses 'on:' as the trigger key, so we must look
        # for both the string "on" and the boolean True.
        on = wf.get("on", wf.get(True, {}))
        check("Trigger: push", "push" in on)
        check("Trigger: pull_request", "pull_request" in on)
        check("Trigger: workflow_dispatch", "workflow_dispatch" in on)

        jobs = wf.get("jobs", {})
        check("At least one job defined", len(jobs) > 0)
        check("Workflow references docker_tag_generator.py", "docker_tag_generator.py" in wf_text)
        check("Workflow references test file", "test_docker_tag_generator.py" in wf_text)

    # actionlint
    al = subprocess.run(
        ["actionlint", str(WORKFLOW_FILE)],
        capture_output=True, text=True,
    )
    detail = (al.stdout + al.stderr).strip() if al.returncode != 0 else ""
    check("actionlint passes (exit 0)", al.returncode == 0, detail)

    sep = "=" * 70
    block = f"\n{sep}\nSTRUCTURE TESTS\n{sep}\n" + "\n".join(lines) + "\n"
    result_fh.write(block)
    result_fh.flush()
    return all_ok


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    print("=" * 70)
    print("Docker Image Tag Generator — Test Harness")
    print("=" * 70)

    with open(ACT_RESULT_FILE, "w") as rf:

        # --- Structure tests ------------------------------------------------
        print("\n[Structure Tests]")
        struct_ok = run_structure_tests(rf)
        if not struct_ok:
            print("\nFATAL: Structure tests failed — fix issues before act tests.")

        # --- Functional tests via act ---------------------------------------
        print("\n[Functional Tests via act]")
        results = []

        for i, tc in enumerate(TEST_CASES, 1):
            print(f"\nTest {i}/{len(TEST_CASES)}: {tc['name']}")
            print(f"  {tc['description']}")

            try:
                passed, output, details = run_act_case(tc)
            except subprocess.TimeoutExpired:
                passed, output = False, "ERROR: act timed out (360 s)"
                details = {
                    "act_exit_code": -1, "job_succeeded": False,
                    "actual_tags": [], "expected_tags": tc["expected_tags"],
                    "tags_match": False,
                }
            except Exception as exc:
                passed, output = False, f"ERROR: {exc}"
                details = {
                    "act_exit_code": -1, "job_succeeded": False,
                    "actual_tags": [], "expected_tags": tc["expected_tags"],
                    "tags_match": False,
                }

            results.append({"tc": tc, "passed": passed, "details": details})

            s = lambda ok: "PASS" if ok else "FAIL"
            print(f"  [{s(details['act_exit_code'] == 0)}] act exit code:  {details['act_exit_code']}")
            print(f"  [{s(details['job_succeeded'])}] Job succeeded:  {details['job_succeeded']}")
            print(f"  [{s(details['tags_match'])}] Expected tags:  {details['expected_tags']}")
            print(f"  [{s(details['tags_match'])}] Actual tags:    {details['actual_tags']}")
            print(f"  => {s(passed)}")

            sep = "=" * 70
            body = (
                f"Test:         {tc['name']}\n"
                f"Description:  {tc['description']}\n"
                f"Input env:    {tc['env']}\n"
                f"Expected:     {details['expected_tags']}\n"
                f"Actual:       {details['actual_tags']}\n"
                f"act exit:     {details['act_exit_code']}\n"
                f"Job succeeded:{details['job_succeeded']}\n"
                f"Tags match:   {details['tags_match']}\n"
                f"RESULT:       {s(passed)}\n\n"
                f"--- act output ---\n{output}\n--- end ---"
            )
            rf.write(f"\n{sep}\nTEST CASE: {tc['name'].upper()}\n{sep}\n{body}\n")
            rf.flush()

        # --- Summary --------------------------------------------------------
        n_pass = sum(1 for r in results if r["passed"])
        n_total = len(results)
        all_ok = struct_ok and (n_pass == n_total)

        summary = (
            f"Structure tests:  {'PASS' if struct_ok else 'FAIL'}\n"
            f"Functional tests: {n_pass}/{n_total} passed\n"
            f"Overall:          {'PASS' if all_ok else 'FAIL'}\n"
        )
        sep = "=" * 70
        rf.write(f"\n{sep}\nFINAL SUMMARY\n{sep}\n{summary}\n")

        print(f"\n{'=' * 70}")
        print("FINAL SUMMARY")
        print("=" * 70)
        print(summary)
        print(f"Full output saved to: {ACT_RESULT_FILE}")

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
