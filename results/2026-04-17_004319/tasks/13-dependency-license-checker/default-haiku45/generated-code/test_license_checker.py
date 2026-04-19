"""
Red/Green TDD: Start with a failing test for parsing package.json.
This test defines the core behavior before any implementation exists.
"""

import json
import pytest
from pathlib import Path
from unittest.mock import Mock, patch
from license_checker import parse_manifest, check_licenses


def test_parse_package_json_extracts_dependencies():
    """FAILING TEST: Parse package.json and extract name+version."""
    manifest = {
        "name": "test-app",
        "version": "1.0.0",
        "dependencies": {
            "lodash": "^4.17.21",
            "express": "~4.18.2"
        }
    }

    deps = parse_manifest(manifest, manifest_type="package.json")

    assert len(deps) == 2
    assert deps[0] == {"name": "lodash", "version": "^4.17.21"}
    assert deps[1] == {"name": "express", "version": "~4.18.2"}


def test_parse_requirements_txt_extracts_dependencies():
    """FAILING TEST: Parse requirements.txt and extract name+version."""
    manifest_text = """
requests==2.28.0
flask>=2.0.0
numpy~=1.21.0
"""

    deps = parse_manifest(manifest_text, manifest_type="requirements.txt")

    assert len(deps) == 3
    assert deps[0] == {"name": "requests", "version": "2.28.0"}
    assert deps[1] == {"name": "flask", "version": ">=2.0.0"}
    assert deps[2] == {"name": "numpy", "version": "~=1.21.0"}


def test_check_licenses_against_allow_list():
    """FAILING TEST: Check dependencies against allow-list."""
    dependencies = [
        {"name": "lodash", "version": "4.17.21"},
        {"name": "express", "version": "4.18.2"}
    ]

    # Mock license lookup
    def mock_get_license(name, version):
        licenses = {
            "lodash": "MIT",
            "express": "MIT"
        }
        return licenses.get(name)

    config = {
        "allow_licenses": ["MIT", "Apache-2.0"],
        "deny_licenses": ["GPL-3.0"]
    }

    with patch('license_checker.get_license', side_effect=mock_get_license):
        report = check_licenses(dependencies, config)

    assert len(report) == 2
    assert report[0]["name"] == "lodash"
    assert report[0]["status"] == "approved"
    assert report[1]["name"] == "express"
    assert report[1]["status"] == "approved"


def test_check_licenses_against_deny_list():
    """FAILING TEST: Deny-list blocks GPL licenses."""
    dependencies = [{"name": "some-gpl-lib", "version": "1.0.0"}]

    def mock_get_license(name, version):
        return "GPL-3.0"

    config = {
        "allow_licenses": ["MIT"],
        "deny_licenses": ["GPL-3.0"]
    }

    with patch('license_checker.get_license', side_effect=mock_get_license):
        report = check_licenses(dependencies, config)

    assert report[0]["status"] == "denied"
    assert report[0]["reason"] == "GPL-3.0 in deny-list"


def test_check_licenses_unknown_license():
    """FAILING TEST: Unknown licenses should be marked as unknown."""
    dependencies = [{"name": "obscure-lib", "version": "1.0.0"}]

    def mock_get_license(name, version):
        return None

    config = {
        "allow_licenses": ["MIT"],
        "deny_licenses": []
    }

    with patch('license_checker.get_license', side_effect=mock_get_license):
        report = check_licenses(dependencies, config)

    assert report[0]["status"] == "unknown"
    assert "Could not determine license" in report[0]["reason"]


def test_generate_compliance_report():
    """FAILING TEST: Generate a formatted compliance report."""
    from license_checker import generate_report

    report = [
        {"name": "lodash", "version": "4.17.21", "status": "approved", "license": "MIT"},
        {"name": "gpl-lib", "version": "1.0.0", "status": "denied", "license": "GPL-3.0", "reason": "GPL-3.0 in deny-list"}
    ]

    formatted = generate_report(report)

    assert "lodash" in formatted
    assert "MIT" in formatted
    assert "approved" in formatted
    assert "gpl-lib" in formatted
    assert "denied" in formatted


def test_parse_empty_dependencies():
    """FAILING TEST: Handle manifest with no dependencies."""
    manifest = {"name": "test-app", "version": "1.0.0"}
    deps = parse_manifest(manifest, manifest_type="package.json")
    assert len(deps) == 0


def test_parse_requirements_with_comments():
    """FAILING TEST: Ignore comments in requirements.txt."""
    manifest_text = """
# This is a comment
requests==2.28.0
# Another comment
flask>=2.0.0
"""
    deps = parse_manifest(manifest_text, manifest_type="requirements.txt")
    assert len(deps) == 2
    assert deps[0]["name"] == "requests"
    assert deps[1]["name"] == "flask"


def test_mixed_licenses_in_report():
    """FAILING TEST: Report with mixed approved/denied/unknown."""
    dependencies = [
        {"name": "lodash", "version": "4.17.21"},
        {"name": "gpl-lib", "version": "1.0.0"},
        {"name": "unknown-lib", "version": "1.0.0"}
    ]

    def mock_get_license(name, version):
        licenses = {"lodash": "MIT", "gpl-lib": "GPL-3.0"}
        return licenses.get(name)

    config = {
        "allow_licenses": ["MIT", "Apache-2.0"],
        "deny_licenses": ["GPL-3.0"]
    }

    with patch('license_checker.get_license', side_effect=mock_get_license):
        report = check_licenses(dependencies, config)

    assert len(report) == 3
    assert sum(1 for r in report if r["status"] == "approved") == 1
    assert sum(1 for r in report if r["status"] == "denied") == 1
    assert sum(1 for r in report if r["status"] == "unknown") == 1


def test_error_handling_missing_manifest():
    """FAILING TEST: Handle missing manifest file gracefully."""
    import tempfile
    import os

    config = {
        "allow_licenses": ["MIT"],
        "deny_licenses": []
    }

    # Try to load non-existent file
    try:
        from license_checker import main
        main("/nonexistent/manifest.json", "/nonexistent/config.json")
        assert False, "Should have raised an error"
    except FileNotFoundError:
        pass  # Expected


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
