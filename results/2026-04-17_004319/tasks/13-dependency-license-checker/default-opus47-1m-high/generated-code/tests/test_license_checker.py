"""Tests for the dependency-license checker.

Red/green TDD: tests were written first, one concern at a time.
The mocks live in `tests/fake_license_db.py` to keep lookups deterministic.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

# Ensure the package under test is importable when pytest is run from the
# project root.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from license_checker import (  # noqa: E402
    ComplianceReport,
    DependencyStatus,
    check_dependencies,
    load_config,
    parse_manifest,
    render_report,
)
from tests.fake_license_db import FakeLicenseDB  # noqa: E402


# ---------------------------------------------------------------------------
# parse_manifest
# ---------------------------------------------------------------------------


def test_parse_manifest_package_json(tmp_path: Path) -> None:
    """package.json with prod + dev deps yields (name, version) pairs."""
    manifest = tmp_path / "package.json"
    manifest.write_text(
        json.dumps(
            {
                "name": "demo",
                "dependencies": {"lodash": "^4.17.21", "express": "4.18.2"},
                "devDependencies": {"jest": "~29.0.0"},
            }
        )
    )

    deps = parse_manifest(manifest)

    assert sorted(deps) == [
        ("express", "4.18.2"),
        ("jest", "~29.0.0"),
        ("lodash", "^4.17.21"),
    ]


def test_parse_manifest_requirements_txt(tmp_path: Path) -> None:
    """requirements.txt supports ==, >=, comments, and blank lines."""
    manifest = tmp_path / "requirements.txt"
    manifest.write_text(
        "# core\n"
        "requests==2.31.0\n"
        "\n"
        "flask>=2.0.0\n"
        "pytest  # used for tests\n"
    )

    deps = parse_manifest(manifest)

    assert sorted(deps) == [
        ("flask", ">=2.0.0"),
        ("pytest", ""),
        ("requests", "==2.31.0"),
    ]


def test_parse_manifest_missing_file_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        parse_manifest(tmp_path / "does-not-exist.json")


def test_parse_manifest_unsupported_extension(tmp_path: Path) -> None:
    bad = tmp_path / "Gemfile"
    bad.write_text("gem 'rails'\n")
    with pytest.raises(ValueError, match="Unsupported manifest"):
        parse_manifest(bad)


def test_parse_manifest_accepts_alternate_json_names(tmp_path: Path) -> None:
    """Any `.json` file is treated as a package.json-style manifest so CI
    fixtures like `sample-package.json` can drive the workflow without being
    renamed."""
    alt = tmp_path / "ci-fixture-package.json"
    alt.write_text(json.dumps({"dependencies": {"react": "18.2.0"}}))
    assert parse_manifest(alt) == [("react", "18.2.0")]


def test_parse_manifest_malformed_json(tmp_path: Path) -> None:
    bad = tmp_path / "package.json"
    bad.write_text("{ this is not json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        parse_manifest(bad)


# ---------------------------------------------------------------------------
# load_config
# ---------------------------------------------------------------------------


def test_load_config_reads_allow_and_deny(tmp_path: Path) -> None:
    cfg = tmp_path / "policy.json"
    cfg.write_text(
        json.dumps(
            {
                "allow": ["MIT", "Apache-2.0", "BSD-3-Clause"],
                "deny": ["GPL-3.0", "AGPL-3.0"],
            }
        )
    )

    policy = load_config(cfg)

    assert policy.allow == {"MIT", "Apache-2.0", "BSD-3-Clause"}
    assert policy.deny == {"GPL-3.0", "AGPL-3.0"}


def test_load_config_defaults_to_empty_lists(tmp_path: Path) -> None:
    cfg = tmp_path / "policy.json"
    cfg.write_text("{}")
    policy = load_config(cfg)
    assert policy.allow == set()
    assert policy.deny == set()


def test_load_config_missing_file_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        load_config(tmp_path / "missing.json")


# ---------------------------------------------------------------------------
# check_dependencies (mocked license lookup)
# ---------------------------------------------------------------------------


def test_check_dependencies_classifies_each_entry() -> None:
    """A dep is APPROVED iff its license is on the allow-list, DENIED iff on
    the deny-list, UNKNOWN if the lookup returns None."""
    deps = [
        ("lodash", "4.17.21"),
        ("left-pad", "1.3.0"),
        ("banned-pkg", "1.0.0"),
        ("mystery", "0.0.1"),
    ]
    db = FakeLicenseDB(
        {
            "lodash": "MIT",
            "left-pad": "WTFPL",
            "banned-pkg": "GPL-3.0",
            # mystery intentionally missing -> None
        }
    )
    policy_allow = {"MIT", "Apache-2.0"}
    policy_deny = {"GPL-3.0"}

    report = check_dependencies(deps, db, policy_allow, policy_deny)

    by_name = {d.name: d for d in report.entries}
    assert by_name["lodash"].status == "approved"
    assert by_name["lodash"].license == "MIT"
    assert by_name["banned-pkg"].status == "denied"
    # A license that's on neither list is unknown — operator decides.
    assert by_name["left-pad"].status == "unknown"
    # A missing license (None) is also unknown, but with a distinct reason.
    assert by_name["mystery"].status == "unknown"
    assert by_name["mystery"].license is None


def test_check_dependencies_counts_summaries() -> None:
    deps = [("a", "1"), ("b", "1"), ("c", "1")]
    db = FakeLicenseDB({"a": "MIT", "b": "GPL-3.0", "c": "Unlicense"})
    report = check_dependencies(deps, db, {"MIT"}, {"GPL-3.0"})

    assert report.approved_count == 1
    assert report.denied_count == 1
    assert report.unknown_count == 1
    assert report.total == 3


def test_check_dependencies_empty_list() -> None:
    report = check_dependencies([], FakeLicenseDB({}), {"MIT"}, {"GPL-3.0"})
    assert report.total == 0
    assert report.entries == []


# ---------------------------------------------------------------------------
# render_report
# ---------------------------------------------------------------------------


def test_render_report_text_includes_each_dep() -> None:
    report = ComplianceReport(
        entries=[
            DependencyStatus("lodash", "4.17.21", "MIT", "approved"),
            DependencyStatus("banned-pkg", "1.0.0", "GPL-3.0", "denied"),
            DependencyStatus("mystery", "0.0.1", None, "unknown"),
        ]
    )

    text = render_report(report)

    # Human-readable report lists every dependency with its verdict.
    assert "lodash" in text
    assert "4.17.21" in text
    assert "MIT" in text
    assert "APPROVED" in text
    assert "DENIED" in text
    assert "UNKNOWN" in text
    # Summary counts are visible at the bottom.
    assert "approved=1" in text
    assert "denied=1" in text
    assert "unknown=1" in text


def test_render_report_has_nonzero_exit_code_when_denied() -> None:
    """The `exit_code` property lets CI fail the build when any dep is denied."""
    clean = ComplianceReport(entries=[DependencyStatus("a", "1", "MIT", "approved")])
    dirty = ComplianceReport(entries=[DependencyStatus("a", "1", "GPL-3.0", "denied")])

    assert clean.exit_code == 0
    assert dirty.exit_code == 1


# ---------------------------------------------------------------------------
# CLI end-to-end (shells out to the script)
# ---------------------------------------------------------------------------


def _run_cli(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    # Tests use the fake DB baked into the module — no network calls.
    env["LICENSE_CHECKER_USE_FAKE"] = "1"
    return subprocess.run(
        [sys.executable, str(ROOT / "license_checker.py"), *args],
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )


def test_cli_exits_zero_when_all_approved(tmp_path: Path) -> None:
    manifest = tmp_path / "package.json"
    manifest.write_text(json.dumps({"dependencies": {"lodash": "4.17.21"}}))
    policy = tmp_path / "policy.json"
    policy.write_text(json.dumps({"allow": ["MIT"], "deny": ["GPL-3.0"]}))

    result = _run_cli(
        "--manifest", str(manifest), "--policy", str(policy)
    )

    assert result.returncode == 0, result.stderr
    assert "lodash" in result.stdout
    assert "APPROVED" in result.stdout


def test_cli_exits_nonzero_when_any_denied(tmp_path: Path) -> None:
    manifest = tmp_path / "package.json"
    manifest.write_text(json.dumps({"dependencies": {"banned-pkg": "1.0.0"}}))
    policy = tmp_path / "policy.json"
    policy.write_text(json.dumps({"allow": ["MIT"], "deny": ["GPL-3.0"]}))

    result = _run_cli(
        "--manifest", str(manifest), "--policy", str(policy)
    )

    assert result.returncode == 1
    assert "DENIED" in result.stdout


def test_cli_missing_manifest_prints_error(tmp_path: Path) -> None:
    policy = tmp_path / "policy.json"
    policy.write_text(json.dumps({"allow": [], "deny": []}))

    result = _run_cli(
        "--manifest", str(tmp_path / "nope.json"), "--policy", str(policy)
    )

    # Exit code 2 is the conventional "usage/input error" signal.
    assert result.returncode == 2
    assert "not found" in result.stderr.lower() or "no such" in result.stderr.lower()
