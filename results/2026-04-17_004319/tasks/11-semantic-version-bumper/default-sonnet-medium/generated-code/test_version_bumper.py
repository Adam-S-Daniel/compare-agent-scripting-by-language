# TDD test suite for semantic version bumper
# Red/green methodology: tests written before implementation

import pytest
import os
import json
import tempfile
import shutil
import subprocess
import sys
import yaml  # pyyaml - for workflow structure tests


# ── RED PHASE 1: parse_version ──────────────────────────────────────────────

def test_parse_version_basic():
    from version_bumper import parse_version
    assert parse_version("1.2.3") == (1, 2, 3)

def test_parse_version_zeros():
    from version_bumper import parse_version
    assert parse_version("0.0.0") == (0, 0, 0)

def test_parse_version_large():
    from version_bumper import parse_version
    assert parse_version("10.20.30") == (10, 20, 30)

def test_parse_version_with_newline():
    from version_bumper import parse_version
    assert parse_version("1.0.0\n") == (1, 0, 0)

def test_parse_version_invalid_raises():
    from version_bumper import parse_version
    with pytest.raises(ValueError, match="Invalid version"):
        parse_version("not-a-version")


# ── RED PHASE 2: determine_bump_type ────────────────────────────────────────

def test_bump_type_patch_for_fix():
    from version_bumper import determine_bump_type
    assert determine_bump_type(["fix: correct off-by-one error"]) == "patch"

def test_bump_type_minor_for_feat():
    from version_bumper import determine_bump_type
    assert determine_bump_type(["feat: add user login"]) == "minor"

def test_bump_type_major_for_breaking_bang():
    from version_bumper import determine_bump_type
    assert determine_bump_type(["feat!: redesign public API"]) == "major"

def test_bump_type_major_for_breaking_change_keyword():
    from version_bumper import determine_bump_type
    assert determine_bump_type(["feat: new thing\n\nBREAKING CHANGE: removed old endpoint"]) == "major"

def test_bump_type_highest_wins_feat_over_fix():
    from version_bumper import determine_bump_type
    commits = [
        "fix: small patch",
        "feat: new feature",
        "fix: another patch",
    ]
    assert determine_bump_type(commits) == "minor"

def test_bump_type_major_wins_over_feat():
    from version_bumper import determine_bump_type
    commits = [
        "feat: new feature",
        "fix!: breaking fix",
    ]
    assert determine_bump_type(commits) == "major"

def test_bump_type_fix_only_is_patch():
    from version_bumper import determine_bump_type
    commits = ["fix: typo", "fix: null check", "fix(api): edge case"]
    assert determine_bump_type(commits) == "patch"

def test_bump_type_feat_with_scope():
    from version_bumper import determine_bump_type
    assert determine_bump_type(["feat(auth): add OAuth2 support"]) == "minor"

def test_bump_type_chore_is_patch():
    # chore commits are not feat/fix, default to patch
    from version_bumper import determine_bump_type
    assert determine_bump_type(["chore: update deps"]) == "patch"


# ── RED PHASE 3: bump_version ────────────────────────────────────────────────

def test_bump_patch():
    from version_bumper import bump_version
    assert bump_version(1, 2, 3, "patch") == (1, 2, 4)

def test_bump_minor_resets_patch():
    from version_bumper import bump_version
    assert bump_version(1, 2, 3, "minor") == (1, 3, 0)

def test_bump_major_resets_minor_and_patch():
    from version_bumper import bump_version
    assert bump_version(1, 2, 3, "major") == (2, 0, 0)

def test_bump_minor_from_zero():
    from version_bumper import bump_version
    assert bump_version(0, 0, 0, "minor") == (0, 1, 0)


# ── RED PHASE 4: read_version / write_version ─────────────────────────────

def test_read_version_txt(tmp_path):
    from version_bumper import read_version
    vf = tmp_path / "version.txt"
    vf.write_text("2.5.1\n")
    assert read_version(str(vf)) == "2.5.1"

def test_read_version_package_json(tmp_path):
    from version_bumper import read_version
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "myapp", "version": "3.1.4"}))
    assert read_version(str(pkg)) == "3.1.4"

def test_write_version_txt(tmp_path):
    from version_bumper import write_version
    vf = tmp_path / "version.txt"
    vf.write_text("1.0.0\n")
    write_version(str(vf), "1.1.0")
    assert vf.read_text().strip() == "1.1.0"

def test_write_version_package_json(tmp_path):
    from version_bumper import write_version
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "myapp", "version": "1.0.0"}, indent=2))
    write_version(str(pkg), "2.0.0")
    data = json.loads(pkg.read_text())
    assert data["version"] == "2.0.0"

def test_read_version_missing_file_raises(tmp_path):
    from version_bumper import read_version
    with pytest.raises(FileNotFoundError):
        read_version(str(tmp_path / "nonexistent.txt"))


# ── RED PHASE 5: parse_commits ──────────────────────────────────────────────

def test_parse_commits_basic():
    from version_bumper import parse_commits
    text = "fix: bug\nfeat: thing\n"
    assert parse_commits(text) == ["fix: bug", "feat: thing"]

def test_parse_commits_ignores_blank_lines():
    from version_bumper import parse_commits
    text = "fix: bug\n\nfeat: thing\n\n"
    assert parse_commits(text) == ["fix: bug", "feat: thing"]

def test_parse_commits_single():
    from version_bumper import parse_commits
    assert parse_commits("feat: initial") == ["feat: initial"]


# ── RED PHASE 6: generate_changelog ─────────────────────────────────────────

def test_changelog_contains_version():
    from version_bumper import generate_changelog
    result = generate_changelog(["fix: bug fix"], "1.0.1")
    assert "1.0.1" in result

def test_changelog_features_section():
    from version_bumper import generate_changelog
    result = generate_changelog(["feat: add auth", "feat: add search"], "1.1.0")
    assert "Features" in result
    assert "feat: add auth" in result

def test_changelog_fixes_section():
    from version_bumper import generate_changelog
    result = generate_changelog(["fix: null pointer"], "1.0.1")
    assert "Bug Fixes" in result
    assert "fix: null pointer" in result

def test_changelog_breaking_section():
    from version_bumper import generate_changelog
    result = generate_changelog(["feat!: new API"], "2.0.0")
    assert "Breaking Changes" in result


# ── RED PHASE 7: end-to-end main() integration ───────────────────────────────

def test_main_patch_bump(tmp_path):
    """End-to-end: fix commits bump patch."""
    from version_bumper import main
    vf = tmp_path / "version.txt"
    vf.write_text("1.2.3\n")
    cf = tmp_path / "commits.txt"
    cf.write_text("fix: correct edge case\nfix: another bug\n")
    clf = tmp_path / "CHANGELOG.md"

    result = main([
        "--version-file", str(vf),
        "--commits-file", str(cf),
        "--changelog-file", str(clf),
    ])
    assert result == "1.2.4"
    assert vf.read_text().strip() == "1.2.4"

def test_main_minor_bump(tmp_path):
    """End-to-end: feat commits bump minor."""
    from version_bumper import main
    vf = tmp_path / "version.txt"
    vf.write_text("1.0.0\n")
    cf = tmp_path / "commits.txt"
    cf.write_text("feat: add login\nfix: typo\n")

    result = main([
        "--version-file", str(vf),
        "--commits-file", str(cf),
        "--changelog-file", str(tmp_path / "CHANGELOG.md"),
    ])
    assert result == "1.1.0"

def test_main_major_bump(tmp_path):
    """End-to-end: breaking commit bumps major."""
    from version_bumper import main
    vf = tmp_path / "version.txt"
    vf.write_text("1.5.2\n")
    cf = tmp_path / "commits.txt"
    cf.write_text("feat!: redesign API\n")

    result = main([
        "--version-file", str(vf),
        "--commits-file", str(cf),
        "--changelog-file", str(tmp_path / "CHANGELOG.md"),
    ])
    assert result == "2.0.0"

def test_main_dry_run_no_file_change(tmp_path):
    """Dry run: files unchanged."""
    from version_bumper import main
    vf = tmp_path / "version.txt"
    vf.write_text("1.0.0\n")
    cf = tmp_path / "commits.txt"
    cf.write_text("feat: new thing\n")

    main([
        "--version-file", str(vf),
        "--commits-file", str(cf),
        "--changelog-file", str(tmp_path / "CHANGELOG.md"),
        "--dry-run",
    ])
    assert vf.read_text().strip() == "1.0.0"  # unchanged


# ── RED PHASE 8: workflow structure tests ────────────────────────────────────

WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__),
    ".github", "workflows", "semantic-version-bumper.yml"
)

def test_workflow_file_exists():
    assert os.path.exists(WORKFLOW_PATH), f"Workflow not found at {WORKFLOW_PATH}"

def test_workflow_valid_yaml():
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    assert wf is not None

def test_workflow_has_push_trigger():
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    # PyYAML parses bare 'on' key as boolean True
    triggers = wf.get("on") or wf.get(True) or {}
    assert "push" in triggers or triggers == "push"

def test_workflow_has_jobs():
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    assert "jobs" in wf
    assert len(wf["jobs"]) > 0

def test_workflow_has_checkout_step():
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    jobs = wf["jobs"]
    found_checkout = False
    for job in jobs.values():
        for step in job.get("steps", []):
            if step.get("uses", "").startswith("actions/checkout"):
                found_checkout = True
    assert found_checkout, "No actions/checkout step found"

def test_workflow_references_script():
    """Workflow must reference version_bumper.py and it must exist."""
    with open(WORKFLOW_PATH) as f:
        content = f.read()
    assert "version_bumper.py" in content
    script_path = os.path.join(os.path.dirname(__file__), "version_bumper.py")
    assert os.path.exists(script_path), "version_bumper.py not found"

def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"


# ── RED PHASE 9: act integration tests ──────────────────────────────────────

def _setup_act_repo(test_dir, version, commits_content):
    """Copy project files into test_dir and set up fixture data."""
    src_dir = os.path.dirname(os.path.abspath(__file__))

    # Copy core project files
    for fname in ["version_bumper.py"]:
        shutil.copy(os.path.join(src_dir, fname), test_dir)

    # Copy workflow
    wf_dir = os.path.join(test_dir, ".github", "workflows")
    os.makedirs(wf_dir, exist_ok=True)
    shutil.copy(
        os.path.join(src_dir, ".github", "workflows", "semantic-version-bumper.yml"),
        wf_dir
    )

    # Copy .actrc so act uses the correct container image
    actrc = os.path.join(src_dir, ".actrc")
    if os.path.exists(actrc):
        shutil.copy(actrc, test_dir)

    # Write fixture data for this test case
    with open(os.path.join(test_dir, "version.txt"), "w") as f:
        f.write(version + "\n")
    with open(os.path.join(test_dir, "commits.txt"), "w") as f:
        f.write(commits_content)

    # Init git repo
    subprocess.run(["git", "init"], cwd=test_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=test_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=test_dir, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=test_dir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "initial"], cwd=test_dir, check=True, capture_output=True)


def _run_act(test_dir):
    """Run act push in test_dir, return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=test_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return result.returncode, result.stdout + result.stderr


ACT_RESULT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "act-result.txt")


def _append_act_result(label, output):
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"TEST CASE: {label}\n")
        f.write(f"{'='*60}\n")
        f.write(output)
        f.write("\n")


@pytest.mark.act
def test_act_patch_bump():
    """ACT: fix commits on 1.2.3 -> 1.2.4"""
    with tempfile.TemporaryDirectory() as td:
        _setup_act_repo(td, "1.2.3", "fix: correct edge case\nfix: another bug\n")
        rc, output = _run_act(td)
        _append_act_result("patch_bump (1.2.3 -> 1.2.4)", output)
        assert rc == 0, f"act exited {rc}:\n{output}"
        assert "Job succeeded" in output, f"Job did not succeed:\n{output}"
        assert "NEW_VERSION=1.2.4" in output, f"Expected NEW_VERSION=1.2.4:\n{output}"


@pytest.mark.act
def test_act_minor_bump():
    """ACT: feat commit on 2.0.0 -> 2.1.0"""
    with tempfile.TemporaryDirectory() as td:
        _setup_act_repo(td, "2.0.0", "feat: add search\nfix: typo\n")
        rc, output = _run_act(td)
        _append_act_result("minor_bump (2.0.0 -> 2.1.0)", output)
        assert rc == 0, f"act exited {rc}:\n{output}"
        assert "Job succeeded" in output, f"Job did not succeed:\n{output}"
        assert "NEW_VERSION=2.1.0" in output, f"Expected NEW_VERSION=2.1.0:\n{output}"


@pytest.mark.act
def test_act_major_bump():
    """ACT: breaking commit on 1.5.2 -> 2.0.0"""
    with tempfile.TemporaryDirectory() as td:
        _setup_act_repo(td, "1.5.2", "feat!: redesign public API\n")
        rc, output = _run_act(td)
        _append_act_result("major_bump (1.5.2 -> 2.0.0)", output)
        assert rc == 0, f"act exited {rc}:\n{output}"
        assert "Job succeeded" in output, f"Job did not succeed:\n{output}"
        assert "NEW_VERSION=2.0.0" in output, f"Expected NEW_VERSION=2.0.0:\n{output}"
