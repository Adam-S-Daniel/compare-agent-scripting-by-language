"""
Unit tests for the semantic version bumper, written TDD-style.
Each test corresponds to a single piece of functionality I built up incrementally:
  1. read_version    - parse current version from package.json
  2. parse_commits   - turn raw commit log lines into structured commits
  3. determine_bump  - decide major/minor/patch based on conventional commits
  4. bump_version    - apply the chosen bump to a SemVer string
  5. write_version   - update the package.json with the new version
  6. render_changelog- produce a markdown changelog block from the commits
  7. run             - end-to-end orchestration used by the CLI / workflow
"""

import json
import os
import tempfile
import unittest
from pathlib import Path

import bumper


class ReadVersionTests(unittest.TestCase):
    def test_reads_version_from_package_json(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "x", "version": "1.2.3"}))
            self.assertEqual(bumper.read_version(p), "1.2.3")

    def test_missing_version_field_raises(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "x"}))
            with self.assertRaises(bumper.BumperError):
                bumper.read_version(p)

    def test_missing_file_raises(self):
        with self.assertRaises(bumper.BumperError):
            bumper.read_version(Path("/nope/does-not-exist.json"))


class ParseCommitsTests(unittest.TestCase):
    def test_parses_simple_feat_commit(self):
        log = "abc123 feat: add login\n"
        commits = bumper.parse_commits(log)
        self.assertEqual(len(commits), 1)
        self.assertEqual(commits[0].type, "feat")
        self.assertEqual(commits[0].subject, "add login")
        self.assertFalse(commits[0].breaking)

    def test_parses_breaking_with_bang(self):
        log = "abc123 feat!: drop node 14 support\n"
        commits = bumper.parse_commits(log)
        self.assertTrue(commits[0].breaking)

    def test_parses_breaking_change_footer(self):
        log = "abc123 fix: rework api\n\nBREAKING CHANGE: api removed\n"
        commits = bumper.parse_commits(log)
        self.assertTrue(commits[0].breaking)

    def test_ignores_non_conventional_lines(self):
        log = "abc123 random unstructured message\nabc124 fix: real one\n"
        commits = bumper.parse_commits(log)
        self.assertEqual(len(commits), 1)
        self.assertEqual(commits[0].type, "fix")


class DetermineBumpTests(unittest.TestCase):
    def _commit(self, t, breaking=False):
        return bumper.Commit(sha="x", type=t, scope=None, subject="s", breaking=breaking)

    def test_breaking_wins(self):
        cs = [self._commit("fix"), self._commit("feat", breaking=True)]
        self.assertEqual(bumper.determine_bump(cs), "major")

    def test_feat_yields_minor(self):
        cs = [self._commit("fix"), self._commit("feat")]
        self.assertEqual(bumper.determine_bump(cs), "minor")

    def test_fix_yields_patch(self):
        cs = [self._commit("fix"), self._commit("chore")]
        self.assertEqual(bumper.determine_bump(cs), "patch")

    def test_no_relevant_commits_yields_none(self):
        cs = [self._commit("chore"), self._commit("docs")]
        self.assertIsNone(bumper.determine_bump(cs))


class BumpVersionTests(unittest.TestCase):
    def test_major(self):
        self.assertEqual(bumper.bump_version("1.2.3", "major"), "2.0.0")

    def test_minor(self):
        self.assertEqual(bumper.bump_version("1.2.3", "minor"), "1.3.0")

    def test_patch(self):
        self.assertEqual(bumper.bump_version("1.2.3", "patch"), "1.2.4")

    def test_invalid_version_raises(self):
        with self.assertRaises(bumper.BumperError):
            bumper.bump_version("not-a-version", "patch")


class WriteVersionTests(unittest.TestCase):
    def test_updates_only_version_field(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "x", "version": "1.2.3", "extra": 7}, indent=2))
            bumper.write_version(p, "1.3.0")
            data = json.loads(p.read_text())
            self.assertEqual(data["version"], "1.3.0")
            self.assertEqual(data["extra"], 7)
            self.assertEqual(data["name"], "x")


class ChangelogTests(unittest.TestCase):
    def test_groups_commits_by_type(self):
        commits = [
            bumper.Commit("a1", "feat", None, "add A", False),
            bumper.Commit("a2", "fix", None, "fix B", False),
            bumper.Commit("a3", "feat", None, "drop X", True),
        ]
        out = bumper.render_changelog("1.3.0", commits, date="2026-05-07")
        self.assertIn("## 1.3.0 - 2026-05-07", out)
        self.assertIn("### Breaking Changes", out)
        self.assertIn("drop X", out)
        self.assertIn("### Features", out)
        self.assertIn("add A", out)
        self.assertIn("### Bug Fixes", out)
        self.assertIn("fix B", out)


class RunTests(unittest.TestCase):
    def test_end_to_end_minor_bump(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "package.json").write_text(json.dumps({"name": "x", "version": "1.1.0"}))
            log = d / "commits.txt"
            log.write_text("abc1 feat: a\nabc2 fix: b\n")
            result = bumper.run(
                package_path=d / "package.json",
                commits_path=log,
                changelog_path=d / "CHANGELOG.md",
                date="2026-05-07",
            )
            self.assertEqual(result["old_version"], "1.1.0")
            self.assertEqual(result["new_version"], "1.2.0")
            self.assertEqual(result["bump"], "minor")
            self.assertIn("1.2.0", (d / "CHANGELOG.md").read_text())
            data = json.loads((d / "package.json").read_text())
            self.assertEqual(data["version"], "1.2.0")

    def test_end_to_end_no_bump(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "package.json").write_text(json.dumps({"name": "x", "version": "1.1.0"}))
            log = d / "commits.txt"
            log.write_text("abc1 chore: housekeeping\n")
            result = bumper.run(
                package_path=d / "package.json",
                commits_path=log,
                changelog_path=d / "CHANGELOG.md",
                date="2026-05-07",
            )
            self.assertIsNone(result["bump"])
            self.assertEqual(result["new_version"], "1.1.0")


if __name__ == "__main__":
    unittest.main()
