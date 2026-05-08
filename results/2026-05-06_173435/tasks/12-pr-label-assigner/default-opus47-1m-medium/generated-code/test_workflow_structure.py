"""Static workflow structure validation — no act required."""
import subprocess
import unittest
from pathlib import Path

WF = Path(__file__).parent / ".github/workflows/pr-label-assigner.yml"


class TestWorkflowStructure(unittest.TestCase):
    def setUp(self):
        try:
            import yaml  # noqa: F401
        except ImportError:
            self.skipTest("PyYAML not installed")

    def _load(self):
        import yaml
        return yaml.safe_load(WF.read_text())

    def test_workflow_file_exists(self):
        self.assertTrue(WF.exists(), f"missing: {WF}")

    def test_has_expected_triggers(self):
        wf = self._load()
        # YAML 'on' may parse as the boolean True under some loaders.
        triggers = wf.get("on") or wf.get(True)
        self.assertIsNotNone(triggers, "no 'on' triggers found")
        self.assertIn("push", triggers)
        self.assertIn("pull_request", triggers)
        self.assertIn("workflow_dispatch", triggers)

    def test_has_expected_jobs(self):
        wf = self._load()
        self.assertIn("unit-tests", wf["jobs"])
        self.assertIn("assign-labels", wf["jobs"])
        self.assertEqual(wf["jobs"]["assign-labels"]["needs"], "unit-tests")

    def test_references_existing_script_files(self):
        # Steps mention label_assigner.py, test_label_assigner.py, rules.json
        text = WF.read_text()
        for ref in ("label_assigner.py", "test_label_assigner.py", "rules.json"):
            self.assertIn(ref, text, f"workflow does not reference {ref}")
            self.assertTrue((WF.parent.parent.parent / ref).exists(), f"missing: {ref}")

    def test_actionlint_passes(self):
        r = subprocess.run(["actionlint", str(WF)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
