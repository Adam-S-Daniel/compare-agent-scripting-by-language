"""End-to-end harness: runs the workflow via `act push --rm` against each
fixture case, collects output to act-result.txt, and asserts exact values.

Workflow structure tests (YAML / actionlint) run first; then up to 2 act runs.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

REPO = Path(__file__).parent.resolve()
WORKFLOW = REPO / ".github/workflows/artifact-cleanup-script.yml"
ACT_RESULT = REPO / "act-result.txt"


class WorkflowStructureTests(unittest.TestCase):
    def setUp(self):
        with open(WORKFLOW) as f:
            self.doc = yaml.safe_load(f)

    def test_triggers_present(self):
        on = self.doc.get(True) or self.doc.get("on")  # PyYAML: 'on' -> True
        self.assertIn("push", on)
        self.assertIn("pull_request", on)
        self.assertIn("workflow_dispatch", on)
        self.assertIn("schedule", on)

    def test_jobs_present(self):
        jobs = self.doc["jobs"]
        self.assertIn("unit-tests", jobs)
        self.assertIn("cleanup-plan", jobs)
        self.assertEqual(jobs["cleanup-plan"]["needs"], "unit-tests")

    def test_references_script_files(self):
        self.assertTrue((REPO / "cleanup.py").exists())
        self.assertTrue((REPO / "test_cleanup.py").exists())
        text = WORKFLOW.read_text()
        self.assertIn("cleanup.py", text)
        self.assertIn("test_cleanup.py", text)

    def test_actionlint_passes(self):
        res = subprocess.run(
            ["actionlint", str(WORKFLOW)], capture_output=True, text=True
        )
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)


def _run_act_case(case_name: str, fixture_src: Path) -> tuple[int, str]:
    """Set up an isolated git repo, install the fixture as default.json,
    run `act push --rm`, and return (exit_code, combined_output)."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        # Mirror project files into the temp repo.
        for item in ("cleanup.py", "test_cleanup.py", ".github",
                     "fixtures", ".actrc"):
            src = REPO / item
            if not src.exists():
                continue
            dst = tmp / item
            if src.is_dir():
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)
        # Overwrite the default fixture with this case's data.
        shutil.copy2(fixture_src, tmp / "fixtures" / "default.json")

        env = os.environ.copy()
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True)
        subprocess.run(["git", "config", "user.email", "t@t"], cwd=tmp, check=True)
        subprocess.run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
        subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "case"], cwd=tmp, check=True)

        res = subprocess.run(
            ["act", "push", "--rm", "--pull=false"],
            cwd=tmp, capture_output=True, text=True, env=env, timeout=300,
        )
        combined = (
            f"\n===== CASE: {case_name} =====\n"
            f"--- STDOUT ---\n{res.stdout}\n"
            f"--- STDERR ---\n{res.stderr}\n"
            f"--- EXIT: {res.returncode} ---\n"
        )
        return res.returncode, combined


class ActEndToEndTests(unittest.TestCase):
    """Each test case runs the whole workflow via act and asserts on output."""
    @classmethod
    def setUpClass(cls):
        # Truncate act-result.txt at start of run.
        ACT_RESULT.write_text("")

    def _append_result(self, text: str):
        with open(ACT_RESULT, "a") as f:
            f.write(text)

    def test_case_default_fixture(self):
        """Default fixture: 5 artifacts, policies delete 3, reclaim 6656."""
        rc, out = _run_act_case("default", REPO / "fixtures" / "default.json")
        self._append_result(out)
        self.assertEqual(rc, 0, f"act exit != 0\n{out[-3000:]}")
        # Each job succeeded.
        self.assertGreaterEqual(out.count("Job succeeded"), 2, out[-2000:])
        # Exact summary values.
        self.assertIn("deleted=3 retained=2 reclaimed=6656", out)

    def test_case_nothing_to_delete(self):
        """All artifacts are recent and small: nothing deleted."""
        rc, out = _run_act_case(
            "nothing_to_delete", REPO / "fixtures" / "nothing_to_delete.json"
        )
        self._append_result(out)
        self.assertEqual(rc, 0, f"act exit != 0\n{out[-3000:]}")
        self.assertGreaterEqual(out.count("Job succeeded"), 2, out[-2000:])
        self.assertIn("deleted=0 retained=2 reclaimed=0", out)


if __name__ == "__main__":
    # Allow running just the fast tests: `python3 test_workflow.py fast`
    if len(sys.argv) > 1 and sys.argv[1] == "fast":
        sys.argv.pop(1)
        loader = unittest.TestLoader()
        suite = loader.loadTestsFromTestCase(WorkflowStructureTests)
        runner = unittest.TextTestRunner(verbosity=2)
        sys.exit(0 if runner.run(suite).wasSuccessful() else 1)
    unittest.main(verbosity=2)
