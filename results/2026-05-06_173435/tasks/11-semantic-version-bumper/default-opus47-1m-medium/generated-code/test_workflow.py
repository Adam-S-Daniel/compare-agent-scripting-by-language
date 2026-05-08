"""
Workflow-level test harness.

For each test case it:
  1. builds a clean temp git repo containing the project files and the case's
     fixture data (so the workflow runs in isolation, not against the
     working tree),
  2. runs `act push --rm` inside that repo,
  3. appends the captured stdout+stderr to ``act-result.txt`` (in the
     project root) with a clear delimiter,
  4. asserts act exited 0,
  5. asserts that the act output contains the *exact* expected
     ``new_version`` line and "Job succeeded".

Also performs structural checks on the workflow file itself and verifies
actionlint passes.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

try:
    import yaml  # type: ignore
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


PROJECT_ROOT = Path(__file__).resolve().parent
ACT_RESULT = PROJECT_ROOT / "act-result.txt"


# Files that must be present in each isolated repo we hand to act.
PROJECT_FILES = ["bumper.py", "test_bumper.py", "package.json"]
PROJECT_DIRS = ["fixtures", ".github"]


def _build_repo(workdir: Path) -> None:
    for f in PROJECT_FILES:
        shutil.copy2(PROJECT_ROOT / f, workdir / f)
    for d in PROJECT_DIRS:
        shutil.copytree(PROJECT_ROOT / d, workdir / d)
    # act expects the repo to be a real git repo.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.email", "t@example.com"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.name", "Tester"], cwd=workdir, check=True)
    # Match the harness's .actrc so act picks the right pwsh-friendly image.
    shutil.copy2(PROJECT_ROOT / ".actrc", workdir / ".actrc")
    subprocess.run(["git", "add", "-A"], cwd=workdir, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "init"],
        cwd=workdir,
        check=True,
        env={**os.environ, "GIT_COMMITTER_DATE": "2026-05-07T00:00:00Z"},
    )


def _run_act(workdir: Path, fixture: str) -> subprocess.CompletedProcess:
    cmd = [
        "act", "push",
        "--rm",
        "--pull=false",  # use the locally-built act-ubuntu-pwsh image
        "--env", f"FIXTURE={fixture}",
    ]
    return subprocess.run(
        cmd,
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=600,
    )


def _append_act_output(label: str, fixture: str, proc: subprocess.CompletedProcess) -> None:
    delim = "=" * 80
    block = textwrap.dedent(f"""
        {delim}
        CASE: {label}  (fixture={fixture}, exit={proc.returncode})
        {delim}
        --- STDOUT ---
        {proc.stdout}
        --- STDERR ---
        {proc.stderr}
    """).lstrip("\n")
    with ACT_RESULT.open("a") as f:
        f.write(block)


# Each tuple: (label, fixture file, expected new_version line emitted by bumper.py)
ACT_CASES = [
    ("feat bumps minor",     "feat-commits.txt",     "new_version=1.2.0"),
    ("fix bumps patch",      "fix-commits.txt",      "new_version=1.1.1"),
    ("breaking bumps major", "breaking-commits.txt", "new_version=2.0.0"),
    ("nobump keeps version", "nobump-commits.txt",   "new_version=1.1.0"),
]


class WorkflowStructureTests(unittest.TestCase):
    """Static checks on the workflow YAML — instant, run before act."""

    def setUp(self) -> None:
        self.wf_path = PROJECT_ROOT / ".github" / "workflows" / "semantic-version-bumper.yml"
        if not HAS_YAML:
            self.skipTest("PyYAML not installed in test environment")
        self.wf = yaml.safe_load(self.wf_path.read_text())

    def test_workflow_has_expected_triggers(self):
        # PyYAML parses the bare key `on` as boolean True, hence the lookup.
        on = self.wf.get("on") if "on" in self.wf else self.wf.get(True)
        self.assertIsNotNone(on, "workflow has no 'on:' trigger block")
        self.assertIn("push", on)
        self.assertIn("pull_request", on)
        self.assertIn("workflow_dispatch", on)
        self.assertIn("schedule", on)

    def test_workflow_has_bump_job_with_checkout_and_script(self):
        jobs = self.wf["jobs"]
        self.assertIn("bump", jobs)
        steps = jobs["bump"]["steps"]
        uses = [s.get("uses", "") for s in steps]
        self.assertTrue(any(u.startswith("actions/checkout@v4") for u in uses))
        run_blob = "\n".join(s.get("run", "") for s in steps)
        self.assertIn("python3 bumper.py", run_blob)
        self.assertIn("python3 -m unittest test_bumper.py", run_blob)

    def test_referenced_files_exist(self):
        # The workflow refers to bumper.py, test_bumper.py, package.json,
        # and the fixtures/ directory — all must be present.
        for f in ["bumper.py", "test_bumper.py", "package.json"]:
            self.assertTrue((PROJECT_ROOT / f).exists(), f)
        self.assertTrue((PROJECT_ROOT / "fixtures").is_dir())

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(self.wf_path)],
            capture_output=True, text=True,
        )
        self.assertEqual(
            result.returncode, 0,
            msg=f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )


class ActIntegrationTests(unittest.TestCase):
    """Drive the workflow end-to-end through act for every fixture."""

    @classmethod
    def setUpClass(cls):
        # Reset the artifact at the start of the run so prior runs don't
        # accumulate. Each test case appends its own block.
        ACT_RESULT.write_text(
            "act run results — semantic-version-bumper workflow\n"
        )

    def _run_case(self, label: str, fixture: str, expected_version_line: str) -> None:
        with tempfile.TemporaryDirectory(prefix="svb-act-") as d:
            workdir = Path(d)
            _build_repo(workdir)
            proc = _run_act(workdir, fixture)
            _append_act_output(label, fixture, proc)
            self.assertEqual(
                proc.returncode, 0,
                msg=f"act exited {proc.returncode} for {label}; see act-result.txt"
            )
            combined = proc.stdout + proc.stderr
            self.assertIn(
                expected_version_line, combined,
                msg=f"expected '{expected_version_line}' in act output for {label}"
            )
            self.assertIn(
                "Job succeeded", combined,
                msg=f"missing 'Job succeeded' for {label}"
            )

    def test_all_act_cases(self):
        # One subTest per fixture so a single failure doesn't mask the rest.
        for label, fixture, expected in ACT_CASES:
            with self.subTest(label=label):
                self._run_case(label, fixture, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
