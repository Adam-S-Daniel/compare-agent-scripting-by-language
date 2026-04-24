"""Workflow test harness.

Runs the GitHub Actions workflow locally via `act` for each test case, saves
the combined log to `act-result.txt`, and asserts exact expected output.

The harness ALSO validates the workflow's YAML structure and that actionlint
passes (both cheap sanity checks that would catch regressions without needing
an act run).

Budget: at most 3 `act push` invocations total — keep it that way.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, List

import yaml

HERE = Path(__file__).resolve().parent
WORKFLOW = HERE / ".github" / "workflows" / "dependency-license-checker.yml"
ACT_RESULT = HERE / "act-result.txt"


# ---------------------------------------------------------------------------
# Static structural checks (no act required)
# ---------------------------------------------------------------------------


def check_yaml_structure() -> None:
    """Parse the workflow and assert the shape we depend on."""
    doc = yaml.safe_load(WORKFLOW.read_text())
    # PyYAML parses the top-level `on` key as bool True on some builds;
    # accept either spelling for safety.
    triggers = doc.get("on") or doc.get(True)
    assert triggers is not None, "workflow must declare triggers"
    for needed in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert needed in triggers, f"missing trigger: {needed}"

    jobs = doc.get("jobs", {})
    assert "unit-tests" in jobs and "compliance" in jobs, "expected both jobs"
    assert jobs["compliance"].get("needs") == "unit-tests", \
        "compliance must depend on unit-tests"

    steps = jobs["compliance"]["steps"]
    step_names = [s.get("name", "") for s in steps]
    assert any("compliance report" in n.lower() for n in step_names), \
        "missing compliance-report step"

    # Every `run:` that invokes license_checker.py must reference a real file.
    referenced = re.findall(r"license_checker\.py", WORKFLOW.read_text())
    assert referenced, "workflow should invoke license_checker.py"
    assert (HERE / "license_checker.py").exists(), "script missing"
    assert (HERE / "fixtures" / "policy.json").exists(), "policy fixture missing"

    print("[ok] YAML structure checks passed")


def check_actionlint() -> None:
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)], capture_output=True, text=True
    )
    assert result.returncode == 0, (
        f"actionlint failed: {result.stdout}\n{result.stderr}"
    )
    print("[ok] actionlint clean")


# ---------------------------------------------------------------------------
# act-based cases
# ---------------------------------------------------------------------------


@dataclass
class Case:
    name: str
    # setup receives the temp repo root and writes the fixture it needs.
    setup: Callable[[Path], str]  # returns the MANIFEST_FILE path
    # assertions receive the captured stdout+stderr from act.
    assertions: Callable[[str], None]


def _write(p: Path, contents: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(contents)


def _setup_all_approved(repo: Path) -> str:
    # Ship the default fixture; all listed deps have allow-list licenses
    # in the built-in fake DB.
    return "fixtures/sample-package.json"


def _assert_all_approved(output: str) -> None:
    # Three deps listed, all approved, no violations.
    assert "lodash" in output and "APPROVED" in output
    assert "express" in output
    assert "jest" in output
    assert "DENIED" not in output, "no denied deps expected"
    assert "approved=3" in output
    assert "denied=0" in output
    assert "unknown=0" in output
    assert "COMPLIANCE_EXIT=0" in output
    assert "STATUS: clean" in output


def _setup_violation(repo: Path) -> str:
    manifest = {
        "name": "risky-app",
        "dependencies": {
            "lodash": "^4.17.21",
            "banned-pkg": "1.0.0",
        },
    }
    _write(repo / "fixtures" / "violation-package.json", json.dumps(manifest))
    return "fixtures/violation-package.json"


def _assert_violation(output: str) -> None:
    assert "banned-pkg" in output
    assert "GPL-3.0" in output
    assert "DENIED" in output
    assert "APPROVED" in output  # lodash still fine
    assert "approved=1" in output
    assert "denied=1" in output
    assert "COMPLIANCE_EXIT=1" in output
    assert "STATUS: violations-present" in output


def _setup_requirements(repo: Path) -> str:
    contents = (
        "# test fixture\n"
        "flask>=2.0.0\n"
        "pytest\n"
        "requests==2.31.0\n"
        "mystery-pkg==0.0.1  # not in the fake DB -> unknown\n"
    )
    _write(repo / "fixtures" / "sample-requirements.txt", contents)
    return "fixtures/sample-requirements.txt"


def _assert_requirements(output: str) -> None:
    # flask (BSD-3-Clause) + requests (Apache-2.0) + pytest (MIT) approved;
    # mystery-pkg unknown (not in DB); nothing denied.
    assert "flask" in output
    assert "requests" in output
    assert "pytest" in output
    assert "mystery-pkg" in output
    assert "UNKNOWN" in output
    assert "DENIED" not in output
    assert "approved=3" in output
    assert "denied=0" in output
    assert "unknown=1" in output
    assert "COMPLIANCE_EXIT=0" in output
    assert "STATUS: clean" in output


CASES: List[Case] = [
    Case("all-approved", _setup_all_approved, _assert_all_approved),
    Case("violation", _setup_violation, _assert_violation),
    Case("requirements-txt", _setup_requirements, _assert_requirements),
]


# Files that must be present in the temp repo for the workflow to run.
# Everything else (node_modules, __pycache__, etc.) is skipped.
_SHIPPED = [
    "license_checker.py",
    "tests/__init__.py",
    "tests/test_license_checker.py",
    "tests/fake_license_db.py",
    "fixtures/policy.json",
    "fixtures/sample-package.json",
    ".github/workflows/dependency-license-checker.yml",
    ".actrc",
]


def _prepare_repo(root: Path) -> None:
    for rel in _SHIPPED:
        src = HERE / rel
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    # act requires a git repo; minimal init is enough.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=root, check=True)
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(
        ["git", "-c", "user.email=ci@test", "-c", "user.name=ci",
         "commit", "-qm", "test"],
        cwd=root, check=True,
    )


def run_case(case: Case, tmp_root: Path) -> None:
    repo = tmp_root / f"repo-{case.name}"
    repo.mkdir(parents=True, exist_ok=True)
    _prepare_repo(repo)
    manifest_path = case.setup(repo)

    # Re-commit any new fixture files written by the case.
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(
        ["git", "-c", "user.email=ci@test", "-c", "user.name=ci",
         "commit", "--allow-empty", "-qm", f"case:{case.name}"],
        cwd=repo, check=True,
    )

    cmd = [
        "act", "push", "--rm",
        "--pull=false",  # act-ubuntu-pwsh is a locally-built image
        "--env", f"MANIFEST_FILE={manifest_path}",
        "-W", ".github/workflows/dependency-license-checker.yml",
    ]
    print(f"\n[run] {case.name}: {' '.join(cmd)}")
    proc = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
    combined = proc.stdout + "\n" + proc.stderr

    with ACT_RESULT.open("a") as f:
        f.write(f"\n\n===== CASE: {case.name} =====\n")
        f.write(f"command: {' '.join(cmd)}\n")
        f.write(f"cwd: {repo}\n")
        f.write(f"exit_code: {proc.returncode}\n")
        f.write("----- STDOUT -----\n")
        f.write(proc.stdout)
        f.write("\n----- STDERR -----\n")
        f.write(proc.stderr)
        f.write("\n===== END CASE: " + case.name + " =====\n")

    assert proc.returncode == 0, (
        f"act exited {proc.returncode} for case {case.name}\n"
        f"--- stdout ---\n{proc.stdout}\n--- stderr ---\n{proc.stderr}"
    )
    # act emits a "Job succeeded" line per successful job. We expect both.
    job_succeeded = combined.count("Job succeeded")
    assert job_succeeded >= 2, (
        f"expected both jobs to print 'Job succeeded', got {job_succeeded}"
        f"\nOutput:\n{combined[-4000:]}"
    )
    case.assertions(combined)
    print(f"[pass] {case.name}")


def main() -> int:
    # Reset the artifact file on each run.
    ACT_RESULT.write_text(
        f"# dependency-license-checker act test harness output\n"
        f"# cases: {', '.join(c.name for c in CASES)}\n"
    )

    check_yaml_structure()
    check_actionlint()

    tmp_root = HERE / ".act-harness-tmp"
    if tmp_root.exists():
        shutil.rmtree(tmp_root)
    tmp_root.mkdir()

    try:
        for case in CASES:
            run_case(case, tmp_root)
    finally:
        # Keep the logs but remove the working copies to save disk.
        shutil.rmtree(tmp_root, ignore_errors=True)

    print("\nAll act cases passed. Artifact: act-result.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
