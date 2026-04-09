"""
Dependency License Checker - TDD Test Suite

Red/Green TDD methodology:
1. Write a failing test
2. Write minimum code to make it pass
3. Refactor
4. Repeat

Tests use mocked license lookups so no real network calls are needed.
"""

import json
import pytest
from unittest.mock import patch, MagicMock

# ============================================================
# RED PHASE 1: Parse package.json
# These tests are written BEFORE the implementation exists.
# ============================================================

def test_parse_package_json_basic():
    """Parse package.json and extract production dependencies only."""
    from license_checker import parse_package_json
    manifest = {
        "name": "my-app",
        "dependencies": {
            "express": "^4.18.0",
            "lodash": "~4.17.21",
        },
        "devDependencies": {
            "jest": "^29.0.0",
        },
    }
    result = parse_package_json(manifest)
    assert result == [
        {"name": "express", "version": "^4.18.0"},
        {"name": "lodash", "version": "~4.17.21"},
    ]


def test_parse_package_json_no_dependencies():
    """Package.json with no dependencies returns empty list."""
    from license_checker import parse_package_json
    result = parse_package_json({"name": "empty-app"})
    assert result == []


def test_parse_package_json_empty_dependencies():
    """Package.json with empty dependencies dict returns empty list."""
    from license_checker import parse_package_json
    result = parse_package_json({"name": "empty-app", "dependencies": {}})
    assert result == []


# ============================================================
# RED PHASE 2: Parse requirements.txt
# ============================================================

def test_parse_requirements_txt_basic():
    """Parse requirements.txt with pinned and range versions."""
    from license_checker import parse_requirements_txt
    content = "requests==2.31.0\nflask>=2.0,<3.0\nnumpy==1.24.0\n"
    result = parse_requirements_txt(content)
    assert result == [
        {"name": "requests", "version": "==2.31.0"},
        {"name": "flask", "version": ">=2.0,<3.0"},
        {"name": "numpy", "version": "==1.24.0"},
    ]


def test_parse_requirements_txt_skips_comments_and_blanks():
    """Requirements.txt parser ignores comments and blank lines."""
    from license_checker import parse_requirements_txt
    content = "# This is a comment\n\nrequests==2.31.0\n  # inline comment\nflask==3.0.0\n"
    result = parse_requirements_txt(content)
    assert result == [
        {"name": "requests", "version": "==2.31.0"},
        {"name": "flask", "version": "==3.0.0"},
    ]


def test_parse_requirements_txt_no_version():
    """Dependencies without version specifiers get '*' as version."""
    from license_checker import parse_requirements_txt
    content = "requests\nflask==3.0.0\n"
    result = parse_requirements_txt(content)
    assert result == [
        {"name": "requests", "version": "*"},
        {"name": "flask", "version": "==3.0.0"},
    ]


# ============================================================
# RED PHASE 3: License config loading
# ============================================================

def test_load_license_config_basic():
    """Load allow/deny list from a config dict."""
    from license_checker import load_license_config
    config_data = {
        "allow": ["MIT", "Apache-2.0", "BSD-3-Clause"],
        "deny": ["GPL-2.0", "GPL-3.0", "AGPL-3.0"],
    }
    config = load_license_config(config_data)
    assert config["allow"] == {"MIT", "Apache-2.0", "BSD-3-Clause"}
    assert config["deny"] == {"GPL-2.0", "GPL-3.0", "AGPL-3.0"}


def test_load_license_config_empty_lists():
    """Config with empty allow/deny lists is valid."""
    from license_checker import load_license_config
    config = load_license_config({"allow": [], "deny": []})
    assert config["allow"] == set()
    assert config["deny"] == set()


def test_load_license_config_missing_keys():
    """Config missing allow or deny defaults to empty set."""
    from license_checker import load_license_config
    config = load_license_config({"allow": ["MIT"]})
    assert config["allow"] == {"MIT"}
    assert config["deny"] == set()


# ============================================================
# RED PHASE 4: License status classification
# ============================================================

def test_classify_license_approved():
    """A license on the allow-list is 'approved'."""
    from license_checker import classify_license
    config = {"allow": {"MIT", "Apache-2.0"}, "deny": {"GPL-3.0"}}
    assert classify_license("MIT", config) == "approved"
    assert classify_license("Apache-2.0", config) == "approved"


def test_classify_license_denied():
    """A license on the deny-list is 'denied'."""
    from license_checker import classify_license
    config = {"allow": {"MIT"}, "deny": {"GPL-3.0", "AGPL-3.0"}}
    assert classify_license("GPL-3.0", config) == "denied"
    assert classify_license("AGPL-3.0", config) == "denied"


def test_classify_license_unknown():
    """A license on neither list is 'unknown'."""
    from license_checker import classify_license
    config = {"allow": {"MIT"}, "deny": {"GPL-3.0"}}
    assert classify_license("LGPL-2.1", config) == "unknown"


def test_classify_license_none_is_unknown():
    """None license (lookup failed) is 'unknown'."""
    from license_checker import classify_license
    config = {"allow": {"MIT"}, "deny": {"GPL-3.0"}}
    assert classify_license(None, config) == "unknown"


def test_classify_deny_takes_priority_over_allow():
    """If a license is on both lists, deny takes priority."""
    from license_checker import classify_license
    config = {"allow": {"MIT", "GPL-3.0"}, "deny": {"GPL-3.0"}}
    assert classify_license("GPL-3.0", config) == "denied"


# ============================================================
# RED PHASE 5: Mocked license lookup
# ============================================================

MOCK_LICENSE_DB = {
    "express": "MIT",
    "lodash": "MIT",
    "gpl-package": "GPL-3.0",
    "unknown-package": None,
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "gpl-lib": "GPL-2.0",
    "numpy": "BSD-3-Clause",
}


def test_mock_lookup_known_package():
    """Mock lookup returns correct license for known packages."""
    from license_checker import mock_license_lookup
    assert mock_license_lookup("express", MOCK_LICENSE_DB) == "MIT"
    assert mock_license_lookup("requests", MOCK_LICENSE_DB) == "Apache-2.0"


def test_mock_lookup_unknown_package():
    """Mock lookup returns None for packages not in the mock DB."""
    from license_checker import mock_license_lookup
    assert mock_license_lookup("some-random-package", MOCK_LICENSE_DB) is None


def test_mock_lookup_explicit_none():
    """Mock lookup returns None when package is in DB with None value."""
    from license_checker import mock_license_lookup
    assert mock_license_lookup("unknown-package", MOCK_LICENSE_DB) is None


# ============================================================
# RED PHASE 6: Full compliance report generation
# ============================================================

def test_generate_report_all_statuses():
    """Generate report correctly classifies approved, denied, and unknown."""
    from license_checker import generate_report

    deps = [
        {"name": "express", "version": "4.18.0"},
        {"name": "gpl-package", "version": "1.0.0"},
        {"name": "unknown-package", "version": "2.0.0"},
    ]
    config = {
        "allow": {"MIT", "Apache-2.0"},
        "deny": {"GPL-3.0", "GPL-2.0"},
    }

    def mock_lookup(name):
        return MOCK_LICENSE_DB.get(name)

    report = generate_report(deps, mock_lookup, config)

    assert report["summary"]["total"] == 3
    assert report["summary"]["approved"] == 1
    assert report["summary"]["denied"] == 1
    assert report["summary"]["unknown"] == 1

    by_name = {r["name"]: r for r in report["results"]}
    assert by_name["express"]["license"] == "MIT"
    assert by_name["express"]["status"] == "approved"
    assert by_name["gpl-package"]["license"] == "GPL-3.0"
    assert by_name["gpl-package"]["status"] == "denied"
    assert by_name["unknown-package"]["license"] is None
    assert by_name["unknown-package"]["status"] == "unknown"


def test_generate_report_all_approved():
    """Report summary shows 0 denied and 0 unknown when all pass."""
    from license_checker import generate_report

    deps = [
        {"name": "express", "version": "4.18.0"},
        {"name": "lodash", "version": "4.17.21"},
    ]
    config = {"allow": {"MIT"}, "deny": {"GPL-3.0"}}

    def mock_lookup(name):
        return MOCK_LICENSE_DB.get(name)

    report = generate_report(deps, mock_lookup, config)
    assert report["summary"]["total"] == 2
    assert report["summary"]["approved"] == 2
    assert report["summary"]["denied"] == 0
    assert report["summary"]["unknown"] == 0


def test_generate_report_empty_deps():
    """Report for empty dependency list has zero counts."""
    from license_checker import generate_report
    config = {"allow": {"MIT"}, "deny": {"GPL-3.0"}}
    report = generate_report([], lambda name: None, config)
    assert report["summary"]["total"] == 0
    assert report["results"] == []


# ============================================================
# RED PHASE 7: Auto-detect manifest format
# ============================================================

def test_detect_manifest_package_json(tmp_path):
    """Auto-detect package.json format from file extension."""
    from license_checker import parse_manifest
    manifest_file = tmp_path / "package.json"
    manifest_file.write_text(json.dumps({
        "name": "test",
        "dependencies": {"express": "4.18.0"}
    }))
    deps = parse_manifest(str(manifest_file))
    assert deps == [{"name": "express", "version": "4.18.0"}]


def test_detect_manifest_requirements_txt(tmp_path):
    """Auto-detect requirements.txt format from file extension."""
    from license_checker import parse_manifest
    manifest_file = tmp_path / "requirements.txt"
    manifest_file.write_text("flask==3.0.0\nrequests==2.31.0\n")
    deps = parse_manifest(str(manifest_file))
    assert deps == [
        {"name": "flask", "version": "==3.0.0"},
        {"name": "requests", "version": "==2.31.0"},
    ]


def test_detect_manifest_unknown_format(tmp_path):
    """Unknown manifest format raises ValueError."""
    from license_checker import parse_manifest
    manifest_file = tmp_path / "Gemfile"
    manifest_file.write_text("gem 'rails'")
    with pytest.raises(ValueError, match="Unsupported manifest format"):
        parse_manifest(str(manifest_file))


def test_detect_manifest_file_not_found():
    """Missing manifest file raises FileNotFoundError."""
    from license_checker import parse_manifest
    with pytest.raises(FileNotFoundError):
        parse_manifest("/nonexistent/path/package.json")


# ============================================================
# RED PHASE 8: Report formatting (text output for CI)
# ============================================================

def test_format_report_text():
    """Text report format shows status for each dependency."""
    from license_checker import format_report_text
    report = {
        "summary": {"total": 3, "approved": 1, "denied": 1, "unknown": 1},
        "results": [
            {"name": "express", "version": "4.18.0", "license": "MIT", "status": "approved"},
            {"name": "gpl-package", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "unknown-package", "version": "2.0.0", "license": None, "status": "unknown"},
        ],
    }
    text = format_report_text(report)
    assert "express@4.18.0" in text
    assert "MIT" in text
    assert "approved" in text
    assert "gpl-package@1.0.0" in text
    assert "GPL-3.0" in text
    assert "denied" in text
    assert "unknown-package@2.0.0" in text
    assert "unknown" in text
    # Summary line
    assert "Total: 3" in text
    assert "Approved: 1" in text
    assert "Denied: 1" in text
    assert "Unknown: 1" in text


def test_format_report_contains_compliance_status():
    """Text report indicates overall compliance pass/fail."""
    from license_checker import format_report_text
    passing_report = {
        "summary": {"total": 2, "approved": 2, "denied": 0, "unknown": 0},
        "results": [
            {"name": "express", "version": "4.18.0", "license": "MIT", "status": "approved"},
            {"name": "lodash", "version": "4.17.21", "license": "MIT", "status": "approved"},
        ],
    }
    text = format_report_text(passing_report)
    assert "COMPLIANT" in text

    failing_report = {
        "summary": {"total": 2, "approved": 1, "denied": 1, "unknown": 0},
        "results": [
            {"name": "express", "version": "4.18.0", "license": "MIT", "status": "approved"},
            {"name": "gpl-package", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
        ],
    }
    text = format_report_text(failing_report)
    assert "NON-COMPLIANT" in text
