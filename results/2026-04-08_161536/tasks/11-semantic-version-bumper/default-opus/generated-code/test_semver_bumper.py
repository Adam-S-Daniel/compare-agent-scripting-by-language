"""Tests for the semantic version bumper.

TDD approach: each test was written BEFORE the corresponding implementation.
Tests cover version parsing, commit classification, version bumping,
changelog generation, file I/O, and the GitHub Actions workflow.
"""

import unittest


# -- Round 1: Parse a semantic version string --

class TestParseVersion(unittest.TestCase):
    """Test that we can parse a semver string like '1.2.3' into components."""

    def test_parse_simple_version(self):
        from semver_bumper import parse_version
        self.assertEqual(parse_version("1.2.3"), (1, 2, 3))

    def test_parse_zero_version(self):
        from semver_bumper import parse_version
        self.assertEqual(parse_version("0.0.0"), (0, 0, 0))

    def test_parse_version_with_v_prefix(self):
        from semver_bumper import parse_version
        self.assertEqual(parse_version("v1.2.3"), (1, 2, 3))

    def test_parse_invalid_version_raises(self):
        from semver_bumper import parse_version
        with self.assertRaises(ValueError):
            parse_version("not-a-version")

    def test_parse_incomplete_version_raises(self):
        from semver_bumper import parse_version
        with self.assertRaises(ValueError):
            parse_version("1.2")


# -- Round 2: Classify commit messages into bump types --

class TestClassifyCommit(unittest.TestCase):
    """Test conventional commit message classification."""

    def test_feat_is_minor(self):
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("feat: add login page"), "minor")

    def test_fix_is_patch(self):
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("fix: correct typo in header"), "patch")

    def test_breaking_change_footer_is_major(self):
        from semver_bumper import classify_commit
        self.assertEqual(
            classify_commit("feat: rework API\n\nBREAKING CHANGE: removed v1 endpoints"),
            "major",
        )

    def test_bang_notation_is_major(self):
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("feat!: drop Python 2 support"), "major")

    def test_fix_bang_is_major(self):
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("fix!: change error format"), "major")

    def test_chore_is_patch(self):
        """Non-feat, non-breaking commits default to patch."""
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("chore: update deps"), "patch")

    def test_docs_is_patch(self):
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("docs: update readme"), "patch")

    def test_unknown_format_is_patch(self):
        from semver_bumper import classify_commit
        self.assertEqual(classify_commit("random commit message"), "patch")


# -- Round 3: Determine next version from commits --

class TestBumpVersion(unittest.TestCase):
    """Test computing the next version given current version + commit list."""

    def test_patch_bump(self):
        from semver_bumper import bump_version
        commits = ["fix: repair widget", "chore: lint"]
        self.assertEqual(bump_version((1, 0, 0), commits), (1, 0, 1))

    def test_minor_bump_resets_patch(self):
        from semver_bumper import bump_version
        commits = ["feat: add dashboard", "fix: typo"]
        self.assertEqual(bump_version((1, 2, 3), commits), (1, 3, 0))

    def test_major_bump_resets_minor_and_patch(self):
        from semver_bumper import bump_version
        commits = ["feat!: new API", "feat: small thing", "fix: bug"]
        self.assertEqual(bump_version((1, 2, 3), commits), (2, 0, 0))

    def test_no_commits_no_bump(self):
        from semver_bumper import bump_version
        self.assertEqual(bump_version((1, 0, 0), []), (1, 0, 0))


# -- Round 4: Read/write version from files --

class TestVersionFileIO(unittest.TestCase):
    """Test reading and writing version from VERSION file and package.json."""

    def setUp(self):
        import tempfile, os
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir)

    def test_read_version_file(self):
        from semver_bumper import read_version_file
        import os
        path = os.path.join(self.tmpdir, "VERSION")
        with open(path, "w") as f:
            f.write("2.1.0\n")
        self.assertEqual(read_version_file(path), "2.1.0")

    def test_read_package_json(self):
        from semver_bumper import read_version_file
        import os, json
        path = os.path.join(self.tmpdir, "package.json")
        with open(path, "w") as f:
            json.dump({"name": "test", "version": "3.0.1"}, f)
        self.assertEqual(read_version_file(path), "3.0.1")

    def test_write_version_file(self):
        from semver_bumper import write_version_file
        import os
        path = os.path.join(self.tmpdir, "VERSION")
        with open(path, "w") as f:
            f.write("1.0.0\n")
        write_version_file(path, "1.1.0")
        with open(path) as f:
            self.assertEqual(f.read().strip(), "1.1.0")

    def test_write_package_json(self):
        from semver_bumper import write_version_file
        import os, json
        path = os.path.join(self.tmpdir, "package.json")
        with open(path, "w") as f:
            json.dump({"name": "myapp", "version": "1.0.0"}, f)
        write_version_file(path, "1.1.0")
        with open(path) as f:
            data = json.load(f)
        self.assertEqual(data["version"], "1.1.0")
        self.assertEqual(data["name"], "myapp")  # other fields preserved

    def test_read_missing_file_raises(self):
        from semver_bumper import read_version_file
        import os
        with self.assertRaises(FileNotFoundError):
            read_version_file(os.path.join(self.tmpdir, "nope"))

    def test_read_package_json_no_version_raises(self):
        from semver_bumper import read_version_file
        import os, json
        path = os.path.join(self.tmpdir, "package.json")
        with open(path, "w") as f:
            json.dump({"name": "test"}, f)
        with self.assertRaises(ValueError):
            read_version_file(path)


# -- Round 5: Generate changelog entry --

class TestChangelog(unittest.TestCase):
    """Test changelog generation from commit messages."""

    def test_basic_changelog(self):
        from semver_bumper import generate_changelog
        commits = ["feat: add search", "fix: repair button"]
        result = generate_changelog("1.1.0", commits, today="2026-04-08")
        self.assertIn("## 1.1.0", result)
        self.assertIn("2026-04-08", result)
        self.assertIn("### Features", result)
        self.assertIn("add search", result)
        self.assertIn("### Bug Fixes", result)
        self.assertIn("repair button", result)

    def test_changelog_with_breaking(self):
        from semver_bumper import generate_changelog
        commits = ["feat!: new API"]
        result = generate_changelog("2.0.0", commits, today="2026-04-08")
        self.assertIn("### BREAKING CHANGES", result)

    def test_empty_commits(self):
        from semver_bumper import generate_changelog
        result = generate_changelog("1.0.0", [], today="2026-04-08")
        self.assertIn("## 1.0.0", result)


# -- Round 6: Parse git log output --

class TestParseGitLog(unittest.TestCase):
    """Test parsing raw git log output into individual commit messages."""

    def test_parse_oneline(self):
        from semver_bumper import parse_git_log
        raw = "abc1234 feat: add search\ndef5678 fix: typo"
        result = parse_git_log(raw)
        self.assertEqual(result, ["feat: add search", "fix: typo"])

    def test_parse_empty(self):
        from semver_bumper import parse_git_log
        self.assertEqual(parse_git_log(""), [])
        self.assertEqual(parse_git_log("  "), [])


# -- Round 7: Integration test using fixture files --

class TestIntegrationWithFixtures(unittest.TestCase):
    """End-to-end tests: read fixtures, bump version, generate changelog."""

    def setUp(self):
        import tempfile, shutil, os
        self.tmpdir = tempfile.mkdtemp()
        self.fixtures = os.path.join(os.path.dirname(__file__), "fixtures")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir)

    def _run_bumper(self, fixture_name, start_version="1.2.3"):
        """Helper: run the bumper against a fixture file and a temp VERSION file."""
        import os, subprocess
        # Write starting version
        version_path = os.path.join(self.tmpdir, "VERSION")
        with open(version_path, "w") as f:
            f.write(start_version + "\n")

        fixture_path = os.path.join(self.fixtures, fixture_name)
        changelog_path = os.path.join(self.tmpdir, "CHANGELOG.md")

        result = subprocess.run(
            ["python3", "semver_bumper.py", version_path,
             "--commits-from-stdin", "--changelog", changelog_path],
            stdin=open(fixture_path),
            capture_output=True, text=True,
        )
        return result, version_path, changelog_path

    def test_patch_fixture(self):
        result, vpath, cpath = self._run_bumper("commits_patch.txt")
        self.assertEqual(result.returncode, 0)
        with open(vpath) as f:
            self.assertEqual(f.read().strip(), "1.2.4")

    def test_minor_fixture(self):
        result, vpath, cpath = self._run_bumper("commits_minor.txt")
        self.assertEqual(result.returncode, 0)
        with open(vpath) as f:
            self.assertEqual(f.read().strip(), "1.3.0")

    def test_major_fixture(self):
        result, vpath, cpath = self._run_bumper("commits_major.txt")
        self.assertEqual(result.returncode, 0)
        with open(vpath) as f:
            self.assertEqual(f.read().strip(), "2.0.0")

    def test_empty_fixture_no_change(self):
        result, vpath, cpath = self._run_bumper("commits_empty.txt")
        self.assertEqual(result.returncode, 0)
        with open(vpath) as f:
            self.assertEqual(f.read().strip(), "1.2.3")

    def test_changelog_written(self):
        import os
        result, vpath, cpath = self._run_bumper("commits_minor.txt")
        self.assertTrue(os.path.exists(cpath))
        with open(cpath) as f:
            content = f.read()
        self.assertIn("## 1.3.0", content)
        self.assertIn("### Features", content)


# -- Round 8: GitHub Actions workflow tests --

WORKFLOW_PATH = ".github/workflows/semantic-version-bumper.yml"


class TestWorkflow(unittest.TestCase):
    """Verify the GitHub Actions workflow is valid and correctly structured."""

    def test_workflow_file_exists(self):
        import os
        self.assertTrue(
            os.path.exists(WORKFLOW_PATH),
            f"Workflow file not found at {WORKFLOW_PATH}",
        )

    def test_workflow_yaml_parses(self):
        """The workflow must be valid YAML with expected top-level keys."""
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # Must have triggers and jobs
        self.assertIn(True, wf, "Workflow must have 'on' triggers")
        self.assertIn("jobs", wf, "Workflow must have 'jobs'")

    def test_workflow_has_triggers(self):
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        triggers = wf[True]  # 'on' parses as True in YAML
        self.assertIsInstance(triggers, dict)
        # Should have at least push or workflow_dispatch
        trigger_keys = set(triggers.keys())
        self.assertTrue(
            trigger_keys & {"push", "workflow_dispatch", "pull_request"},
            "Workflow should have push, pull_request, or workflow_dispatch trigger",
        )

    def test_workflow_jobs_have_steps(self):
        import yaml
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        for job_name, job in wf["jobs"].items():
            self.assertIn("steps", job, f"Job '{job_name}' must have steps")
            self.assertIsInstance(job["steps"], list)
            self.assertGreater(len(job["steps"]), 0, f"Job '{job_name}' has no steps")

    def test_workflow_references_script(self):
        """The workflow should reference semver_bumper.py in at least one step."""
        import yaml
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        self.assertIn("semver_bumper.py", content)

    def test_workflow_references_existing_files(self):
        """All script paths referenced in the workflow should exist."""
        import yaml, os, re
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        # Find python file references
        py_files = re.findall(r"[\w/]+\.py", content)
        for py_file in py_files:
            self.assertTrue(
                os.path.exists(py_file),
                f"Workflow references '{py_file}' but it doesn't exist",
            )

    def test_workflow_uses_checkout(self):
        """Should use actions/checkout to get the code."""
        import yaml
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        self.assertIn("actions/checkout", content)

    def test_actionlint_passes(self):
        """actionlint must report no errors (skipped if actionlint not installed)."""
        import subprocess, shutil
        if not shutil.which("actionlint"):
            self.skipTest("actionlint not installed")
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True, text=True,
        )
        self.assertEqual(
            result.returncode, 0,
            f"actionlint failed:\n{result.stdout}\n{result.stderr}",
        )


if __name__ == "__main__":
    unittest.main()
