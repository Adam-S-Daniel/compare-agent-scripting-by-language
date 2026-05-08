"""TDD tests for the PR label assigner.

We use Python's unittest so no external dependency is required in CI.
"""
import json
import subprocess
import sys
import unittest
from pathlib import Path

from label_assigner import assign_labels, load_rules, RuleError


class TestRuleMatching(unittest.TestCase):
    def test_single_rule_matches_single_file(self):
        rules = [{"pattern": "docs/**", "label": "documentation"}]
        files = ["docs/readme.md"]
        self.assertEqual(assign_labels(files, rules), ["documentation"])

    def test_no_match_returns_empty(self):
        rules = [{"pattern": "docs/**", "label": "documentation"}]
        files = ["src/app.py"]
        self.assertEqual(assign_labels(files, rules), [])

    def test_multiple_labels_per_file(self):
        # A test file under src/api should get both "api" and "tests"
        rules = [
            {"pattern": "src/api/**", "label": "api"},
            {"pattern": "**/*.test.*", "label": "tests"},
        ]
        files = ["src/api/users.test.js"]
        result = assign_labels(files, rules)
        self.assertIn("api", result)
        self.assertIn("tests", result)

    def test_labels_deduplicated(self):
        rules = [
            {"pattern": "src/**", "label": "code"},
            {"pattern": "**/*.py", "label": "code"},
        ]
        files = ["src/a.py", "src/b.py"]
        self.assertEqual(assign_labels(files, rules), ["code"])

    def test_priority_ordering_returns_higher_priority_first(self):
        # When rules conflict on label-set ordering, higher priority comes first
        rules = [
            {"pattern": "**/*.md", "label": "documentation", "priority": 1},
            {"pattern": "SECURITY.md", "label": "security", "priority": 10},
        ]
        files = ["SECURITY.md"]
        result = assign_labels(files, rules)
        # Higher priority label should come first
        self.assertEqual(result[0], "security")
        self.assertIn("documentation", result)

    def test_glob_question_mark(self):
        rules = [{"pattern": "v?.txt", "label": "versioned"}]
        self.assertEqual(assign_labels(["v1.txt"], rules), ["versioned"])
        self.assertEqual(assign_labels(["v12.txt"], rules), [])

    def test_invalid_rule_missing_pattern_raises(self):
        with self.assertRaises(RuleError):
            assign_labels(["a.py"], [{"label": "x"}])

    def test_invalid_rule_missing_label_raises(self):
        with self.assertRaises(RuleError):
            assign_labels(["a.py"], [{"pattern": "*.py"}])


class TestLoadRules(unittest.TestCase):
    def test_load_rules_from_file(self):
        tmp = Path("/tmp/rules_test.json")
        tmp.write_text(json.dumps([{"pattern": "*.py", "label": "python"}]))
        rules = load_rules(str(tmp))
        self.assertEqual(rules[0]["label"], "python")

    def test_load_rules_missing_file_raises(self):
        with self.assertRaises(RuleError):
            load_rules("/tmp/does_not_exist_xyz.json")


class TestCLI(unittest.TestCase):
    """End-to-end CLI tests — invoked through subprocess so we exercise the same
    entrypoint that the GitHub Actions workflow uses."""

    def _run(self, files_json, rules_path):
        return subprocess.run(
            [sys.executable, "label_assigner.py", "--rules", rules_path, "--files-json", files_json],
            capture_output=True, text=True,
        )

    def test_cli_outputs_json_labels(self):
        rules = Path("/tmp/cli_rules.json")
        rules.write_text(json.dumps([
            {"pattern": "docs/**", "label": "documentation"},
            {"pattern": "src/api/**", "label": "api"},
        ]))
        files = json.dumps(["docs/x.md", "src/api/y.py"])
        r = self._run(files, str(rules))
        self.assertEqual(r.returncode, 0, r.stderr)
        out = json.loads(r.stdout)
        self.assertEqual(sorted(out), ["api", "documentation"])


if __name__ == "__main__":
    unittest.main()
