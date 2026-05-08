#!/usr/bin/env python3
"""
Act-based integration harness for the dependency license checker.

For each fixture under tests/fixtures/case_*, this script:
  1. Builds an isolated temp git repo containing the project files plus that
     case's manifest, config.json, license_db.json.
  2. Invokes `act push --rm` inside it.
  3. Appends every act invocation's combined stdout/stderr to act-result.txt
     (with a clear delimiter between cases).
  4. Asserts:
       - act exited with code 0
       - both jobs (unit-tests, license-check) printed "Job succeeded"
       - the workflow's printed checker output contains the EXACT summary
         line, EXACT compliance verdict, and EXACT per-dependency status
         rows recorded in the case's expected.json
       - actionlint passes against the workflow file (exit 0)
       - the workflow YAML has the expected high-level structure

Run:
    python3 run_act_tests.py
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parent
WORKFLOW = ROOT / ".github/workflows/dependency-license-checker.yml"
FIXTURES_DIR = ROOT / "tests/fixtures"
ACT_RESULT_FILE = ROOT / "act-result.txt"

# Files copied into every per-case temp repo. Globs and dirs allowed.
PROJECT_FILES = [
    "license_checker.py",
    "tests",
    ".github",
    ".actrc",
]


# ---------------------------------------------------------------------------
# Pre-flight checks (do not exercise the script directly — pure structural)
# ---------------------------------------------------------------------------

def assert_actionlint_passes() -> None:
    """Workflow must pass actionlint cleanly."""
    proc = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        sys.stderr.write(
            "actionlint failed:\n"
            f"stdout: {proc.stdout}\nstderr: {proc.stderr}\n"
        )
        raise SystemExit(1)
    print("[ok] actionlint clean")


def assert_workflow_structure() -> None:
    """Parse the workflow YAML and assert on its high-level shape.

    Verifies triggers, jobs, and that the workflow refers to files that
    actually exist on disk.
    """
    try:
        import yaml  # PyYAML is in the act image; locally maybe not.
    except ImportError:
        # Fall back to a regex-based structural check so the harness still
        # runs on a vanilla Python install.
        text = WORKFLOW.read_text()
        for needle in (
            "name: Dependency License Checker",
            "push:",
            "pull_request:",
            "schedule:",
            "workflow_dispatch:",
            "permissions:",
            "contents: read",
            "unit-tests:",
            "license-check:",
            "actions/checkout@v4",
            "actions/setup-python@v5",
            "license_checker.py",
            "pytest tests/",
        ):
            assert needle in text, f"workflow missing structural element: {needle!r}"
        print("[ok] workflow structure (regex fallback)")
    else:
        spec = yaml.safe_load(WORKFLOW.read_text())
        # PyYAML interprets the bare YAML key `on:` as the boolean True.
        triggers = spec.get("on") or spec.get(True)
        assert isinstance(triggers, dict), "expected `on:` to be a mapping"
        for ev in ("push", "pull_request", "schedule", "workflow_dispatch"):
            assert ev in triggers, f"missing trigger: {ev}"
        assert spec.get("permissions", {}).get("contents") == "read"
        jobs = spec["jobs"]
        assert "unit-tests" in jobs and "license-check" in jobs
        assert jobs["license-check"].get("needs") == "unit-tests"
        # Verify referenced files exist on disk.
        assert (ROOT / "license_checker.py").exists()
        assert (ROOT / "tests").is_dir()
        # Verify the checkout/setup-python action references are present.
        all_uses = []
        for job in jobs.values():
            for step in job.get("steps", []):
                if "uses" in step:
                    all_uses.append(step["uses"])
        assert "actions/checkout@v4" in all_uses
        assert "actions/setup-python@v5" in all_uses
        print("[ok] workflow structure (yaml)")


# ---------------------------------------------------------------------------
# Per-case act runner
# ---------------------------------------------------------------------------

def _populate_temp_repo(temp: Path, case_dir: Path) -> None:
    """Copy project files + the case fixture into a fresh temp repo."""
    for entry in PROJECT_FILES:
        src = ROOT / entry
        dst = temp / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    # Copy fixture manifest + config + license_db to the repo root.
    for f in case_dir.iterdir():
        if f.name == "expected.json":
            continue
        shutil.copy2(f, temp / f.name)
    # `git init` + commit so act has something to "push".
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=temp, check=True)
    subprocess.run(
        ["git", "config", "user.email", "ci@example.com"], cwd=temp, check=True
    )
    subprocess.run(
        ["git", "config", "user.name", "ci"], cwd=temp, check=True
    )
    subprocess.run(["git", "add", "-A"], cwd=temp, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "test fixture"], cwd=temp, check=True
    )


def _run_act(temp: Path) -> subprocess.CompletedProcess:
    """Run `act push --rm` in the temp repo, capturing combined output."""
    return subprocess.run(
        ["act", "push", "--rm"],
        cwd=temp,
        capture_output=True,
        text=True,
        check=False,
        timeout=600,
    )


def _append_to_result(case_name: str, header: str, body: str) -> None:
    with ACT_RESULT_FILE.open("a", encoding="utf-8") as f:
        f.write(f"\n{'=' * 80}\n")
        f.write(f"TEST CASE: {case_name}\n")
        f.write(f"{header}\n")
        f.write("=" * 80 + "\n")
        f.write(body)
        if not body.endswith("\n"):
            f.write("\n")


def _assert_case(case_name: str, expected: dict, output: str) -> List[str]:
    """Return list of failure messages (empty on success)."""
    failures: List[str] = []

    # Both jobs must emit `Job succeeded`.
    job_succeeded_count = output.count("Job succeeded")
    if job_succeeded_count < 2:
        failures.append(
            f"expected 2x 'Job succeeded' (one per job), saw {job_succeeded_count}"
        )

    for line in expected["expected_status_lines"]:
        if line not in output:
            failures.append(f"missing status row: {line!r}")
    if expected["expected_summary_line"] not in output:
        failures.append(f"missing summary line: {expected['expected_summary_line']!r}")
    if expected["expected_compliant_line"] not in output:
        failures.append(
            f"missing compliance verdict line: {expected['expected_compliant_line']!r}"
        )
    # Script exit code echoed by the workflow as `SCRIPT_EXIT_CODE=N`.
    expected_exit_token = f"SCRIPT_EXIT_CODE={expected['expected_script_exit']}"
    if expected_exit_token not in output:
        failures.append(f"missing script exit echo: {expected_exit_token!r}")

    # Verdict line printed by the final workflow step.
    if expected["expected_script_exit"] == "0":
        if "VERDICT: COMPLIANT" not in output:
            failures.append("missing 'VERDICT: COMPLIANT'")
    else:
        if "VERDICT: NON_COMPLIANT" not in output:
            failures.append("missing 'VERDICT: NON_COMPLIANT'")

    return failures


def run_case(case_dir: Path) -> bool:
    """Run a single test case end-to-end. Returns True iff it passes."""
    case_name = case_dir.name
    expected = json.loads((case_dir / "expected.json").read_text())
    print(f"\n--- {case_name} ---")
    with tempfile.TemporaryDirectory(prefix=f"act-{case_name}-") as td:
        temp = Path(td)
        _populate_temp_repo(temp, case_dir)
        proc = _run_act(temp)

    combined = (proc.stdout or "") + (proc.stderr or "")
    header = f"act exit code: {proc.returncode}"
    _append_to_result(case_name, header, combined)

    failures: List[str] = []
    if proc.returncode != 0:
        failures.append(f"act exit code {proc.returncode} (expected 0)")
    failures.extend(_assert_case(case_name, expected, combined))

    if failures:
        for f in failures:
            print(f"  FAIL: {f}")
        return False
    print("  PASS")
    return True


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    # Truncate the result file at the start of each run so reruns don't append
    # forever — but keep the path stable so the artifact requirement is met.
    ACT_RESULT_FILE.write_text("")

    assert_actionlint_passes()
    assert_workflow_structure()

    cases = sorted(p for p in FIXTURES_DIR.iterdir() if p.is_dir() and p.name.startswith("case_"))
    if not cases:
        print("no fixtures found", file=sys.stderr)
        return 1

    results = [run_case(c) for c in cases]
    failed = sum(1 for ok in results if not ok)
    total = len(results)
    print()
    print(textwrap.dedent(
        f"""
        Summary
        -------
        Cases run: {total}
        Passed   : {total - failed}
        Failed   : {failed}
        Result   : {ACT_RESULT_FILE}
        """
    ).strip())
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
