"""
End-to-end test harness: every test case runs through the GitHub Actions
workflow via `act`.

For each case we:
    1. Set up a temp git repo containing the project + the case's fixtures.
    2. Run `act push --rm`.
    3. Capture stdout/stderr to `act-result.txt` (append, delimited per case).
    4. Assert act exited 0, both jobs succeeded, and the captured report
       matches the exact expected values for that case.

We also run a few workflow-structure tests up front: YAML parse, expected
jobs/triggers/steps, referenced paths exist, and actionlint passes. These
do not need act to run, per the task spec.

Run directly:  python3 run_act_tests.py
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
WORKFLOW = HERE / ".github" / "workflows" / "dependency-license-checker.yml"
SCRIPT = HERE / "license_checker.py"
ACT_RESULT = HERE / "act-result.txt"

# Project files that must exist in the temp repo for the workflow to run.
PROJECT_FILES = [
    "license_checker.py",
    "tests/__init__.py",
    "tests/test_license_checker.py",
    ".github/workflows/dependency-license-checker.yml",
    ".actrc",
]


# ---------------------------------------------------------------------------
# Test cases — each is driven by a manifest + config pair
# ---------------------------------------------------------------------------

TEST_CASES = [
    {
        "name": "all_approved",
        "manifest_name": "requirements.txt",
        "manifest": "requests==2.31.0\nflask==3.0.0\n",
        "config": {
            "allow": ["Apache-2.0", "BSD-3-Clause", "MIT"],
            "deny": ["GPL-3.0", "AGPL-3.0"],
            "mock_licenses": {
                "requests": "Apache-2.0",
                "flask": "BSD-3-Clause",
            },
        },
        "expected_overall": "pass",
        "expected_summary": {"approved": 2, "denied": 0, "unknown": 0, "total": 2},
        "expected_checker_rc": 0,
    },
    {
        "name": "has_denied",
        "manifest_name": "requirements.txt",
        "manifest": "evil-lib==0.1.0\nflask==3.0.0\n",
        "config": {
            "allow": ["BSD-3-Clause", "MIT"],
            "deny": ["GPL-3.0"],
            "mock_licenses": {
                "evil-lib": "GPL-3.0",
                "flask": "BSD-3-Clause",
            },
        },
        "expected_overall": "fail",
        "expected_summary": {"approved": 1, "denied": 1, "unknown": 0, "total": 2},
        "expected_checker_rc": 2,
    },
    {
        "name": "package_json_with_unknown",
        "manifest_name": "package.json",
        "manifest": json.dumps({
            "name": "demo",
            "dependencies": {"lodash": "^4.17.21", "mystery-lib": "1.0.0"},
            "devDependencies": {"jest": "29.7.0"},
        }, indent=2),
        "config": {
            "allow": ["MIT", "Apache-2.0"],
            "deny": ["GPL-3.0"],
            "mock_licenses": {
                "lodash": "MIT",
                "jest": "MIT",
            },
        },
        "expected_overall": "warn",
        "expected_summary": {"approved": 2, "denied": 0, "unknown": 1, "total": 3},
        "expected_checker_rc": 1,
    },
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class HarnessError(Exception):
    pass


def _log(msg: str) -> None:
    print(f"[harness] {msg}", flush=True)


def _run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def _assert(cond: bool, msg: str) -> None:
    if not cond:
        raise HarnessError(msg)


def _prepare_repo(root: Path, case: dict) -> None:
    """Copy project files into `root`, drop in the case's fixtures, git init."""
    for rel in PROJECT_FILES:
        src = HERE / rel
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Write the case-specific fixtures to fixtures/ (where the workflow reads).
    fixtures_dir = root / "fixtures"
    fixtures_dir.mkdir(exist_ok=True)
    # The workflow hard-codes `fixtures/manifest` as the path (env var MANIFEST).
    # If this case uses package.json, write the content to `fixtures/manifest`
    # AND rename to `package.json` for the parser to dispatch correctly.
    manifest_path = fixtures_dir / case["manifest_name"]
    manifest_path.write_text(case["manifest"])
    (fixtures_dir / "config.json").write_text(json.dumps(case["config"], indent=2))

    # Rewrite the MANIFEST env var in the workflow to match this case's name
    # (requirements.txt vs package.json are dispatched by filename).
    wf = root / ".github" / "workflows" / "dependency-license-checker.yml"
    wf_text = wf.read_text()
    # The default workflow references fixtures/requirements.txt. Rewrite to
    # the per-case manifest filename (the parser dispatches on filename).
    wf_text = re.sub(
        r"MANIFEST: fixtures/[^\s]+",
        f"MANIFEST: fixtures/{case['manifest_name']}",
        wf_text,
    )
    wf.write_text(wf_text)

    # git init — act insists on running inside a git repository.
    _run(["git", "init", "-q", "-b", "main"], cwd=root)
    _run(["git", "config", "user.email", "test@example.com"], cwd=root)
    _run(["git", "config", "user.name", "Test"], cwd=root)
    _run(["git", "add", "."], cwd=root)
    _run(["git", "commit", "-q", "-m", "test fixture"], cwd=root)


def _strip_act_prefix(line: str) -> str:
    """Strip act's `[workflow/job]   | ` line prefix (any amount of either)."""
    # Remove `[anything] ` leading tag.
    line = re.sub(r"^\[[^\]]*\]\s*", "", line)
    # Remove a leading `| ` pipe marker (act's stdout marker).
    line = re.sub(r"^\|\s?", "", line)
    return line


def _extract_report(act_output: str) -> dict:
    """Find the JSON report printed between BEGIN_REPORT / END_REPORT."""
    m = re.search(r"BEGIN_REPORT[^\n]*\n(.+?)END_REPORT", act_output, re.DOTALL)
    _assert(m is not None, "could not find BEGIN_REPORT/END_REPORT markers in act output")
    raw = m.group(1)
    cleaned = "\n".join(_strip_act_prefix(ln) for ln in raw.splitlines())
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise HarnessError(f"report JSON was not parseable: {exc}\n---\n{cleaned[:500]}")


def _extract_checker_rc(act_output: str) -> int:
    m = re.search(r"LICENSE_CHECK_EXIT_CODE=(\d+)", act_output)
    _assert(m is not None, "LICENSE_CHECK_EXIT_CODE not found in act output")
    return int(m.group(1))


# ---------------------------------------------------------------------------
# Workflow structure tests (no act required)
# ---------------------------------------------------------------------------

def test_workflow_structure() -> None:
    _log("workflow-structure: checking YAML, paths, and actionlint")
    import yaml  # PyYAML is in the default Python stdlib-ish ecosystem; fallback below

    wf_text = WORKFLOW.read_text()
    data = yaml.safe_load(wf_text)

    # Triggers
    # NOTE: PyYAML parses the YAML key `on:` as the boolean True (since YAML
    # 1.1 treats "on" as a bool). Accept either form.
    triggers = data.get("on", data.get(True))
    _assert(triggers is not None, "workflow has no triggers")
    _assert("push" in triggers, "workflow missing push trigger")
    _assert("pull_request" in triggers, "workflow missing pull_request trigger")
    _assert("schedule" in triggers, "workflow missing schedule trigger")
    _assert("workflow_dispatch" in triggers, "workflow missing workflow_dispatch trigger")

    # Jobs
    jobs = data.get("jobs", {})
    _assert("unit-tests" in jobs, "workflow missing unit-tests job")
    _assert("license-check" in jobs, "workflow missing license-check job")
    _assert(jobs["license-check"].get("needs") == "unit-tests",
            "license-check should depend on unit-tests")

    # Steps reference real paths
    all_steps = []
    for job in jobs.values():
        all_steps.extend(job.get("steps", []))
    body = json.dumps(all_steps)
    _assert("license_checker.py" in body, "workflow does not reference license_checker.py")
    _assert("tests/" in body, "workflow does not reference tests/")
    _assert(SCRIPT.exists(), f"referenced script missing: {SCRIPT}")

    # actionlint must be clean
    r = _run(["actionlint", str(WORKFLOW)])
    _assert(r.returncode == 0, f"actionlint failed: {r.stdout}{r.stderr}")

    _log("workflow-structure: OK")


# ---------------------------------------------------------------------------
# Per-case: run via act and assert
# ---------------------------------------------------------------------------

def run_case(case: dict, out_fh) -> None:
    _log(f"--- case: {case['name']} ---")
    out_fh.write(f"\n\n========== CASE: {case['name']} ==========\n")
    out_fh.flush()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        _prepare_repo(tmp_path, case)

        # `act push --rm --pull=false` — --rm cleans up containers afterwards,
        # --pull=false uses the local act-ubuntu-pwsh image (from .actrc)
        # without trying to fetch it from a registry (it is local-only).
        proc = subprocess.run(
            ["act", "push", "--rm", "--pull=false"],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=600,
        )

        combined = proc.stdout + "\n--- STDERR ---\n" + proc.stderr
        out_fh.write(combined)
        out_fh.write(f"\n[act exit code: {proc.returncode}]\n")
        out_fh.flush()

        # Hard assertions — failure here fails the harness.
        _assert(proc.returncode == 0, f"act exited {proc.returncode} for {case['name']}")
        _assert("Job succeeded" in combined, f"no 'Job succeeded' in output for {case['name']}")

        # Both jobs must succeed — count the messages.
        succeeded = combined.count("Job succeeded")
        _assert(succeeded >= 2, f"expected >=2 job successes, got {succeeded}")

        # Assert the script's exit code is the exact value we expect.
        rc = _extract_checker_rc(combined)
        _assert(
            rc == case["expected_checker_rc"],
            f"{case['name']}: checker rc {rc} != expected {case['expected_checker_rc']}",
        )

        # Parse the JSON report and assert on EXACT expected values.
        report = _extract_report(combined)
        _assert(
            report["overall"] == case["expected_overall"],
            f"{case['name']}: overall {report['overall']!r} != {case['expected_overall']!r}",
        )
        _assert(
            report["summary"] == case["expected_summary"],
            f"{case['name']}: summary {report['summary']} != {case['expected_summary']}",
        )
        _log(f"case {case['name']}: OK "
             f"(overall={report['overall']}, summary={report['summary']}, rc={rc})")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    # Fresh act-result.txt each run.
    ACT_RESULT.write_text(
        f"act-result.txt — license checker harness\n"
        f"workflow: {WORKFLOW}\n"
        f"cases: {[c['name'] for c in TEST_CASES]}\n"
    )

    try:
        test_workflow_structure()
    except HarnessError as exc:
        print(f"STRUCTURE FAIL: {exc}", file=sys.stderr)
        return 1

    with ACT_RESULT.open("a") as fh:
        for case in TEST_CASES:
            try:
                run_case(case, fh)
            except HarnessError as exc:
                fh.write(f"\n[FAIL] {exc}\n")
                print(f"CASE FAIL: {exc}", file=sys.stderr)
                return 1
            except subprocess.TimeoutExpired:
                fh.write("\n[FAIL] act timed out\n")
                print("CASE FAIL: act timed out", file=sys.stderr)
                return 1

    _log("ALL CASES PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
