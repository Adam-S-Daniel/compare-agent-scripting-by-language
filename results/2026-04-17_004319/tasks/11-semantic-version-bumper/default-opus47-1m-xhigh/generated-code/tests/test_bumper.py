"""TDD tests for the semantic version bumper.

Each test starts red, then we write minimum code to make it pass.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

# Make the project root importable so we can import `bumper`.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import bumper  # noqa: E402


# ---------------------------------------------------------------------------
# parse_version: reads the current version from a package.json or VERSION file
# ---------------------------------------------------------------------------

def test_parse_version_from_package_json(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "demo", "version": "1.2.3"}))
    assert bumper.parse_version(pkg) == "1.2.3"


def test_parse_version_from_plain_version_file(tmp_path):
    vfile = tmp_path / "VERSION"
    vfile.write_text("4.5.6\n")
    assert bumper.parse_version(vfile) == "4.5.6"


def test_parse_version_missing_file_raises(tmp_path):
    missing = tmp_path / "nope.json"
    with pytest.raises(FileNotFoundError):
        bumper.parse_version(missing)


def test_parse_version_invalid_semver_raises(tmp_path):
    vfile = tmp_path / "VERSION"
    vfile.write_text("not-a-version")
    with pytest.raises(ValueError, match="semantic version"):
        bumper.parse_version(vfile)


def test_parse_version_package_json_without_version_raises(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "demo"}))
    with pytest.raises(ValueError, match="version"):
        bumper.parse_version(pkg)


# ---------------------------------------------------------------------------
# parse_commits: turn raw git-log-style text into structured commit records
# ---------------------------------------------------------------------------

def test_parse_commits_basic_feat_fix_chore():
    log = (
        "feat: add search endpoint\n"
        "fix: correct pagination off-by-one\n"
        "chore: bump dependency\n"
    )
    commits = bumper.parse_commits(log)
    assert len(commits) == 3
    assert commits[0]["type"] == "feat"
    assert commits[0]["description"] == "add search endpoint"
    assert commits[0]["breaking"] is False
    assert commits[1]["type"] == "fix"
    assert commits[2]["type"] == "chore"


def test_parse_commits_ignores_blank_lines():
    log = "\n\nfeat: x\n\n\nfix: y\n"
    commits = bumper.parse_commits(log)
    assert [c["type"] for c in commits] == ["feat", "fix"]


def test_parse_commits_detects_bang_breaking():
    log = "feat!: redesign auth flow\n"
    commits = bumper.parse_commits(log)
    assert commits[0]["breaking"] is True
    assert commits[0]["type"] == "feat"
    assert commits[0]["description"] == "redesign auth flow"


def test_parse_commits_detects_breaking_change_footer():
    log = (
        "feat: rework configuration\n"
        "BREAKING CHANGE: config keys are renamed\n"
    )
    commits = bumper.parse_commits(log)
    # The BREAKING CHANGE line flags the *previous* commit as breaking.
    assert commits[0]["breaking"] is True


def test_parse_commits_non_conventional_preserved_as_other():
    log = "Merge pull request #12 from foo/bar\n"
    commits = bumper.parse_commits(log)
    assert commits[0]["type"] == "other"
    assert "Merge pull request" in commits[0]["description"]


def test_parse_commits_with_scope():
    log = "feat(api): add filtering\n"
    commits = bumper.parse_commits(log)
    assert commits[0]["type"] == "feat"
    assert commits[0]["scope"] == "api"


# ---------------------------------------------------------------------------
# determine_bump_type: pick major/minor/patch/none from a list of commits
# ---------------------------------------------------------------------------

def test_determine_bump_none_when_no_commits():
    assert bumper.determine_bump_type([]) == "none"


def test_determine_bump_patch_for_fix_only():
    commits = [{"type": "fix", "breaking": False, "description": "x", "scope": None}]
    assert bumper.determine_bump_type(commits) == "patch"


def test_determine_bump_minor_for_feat():
    commits = [
        {"type": "fix", "breaking": False, "description": "x", "scope": None},
        {"type": "feat", "breaking": False, "description": "y", "scope": None},
    ]
    assert bumper.determine_bump_type(commits) == "minor"


def test_determine_bump_major_for_breaking():
    commits = [
        {"type": "feat", "breaking": True, "description": "x", "scope": None},
    ]
    assert bumper.determine_bump_type(commits) == "major"


def test_determine_bump_none_for_chore_docs_only():
    commits = [
        {"type": "chore", "breaking": False, "description": "x", "scope": None},
        {"type": "docs", "breaking": False, "description": "y", "scope": None},
    ]
    assert bumper.determine_bump_type(commits) == "none"


# ---------------------------------------------------------------------------
# bump_version: increment the right component and zero the lower ones
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("current,bump,expected", [
    ("1.2.3", "patch", "1.2.4"),
    ("1.2.3", "minor", "1.3.0"),
    ("1.2.3", "major", "2.0.0"),
    ("0.9.9", "patch", "0.9.10"),
    ("0.0.1", "major", "1.0.0"),
    ("1.2.3", "none", "1.2.3"),
])
def test_bump_version_increments(current, bump, expected):
    assert bumper.bump_version(current, bump) == expected


def test_bump_version_rejects_bad_input():
    with pytest.raises(ValueError):
        bumper.bump_version("1.2.3", "huge")
    with pytest.raises(ValueError):
        bumper.bump_version("not-semver", "minor")


# ---------------------------------------------------------------------------
# update_version_file: write the new version back to the right file/format
# ---------------------------------------------------------------------------

def test_update_package_json_preserves_other_fields(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps(
        {"name": "demo", "version": "1.0.0", "dependencies": {"x": "^1.0.0"}},
        indent=2,
    ))
    bumper.update_version_file(pkg, "2.0.0")
    data = json.loads(pkg.read_text())
    assert data["version"] == "2.0.0"
    assert data["dependencies"] == {"x": "^1.0.0"}
    assert data["name"] == "demo"


def test_update_plain_version_file(tmp_path):
    vfile = tmp_path / "VERSION"
    vfile.write_text("1.0.0\n")
    bumper.update_version_file(vfile, "1.1.0")
    assert vfile.read_text().strip() == "1.1.0"


# ---------------------------------------------------------------------------
# generate_changelog: produce a markdown entry grouping commits by type
# ---------------------------------------------------------------------------

def test_generate_changelog_groups_commits_by_type():
    commits = [
        {"type": "feat", "breaking": False, "description": "add search", "scope": None},
        {"type": "feat", "breaking": True, "description": "rework auth", "scope": None},
        {"type": "fix", "breaking": False, "description": "null guard", "scope": "api"},
        {"type": "chore", "breaking": False, "description": "tidy", "scope": None},
    ]
    entry = bumper.generate_changelog("2.0.0", commits, date="2026-04-17")
    assert "## [2.0.0] - 2026-04-17" in entry
    assert "### Breaking Changes" in entry
    assert "rework auth" in entry
    assert "### Features" in entry
    assert "add search" in entry
    assert "### Bug Fixes" in entry
    assert "**api**: null guard" in entry
    # chore is recorded but under Other.
    assert "tidy" in entry


def test_generate_changelog_skips_empty_sections():
    commits = [
        {"type": "fix", "breaking": False, "description": "patch", "scope": None},
    ]
    entry = bumper.generate_changelog("1.0.1", commits, date="2026-04-17")
    assert "### Bug Fixes" in entry
    assert "### Features" not in entry
    assert "### Breaking Changes" not in entry


# ---------------------------------------------------------------------------
# CLI: run bumper.py as a subprocess and check STDOUT + side effects
# ---------------------------------------------------------------------------

def _write_fixture(tmp_path: Path, version: str, commits_text: str):
    """Create a working tree with a package.json and a commits file."""
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "demo", "version": version}, indent=2))
    commits = tmp_path / "commits.txt"
    commits.write_text(commits_text)
    changelog = tmp_path / "CHANGELOG.md"
    return pkg, commits, changelog


def test_cli_bumps_minor_for_feat(tmp_path):
    pkg, commits, changelog = _write_fixture(
        tmp_path, "1.1.0", "feat: add x\nfix: y\n"
    )
    result = subprocess.run(
        [sys.executable, str(ROOT / "bumper.py"),
         "--version-file", str(pkg),
         "--commits-file", str(commits),
         "--changelog-file", str(changelog)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    assert "NEW_VERSION=1.2.0" in result.stdout
    assert "BUMP_TYPE=minor" in result.stdout
    assert json.loads(pkg.read_text())["version"] == "1.2.0"
    assert "## [1.2.0]" in changelog.read_text()


def test_cli_bumps_major_for_breaking(tmp_path):
    pkg, commits, changelog = _write_fixture(
        tmp_path, "1.1.0", "feat!: redo api\n"
    )
    result = subprocess.run(
        [sys.executable, str(ROOT / "bumper.py"),
         "--version-file", str(pkg),
         "--commits-file", str(commits),
         "--changelog-file", str(changelog)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    assert "NEW_VERSION=2.0.0" in result.stdout
    assert "BUMP_TYPE=major" in result.stdout


def test_cli_no_bump_when_no_releasable_commits(tmp_path):
    pkg, commits, changelog = _write_fixture(
        tmp_path, "1.1.0", "chore: tidy\ndocs: readme\n"
    )
    result = subprocess.run(
        [sys.executable, str(ROOT / "bumper.py"),
         "--version-file", str(pkg),
         "--commits-file", str(commits),
         "--changelog-file", str(changelog)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    assert "NEW_VERSION=1.1.0" in result.stdout
    assert "BUMP_TYPE=none" in result.stdout
    # package.json unchanged
    assert json.loads(pkg.read_text())["version"] == "1.1.0"


def test_cli_errors_on_missing_version_file(tmp_path):
    commits = tmp_path / "commits.txt"
    commits.write_text("feat: x\n")
    result = subprocess.run(
        [sys.executable, str(ROOT / "bumper.py"),
         "--version-file", str(tmp_path / "nope.json"),
         "--commits-file", str(commits),
         "--changelog-file", str(tmp_path / "CHANGELOG.md")],
        capture_output=True, text=True,
    )
    assert result.returncode != 0
    assert "not found" in result.stderr.lower() or "no such file" in result.stderr.lower()
