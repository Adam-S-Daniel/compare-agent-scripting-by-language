"""Tests for semantic version bumper - developed using TDD (red/green/refactor)."""

import os
import json
import shutil
import tempfile
import subprocess

import pytest

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")

# -- Round 1: Parse a semantic version string --

def test_parse_version_valid():
    """RED: parse_version should split '1.2.3' into (1, 2, 3)."""
    from version_bumper import parse_version
    assert parse_version("1.2.3") == (1, 2, 3)

def test_parse_version_with_whitespace():
    """RED: parse_version should strip whitespace."""
    from version_bumper import parse_version
    assert parse_version("  1.2.3\n") == (1, 2, 3)

def test_parse_version_invalid():
    """RED: parse_version should raise ValueError on bad input."""
    from version_bumper import parse_version
    with pytest.raises(ValueError, match="Invalid semantic version"):
        parse_version("not.a.version")


# -- Round 2: Read and write version from files --

def test_read_version_file():
    """RED: read_version should read from a plain VERSION file."""
    from version_bumper import read_version
    assert read_version(os.path.join(FIXTURES, "VERSION")) == (1, 2, 3)

def test_read_version_package_json():
    """RED: read_version should read from package.json."""
    from version_bumper import read_version
    assert read_version(os.path.join(FIXTURES, "package.json")) == (2, 0, 1)

def test_read_version_missing_file():
    """RED: read_version should raise FileNotFoundError."""
    from version_bumper import read_version
    with pytest.raises(FileNotFoundError):
        read_version("/nonexistent/VERSION")

def test_write_version_file(tmp_path):
    """RED: write_version should update a plain VERSION file."""
    from version_bumper import write_version
    vf = tmp_path / "VERSION"
    vf.write_text("1.0.0\n")
    write_version(str(vf), (1, 1, 0))
    assert vf.read_text().strip() == "1.1.0"

def test_write_version_package_json(tmp_path):
    """RED: write_version should update version in package.json."""
    from version_bumper import write_version
    pj = tmp_path / "package.json"
    pj.write_text(json.dumps({"name": "test", "version": "1.0.0"}))
    write_version(str(pj), (2, 3, 4))
    data = json.loads(pj.read_text())
    assert data["version"] == "2.3.4"


# -- Round 3: Classify conventional commit messages --

def test_classify_fix_commit():
    """RED: classify_commit should return 'patch' for fix: commits."""
    from version_bumper import classify_commit
    assert classify_commit("fix: resolve null pointer") == "patch"

def test_classify_feat_commit():
    """RED: classify_commit should return 'minor' for feat: commits."""
    from version_bumper import classify_commit
    assert classify_commit("feat: add user profile") == "minor"

def test_classify_breaking_bang():
    """RED: feat!: should be classified as 'major'."""
    from version_bumper import classify_commit
    assert classify_commit("feat!: redesign API") == "major"

def test_classify_breaking_footer():
    """RED: BREAKING CHANGE footer should be classified as 'major'."""
    from version_bumper import classify_commit
    msg = "feat: migrate db\n\nBREAKING CHANGE: schema changed"
    assert classify_commit(msg) == "major"

def test_classify_scoped_commit():
    """RED: scoped commits like feat(api): should work."""
    from version_bumper import classify_commit
    assert classify_commit("feat(api): add endpoint") == "minor"
    assert classify_commit("fix(db): prevent duplicates") == "patch"

def test_classify_other_commit():
    """RED: non-feat/fix commits return None (no version bump)."""
    from version_bumper import classify_commit
    assert classify_commit("docs: update readme") is None
    assert classify_commit("chore: upgrade deps") is None


# -- Round 4: Parse commit log and determine bump type --

def test_parse_commit_log():
    """RED: parse_commit_log should split a log file into individual messages."""
    from version_bumper import parse_commit_log
    log = os.path.join(FIXTURES, "commits_minor.txt")
    commits = parse_commit_log(log)
    assert len(commits) == 3
    assert commits[0] == "feat: add user profile endpoint"

def test_determine_bump_patch():
    """RED: all fix commits -> patch bump."""
    from version_bumper import determine_bump
    commits = ["fix: bug one", "fix: bug two"]
    assert determine_bump(commits) == "patch"

def test_determine_bump_minor():
    """RED: feat present (no breaking) -> minor bump."""
    from version_bumper import determine_bump
    commits = ["feat: new feature", "fix: a bugfix"]
    assert determine_bump(commits) == "minor"

def test_determine_bump_major():
    """RED: breaking change present -> major bump."""
    from version_bumper import determine_bump
    commits = ["feat!: breaking api change", "fix: a bugfix"]
    assert determine_bump(commits) == "major"

def test_determine_bump_no_bump():
    """RED: only chore/docs commits -> None."""
    from version_bumper import determine_bump
    commits = ["docs: update readme", "chore: deps"]
    assert determine_bump(commits) is None

def test_determine_bump_from_fixture_files():
    """RED: test with actual fixture files."""
    from version_bumper import parse_commit_log, determine_bump
    assert determine_bump(parse_commit_log(os.path.join(FIXTURES, "commits_patch.txt"))) == "patch"
    assert determine_bump(parse_commit_log(os.path.join(FIXTURES, "commits_minor.txt"))) == "minor"
    assert determine_bump(parse_commit_log(os.path.join(FIXTURES, "commits_major.txt"))) == "major"
    assert determine_bump(parse_commit_log(os.path.join(FIXTURES, "commits_breaking_footer.txt"))) == "major"
    assert determine_bump(parse_commit_log(os.path.join(FIXTURES, "commits_mixed.txt"))) == "minor"


# -- Round 5: Bump version --

def test_bump_version_patch():
    """RED: patch bump 1.2.3 -> 1.2.4."""
    from version_bumper import bump_version
    assert bump_version((1, 2, 3), "patch") == (1, 2, 4)

def test_bump_version_minor():
    """RED: minor bump 1.2.3 -> 1.3.0 (resets patch)."""
    from version_bumper import bump_version
    assert bump_version((1, 2, 3), "minor") == (1, 3, 0)

def test_bump_version_major():
    """RED: major bump 1.2.3 -> 2.0.0 (resets minor and patch)."""
    from version_bumper import bump_version
    assert bump_version((1, 2, 3), "major") == (2, 0, 0)

def test_bump_version_invalid_type():
    """RED: invalid bump type should raise ValueError."""
    from version_bumper import bump_version
    with pytest.raises(ValueError, match="Invalid bump type"):
        bump_version((1, 0, 0), "invalid")


# -- Round 6: Generate changelog entry --

def test_generate_changelog():
    """RED: generate_changelog should produce a formatted markdown entry."""
    from version_bumper import generate_changelog
    commits = [
        "feat: add search functionality",
        "fix: handle empty query strings",
        "docs: update API documentation",
        "feat(ui): add dark mode toggle",
    ]
    entry = generate_changelog("2.0.0", commits, "2026-01-15")
    # Should have version header
    assert "## 2.0.0 (2026-01-15)" in entry
    # Should group features and fixes
    assert "### Features" in entry
    assert "- add search functionality" in entry
    assert "- add dark mode toggle" in entry
    assert "### Bug Fixes" in entry
    assert "- handle empty query strings" in entry
    # docs shouldn't appear under features/fixes
    assert "update API documentation" not in entry.split("### Bug Fixes")[0].split("### Features")[1]

def test_generate_changelog_no_commits():
    """RED: generate_changelog with no relevant commits."""
    from version_bumper import generate_changelog
    entry = generate_changelog("1.0.1", ["chore: deps"], "2026-01-15")
    assert "## 1.0.1 (2026-01-15)" in entry


# -- Round 7: End-to-end integration via CLI --

def test_run_bumper_cli_patch(tmp_path):
    """RED: CLI should bump version, write files, and output new version."""
    from version_bumper import run_bumper
    # Set up a VERSION file and commit log
    vf = tmp_path / "VERSION"
    vf.write_text("1.2.3\n")
    cl = tmp_path / "commits.txt"
    cl.write_text("fix: resolve null pointer\nfix: handle edge case\n")
    changelog = tmp_path / "CHANGELOG.md"

    result = run_bumper(str(vf), str(cl), str(changelog), date_override="2026-03-01")
    assert result == "1.2.4"
    assert vf.read_text().strip() == "1.2.4"
    assert changelog.exists()
    content = changelog.read_text()
    assert "## 1.2.4 (2026-03-01)" in content

def test_run_bumper_cli_minor(tmp_path):
    """RED: CLI with feat commits -> minor bump."""
    from version_bumper import run_bumper
    vf = tmp_path / "VERSION"
    vf.write_text("0.5.9\n")
    cl = tmp_path / "commits.txt"
    cl.write_text("feat: add search\nfix: handle empty input\n")
    changelog = tmp_path / "CHANGELOG.md"

    result = run_bumper(str(vf), str(cl), str(changelog), date_override="2026-03-01")
    assert result == "0.6.0"
    assert vf.read_text().strip() == "0.6.0"

def test_run_bumper_cli_major(tmp_path):
    """RED: CLI with breaking change -> major bump."""
    from version_bumper import run_bumper
    vf = tmp_path / "VERSION"
    vf.write_text("2.1.5\n")
    cl = tmp_path / "commits.txt"
    cl.write_text("feat!: redesign auth API\nfix: minor cleanup\n")
    changelog = tmp_path / "CHANGELOG.md"

    result = run_bumper(str(vf), str(cl), str(changelog), date_override="2026-03-01")
    assert result == "3.0.0"

def test_run_bumper_no_bump(tmp_path):
    """RED: CLI with no bump-worthy commits returns None."""
    from version_bumper import run_bumper
    vf = tmp_path / "VERSION"
    vf.write_text("1.0.0\n")
    cl = tmp_path / "commits.txt"
    cl.write_text("docs: update readme\nchore: cleanup\n")
    changelog = tmp_path / "CHANGELOG.md"

    result = run_bumper(str(vf), str(cl), str(changelog))
    assert result is None
    # Version file should be unchanged
    assert vf.read_text().strip() == "1.0.0"

def test_run_bumper_appends_changelog(tmp_path):
    """RED: CLI should prepend new entry to existing changelog."""
    from version_bumper import run_bumper
    vf = tmp_path / "VERSION"
    vf.write_text("1.0.0\n")
    cl = tmp_path / "commits.txt"
    cl.write_text("feat: initial feature\n")
    changelog = tmp_path / "CHANGELOG.md"
    changelog.write_text("## 0.9.0 (2025-12-01)\n\nOld entry\n")

    run_bumper(str(vf), str(cl), str(changelog), date_override="2026-03-01")
    content = changelog.read_text()
    # New entry should come before old entry
    assert content.index("## 1.1.0") < content.index("## 0.9.0")


# -- Workflow structure tests --

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_FILE = os.path.join(PROJECT_DIR, ".github", "workflows", "semantic-version-bumper.yml")


def test_workflow_file_exists():
    """Workflow YAML file must exist."""
    assert os.path.exists(WORKFLOW_FILE), f"Workflow not found at {WORKFLOW_FILE}"


def test_workflow_yaml_structure():
    """Parse the workflow YAML and verify expected structure."""
    import yaml
    with open(WORKFLOW_FILE) as f:
        wf = yaml.safe_load(f)

    # Must have trigger events
    assert "on" in wf or True in wf  # YAML parses 'on' as True
    triggers = wf.get("on") or wf.get(True)
    assert "push" in triggers
    assert "workflow_dispatch" in triggers

    # Must have jobs
    assert "jobs" in wf
    jobs = wf["jobs"]
    assert "test" in jobs
    assert "bump" in jobs

    # Test job should have checkout and pytest steps
    test_steps = jobs["test"]["steps"]
    step_uses = [s.get("uses", "") for s in test_steps]
    assert any("actions/checkout@v4" in u for u in step_uses)

    # Bump job should depend on test
    assert "test" in jobs["bump"].get("needs", [])


def test_workflow_references_correct_files():
    """Verify the workflow references files that actually exist."""
    import yaml
    with open(WORKFLOW_FILE) as f:
        wf = yaml.safe_load(f)

    # Collect all 'run' steps and check file references
    for job_name, job in wf["jobs"].items():
        for step in job["steps"]:
            run_cmd = step.get("run", "")
            # Check that referenced Python files exist
            if "version_bumper.py" in run_cmd:
                assert os.path.exists(os.path.join(PROJECT_DIR, "version_bumper.py"))
            if "test_version_bumper.py" in run_cmd:
                assert os.path.exists(os.path.join(PROJECT_DIR, "test_version_bumper.py"))
            if "fixtures/" in run_cmd:
                assert os.path.isdir(os.path.join(PROJECT_DIR, "fixtures"))


def _has_command(cmd):
    """Check if a command is available on PATH."""
    return shutil.which(cmd) is not None


@pytest.mark.skipif(not _has_command("actionlint"), reason="actionlint not installed")
def test_workflow_passes_actionlint():
    """actionlint must pass with no errors."""
    result = subprocess.run(
        ["actionlint", WORKFLOW_FILE],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, f"actionlint errors:\n{result.stdout}\n{result.stderr}"


# -- Act execution test --

ACT_RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")


@pytest.mark.skipif(not _has_command("act"), reason="act not installed")
def test_act_execution():
    """Run the workflow via act in a temp git repo and verify results.

    This test:
    1. Copies project files to a temp dir with a fresh git repo
    2. Runs act push --rm
    3. Saves output to act-result.txt
    4. Verifies exit code 0 and expected output values
    """
    tmpdir = tempfile.mkdtemp(prefix="act-test-")
    try:
        # Copy project files into the temp directory
        for item in ["version_bumper.py", "test_version_bumper.py", "fixtures", ".github"]:
            src = os.path.join(PROJECT_DIR, item)
            dst = os.path.join(tmpdir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        # Initialize a git repo (act requires it)
        subprocess.run(["git", "init"], cwd=tmpdir, capture_output=True, check=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmpdir, capture_output=True, check=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=tmpdir, capture_output=True, check=True)
        subprocess.run(["git", "add", "-A"], cwd=tmpdir, capture_output=True, check=True)
        subprocess.run(["git", "commit", "-m", "test"], cwd=tmpdir, capture_output=True, check=True)

        # Run act
        result = subprocess.run(
            ["act", "push", "--rm"],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            timeout=300,
        )
        output = result.stdout + "\n" + result.stderr

        # Save to act-result.txt in project dir
        with open(ACT_RESULT_FILE, "w") as f:
            f.write(output)

        # Assert act succeeded
        assert result.returncode == 0, f"act failed (exit {result.returncode}):\n{output[-2000:]}"

        # Assert each job succeeded
        # act outputs "Job succeeded" or similar for each job
        assert output.count("success") >= 2 or "Job succeeded" in output, \
            f"Not all jobs succeeded:\n{output[-2000:]}"

        # Assert the version bumper produced the correct output:
        # Starting from 1.2.3 with commits_minor.txt (feat + fix), expect minor bump -> 1.3.0
        assert "1.3.0" in output, f"Expected version '1.3.0' in act output:\n{output[-2000:]}"

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.mark.skipif(not _has_command("act"), reason="act not installed")
def test_act_result_file_exists():
    """act-result.txt must exist as a required artifact."""
    assert os.path.exists(ACT_RESULT_FILE), \
        "act-result.txt not found - test_act_execution must run first"
