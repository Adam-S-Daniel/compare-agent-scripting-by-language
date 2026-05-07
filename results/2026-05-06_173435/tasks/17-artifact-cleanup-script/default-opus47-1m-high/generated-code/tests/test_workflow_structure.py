"""Workflow-structure tests.

These do NOT run act -- they statically inspect the workflow YAML
to make sure it has the shape we promise (triggers, jobs, steps,
referenced files exist, actionlint clean).
"""

import os
import re
import shutil
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "artifact-cleanup-script.yml")


def _read():
    with open(WORKFLOW) as f:
        return f.read()


class WorkflowStructureTests(unittest.TestCase):
    def test_workflow_file_exists(self):
        self.assertTrue(os.path.isfile(WORKFLOW), f"missing {WORKFLOW}")

    def test_required_triggers_present(self):
        text = _read()
        for needle in ("push:", "pull_request:", "workflow_dispatch:", "schedule:"):
            self.assertIn(needle, text, f"missing trigger {needle}")

    def test_jobs_present(self):
        text = _read()
        # We rely on substring checks so we don't need a YAML parser
        # available in the act container.
        self.assertIn("unit-tests:", text)
        self.assertIn("cleanup-plan:", text)
        self.assertIn("needs: unit-tests", text)

    def test_steps_reference_existing_files(self):
        text = _read()
        # The workflow must use actions/checkout (so a fresh container has the code).
        self.assertIn("actions/checkout@v4", text)
        # The workflow must invoke retention.py.
        self.assertIn("retention.py", text)
        self.assertTrue(os.path.isfile(os.path.join(ROOT, "retention.py")))
        # The workflow must invoke unit tests.
        self.assertIn("unittest", text)
        self.assertTrue(os.path.isdir(os.path.join(ROOT, "tests")))

    def test_permissions_least_privilege(self):
        text = _read()
        # contents: read is fine for a planner; we don't need write.
        self.assertRegex(text, r"permissions:\s*\n\s*contents:\s*read")

    def test_actionlint_passes(self):
        """If actionlint is on PATH, it must exit 0."""
        actionlint = shutil.which("actionlint")
        if not actionlint:
            self.skipTest("actionlint not installed")
        result = subprocess.run(
            [actionlint, WORKFLOW],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            result.returncode,
            0,
            f"actionlint failed:\nstdout={result.stdout}\nstderr={result.stderr}",
        )


if __name__ == "__main__":
    unittest.main()
