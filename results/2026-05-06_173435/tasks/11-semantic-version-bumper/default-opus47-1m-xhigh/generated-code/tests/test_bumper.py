# Unit tests for bumper.py — built incrementally via red/green TDD.
#
# Each `class Test...` corresponds to one TDD cycle: a failing test was
# written first, then the minimum production code was added to make it
# pass, then the next cycle began.
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Make the repo root importable so `import bumper` works without packaging.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import bumper  # noqa: E402


class TestParseVersion(unittest.TestCase):
    """Cycle 1: parse a SemVer string into a tuple."""

    def test_parses_basic_version(self):
        self.assertEqual(bumper.parse_version("1.2.3"), (1, 2, 3))

    def test_parses_zero_version(self):
        self.assertEqual(bumper.parse_version("0.0.0"), (0, 0, 0))

    def test_strips_v_prefix(self):
        # `v1.2.3` is a common tag style — accept it.
        self.assertEqual(bumper.parse_version("v1.2.3"), (1, 2, 3))

    def test_rejects_invalid_version(self):
        with self.assertRaises(ValueError) as ctx:
            bumper.parse_version("not.a.version")
        self.assertIn("invalid", str(ctx.exception).lower())


class TestFormatVersion(unittest.TestCase):
    """Cycle 2: turn a tuple back into a SemVer string."""

    def test_formats_basic_version(self):
        self.assertEqual(bumper.format_version((1, 2, 3)), "1.2.3")


class TestClassifyCommit(unittest.TestCase):
    """Cycle 3: map one conventional commit message to a bump kind."""

    def test_feat_is_minor(self):
        self.assertEqual(bumper.classify_commit("feat: add new login page"), "minor")

    def test_fix_is_patch(self):
        self.assertEqual(bumper.classify_commit("fix: handle null user id"), "patch")

    def test_bang_breaking_is_major(self):
        # `feat!:` is the conventional-commits short form for a breaking change.
        self.assertEqual(bumper.classify_commit("feat!: drop legacy API"), "major")

    def test_breaking_change_footer_is_major(self):
        msg = "refactor: rename config keys\n\nBREAKING CHANGE: keys renamed"
        self.assertEqual(bumper.classify_commit(msg), "major")

    def test_chore_is_none(self):
        # chore/docs/ci/etc. don't trigger any bump on their own.
        self.assertIsNone(bumper.classify_commit("chore: bump deps"))

    def test_unknown_is_none(self):
        self.assertIsNone(bumper.classify_commit("random commit message"))

    def test_scoped_feat_is_minor(self):
        # `feat(scope):` should still classify as minor.
        self.assertEqual(bumper.classify_commit("feat(api): support pagination"), "minor")

    def test_scoped_breaking_is_major(self):
        self.assertEqual(bumper.classify_commit("feat(api)!: rewrite client"), "major")


class TestDetermineBump(unittest.TestCase):
    """Cycle 4: aggregate many commits into one bump kind (max severity wins)."""

    def test_only_fix_is_patch(self):
        commits = ["fix: a", "fix: b"]
        self.assertEqual(bumper.determine_bump(commits), "patch")

    def test_feat_beats_fix(self):
        commits = ["fix: a", "feat: b"]
        self.assertEqual(bumper.determine_bump(commits), "minor")

    def test_breaking_beats_feat(self):
        commits = ["feat: a", "feat!: b"]
        self.assertEqual(bumper.determine_bump(commits), "major")

    def test_no_meaningful_commits_returns_none(self):
        commits = ["chore: fmt", "docs: typo"]
        self.assertIsNone(bumper.determine_bump(commits))

    def test_empty_list_returns_none(self):
        self.assertIsNone(bumper.determine_bump([]))


class TestBumpVersion(unittest.TestCase):
    """Cycle 5: apply a bump kind to a version tuple."""

    def test_patch_bump(self):
        self.assertEqual(bumper.bump_version((1, 2, 3), "patch"), (1, 2, 4))

    def test_minor_bump_resets_patch(self):
        self.assertEqual(bumper.bump_version((1, 2, 3), "minor"), (1, 3, 0))

    def test_major_bump_resets_minor_and_patch(self):
        self.assertEqual(bumper.bump_version((1, 2, 3), "major"), (2, 0, 0))

    def test_unknown_bump_raises(self):
        with self.assertRaises(ValueError):
            bumper.bump_version((1, 0, 0), "weird")


class TestParseCommitsFile(unittest.TestCase):
    """Cycle 6: split a `git log` text dump into individual commit messages.

    The mock format used in fixtures separates commits by a delimiter line
    so multi-line BREAKING CHANGE footers stay attached to their commit.
    """

    def test_splits_on_delimiter(self):
        text = (
            "feat: A\n"
            "---COMMIT---\n"
            "fix: B\n"
            "---COMMIT---\n"
            "refactor: C\n\nBREAKING CHANGE: yes\n"
        )
        commits = bumper.parse_commits_file(text)
        self.assertEqual(len(commits), 3)
        self.assertEqual(commits[0], "feat: A")
        self.assertEqual(commits[1], "fix: B")
        self.assertIn("BREAKING CHANGE", commits[2])

    def test_ignores_blank_chunks(self):
        text = "\n---COMMIT---\nfeat: A\n---COMMIT---\n\n"
        self.assertEqual(bumper.parse_commits_file(text), ["feat: A"])


class TestReadVersionFromPackageJson(unittest.TestCase):
    """Cycle 7: read the `version` field from a package.json file."""

    def test_reads_version(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "demo", "version": "1.4.2"}))
            self.assertEqual(bumper.read_version(p), "1.4.2")

    def test_reads_plain_version_file(self):
        # If the file is not JSON, treat it as a plain `1.2.3` text file.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "VERSION"
            p.write_text("0.9.0\n")
            self.assertEqual(bumper.read_version(p), "0.9.0")

    def test_missing_file_raises_friendly_error(self):
        with self.assertRaises(FileNotFoundError) as ctx:
            bumper.read_version(Path("/nonexistent/package.json"))
        self.assertIn("not found", str(ctx.exception).lower())


class TestWriteVersion(unittest.TestCase):
    """Cycle 8: write a new version back, preserving file format."""

    def test_writes_package_json_preserving_other_fields(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "package.json"
            p.write_text(json.dumps({"name": "demo", "version": "1.0.0", "scripts": {"x": "y"}}))
            bumper.write_version(p, "1.1.0")
            data = json.loads(p.read_text())
            self.assertEqual(data["version"], "1.1.0")
            self.assertEqual(data["name"], "demo")
            self.assertEqual(data["scripts"], {"x": "y"})

    def test_writes_plain_version_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "VERSION"
            p.write_text("0.1.0")
            bumper.write_version(p, "0.2.0")
            self.assertEqual(p.read_text().strip(), "0.2.0")


class TestGenerateChangelog(unittest.TestCase):
    """Cycle 9: render a changelog block in Keep-a-Changelog style."""

    def test_groups_commits_by_kind(self):
        commits = [
            "feat: add login",
            "fix: nullcheck",
            "feat!: drop v1 API",
            "chore: deps",  # ignored — no user-visible change
        ]
        out = bumper.generate_changelog("1.2.0", commits, date="2026-05-07")
        self.assertIn("## [1.2.0] - 2026-05-07", out)
        self.assertIn("### Breaking Changes", out)
        self.assertIn("drop v1 API", out)
        self.assertIn("### Features", out)
        self.assertIn("add login", out)
        self.assertIn("### Fixes", out)
        self.assertIn("nullcheck", out)
        # Chore should NOT appear since it's not user-visible.
        self.assertNotIn("deps", out)


class TestCli(unittest.TestCase):
    """Cycle 10: end-to-end run of `python bumper.py` against fixture files.

    This is what the GitHub Actions workflow exercises — we validate it
    locally before wiring it through act.
    """

    def _run(self, version_file, commits_file, changelog_file=None):
        cmd = [
            sys.executable,
            str(Path(__file__).resolve().parent.parent / "bumper.py"),
            "--version-file",
            str(version_file),
            "--commits-file",
            str(commits_file),
        ]
        if changelog_file is not None:
            cmd += ["--changelog-file", str(changelog_file)]
        return subprocess.run(cmd, capture_output=True, text=True)

    def test_feat_yields_minor_bump_and_writes_files(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            pkg = d / "package.json"
            pkg.write_text(json.dumps({"name": "demo", "version": "1.0.0"}))
            commits = d / "commits.txt"
            commits.write_text("feat: a\n---COMMIT---\nfix: b\n")
            changelog = d / "CHANGELOG.md"

            r = self._run(pkg, commits, changelog)
            self.assertEqual(r.returncode, 0, msg=r.stderr)
            # The CLI prints a stable, machine-readable line.
            self.assertIn("NEW_VERSION=1.1.0", r.stdout)
            self.assertIn("BUMP_TYPE=minor", r.stdout)
            # Side effects on disk.
            self.assertEqual(json.loads(pkg.read_text())["version"], "1.1.0")
            self.assertIn("## [1.1.0]", changelog.read_text())

    def test_no_bump_exits_with_message(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            pkg = d / "package.json"
            pkg.write_text(json.dumps({"name": "demo", "version": "1.0.0"}))
            commits = d / "commits.txt"
            commits.write_text("chore: housekeeping\n")
            r = self._run(pkg, commits)
            self.assertEqual(r.returncode, 0)
            self.assertIn("NEW_VERSION=1.0.0", r.stdout)
            self.assertIn("BUMP_TYPE=none", r.stdout)


if __name__ == "__main__":
    unittest.main()
