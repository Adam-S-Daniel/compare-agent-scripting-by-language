"""
Tests for the semantic version bumper — written BEFORE the implementation (TDD).

Each TestCase class represents one TDD cycle:
  Cycle 1: parse_version — parse "1.2.3" into a (major, minor, patch) tuple
  Cycle 2: classify_commit — decide if a commit is major/minor/patch/none
  Cycle 3: determine_bump — given a list of commits pick the highest bump
  Cycle 4: bump_version — apply a bump type to a version tuple
  Cycle 5: read/write version files (plain text and package.json)
  Cycle 6: generate_changelog — produce a markdown changelog entry
  Cycle 7: full pipeline — end-to-end integration

Uses only the stdlib unittest module (no pip install required).
"""

import json
import os
import tempfile
import unittest

from fixtures.commit_logs import (
    EMPTY_COMMITS,
    MAJOR_COMMITS,
    MAJOR_COMMITS_FOOTER,
    MINOR_COMMITS,
    MIXED_PATCH_AND_MINOR,
    MIXED_WITH_BREAKING,
    NON_CONVENTIONAL,
    PATCH_COMMITS,
    SCOPED_COMMITS,
)

from version_bumper import (
    BumpType,
    bump_version,
    classify_commit,
    determine_bump,
    format_version,
    generate_changelog,
    parse_version,
    read_version_file,
    run_pipeline,
    write_version_file,
)


# ── Cycle 1: parse_version ───────────────────────────────────────────

class TestParseVersion(unittest.TestCase):
    """parse_version('1.2.3') -> (1, 2, 3)"""

    def test_simple_version(self):
        self.assertEqual(parse_version("1.2.3"), (1, 2, 3))

    def test_zero_version(self):
        self.assertEqual(parse_version("0.0.0"), (0, 0, 0))

    def test_large_numbers(self):
        self.assertEqual(parse_version("10.200.3000"), (10, 200, 3000))

    def test_with_v_prefix(self):
        self.assertEqual(parse_version("v1.2.3"), (1, 2, 3))

    def test_with_v_prefix_and_whitespace(self):
        self.assertEqual(parse_version("  v1.2.3\n"), (1, 2, 3))

    def test_invalid_version_raises(self):
        with self.assertRaises(ValueError) as ctx:
            parse_version("not-a-version")
        self.assertIn("Invalid semantic version", str(ctx.exception))

    def test_incomplete_version_raises(self):
        with self.assertRaises(ValueError):
            parse_version("1.2")

    def test_negative_number_raises(self):
        with self.assertRaises(ValueError):
            parse_version("-1.2.3")


# ── Cycle 1b: format_version ─────────────────────────────────────────

class TestFormatVersion(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(format_version((1, 2, 3)), "1.2.3")

    def test_zeros(self):
        self.assertEqual(format_version((0, 0, 0)), "0.0.0")


# ── Cycle 2: classify_commit ─────────────────────────────────────────

class TestClassifyCommit(unittest.TestCase):
    """Classify a single commit message into a BumpType."""

    def test_fix_is_patch(self):
        self.assertEqual(classify_commit("fix: resolve crash on startup"), BumpType.PATCH)

    def test_feat_is_minor(self):
        self.assertEqual(classify_commit("feat: add dark mode"), BumpType.MINOR)

    def test_breaking_bang_is_major(self):
        self.assertEqual(classify_commit("feat!: remove deprecated API"), BumpType.MAJOR)

    def test_breaking_footer_is_major(self):
        msg = "feat: new config\n\nBREAKING CHANGE: old config no longer supported"
        self.assertEqual(classify_commit(msg), BumpType.MAJOR)

    def test_scoped_fix_is_patch(self):
        self.assertEqual(classify_commit("fix(ui): button color"), BumpType.PATCH)

    def test_scoped_feat_is_minor(self):
        self.assertEqual(classify_commit("feat(api): add endpoint"), BumpType.MINOR)

    def test_non_conventional_is_none(self):
        self.assertEqual(classify_commit("updated readme"), BumpType.NONE)

    def test_chore_is_none(self):
        self.assertEqual(classify_commit("chore: update deps"), BumpType.NONE)

    def test_docs_is_none(self):
        self.assertEqual(classify_commit("docs: fix typo in README"), BumpType.NONE)

    def test_refactor_bang_is_major(self):
        self.assertEqual(classify_commit("refactor!: rename models"), BumpType.MAJOR)


# ── Cycle 3: determine_bump ──────────────────────────────────────────

class TestDetermineBump(unittest.TestCase):
    """Given a list of commits, return the highest applicable bump."""

    def test_patch_commits(self):
        self.assertEqual(determine_bump(PATCH_COMMITS), BumpType.PATCH)

    def test_minor_commits(self):
        self.assertEqual(determine_bump(MINOR_COMMITS), BumpType.MINOR)

    def test_major_commits(self):
        self.assertEqual(determine_bump(MAJOR_COMMITS), BumpType.MAJOR)

    def test_major_footer_commits(self):
        self.assertEqual(determine_bump(MAJOR_COMMITS_FOOTER), BumpType.MAJOR)

    def test_mixed_patch_minor(self):
        # Minor is higher than patch
        self.assertEqual(determine_bump(MIXED_PATCH_AND_MINOR), BumpType.MINOR)

    def test_mixed_with_breaking(self):
        # Major is the highest
        self.assertEqual(determine_bump(MIXED_WITH_BREAKING), BumpType.MAJOR)

    def test_non_conventional_is_none(self):
        self.assertEqual(determine_bump(NON_CONVENTIONAL), BumpType.NONE)

    def test_empty_is_none(self):
        self.assertEqual(determine_bump(EMPTY_COMMITS), BumpType.NONE)


# ── Cycle 4: bump_version ────────────────────────────────────────────

class TestBumpVersion(unittest.TestCase):
    """Apply a bump type to a version tuple."""

    def test_patch_bump(self):
        self.assertEqual(bump_version((1, 2, 3), BumpType.PATCH), (1, 2, 4))

    def test_minor_bump_resets_patch(self):
        self.assertEqual(bump_version((1, 2, 3), BumpType.MINOR), (1, 3, 0))

    def test_major_bump_resets_minor_and_patch(self):
        self.assertEqual(bump_version((1, 2, 3), BumpType.MAJOR), (2, 0, 0))

    def test_none_bump_returns_same(self):
        self.assertEqual(bump_version((1, 2, 3), BumpType.NONE), (1, 2, 3))

    def test_from_zero(self):
        self.assertEqual(bump_version((0, 0, 0), BumpType.PATCH), (0, 0, 1))
        self.assertEqual(bump_version((0, 0, 0), BumpType.MINOR), (0, 1, 0))
        self.assertEqual(bump_version((0, 0, 0), BumpType.MAJOR), (1, 0, 0))


# ── Cycle 5: read/write version files ────────────────────────────────

class TestVersionFileIO(unittest.TestCase):
    """Read and write version from plain text and package.json files."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        # Clean up temp files
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    # — Plain text VERSION file —

    def test_read_plain_text_version(self):
        path = os.path.join(self.tmpdir, "VERSION")
        with open(path, "w") as f:
            f.write("2.1.0\n")
        self.assertEqual(read_version_file(path), (2, 1, 0))

    def test_read_plain_text_with_v_prefix(self):
        path = os.path.join(self.tmpdir, "VERSION")
        with open(path, "w") as f:
            f.write("v3.0.1\n")
        self.assertEqual(read_version_file(path), (3, 0, 1))

    def test_write_plain_text_version(self):
        path = os.path.join(self.tmpdir, "VERSION")
        with open(path, "w") as f:
            f.write("1.0.0\n")
        write_version_file(path, (1, 2, 0))
        with open(path) as f:
            self.assertEqual(f.read().strip(), "1.2.0")

    # — package.json —

    def test_read_package_json_version(self):
        path = os.path.join(self.tmpdir, "package.json")
        with open(path, "w") as f:
            json.dump({"name": "my-app", "version": "4.5.6"}, f)
        self.assertEqual(read_version_file(path), (4, 5, 6))

    def test_write_package_json_version(self):
        path = os.path.join(self.tmpdir, "package.json")
        data = {"name": "my-app", "version": "1.0.0", "description": "test"}
        with open(path, "w") as f:
            json.dump(data, f)
        write_version_file(path, (1, 1, 0))
        with open(path) as f:
            result = json.load(f)
        self.assertEqual(result["version"], "1.1.0")
        # Other fields preserved
        self.assertEqual(result["name"], "my-app")
        self.assertEqual(result["description"], "test")

    # — Error cases —

    def test_read_missing_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            read_version_file(os.path.join(self.tmpdir, "nope"))

    def test_read_package_json_no_version_raises(self):
        path = os.path.join(self.tmpdir, "package.json")
        with open(path, "w") as f:
            json.dump({"name": "my-app"}, f)
        with self.assertRaises(ValueError) as ctx:
            read_version_file(path)
        self.assertIn("version", str(ctx.exception).lower())


# ── Cycle 6: generate_changelog ──────────────────────────────────────

class TestGenerateChangelog(unittest.TestCase):
    """Generate a markdown changelog entry from commits."""

    def test_basic_changelog(self):
        commits = [
            "feat: add dark mode",
            "fix: crash on startup",
        ]
        changelog = generate_changelog("1.1.0", commits)
        # Should contain version header
        self.assertIn("## 1.1.0", changelog)
        # Should contain the feature
        self.assertIn("add dark mode", changelog)
        # Should contain the fix
        self.assertIn("crash on startup", changelog)

    def test_changelog_groups_by_type(self):
        commits = [
            "feat: feature A",
            "feat: feature B",
            "fix: bug fix C",
        ]
        changelog = generate_changelog("2.0.0", commits)
        # Features section should exist
        self.assertIn("### Features", changelog)
        # Bug Fixes section should exist
        self.assertIn("### Bug Fixes", changelog)

    def test_changelog_with_scopes(self):
        commits = ["feat(api): add rate limiting"]
        changelog = generate_changelog("1.2.0", commits)
        self.assertIn("api", changelog)
        self.assertIn("add rate limiting", changelog)

    def test_changelog_breaking_changes_highlighted(self):
        commits = [
            "feat!: remove legacy endpoints",
            "feat: new stuff\n\nBREAKING CHANGE: old stuff removed",
        ]
        changelog = generate_changelog("3.0.0", commits)
        self.assertIn("BREAKING CHANGES", changelog)

    def test_empty_commits_changelog(self):
        changelog = generate_changelog("1.0.1", [])
        self.assertIn("## 1.0.1", changelog)
        self.assertIn("No notable changes", changelog)

    def test_non_conventional_commits_listed(self):
        commits = ["updated readme", "fix: actual fix"]
        changelog = generate_changelog("1.0.1", commits)
        # Non-conventional commits go under "Other"
        self.assertIn("Other", changelog)
        self.assertIn("updated readme", changelog)


# ── Cycle 7: full pipeline (integration) ─────────────────────────────

class TestPipeline(unittest.TestCase):
    """End-to-end: read version, determine bump, write new version, generate changelog."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_pipeline_minor_bump_plain_text(self):
        version_path = os.path.join(self.tmpdir, "VERSION")
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")
        with open(version_path, "w") as f:
            f.write("1.0.0\n")

        commits = [
            "feat: add user profiles",
            "fix: correct email validation",
        ]

        result = run_pipeline(version_path, commits, changelog_path)

        # Returns the new version string
        self.assertEqual(result, "1.1.0")
        # VERSION file updated
        with open(version_path) as f:
            self.assertEqual(f.read().strip(), "1.1.0")
        # CHANGELOG.md created
        self.assertTrue(os.path.exists(changelog_path))
        with open(changelog_path) as f:
            content = f.read()
        self.assertIn("## 1.1.0", content)

    def test_pipeline_major_bump_package_json(self):
        version_path = os.path.join(self.tmpdir, "package.json")
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")
        with open(version_path, "w") as f:
            json.dump({"name": "app", "version": "2.3.4"}, f)

        commits = [
            "feat!: overhaul API",
            "fix: minor typo",
        ]

        result = run_pipeline(version_path, commits, changelog_path)
        self.assertEqual(result, "3.0.0")
        with open(version_path) as f:
            data = json.load(f)
        self.assertEqual(data["version"], "3.0.0")

    def test_pipeline_patch_bump(self):
        version_path = os.path.join(self.tmpdir, "VERSION")
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")
        with open(version_path, "w") as f:
            f.write("5.10.2\n")

        commits = [
            "fix: handle edge case in parser",
        ]

        result = run_pipeline(version_path, commits, changelog_path)
        self.assertEqual(result, "5.10.3")

    def test_pipeline_no_bump_when_no_relevant_commits(self):
        version_path = os.path.join(self.tmpdir, "VERSION")
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")
        with open(version_path, "w") as f:
            f.write("1.0.0\n")

        commits = [
            "chore: update CI config",
            "docs: fix typo",
        ]

        result = run_pipeline(version_path, commits, changelog_path)
        # No bump — version unchanged
        self.assertEqual(result, "1.0.0")
        with open(version_path) as f:
            self.assertEqual(f.read().strip(), "1.0.0")

    def test_pipeline_empty_commits(self):
        version_path = os.path.join(self.tmpdir, "VERSION")
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")
        with open(version_path, "w") as f:
            f.write("1.0.0\n")

        result = run_pipeline(version_path, [], changelog_path)
        self.assertEqual(result, "1.0.0")

    def test_pipeline_appends_to_existing_changelog(self):
        version_path = os.path.join(self.tmpdir, "VERSION")
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")
        with open(version_path, "w") as f:
            f.write("1.0.0\n")
        with open(changelog_path, "w") as f:
            f.write("## 1.0.0\n\nInitial release.\n")

        commits = ["feat: add feature X"]
        run_pipeline(version_path, commits, changelog_path)

        with open(changelog_path) as f:
            content = f.read()
        # New version at the top
        self.assertTrue(content.startswith("## 1.1.0"))
        # Old content still present
        self.assertIn("## 1.0.0", content)
        self.assertIn("Initial release.", content)

    def test_pipeline_missing_version_file_raises(self):
        version_path = os.path.join(self.tmpdir, "NOPE")
        with self.assertRaises(FileNotFoundError):
            run_pipeline(version_path, ["feat: something"], "/dev/null")


if __name__ == "__main__":
    unittest.main()
