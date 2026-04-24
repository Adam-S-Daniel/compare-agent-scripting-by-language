"""
Unit tests for license_checker.py.

TDD approach: each test was written first, then the minimal implementation
to satisfy it was added to license_checker.py.
"""
import json
import pytest
from pathlib import Path

from license_checker import (
    parse_requirements,
    check_license,
    generate_report,
    LicenseLookup,
    load_config,
)


# ----- parse_requirements -----

def test_parse_requirements_simple(tmp_path):
    """Parse a basic requirements.txt with name==version lines."""
    f = tmp_path / "requirements.txt"
    f.write_text("flask==2.0.1\nrequests==2.28.0\n")
    deps = parse_requirements(str(f))
    assert deps == [("flask", "2.0.1"), ("requests", "2.28.0")]


def test_parse_requirements_ignores_comments_and_blanks(tmp_path):
    f = tmp_path / "requirements.txt"
    f.write_text("# a comment\n\nflask==2.0.1\n  \n# another\nrequests==2.28.0\n")
    deps = parse_requirements(str(f))
    assert deps == [("flask", "2.0.1"), ("requests", "2.28.0")]


def test_parse_requirements_handles_unpinned(tmp_path):
    """If a line has no version, version is 'unknown'."""
    f = tmp_path / "requirements.txt"
    f.write_text("flask\nrequests==2.28.0\n")
    deps = parse_requirements(str(f))
    assert deps == [("flask", "unknown"), ("requests", "2.28.0")]


def test_parse_requirements_missing_file_raises():
    with pytest.raises(FileNotFoundError) as exc:
        parse_requirements("/nonexistent/path/requirements.txt")
    assert "requirements" in str(exc.value).lower()


# ----- check_license -----

def test_check_license_approved():
    config = {"allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"]}
    assert check_license("MIT", config) == "approved"


def test_check_license_denied():
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    assert check_license("GPL-3.0", config) == "denied"


def test_check_license_unknown_license_when_not_in_either_list():
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    assert check_license("BSD-3-Clause", config) == "unknown"


def test_check_license_none_license_is_unknown():
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    assert check_license(None, config) == "unknown"


# ----- LicenseLookup (mocked lookup) -----

def test_license_lookup_returns_known_license():
    lookup = LicenseLookup({"flask": "BSD-3-Clause"})
    assert lookup.get("flask") == "BSD-3-Clause"


def test_license_lookup_returns_none_for_unknown():
    lookup = LicenseLookup({})
    assert lookup.get("mystery-pkg") is None


# ----- generate_report -----

def test_generate_report_has_entry_per_dep():
    deps = [("flask", "2.0.1"), ("evilpkg", "1.0.0")]
    config = {"allow": ["BSD-3-Clause"], "deny": ["GPL-3.0"]}
    lookup = LicenseLookup({"flask": "BSD-3-Clause", "evilpkg": "GPL-3.0"})
    report = generate_report(deps, config, lookup)
    assert len(report["dependencies"]) == 2
    names = [d["name"] for d in report["dependencies"]]
    assert names == ["flask", "evilpkg"]


def test_generate_report_statuses():
    deps = [("a", "1"), ("b", "1"), ("c", "1")]
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    lookup = LicenseLookup({"a": "MIT", "b": "GPL-3.0", "c": "Weird"})
    report = generate_report(deps, config, lookup)
    by_name = {d["name"]: d for d in report["dependencies"]}
    assert by_name["a"]["status"] == "approved"
    assert by_name["b"]["status"] == "denied"
    assert by_name["c"]["status"] == "unknown"
    # unknown covers both "license not in lists" and "license not found"


def test_generate_report_handles_missing_license():
    deps = [("ghost", "1.0")]
    config = {"allow": ["MIT"], "deny": []}
    lookup = LicenseLookup({})  # no entry for ghost
    report = generate_report(deps, config, lookup)
    entry = report["dependencies"][0]
    assert entry["status"] == "unknown"
    assert entry["license"] is None


def test_generate_report_summary_counts():
    deps = [("a", "1"), ("b", "1"), ("c", "1"), ("d", "1")]
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    lookup = LicenseLookup({"a": "MIT", "b": "MIT", "c": "GPL-3.0", "d": "Other"})
    report = generate_report(deps, config, lookup)
    assert report["summary"]["approved"] == 2
    assert report["summary"]["denied"] == 1
    assert report["summary"]["unknown"] == 1
    assert report["summary"]["total"] == 4


# ----- load_config -----

def test_load_config_reads_json(tmp_path):
    cfg = tmp_path / "licenses.json"
    cfg.write_text(json.dumps({"allow": ["MIT"], "deny": ["GPL-3.0"]}))
    loaded = load_config(str(cfg))
    assert loaded["allow"] == ["MIT"]
    assert loaded["deny"] == ["GPL-3.0"]


def test_load_config_missing_file_raises():
    with pytest.raises(FileNotFoundError):
        load_config("/nonexistent/licenses.json")


def test_load_config_invalid_json_raises(tmp_path):
    cfg = tmp_path / "bad.json"
    cfg.write_text("{not valid json")
    with pytest.raises(ValueError) as exc:
        load_config(str(cfg))
    assert "config" in str(exc.value).lower() or "json" in str(exc.value).lower()
