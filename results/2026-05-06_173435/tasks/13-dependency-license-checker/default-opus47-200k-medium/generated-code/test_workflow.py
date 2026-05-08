"""End-to-end test harness: runs the workflow under `act` for each test
case, captures output to act-result.txt, and asserts on exact values.

Three cases are exercised — clean npm, dirty npm (denied + unknown), and
python requirements — each in a fresh temp git repo so act sees a real
checkout. We cap at exactly 3 act push runs.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).parent.resolve()
ACT_RESULT = ROOT / "act-result.txt"
WORKFLOW = ROOT / ".github/workflows/dependency-license-checker.yml"


def _truncate_act_log():
    ACT_RESULT.write_text("")


def _append_act_log(header: str, body: str):
    with ACT_RESULT.open("a") as f:
        f.write(f"\n===== {header} =====\n")
        f.write(body)
        f.write("\n")


def _setup_repo(tmp: Path):
    """Copy the project into a fresh git repo so act has a clean checkout."""
    for entry in ROOT.iterdir():
        if entry.name in {".git", "__pycache__", "act-result.txt"}:
            continue
        dest = tmp / entry.name
        if entry.is_dir():
            shutil.copytree(entry, dest)
        else:
            shutil.copy2(entry, dest)
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(
        ["git", "commit", "-qm", "init"], cwd=tmp, check=True,
        env={**os.environ, "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"},
    )


def _run_act(tmp: Path, env_overrides: dict) -> tuple[int, str]:
    cmd = ["act", "push", "--rm", "--pull=false"]
    for k, v in env_overrides.items():
        cmd += ["--env", f"{k}={v}"]
    proc = subprocess.run(
        cmd, cwd=tmp, capture_output=True, text=True, timeout=600
    )
    return proc.returncode, proc.stdout + "\n--- STDERR ---\n" + proc.stderr


# ---------------------------------------------------------------------------
# Workflow structure tests (cheap, run before any act invocations)
# ---------------------------------------------------------------------------

class TestWorkflowStructure(unittest.TestCase):
    def setUp(self):
        with WORKFLOW.open() as f:
            self.wf = yaml.safe_load(f)

    def test_actionlint_passes(self):
        rc = subprocess.run(
            ["actionlint", str(WORKFLOW)],
            capture_output=True, text=True
        )
        self.assertEqual(rc.returncode, 0, msg=rc.stdout + rc.stderr)

    def test_required_triggers(self):
        # PyYAML parses bare `on:` key as boolean True; handle both forms.
        triggers = self.wf.get("on") or self.wf.get(True)
        self.assertIsNotNone(triggers, "workflow has no 'on:' triggers")
        for required in ("push", "pull_request", "workflow_dispatch", "schedule"):
            self.assertIn(required, triggers)

    def test_required_jobs(self):
        jobs = self.wf["jobs"]
        self.assertIn("unit-tests", jobs)
        self.assertIn("license-check", jobs)
        self.assertEqual(jobs["license-check"].get("needs"), "unit-tests")

    def test_uses_checkout_v4(self):
        steps = self.wf["jobs"]["license-check"]["steps"]
        self.assertTrue(any(
            s.get("uses") == "actions/checkout@v4" for s in steps
        ))

    def test_referenced_script_exists(self):
        self.assertTrue((ROOT / "license_checker.py").exists())
        self.assertTrue((ROOT / "test_license_checker.py").exists())
        self.assertTrue((ROOT / "licenses.json").exists())

    def test_permissions_least_privilege(self):
        self.assertEqual(self.wf.get("permissions", {}).get("contents"), "read")


# ---------------------------------------------------------------------------
# act runs — exactly three. Each asserts on exact expected output.
# ---------------------------------------------------------------------------

class TestActRuns(unittest.TestCase):
    """Run the workflow via act for each fixture and assert exact output."""

    @classmethod
    def setUpClass(cls):
        _truncate_act_log()

    def _run_case(self, name: str, env_overrides: dict, expected_substrings: list[str],
                  scan_forbidden: list[str] = ()):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            _setup_repo(tmp)
            rc, out = _run_act(tmp, env_overrides)
            _append_act_log(name, out)
            self.assertEqual(rc, 0, f"act exited {rc} for {name}\n{out[-2000:]}")
            # Both jobs must succeed — count "Job succeeded" markers.
            self.assertGreaterEqual(
                out.count("Job succeeded"), 2,
                f"expected 2 'Job succeeded' lines in {name}",
            )
            for needle in expected_substrings:
                self.assertIn(needle, out, f"missing '{needle}' in {name}\n{out[-2000:]}")
            # `scan_forbidden` is checked only against the License compliance
            # scan job's log lines — the unit-test job legitimately prints
            # "denied" because its CLI smoke fixture exercises that branch.
            scan_lines = [
                line for line in out.splitlines()
                if "License compliance scan" in line
            ]
            scan_log = "\n".join(scan_lines)
            for needle in scan_forbidden:
                self.assertNotIn(
                    needle, scan_log,
                    f"unexpected '{needle}' in scan log for {name}",
                )

    def test_case_1_clean_npm_manifest(self):
        # All deps map to MIT in the mock DB → all approved → checker exits 0
        # → policy step prints POLICY_RESULT: all-clean. Summary must be exact.
        self._run_case(
            "clean-npm",
            {"MANIFEST_PATH": "fixtures/clean/package.json", "EXPECT_FAIL": "false"},
            expected_substrings=[
                "left-pad",
                "lodash",
                "jest",
                "Summary: 3 approved, 0 denied, 0 unknown",
                "POLICY_RESULT: all-clean",
                "Checker exit code: 0",
            ],
        )

    def test_case_2_dirty_npm_manifest(self):
        # evil-lib is GPL-3.0 (denied), totally-unknown-pkg has no entry
        # (unknown), left-pad is MIT (approved). Checker should exit 1 and
        # the policy step should report it as expected failure.
        self._run_case(
            "dirty-npm",
            {"MANIFEST_PATH": "fixtures/dirty/package.json", "EXPECT_FAIL": "true"},
            expected_substrings=[
                "evil-lib",
                "GPL-3.0",
                "denied",
                "totally-unknown-pkg",
                "unknown",
                "Summary: 1 approved, 1 denied, 1 unknown",
                "POLICY_RESULT: denied-deps-found-as-expected",
                "Checker exit code: 1",
            ],
        )

    def test_case_3_python_requirements(self):
        # requests=Apache-2.0 (allow), flask=BSD-3-Clause (allow),
        # numpy=BSD-3-Clause (allow). All approved.
        self._run_case(
            "python-reqs",
            {"MANIFEST_PATH": "fixtures/python/requirements.txt", "EXPECT_FAIL": "false"},
            expected_substrings=[
                "requests",
                "flask",
                "numpy",
                "Apache-2.0",
                "BSD-3-Clause",
                "Summary: 3 approved, 0 denied, 0 unknown",
                "POLICY_RESULT: all-clean",
                "Checker exit code: 0",
            ],
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
