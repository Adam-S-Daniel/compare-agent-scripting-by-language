"""End-to-end workflow tests.

Each case sets up a temp git repo containing the project files plus a starting
VERSION and a commits.log fixture, then runs `act push --rm` and parses output.
All cases append to act-result.txt.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

PROJECT = Path(__file__).resolve().parent
ACT_RESULT = PROJECT / "act-result.txt"

# Project files copied into each fresh harness repo.
PROJECT_FILES = [
    "bumper.py",
    "test_bumper.py",
    ".github",
    ".actrc",
    "fixtures",
]


def _setup_repo(workdir: Path, version: str, commit_log: str) -> None:
    """Build a self-contained git repo for one act run."""
    for name in PROJECT_FILES:
        src = PROJECT / name
        dst = workdir / name
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    (workdir / "VERSION").write_text(version + "\n")
    (workdir / "commits.log").write_text(commit_log)
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=workdir, check=True)
    subprocess.run(["git", "add", "-A"], cwd=workdir, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "init"],
        cwd=workdir, check=True,
        env={**os.environ, "GIT_COMMITTER_DATE": "2026-01-01T00:00:00"},
    )


def _run_act(workdir: Path, label: str) -> subprocess.CompletedProcess:
    """Run `act push --rm` in workdir and append all output to act-result.txt."""
    proc = subprocess.run(
        ["act", "push", "--rm"],
        cwd=workdir, capture_output=True, text=True, timeout=600,
    )
    with ACT_RESULT.open("a") as f:
        f.write(f"\n\n========== CASE: {label} ==========\n")
        f.write(f"--- exit code: {proc.returncode} ---\n")
        f.write("--- stdout ---\n")
        f.write(proc.stdout)
        f.write("\n--- stderr ---\n")
        f.write(proc.stderr)
    return proc


class WorkflowStructureTests(unittest.TestCase):
    """Static checks on the workflow file. Fast — no act required."""

    @classmethod
    def setUpClass(cls):
        cls.wf_path = PROJECT / ".github/workflows/semantic-version-bumper.yml"
        cls.wf = yaml.safe_load(cls.wf_path.read_text())

    def test_actionlint_passes(self):
        r = subprocess.run(
            ["actionlint", str(self.wf_path)], capture_output=True, text=True,
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_triggers_present(self):
        # PyYAML parses bare `on:` as the boolean True; accept either.
        on = self.wf.get("on") or self.wf.get(True)
        self.assertIsNotNone(on)
        for t in ("push", "pull_request", "workflow_dispatch", "schedule"):
            self.assertIn(t, on)

    def test_job_uses_checkout_v4(self):
        steps = self.wf["jobs"]["bump"]["steps"]
        self.assertTrue(any(s.get("uses") == "actions/checkout@v4" for s in steps))

    def test_workflow_references_existing_script(self):
        steps = self.wf["jobs"]["bump"]["steps"]
        joined = "\n".join(s.get("run", "") for s in steps)
        self.assertIn("bumper.py", joined)
        self.assertTrue((PROJECT / "bumper.py").exists())
        self.assertTrue((PROJECT / "test_bumper.py").exists())


# Each case: (label, starting version, commits.log content, expected new version
#  or None if no-op, list of substrings expected in stdout)
CASES = [
    (
        "feat-minor",
        "1.0.0",
        (PROJECT / "fixtures/feat.log").read_text(),
        "1.1.0",
        ["New version: 1.1.0", "Old version: 1.0.0"],
    ),
    (
        "fix-patch",
        "2.4.7",
        (PROJECT / "fixtures/fix.log").read_text(),
        "2.4.8",
        ["New version: 2.4.8"],
    ),
    (
        "breaking-major",
        "1.5.2",
        (PROJECT / "fixtures/breaking.log").read_text(),
        "2.0.0",
        ["New version: 2.0.0"],
    ),
    (
        "noop",
        "0.9.0",
        (PROJECT / "fixtures/noop.log").read_text(),
        None,
        ["New version: 0.9.0", "no-op"],
    ),
]


class WorkflowActTests(unittest.TestCase):
    """Run each case through `act push --rm` and assert on output."""

    @classmethod
    def setUpClass(cls):
        # Reset accumulator file at the start of the suite.
        ACT_RESULT.write_text("act-result.txt -- accumulated output from `act push --rm` runs\n")

    def _run_case(self, label, start, log, expected_new, expected_substrings):
        with tempfile.TemporaryDirectory() as d:
            workdir = Path(d)
            _setup_repo(workdir, start, log)
            proc = _run_act(workdir, label)

            self.assertEqual(proc.returncode, 0,
                             f"act exited {proc.returncode}; see act-result.txt")
            self.assertIn("Job succeeded", proc.stdout,
                          f"missing 'Job succeeded' for {label}")
            for s in expected_substrings:
                self.assertIn(s, proc.stdout, f"missing {s!r} in {label}")

            # Parse the bumper's reported new version from act's stdout.
            # act's containers don't persist file changes back to host, so we
            # rely on the workflow's printed lines for the assertion.
            m = re.search(r"New version: (\S+)", proc.stdout)
            self.assertIsNotNone(m, f"no 'New version:' line in {label}")
            actual_version = m.group(1)
            if expected_new is None:
                self.assertEqual(actual_version, start)
            else:
                self.assertEqual(actual_version, expected_new)

    def test_all_cases(self):
        for case in CASES:
            with self.subTest(case=case[0]):
                self._run_case(*case)


if __name__ == "__main__":
    unittest.main(verbosity=2)
