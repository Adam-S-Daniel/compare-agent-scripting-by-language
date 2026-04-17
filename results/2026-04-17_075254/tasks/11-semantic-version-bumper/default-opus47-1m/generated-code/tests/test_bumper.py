"""TDD tests for semantic version bumper.

Approach: red/green TDD. Each test was written first to fail, then bumper.py
was implemented to make it pass. Tests cover version parsing, bump-type
determination from conventional commits, file updates, and changelog generation.
"""
import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from bumper import (  # noqa: E402
    BumpError,
    bump_version,
    determine_bump,
    generate_changelog,
    parse_commits,
    read_version,
    run,
    write_version,
)


# ---------- read_version ----------

def test_read_version_from_plain_text(tmp_path):
    f = tmp_path / "version.txt"
    f.write_text("1.2.3\n")
    assert read_version(str(f)) == "1.2.3"


def test_read_version_from_package_json(tmp_path):
    f = tmp_path / "package.json"
    f.write_text(json.dumps({"name": "x", "version": "0.1.0"}))
    assert read_version(str(f)) == "0.1.0"


def test_read_version_missing_file_raises(tmp_path):
    with pytest.raises(BumpError, match="not found"):
        read_version(str(tmp_path / "missing.txt"))


def test_read_version_invalid_semver_raises(tmp_path):
    f = tmp_path / "version.txt"
    f.write_text("not-a-version")
    with pytest.raises(BumpError, match="Invalid semantic version"):
        read_version(str(f))


# ---------- parse_commits ----------

def test_parse_commits_splits_by_newline():
    raw = "feat: add x\nfix: bug y\nchore: cleanup\n"
    assert parse_commits(raw) == ["feat: add x", "fix: bug y", "chore: cleanup"]


def test_parse_commits_ignores_blank_lines():
    assert parse_commits("\nfeat: a\n\nfix: b\n\n") == ["feat: a", "fix: b"]


# ---------- determine_bump ----------

def test_determine_bump_feat_is_minor():
    assert determine_bump(["feat: add login"]) == "minor"


def test_determine_bump_fix_is_patch():
    assert determine_bump(["fix: correct off-by-one"]) == "patch"


def test_determine_bump_breaking_is_major():
    assert determine_bump(["feat!: rewrite api"]) == "major"


def test_determine_bump_breaking_footer_is_major():
    msg = "feat: thing\n\nBREAKING CHANGE: removes old endpoint"
    assert determine_bump([msg]) == "major"


def test_determine_bump_picks_highest_priority():
    commits = ["fix: small", "feat: thing", "feat!: huge"]
    assert determine_bump(commits) == "major"


def test_determine_bump_chore_only_returns_none():
    assert determine_bump(["chore: cleanup", "docs: readme"]) is None


# ---------- bump_version ----------

@pytest.mark.parametrize("current,bump,expected", [
    ("1.2.3", "patch", "1.2.4"),
    ("1.2.3", "minor", "1.3.0"),
    ("1.2.3", "major", "2.0.0"),
    ("0.0.0", "patch", "0.0.1"),
    ("0.9.9", "minor", "0.10.0"),
])
def test_bump_version(current, bump, expected):
    assert bump_version(current, bump) == expected


def test_bump_version_invalid_kind_raises():
    with pytest.raises(BumpError):
        bump_version("1.0.0", "wat")


# ---------- write_version ----------

def test_write_version_to_text_file(tmp_path):
    f = tmp_path / "version.txt"
    f.write_text("1.0.0")
    write_version(str(f), "2.0.0")
    assert f.read_text().strip() == "2.0.0"


def test_write_version_to_package_json_preserves_other_fields(tmp_path):
    f = tmp_path / "package.json"
    data = {"name": "pkg", "version": "1.0.0", "scripts": {"t": "echo"}}
    f.write_text(json.dumps(data))
    write_version(str(f), "1.1.0")
    out = json.loads(f.read_text())
    assert out["version"] == "1.1.0"
    assert out["name"] == "pkg"
    assert out["scripts"] == {"t": "echo"}


# ---------- generate_changelog ----------

def test_generate_changelog_groups_by_type():
    commits = [
        "feat: add login",
        "fix: handle null user",
        "feat!: replace api",
        "chore: bump dep",
    ]
    out = generate_changelog("1.1.0", commits)
    assert "## 1.1.0" in out
    assert "### Breaking Changes" in out
    assert "### Features" in out
    assert "### Bug Fixes" in out
    assert "- replace api" in out
    assert "- add login" in out
    assert "- handle null user" in out


def test_generate_changelog_omits_empty_sections():
    out = generate_changelog("1.0.1", ["fix: only"])
    assert "### Bug Fixes" in out
    assert "### Features" not in out
    assert "### Breaking Changes" not in out


# ---------- run (end-to-end glue) ----------

def test_run_end_to_end_minor_bump(tmp_path):
    vfile = tmp_path / "version.txt"
    vfile.write_text("1.1.0")
    cfile = tmp_path / "commits.txt"
    cfile.write_text("feat: cool thing\nfix: small bug\n")
    chfile = tmp_path / "CHANGELOG.md"

    new_version = run(str(vfile), str(cfile), str(chfile))

    assert new_version == "1.2.0"
    assert vfile.read_text().strip() == "1.2.0"
    assert "## 1.2.0" in chfile.read_text()
    assert "- cool thing" in chfile.read_text()


def test_run_no_releasable_commits_raises(tmp_path):
    vfile = tmp_path / "version.txt"
    vfile.write_text("1.0.0")
    cfile = tmp_path / "commits.txt"
    cfile.write_text("chore: nothing\ndocs: readme\n")
    chfile = tmp_path / "CHANGELOG.md"
    with pytest.raises(BumpError, match="No releasable"):
        run(str(vfile), str(cfile), str(chfile))


def test_run_prepends_to_existing_changelog(tmp_path):
    vfile = tmp_path / "version.txt"
    vfile.write_text("1.0.0")
    cfile = tmp_path / "commits.txt"
    cfile.write_text("fix: bug\n")
    chfile = tmp_path / "CHANGELOG.md"
    chfile.write_text("# Changelog\n\n## 1.0.0\n- initial\n")

    run(str(vfile), str(cfile), str(chfile))
    text = chfile.read_text()
    # New entry appears before old
    assert text.index("## 1.0.1") < text.index("## 1.0.0")
