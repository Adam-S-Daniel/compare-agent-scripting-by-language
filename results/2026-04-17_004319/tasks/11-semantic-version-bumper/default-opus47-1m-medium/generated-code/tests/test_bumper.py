"""TDD tests for semantic version bumper.

Approach: red/green TDD. Each test is a small unit covering one piece of behavior.
The suite covers parsing, bump-type analysis, version arithmetic, file update,
changelog generation, and end-to-end CLI behavior.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from bumper import (  # noqa: E402
    bump_version,
    determine_bump,
    generate_changelog,
    parse_commits,
    read_version,
    update_version_file,
)

FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"


# ---------- read_version ----------

def test_read_version_from_package_json(tmp_path):
    p = tmp_path / "package.json"
    p.write_text(json.dumps({"name": "x", "version": "1.2.3"}))
    assert read_version(str(p)) == "1.2.3"


def test_read_version_from_version_file(tmp_path):
    p = tmp_path / "VERSION"
    p.write_text("0.4.1\n")
    assert read_version(str(p)) == "0.4.1"


def test_read_version_missing_file(tmp_path):
    with pytest.raises(FileNotFoundError):
        read_version(str(tmp_path / "nope"))


def test_read_version_invalid_semver(tmp_path):
    p = tmp_path / "VERSION"
    p.write_text("not-a-version")
    with pytest.raises(ValueError):
        read_version(str(p))


# ---------- parse_commits ----------

def test_parse_commits_from_fixture():
    commits = parse_commits((FIXTURES / "commits_feat.txt").read_text())
    assert len(commits) >= 1
    assert any(c["type"] == "feat" for c in commits)


def test_parse_commits_handles_breaking_marker():
    text = "feat(api)!: drop legacy endpoint\nfix: small typo\n"
    commits = parse_commits(text)
    assert commits[0]["breaking"] is True
    assert commits[1]["breaking"] is False


def test_parse_commits_handles_breaking_change_footer():
    text = "feat: new flow\n\nBREAKING CHANGE: removes config key\n"
    commits = parse_commits(text)
    assert commits[0]["breaking"] is True


# ---------- determine_bump ----------

def test_determine_bump_major_for_breaking():
    commits = parse_commits((FIXTURES / "commits_breaking.txt").read_text())
    assert determine_bump(commits) == "major"


def test_determine_bump_minor_for_feat():
    commits = parse_commits((FIXTURES / "commits_feat.txt").read_text())
    assert determine_bump(commits) == "minor"


def test_determine_bump_patch_for_fix():
    commits = parse_commits((FIXTURES / "commits_fix.txt").read_text())
    assert determine_bump(commits) == "patch"


def test_determine_bump_none_for_chore_only():
    text = "chore: deps\ndocs: readme\n"
    assert determine_bump(parse_commits(text)) is None


# ---------- bump_version ----------

@pytest.mark.parametrize("cur,kind,expected", [
    ("1.2.3", "major", "2.0.0"),
    ("1.2.3", "minor", "1.3.0"),
    ("1.2.3", "patch", "1.2.4"),
    ("0.0.0", "patch", "0.0.1"),
])
def test_bump_version(cur, kind, expected):
    assert bump_version(cur, kind) == expected


def test_bump_version_invalid_kind():
    with pytest.raises(ValueError):
        bump_version("1.0.0", "weird")


# ---------- update_version_file ----------

def test_update_package_json_preserves_other_keys(tmp_path):
    p = tmp_path / "package.json"
    p.write_text(json.dumps({"name": "x", "version": "1.0.0", "scripts": {"a": "b"}}))
    update_version_file(str(p), "1.1.0")
    data = json.loads(p.read_text())
    assert data["version"] == "1.1.0"
    assert data["scripts"] == {"a": "b"}


def test_update_plain_version_file(tmp_path):
    p = tmp_path / "VERSION"
    p.write_text("1.0.0\n")
    update_version_file(str(p), "1.0.1")
    assert p.read_text().strip() == "1.0.1"


# ---------- generate_changelog ----------

def test_generate_changelog_groups_by_type():
    commits = parse_commits((FIXTURES / "commits_mixed.txt").read_text())
    entry = generate_changelog(commits, "1.3.0")
    assert "## 1.3.0" in entry
    assert "### Features" in entry
    assert "### Bug Fixes" in entry


# ---------- CLI integration ----------

def _run_cli(tmp_path, version_file, commits_file):
    """Helper: invoke the CLI as a subprocess."""
    env = os.environ.copy()
    env["PYTHONPATH"] = str(Path(__file__).resolve().parent.parent)
    return subprocess.run(
        [sys.executable, str(Path(__file__).resolve().parent.parent / "bumper.py"),
         "--version-file", str(version_file),
         "--commits-file", str(commits_file),
         "--changelog", str(tmp_path / "CHANGELOG.md")],
        capture_output=True, text=True, env=env,
    )


def test_cli_end_to_end_minor(tmp_path):
    vfile = tmp_path / "package.json"
    vfile.write_text(json.dumps({"name": "x", "version": "1.1.0"}))
    cfile = tmp_path / "commits.txt"
    cfile.write_text((FIXTURES / "commits_feat.txt").read_text())

    result = _run_cli(tmp_path, vfile, cfile)
    assert result.returncode == 0, result.stderr
    assert "1.2.0" in result.stdout
    assert json.loads(vfile.read_text())["version"] == "1.2.0"
    assert (tmp_path / "CHANGELOG.md").exists()
    assert "## 1.2.0" in (tmp_path / "CHANGELOG.md").read_text()


def test_cli_end_to_end_major(tmp_path):
    vfile = tmp_path / "VERSION"
    vfile.write_text("2.4.5\n")
    cfile = tmp_path / "commits.txt"
    cfile.write_text((FIXTURES / "commits_breaking.txt").read_text())
    result = _run_cli(tmp_path, vfile, cfile)
    assert result.returncode == 0
    assert "3.0.0" in result.stdout
    assert vfile.read_text().strip() == "3.0.0"
