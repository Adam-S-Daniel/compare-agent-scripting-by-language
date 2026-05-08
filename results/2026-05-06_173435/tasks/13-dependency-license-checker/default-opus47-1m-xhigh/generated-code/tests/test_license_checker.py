"""
Test suite for license_checker.

Methodology: red/green TDD. Tests below were written one at a time, each
beginning red, then driving the minimum implementation to green, then
refactor before moving on. Mocks are used for license lookups so tests
stay deterministic and offline.
"""

import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

# Allow running tests with the project root on sys.path.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from license_checker import (  # noqa: E402
    Dependency,
    Status,
    check_dependency,
    format_report_json,
    format_report_text,
    generate_report,
    main,
    parse_manifest,
    parse_package_json,
    parse_requirements_txt,
)


# ---------------------------------------------------------------------------
# parse_package_json
# ---------------------------------------------------------------------------

def test_parse_package_json_extracts_dependencies():
    content = json.dumps(
        {
            "name": "demo",
            "version": "0.1.0",
            "dependencies": {"react": "^18.0.0", "lodash": "4.17.21"},
        }
    )
    deps = parse_package_json(content)
    assert Dependency(name="react", version="^18.0.0") in deps
    assert Dependency(name="lodash", version="4.17.21") in deps
    assert len(deps) == 2


def test_parse_package_json_includes_devDependencies():
    content = json.dumps(
        {
            "dependencies": {"react": "^18.0.0"},
            "devDependencies": {"jest": "^29.0.0"},
        }
    )
    deps = parse_package_json(content)
    names = {d.name for d in deps}
    assert names == {"react", "jest"}


def test_parse_package_json_handles_missing_dependencies_block():
    content = json.dumps({"name": "empty", "version": "1.0.0"})
    assert parse_package_json(content) == []


def test_parse_package_json_rejects_invalid_json():
    with pytest.raises(ValueError, match="package.json"):
        parse_package_json("{not json")


# ---------------------------------------------------------------------------
# parse_requirements_txt
# ---------------------------------------------------------------------------

def test_parse_requirements_txt_extracts_pinned_versions():
    content = textwrap.dedent(
        """
        requests==2.28.0
        flask>=2.0.0
        # comment line
        numpy
        pandas~=1.5
        """
    )
    deps = parse_requirements_txt(content)
    by_name = {d.name: d.version for d in deps}
    assert by_name == {
        "requests": "2.28.0",
        "flask": ">=2.0.0",
        "numpy": "",
        "pandas": "~=1.5",
    }


def test_parse_requirements_txt_skips_blank_and_comment_lines():
    deps = parse_requirements_txt("\n\n# only comments\n\n")
    assert deps == []


def test_parse_requirements_txt_skips_pip_directives():
    # -e and -r style directives don't represent direct dependencies.
    content = "-r other.txt\n-e ./local\nrequests==2.0\n"
    deps = parse_requirements_txt(content)
    assert deps == [Dependency(name="requests", version="2.0")]


# ---------------------------------------------------------------------------
# parse_manifest dispatch
# ---------------------------------------------------------------------------

def test_parse_manifest_dispatches_on_filename(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"dependencies": {"left-pad": "1.0.0"}}))
    req = tmp_path / "requirements.txt"
    req.write_text("requests==2.0\n")

    assert parse_manifest(str(pkg)) == [Dependency("left-pad", "1.0.0")]
    assert parse_manifest(str(req)) == [Dependency("requests", "2.0")]


def test_parse_manifest_raises_on_missing_file(tmp_path):
    with pytest.raises(FileNotFoundError):
        parse_manifest(str(tmp_path / "nope.json"))


def test_parse_manifest_raises_on_unknown_format(tmp_path):
    bogus = tmp_path / "Cargo.toml"
    bogus.write_text("# unsupported")
    with pytest.raises(ValueError, match="Unsupported manifest"):
        parse_manifest(str(bogus))


# ---------------------------------------------------------------------------
# check_dependency
# ---------------------------------------------------------------------------

def test_check_dependency_returns_approved_for_allowed_license():
    status = check_dependency(
        license="MIT",
        allow_list=["MIT", "Apache-2.0"],
        deny_list=["GPL-3.0"],
    )
    assert status == Status.APPROVED


def test_check_dependency_returns_denied_for_blocked_license():
    status = check_dependency(
        license="GPL-3.0",
        allow_list=["MIT"],
        deny_list=["GPL-3.0"],
    )
    assert status == Status.DENIED


def test_check_dependency_returns_unknown_for_missing_license():
    status = check_dependency(
        license=None,
        allow_list=["MIT"],
        deny_list=["GPL-3.0"],
    )
    assert status == Status.UNKNOWN


def test_check_dependency_unknown_when_license_outside_either_list():
    status = check_dependency(
        license="LGPL-2.1",
        allow_list=["MIT", "Apache-2.0"],
        deny_list=["GPL-3.0"],
    )
    assert status == Status.UNKNOWN


def test_check_dependency_deny_overrides_allow():
    # Same license listed both places -> deny wins (safer default).
    status = check_dependency(
        license="MIT",
        allow_list=["MIT"],
        deny_list=["MIT"],
    )
    assert status == Status.DENIED


def test_check_dependency_normalizes_case():
    status = check_dependency(
        license="mit",
        allow_list=["MIT"],
        deny_list=[],
    )
    assert status == Status.APPROVED


# ---------------------------------------------------------------------------
# generate_report (uses an injected lookup so tests stay offline)
# ---------------------------------------------------------------------------

def _mock_lookup(db):
    """Build a dependency-injected license lookup from a dict."""

    def lookup(name, version):
        return db.get(name)

    return lookup


def test_generate_report_classifies_each_dependency():
    deps = [
        Dependency("react", "18.0.0"),
        Dependency("evil-lib", "1.0.0"),
        Dependency("mystery", "0.0.1"),
    ]
    db = {"react": "MIT", "evil-lib": "GPL-3.0"}
    config = {"allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"]}
    report = generate_report(deps, _mock_lookup(db), config)
    statuses = {e["name"]: e["status"] for e in report["entries"]}
    assert statuses == {
        "react": Status.APPROVED,
        "evil-lib": Status.DENIED,
        "mystery": Status.UNKNOWN,
    }


def test_generate_report_summary_counts():
    deps = [
        Dependency("a", "1"),
        Dependency("b", "1"),
        Dependency("c", "1"),
        Dependency("d", "1"),
    ]
    db = {"a": "MIT", "b": "MIT", "c": "GPL-3.0"}
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    report = generate_report(deps, _mock_lookup(db), config)
    assert report["summary"] == {
        "approved": 2,
        "denied": 1,
        "unknown": 1,
        "total": 4,
    }
    assert report["compliant"] is False  # any denied dep => non-compliant


def test_generate_report_compliant_when_no_denies_and_no_unknowns():
    deps = [Dependency("a", "1")]
    db = {"a": "MIT"}
    config = {"allow": ["MIT"], "deny": []}
    report = generate_report(deps, _mock_lookup(db), config)
    assert report["compliant"] is True


def test_generate_report_compliant_false_when_unknowns_present():
    # Defaults to strict: unknowns count against compliance.
    deps = [Dependency("a", "1")]
    config = {"allow": ["MIT"], "deny": []}
    report = generate_report(deps, _mock_lookup({}), config)
    assert report["compliant"] is False


def test_generate_report_propagates_lookup_errors():
    def boom(name, version):
        raise RuntimeError("registry exploded")

    with pytest.raises(RuntimeError, match="registry exploded"):
        generate_report(
            [Dependency("a", "1")],
            boom,
            {"allow": [], "deny": []},
        )


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

def test_format_report_text_lists_each_dependency_with_status():
    report = {
        "entries": [
            {"name": "react", "version": "18.0.0", "license": "MIT", "status": "approved"},
            {"name": "evil-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "mystery", "version": "0.0.1", "license": None, "status": "unknown"},
        ],
        "summary": {"approved": 1, "denied": 1, "unknown": 1, "total": 3},
        "compliant": False,
    }
    text = format_report_text(report)
    assert "react" in text and "MIT" in text and "approved" in text
    assert "evil-lib" in text and "GPL-3.0" in text and "denied" in text
    assert "mystery" in text and "unknown" in text
    # Summary line is a stable, parseable token for CI assertions.
    assert "SUMMARY: approved=1 denied=1 unknown=1 total=3" in text
    assert "COMPLIANT: false" in text


def test_format_report_text_compliant_true():
    report = {
        "entries": [],
        "summary": {"approved": 0, "denied": 0, "unknown": 0, "total": 0},
        "compliant": True,
    }
    assert "COMPLIANT: true" in format_report_text(report)


def test_format_report_json_round_trips():
    report = {
        "entries": [
            {"name": "x", "version": "1", "license": "MIT", "status": "approved"},
        ],
        "summary": {"approved": 1, "denied": 0, "unknown": 0, "total": 1},
        "compliant": True,
    }
    parsed = json.loads(format_report_json(report))
    assert parsed == report


# ---------------------------------------------------------------------------
# CLI / main()
# ---------------------------------------------------------------------------

def _write_fixture(tmp_path, manifest_name, manifest_content, db, config):
    (tmp_path / manifest_name).write_text(manifest_content)
    (tmp_path / "license_db.json").write_text(json.dumps(db))
    (tmp_path / "config.json").write_text(json.dumps(config))


def test_main_text_output_and_exit_code_for_compliant_run(tmp_path, capsys):
    _write_fixture(
        tmp_path,
        "package.json",
        json.dumps({"dependencies": {"react": "^18.0.0"}}),
        db={"react": "MIT"},
        config={"allow": ["MIT"], "deny": []},
    )
    rc = main(
        [
            str(tmp_path / "package.json"),
            "--config",
            str(tmp_path / "config.json"),
            "--license-db",
            str(tmp_path / "license_db.json"),
        ]
    )
    out = capsys.readouterr().out
    assert rc == 0
    assert "react" in out and "MIT" in out and "approved" in out
    assert "COMPLIANT: true" in out


def test_main_returns_nonzero_when_denied_present(tmp_path, capsys):
    _write_fixture(
        tmp_path,
        "package.json",
        json.dumps({"dependencies": {"evil": "1.0.0"}}),
        db={"evil": "GPL-3.0"},
        config={"allow": ["MIT"], "deny": ["GPL-3.0"]},
    )
    rc = main(
        [
            str(tmp_path / "package.json"),
            "--config",
            str(tmp_path / "config.json"),
            "--license-db",
            str(tmp_path / "license_db.json"),
        ]
    )
    out = capsys.readouterr().out
    assert rc == 1
    assert "denied" in out
    assert "COMPLIANT: false" in out


def test_main_json_format(tmp_path, capsys):
    _write_fixture(
        tmp_path,
        "requirements.txt",
        "requests==2.28.0\n",
        db={"requests": "Apache-2.0"},
        config={"allow": ["Apache-2.0"], "deny": []},
    )
    rc = main(
        [
            str(tmp_path / "requirements.txt"),
            "--config",
            str(tmp_path / "config.json"),
            "--license-db",
            str(tmp_path / "license_db.json"),
            "--format",
            "json",
        ]
    )
    out = capsys.readouterr().out
    payload = json.loads(out)
    assert rc == 0
    assert payload["summary"]["total"] == 1
    assert payload["entries"][0]["license"] == "Apache-2.0"


def test_main_writes_output_file(tmp_path):
    _write_fixture(
        tmp_path,
        "package.json",
        json.dumps({"dependencies": {"a": "1.0.0"}}),
        db={"a": "MIT"},
        config={"allow": ["MIT"], "deny": []},
    )
    out_path = tmp_path / "report.json"
    rc = main(
        [
            str(tmp_path / "package.json"),
            "--config",
            str(tmp_path / "config.json"),
            "--license-db",
            str(tmp_path / "license_db.json"),
            "--format",
            "json",
            "--output",
            str(out_path),
        ]
    )
    assert rc == 0
    payload = json.loads(out_path.read_text())
    assert payload["entries"][0]["name"] == "a"


def test_main_reports_helpful_error_on_missing_manifest(tmp_path, capsys):
    rc = main(
        [
            str(tmp_path / "does-not-exist.json"),
            "--config",
            str(tmp_path / "missing-config.json"),
        ]
    )
    err = capsys.readouterr().err
    assert rc == 2
    assert "Error:" in err
    assert "does-not-exist.json" in err


def test_main_reports_helpful_error_on_invalid_config(tmp_path, capsys):
    (tmp_path / "package.json").write_text(json.dumps({"dependencies": {}}))
    (tmp_path / "config.json").write_text("{not json")
    rc = main(
        [
            str(tmp_path / "package.json"),
            "--config",
            str(tmp_path / "config.json"),
        ]
    )
    err = capsys.readouterr().err
    assert rc == 2
    assert "Error:" in err
    assert "config" in err.lower()


def test_script_invocable_as_module(tmp_path):
    """Smoke-check that `python3 license_checker.py ...` runs end-to-end."""
    _write_fixture(
        tmp_path,
        "package.json",
        json.dumps({"dependencies": {"a": "1.0.0"}}),
        db={"a": "MIT"},
        config={"allow": ["MIT"], "deny": []},
    )
    script = ROOT / "license_checker.py"
    proc = subprocess.run(
        [
            sys.executable,
            str(script),
            str(tmp_path / "package.json"),
            "--config",
            str(tmp_path / "config.json"),
            "--license-db",
            str(tmp_path / "license_db.json"),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr
    assert "COMPLIANT: true" in proc.stdout
