# TDD tests for the license checker.
# Red/green: each test was added before the corresponding code in license_checker.py.

import json
import os
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from license_checker import (
    parse_package_json,
    parse_requirements_txt,
    parse_manifest,
    check_license,
    generate_report,
    run,
    ManifestError,
)


# ---------- parsing ----------

def test_parse_package_json_extracts_dependencies(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({
        "name": "demo",
        "dependencies": {"left-pad": "^1.3.0", "lodash": "4.17.21"},
        "devDependencies": {"jest": "~29.0.0"},
    }))
    deps = parse_package_json(str(pkg))
    assert deps == {"left-pad": "^1.3.0", "lodash": "4.17.21", "jest": "~29.0.0"}


def test_parse_package_json_empty(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "demo"}))
    assert parse_package_json(str(pkg)) == {}


def test_parse_package_json_invalid_json(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text("{ not valid json")
    with pytest.raises(ManifestError):
        parse_package_json(str(pkg))


def test_parse_requirements_txt_simple(tmp_path):
    req = tmp_path / "requirements.txt"
    req.write_text("requests==2.31.0\nflask>=2.0\n# a comment\n\nnumpy\n")
    deps = parse_requirements_txt(str(req))
    assert deps == {
        "requests": "==2.31.0",
        "flask": ">=2.0",
        "numpy": "*",
    }


def test_parse_manifest_dispatches_by_filename(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"dependencies": {"a": "1.0.0"}}))
    assert parse_manifest(str(pkg)) == {"a": "1.0.0"}
    req = tmp_path / "requirements.txt"
    req.write_text("x==1\n")
    assert parse_manifest(str(req)) == {"x": "==1"}


def test_parse_manifest_unsupported(tmp_path):
    f = tmp_path / "Gemfile"
    f.write_text("source 'x'")
    with pytest.raises(ManifestError):
        parse_manifest(str(f))


def test_parse_manifest_missing_file():
    with pytest.raises(ManifestError):
        parse_manifest("/nonexistent/package.json")


# ---------- license lookup / status ----------

def mock_lookup(mapping):
    """Factory for a mock license-lookup callable. Returns None for unknowns."""
    return lambda name, version: mapping.get(name)


def test_check_license_approved():
    lookup = mock_lookup({"lodash": "MIT"})
    result = check_license("lodash", "4.17.21", ["MIT", "Apache-2.0"], ["GPL-3.0"], lookup)
    assert result == {"name": "lodash", "version": "4.17.21", "license": "MIT", "status": "approved"}


def test_check_license_denied():
    lookup = mock_lookup({"somepkg": "GPL-3.0"})
    result = check_license("somepkg", "1.0.0", ["MIT"], ["GPL-3.0"], lookup)
    assert result["status"] == "denied"
    assert result["license"] == "GPL-3.0"


def test_check_license_unknown_when_not_in_either_list():
    lookup = mock_lookup({"weird": "WTFPL"})
    result = check_license("weird", "1.0.0", ["MIT"], ["GPL-3.0"], lookup)
    assert result["status"] == "unknown"


def test_check_license_unknown_when_lookup_returns_none():
    lookup = mock_lookup({})
    result = check_license("mystery", "1.0.0", ["MIT"], ["GPL-3.0"], lookup)
    assert result["status"] == "unknown"
    assert result["license"] is None


def test_check_license_deny_wins_over_allow():
    # If somehow a license is on both lists, deny must win (fail-closed).
    lookup = mock_lookup({"x": "MIT"})
    result = check_license("x", "1.0.0", ["MIT"], ["MIT"], lookup)
    assert result["status"] == "denied"


# ---------- report generation ----------

def test_generate_report_structure():
    entries = [
        {"name": "a", "version": "1", "license": "MIT", "status": "approved"},
        {"name": "b", "version": "2", "license": "GPL-3.0", "status": "denied"},
        {"name": "c", "version": "3", "license": None, "status": "unknown"},
    ]
    report = generate_report(entries)
    assert report["summary"] == {"approved": 1, "denied": 1, "unknown": 1, "total": 3}
    assert report["dependencies"] == entries
    assert report["compliant"] is False  # any denied => not compliant


def test_generate_report_compliant_when_no_denied():
    entries = [
        {"name": "a", "version": "1", "license": "MIT", "status": "approved"},
        {"name": "c", "version": "3", "license": None, "status": "unknown"},
    ]
    report = generate_report(entries)
    assert report["compliant"] is True


# ---------- end-to-end run() ----------

def test_run_end_to_end(tmp_path):
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({
        "dependencies": {"lodash": "4.17.21", "badlib": "1.0.0", "mystery": "0.1.0"},
    }))
    config = {"allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"]}
    lookup = mock_lookup({"lodash": "MIT", "badlib": "GPL-3.0"})

    report = run(str(pkg), config, lookup=lookup)

    names = {d["name"]: d["status"] for d in report["dependencies"]}
    assert names == {"lodash": "approved", "badlib": "denied", "mystery": "unknown"}
    assert report["summary"]["total"] == 3
    assert report["compliant"] is False


def test_run_cli_main_writes_json(tmp_path, capsys, monkeypatch):
    # Uses the built-in mock lookup baked into the CLI for demo/CI purposes.
    from license_checker import main

    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"dependencies": {"lodash": "4.17.21", "badlib": "1.0.0"}}))
    cfg = tmp_path / "config.json"
    cfg.write_text(json.dumps({"allow": ["MIT"], "deny": ["GPL-3.0"]}))

    # deterministic mock license db
    db = tmp_path / "licenses.json"
    db.write_text(json.dumps({"lodash": "MIT", "badlib": "GPL-3.0"}))

    out = tmp_path / "report.json"
    rc = main([
        "--manifest", str(pkg),
        "--config", str(cfg),
        "--license-db", str(db),
        "--output", str(out),
    ])
    # non-compliant => exit code 1
    assert rc == 1
    data = json.loads(out.read_text())
    assert data["summary"]["denied"] == 1
    assert data["summary"]["approved"] == 1


def test_run_cli_main_exit_code_zero_when_compliant(tmp_path):
    from license_checker import main
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"dependencies": {"lodash": "4.17.21"}}))
    cfg = tmp_path / "config.json"
    cfg.write_text(json.dumps({"allow": ["MIT"], "deny": ["GPL-3.0"]}))
    db = tmp_path / "licenses.json"
    db.write_text(json.dumps({"lodash": "MIT"}))
    out = tmp_path / "report.json"
    rc = main([
        "--manifest", str(pkg),
        "--config", str(cfg),
        "--license-db", str(db),
        "--output", str(out),
    ])
    assert rc == 0
