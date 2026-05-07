"""
TDD: Red/Green/Refactor for dependency license checker.

Each test was written BEFORE the corresponding implementation code.
The tests drive the design of the license_checker module.
"""
import json
import pytest
from unittest.mock import patch

# TDD Round 1: Test that we can parse a package.json manifest
def test_parse_package_json():
    from license_checker import parse_manifest

    manifest = json.dumps({
        "name": "my-app",
        "dependencies": {
            "express": "^4.18.0",
            "lodash": "~4.17.21"
        },
        "devDependencies": {
            "jest": "^29.0.0"
        }
    })
    deps = parse_manifest(manifest, "package.json")
    assert deps == [
        {"name": "express", "version": "^4.18.0"},
        {"name": "lodash", "version": "~4.17.21"},
        {"name": "jest", "version": "^29.0.0"},
    ]


# TDD Round 2: Test that we can parse a requirements.txt manifest
def test_parse_requirements_txt():
    from license_checker import parse_manifest

    manifest = "requests==2.31.0\nflask>=2.0.0\nnumpy\n# comment\n\n"
    deps = parse_manifest(manifest, "requirements.txt")
    assert deps == [
        {"name": "requests", "version": "==2.31.0"},
        {"name": "flask", "version": ">=2.0.0"},
        {"name": "numpy", "version": ""},
    ]


# TDD Round 3: Test license lookup (mocked)
def test_lookup_license():
    from license_checker import lookup_license

    mock_db = {
        "express": "MIT",
        "lodash": "MIT",
        "jest": "MIT",
    }
    with patch("license_checker.LICENSE_DB", mock_db):
        assert lookup_license("express") == "MIT"
        assert lookup_license("lodash") == "MIT"
        assert lookup_license("unknown-pkg") == "UNKNOWN"


# TDD Round 4: Test compliance checking against allow/deny lists
def test_check_compliance():
    from license_checker import check_compliance

    config = {
        "allowed_licenses": ["MIT", "Apache-2.0", "BSD-3-Clause"],
        "denied_licenses": ["GPL-3.0", "AGPL-3.0"]
    }
    assert check_compliance("MIT", config) == "approved"
    assert check_compliance("Apache-2.0", config) == "approved"
    assert check_compliance("GPL-3.0", config) == "denied"
    assert check_compliance("AGPL-3.0", config) == "denied"
    assert check_compliance("UNKNOWN", config) == "unknown"
    assert check_compliance("ISC", config) == "unknown"


# TDD Round 5: Test full report generation
def test_generate_report():
    from license_checker import generate_report

    deps = [
        {"name": "express", "version": "^4.18.0"},
        {"name": "redis", "version": "^4.0.0"},
        {"name": "mystery-lib", "version": "1.0.0"},
    ]
    config = {
        "allowed_licenses": ["MIT"],
        "denied_licenses": ["GPL-3.0"]
    }
    mock_db = {
        "express": "MIT",
        "redis": "GPL-3.0",
    }
    with patch("license_checker.LICENSE_DB", mock_db):
        report = generate_report(deps, config)

    assert len(report) == 3
    assert report[0] == {"name": "express", "version": "^4.18.0", "license": "MIT", "status": "approved"}
    assert report[1] == {"name": "redis", "version": "^4.0.0", "license": "GPL-3.0", "status": "denied"}
    assert report[2] == {"name": "mystery-lib", "version": "1.0.0", "license": "UNKNOWN", "status": "unknown"}


# TDD Round 6: Test error handling for unsupported manifest type
def test_parse_unsupported_manifest():
    from license_checker import parse_manifest

    with pytest.raises(ValueError, match="Unsupported manifest type"):
        parse_manifest("content", "Gemfile")


# TDD Round 7: Test error handling for malformed package.json
def test_parse_malformed_package_json():
    from license_checker import parse_manifest

    with pytest.raises(ValueError, match="Invalid JSON"):
        parse_manifest("not valid json {{{", "package.json")


# TDD Round 8: Test the full pipeline end-to-end
def test_run_checker_end_to_end(tmp_path):
    from license_checker import run_checker

    manifest_file = tmp_path / "package.json"
    manifest_file.write_text(json.dumps({
        "name": "test-app",
        "dependencies": {
            "express": "^4.18.0",
            "lodash": "~4.17.21"
        }
    }))

    config_file = tmp_path / "license-config.json"
    config_file.write_text(json.dumps({
        "allowed_licenses": ["MIT", "Apache-2.0"],
        "denied_licenses": ["GPL-3.0"]
    }))

    mock_db = {"express": "MIT", "lodash": "MIT"}
    with patch("license_checker.LICENSE_DB", mock_db):
        report = run_checker(str(manifest_file), str(config_file))

    assert len(report) == 2
    assert all(entry["status"] == "approved" for entry in report)


# TDD Round 9: Test report formatting output
def test_format_report():
    from license_checker import format_report

    report = [
        {"name": "express", "version": "^4.18.0", "license": "MIT", "status": "approved"},
        {"name": "redis", "version": "^4.0.0", "license": "GPL-3.0", "status": "denied"},
        {"name": "unknown-lib", "version": "1.0.0", "license": "UNKNOWN", "status": "unknown"},
    ]
    output = format_report(report)
    assert "APPROVED: express@^4.18.0 (MIT)" in output
    assert "DENIED: redis@^4.0.0 (GPL-3.0)" in output
    assert "UNKNOWN: unknown-lib@1.0.0 (UNKNOWN)" in output
    assert "Summary: 1 approved, 1 denied, 1 unknown" in output
