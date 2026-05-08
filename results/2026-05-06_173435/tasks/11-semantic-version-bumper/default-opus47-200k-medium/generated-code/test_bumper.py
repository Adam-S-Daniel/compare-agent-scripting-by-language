"""Unit tests for the semantic version bumper.

Built incrementally via red/green TDD.
"""
import json
import os
import tempfile
import unittest
from pathlib import Path

from bumper import (
    bump_version,
    determine_bump,
    parse_commits,
    read_version,
    write_version,
    generate_changelog,
    process,
)


class TestParseCommits(unittest.TestCase):
    def test_empty_log_returns_empty_list(self):
        self.assertEqual(parse_commits(""), [])

    def test_parses_single_feat_commit(self):
        log = "feat: add new login flow"
        commits = parse_commits(log)
        self.assertEqual(len(commits), 1)
        self.assertEqual(commits[0]["type"], "feat")
        self.assertEqual(commits[0]["description"], "add new login flow")
        self.assertFalse(commits[0]["breaking"])

    def test_parses_fix_commit(self):
        commits = parse_commits("fix: handle null token")
        self.assertEqual(commits[0]["type"], "fix")

    def test_breaking_change_via_bang(self):
        commits = parse_commits("feat!: drop legacy api")
        self.assertTrue(commits[0]["breaking"])

    def test_breaking_change_via_footer(self):
        log = "feat: new api\n\nBREAKING CHANGE: removes /v1"
        commits = parse_commits(log)
        self.assertTrue(commits[0]["breaking"])

    def test_scope_is_extracted(self):
        commits = parse_commits("feat(auth): support oauth")
        self.assertEqual(commits[0]["scope"], "auth")

    def test_multiple_commits_separated_by_double_newline(self):
        log = "feat: a\n---\nfix: b\n---\nchore: c"
        commits = parse_commits(log)
        self.assertEqual(len(commits), 3)
        self.assertEqual([c["type"] for c in commits], ["feat", "fix", "chore"])

    def test_non_conventional_commit_is_other(self):
        commits = parse_commits("just some random message")
        self.assertEqual(commits[0]["type"], "other")


class TestDetermineBump(unittest.TestCase):
    def test_no_commits_returns_none(self):
        self.assertIsNone(determine_bump([]))

    def test_only_chore_returns_none(self):
        commits = [{"type": "chore", "breaking": False}]
        self.assertIsNone(determine_bump(commits))

    def test_fix_returns_patch(self):
        commits = [{"type": "fix", "breaking": False}]
        self.assertEqual(determine_bump(commits), "patch")

    def test_feat_returns_minor(self):
        commits = [
            {"type": "fix", "breaking": False},
            {"type": "feat", "breaking": False},
        ]
        self.assertEqual(determine_bump(commits), "minor")

    def test_breaking_returns_major(self):
        commits = [
            {"type": "feat", "breaking": False},
            {"type": "fix", "breaking": True},
        ]
        self.assertEqual(determine_bump(commits), "major")


class TestBumpVersion(unittest.TestCase):
    def test_bump_patch(self):
        self.assertEqual(bump_version("1.2.3", "patch"), "1.2.4")

    def test_bump_minor(self):
        self.assertEqual(bump_version("1.2.3", "minor"), "1.3.0")

    def test_bump_major(self):
        self.assertEqual(bump_version("1.2.3", "major"), "2.0.0")

    def test_invalid_version_raises(self):
        with self.assertRaises(ValueError):
            bump_version("not-a-version", "patch")

    def test_invalid_bump_type_raises(self):
        with self.assertRaises(ValueError):
            bump_version("1.0.0", "weird")


class TestReadWriteVersion(unittest.TestCase):
    def test_read_plain_version_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "VERSION"
            p.write_text("2.5.1\n")
            self.assertEqual(read_version(str(p)), "2.5.1")

    def test_read_package_json(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "x", "version": "0.1.0"}))
            self.assertEqual(read_version(str(p)), "0.1.0")

    def test_write_plain_version_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "VERSION"
            p.write_text("1.0.0")
            write_version(str(p), "1.1.0")
            self.assertEqual(p.read_text().strip(), "1.1.0")

    def test_write_package_json_preserves_other_fields(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "x", "version": "0.1.0", "license": "MIT"}))
            write_version(str(p), "0.2.0")
            data = json.loads(p.read_text())
            self.assertEqual(data["version"], "0.2.0")
            self.assertEqual(data["license"], "MIT")

    def test_missing_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            read_version("/no/such/file")


class TestGenerateChangelog(unittest.TestCase):
    def test_groups_commits_by_type(self):
        commits = [
            {"type": "feat", "scope": None, "description": "thing", "breaking": False},
            {"type": "fix", "scope": "api", "description": "bug", "breaking": False},
            {"type": "feat", "scope": None, "description": "boom", "breaking": True},
        ]
        out = generate_changelog("1.1.0", commits)
        self.assertIn("## 1.1.0", out)
        self.assertIn("### Features", out)
        self.assertIn("### Bug Fixes", out)
        self.assertIn("### BREAKING CHANGES", out)
        self.assertIn("thing", out)
        self.assertIn("api", out)
        self.assertIn("boom", out)


class TestProcess(unittest.TestCase):
    """End-to-end driver test."""

    def test_full_pipeline_feat_bumps_minor(self):
        with tempfile.TemporaryDirectory() as d:
            v = Path(d) / "VERSION"
            v.write_text("1.0.0")
            cl = Path(d) / "CHANGELOG.md"
            log = "feat: add feature\n---\nfix: small bug"
            new_version = process(str(v), log, str(cl))
            self.assertEqual(new_version, "1.1.0")
            self.assertEqual(v.read_text().strip(), "1.1.0")
            self.assertIn("1.1.0", cl.read_text())
            self.assertIn("add feature", cl.read_text())


if __name__ == "__main__":
    unittest.main()
