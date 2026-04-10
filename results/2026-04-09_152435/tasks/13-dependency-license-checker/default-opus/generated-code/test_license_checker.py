"""
Tests for the dependency license checker.
Written test-first following red/green TDD methodology.

Each test group was written before the corresponding implementation,
starting with the simplest functionality and building up.
"""
import json
import os
import pytest
import tempfile

# TDD Step 1: Import the module (will fail until module exists)
from license_checker import (
    parse_package_json,
    parse_requirements_txt,
    parse_manifest,
    load_config,
    check_compliance,
    generate_report,
)


# --- Test fixtures ---

SAMPLE_PACKAGE_JSON = {
    "name": "my-app",
    "version": "1.0.0",
    "dependencies": {
        "express": "^4.18.2",
        "lodash": "4.17.21",
    },
    "devDependencies": {
        "jest": "^29.0.0",
    },
}

SAMPLE_REQUIREMENTS_TXT = """# A comment line
requests==2.31.0
flask>=2.3.0
numpy
# Another comment
pandas==2.0.3
"""

SAMPLE_CONFIG = {
    "allowed_licenses": ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC"],
    "denied_licenses": ["GPL-3.0", "AGPL-3.0", "SSPL-1.0"],
}


# --- Mock license lookup function ---

def mock_license_lookup(name, version):
    """Mock that returns known licenses for test dependencies."""
    licenses = {
        "express": "MIT",
        "lodash": "MIT",
        "jest": "MIT",
        "requests": "Apache-2.0",
        "flask": "BSD-3-Clause",
        "numpy": "BSD-3-Clause",
        "pandas": "BSD-3-Clause",
    }
    return licenses.get(name)


def mock_license_lookup_mixed(name, version):
    """Mock that returns a mix of allowed, denied, and unknown licenses."""
    licenses = {
        "express": "MIT",        # allowed
        "lodash": "GPL-3.0",     # denied
        "jest": "Unlicense",     # unknown (not in allow or deny list)
    }
    return licenses.get(name)


def mock_license_lookup_with_unknown(name, version):
    """Mock where some deps have no license info at all."""
    licenses = {
        "express": "MIT",
        "lodash": None,  # no license info found
    }
    return licenses.get(name)


# --- TDD Round 1: Manifest Parsing ---

class TestParsePackageJson:
    """Test parsing of package.json files."""

    def test_extracts_dependencies(self, tmp_path):
        """Should extract both dependencies and devDependencies."""
        pkg_file = tmp_path / "package.json"
        pkg_file.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_package_json(str(pkg_file))

        assert len(deps) == 3
        names = {d["name"] for d in deps}
        assert names == {"express", "lodash", "jest"}

    def test_extracts_versions(self, tmp_path):
        """Should capture version strings as-is."""
        pkg_file = tmp_path / "package.json"
        pkg_file.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_package_json(str(pkg_file))
        by_name = {d["name"]: d["version"] for d in deps}

        assert by_name["express"] == "^4.18.2"
        assert by_name["lodash"] == "4.17.21"
        assert by_name["jest"] == "^29.0.0"

    def test_handles_no_dependencies(self, tmp_path):
        """Should return empty list if no dependencies present."""
        pkg_file = tmp_path / "package.json"
        pkg_file.write_text(json.dumps({"name": "empty", "version": "1.0.0"}))

        deps = parse_package_json(str(pkg_file))
        assert deps == []

    def test_handles_only_dependencies(self, tmp_path):
        """Should work when only dependencies (no devDependencies) exist."""
        pkg_file = tmp_path / "package.json"
        pkg_file.write_text(json.dumps({
            "name": "app",
            "dependencies": {"express": "4.0.0"},
        }))

        deps = parse_package_json(str(pkg_file))
        assert len(deps) == 1
        assert deps[0]["name"] == "express"


class TestParseRequirementsTxt:
    """Test parsing of requirements.txt files."""

    def test_extracts_dependencies(self, tmp_path):
        """Should extract all non-comment, non-blank lines."""
        req_file = tmp_path / "requirements.txt"
        req_file.write_text(SAMPLE_REQUIREMENTS_TXT)

        deps = parse_requirements_txt(str(req_file))

        names = {d["name"] for d in deps}
        assert names == {"requests", "flask", "numpy", "pandas"}

    def test_extracts_versions(self, tmp_path):
        """Should capture version constraints correctly."""
        req_file = tmp_path / "requirements.txt"
        req_file.write_text(SAMPLE_REQUIREMENTS_TXT)

        deps = parse_requirements_txt(str(req_file))
        by_name = {d["name"]: d["version"] for d in deps}

        assert by_name["requests"] == "2.31.0"
        assert by_name["flask"] == "2.3.0"
        assert by_name["numpy"] == "unknown"
        assert by_name["pandas"] == "2.0.3"

    def test_skips_comments_and_blanks(self, tmp_path):
        """Should ignore comment lines and blank lines."""
        req_file = tmp_path / "requirements.txt"
        req_file.write_text("# comment\n\n  \nrequests==1.0\n")

        deps = parse_requirements_txt(str(req_file))
        assert len(deps) == 1
        assert deps[0]["name"] == "requests"

    def test_handles_empty_file(self, tmp_path):
        """Should return empty list for empty file."""
        req_file = tmp_path / "requirements.txt"
        req_file.write_text("")

        deps = parse_requirements_txt(str(req_file))
        assert deps == []


class TestParseManifest:
    """Test the unified parse_manifest dispatcher."""

    def test_dispatches_package_json(self, tmp_path):
        """Should detect package.json by filename."""
        pkg_file = tmp_path / "package.json"
        pkg_file.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_manifest(str(pkg_file))
        assert len(deps) == 3

    def test_dispatches_requirements_txt(self, tmp_path):
        """Should detect requirements.txt by filename."""
        req_file = tmp_path / "requirements.txt"
        req_file.write_text(SAMPLE_REQUIREMENTS_TXT)

        deps = parse_manifest(str(req_file))
        assert len(deps) == 4

    def test_unsupported_manifest_raises(self, tmp_path):
        """Should raise ValueError for unsupported manifest types."""
        other = tmp_path / "Gemfile"
        other.write_text("gem 'rails'")

        with pytest.raises(ValueError, match="Unsupported manifest"):
            parse_manifest(str(other))

    def test_missing_file_raises(self):
        """Should raise FileNotFoundError for non-existent files."""
        with pytest.raises(FileNotFoundError):
            parse_manifest("/nonexistent/package.json")


# --- TDD Round 2: Config and Compliance ---

class TestLoadConfig:
    """Test loading license configuration."""

    def test_loads_valid_config(self, tmp_path):
        """Should load and return config with allowed/denied lists."""
        cfg_file = tmp_path / "config.json"
        cfg_file.write_text(json.dumps(SAMPLE_CONFIG))

        config = load_config(str(cfg_file))

        assert "MIT" in config["allowed_licenses"]
        assert "GPL-3.0" in config["denied_licenses"]

    def test_missing_config_raises(self):
        """Should raise FileNotFoundError for missing config."""
        with pytest.raises(FileNotFoundError):
            load_config("/nonexistent/config.json")

    def test_invalid_json_raises(self, tmp_path):
        """Should raise ValueError for malformed JSON."""
        cfg_file = tmp_path / "config.json"
        cfg_file.write_text("not json {{{")

        with pytest.raises(ValueError, match="Invalid JSON"):
            load_config(str(cfg_file))


class TestCheckCompliance:
    """Test license compliance checking logic."""

    def test_all_approved(self):
        """All deps with allowed licenses should be 'approved'."""
        deps = [
            {"name": "express", "version": "4.18.2"},
            {"name": "lodash", "version": "4.17.21"},
        ]
        results = check_compliance(deps, SAMPLE_CONFIG, mock_license_lookup)

        for r in results:
            assert r["status"] == "approved"

    def test_denied_license_detected(self):
        """Deps with denied licenses should be 'denied'."""
        deps = [
            {"name": "express", "version": "4.18.2"},
            {"name": "lodash", "version": "4.17.21"},
            {"name": "jest", "version": "29.0.0"},
        ]
        results = check_compliance(deps, SAMPLE_CONFIG, mock_license_lookup_mixed)

        by_name = {r["name"]: r for r in results}
        assert by_name["express"]["status"] == "approved"
        assert by_name["lodash"]["status"] == "denied"
        assert by_name["jest"]["status"] == "unknown"

    def test_unknown_license(self):
        """Deps with licenses not in either list should be 'unknown'."""
        deps = [{"name": "jest", "version": "29.0.0"}]
        results = check_compliance(deps, SAMPLE_CONFIG, mock_license_lookup_mixed)

        assert results[0]["status"] == "unknown"
        assert results[0]["license"] == "Unlicense"

    def test_no_license_info(self):
        """Deps where lookup returns None should be 'unknown'."""
        deps = [{"name": "lodash", "version": "4.17.21"}]
        results = check_compliance(deps, SAMPLE_CONFIG, mock_license_lookup_with_unknown)

        assert results[0]["status"] == "unknown"
        assert results[0]["license"] is None

    def test_preserves_dep_info(self):
        """Results should carry forward name and version from deps."""
        deps = [{"name": "express", "version": "4.18.2"}]
        results = check_compliance(deps, SAMPLE_CONFIG, mock_license_lookup)

        assert results[0]["name"] == "express"
        assert results[0]["version"] == "4.18.2"
        assert results[0]["license"] == "MIT"

    def test_empty_deps(self):
        """Should return empty list for empty deps."""
        results = check_compliance([], SAMPLE_CONFIG, mock_license_lookup)
        assert results == []


# --- TDD Round 3: Report Generation ---

class TestGenerateReport:
    """Test compliance report generation."""

    def test_report_contains_header(self):
        """Report should have a clear header."""
        results = [
            {"name": "express", "version": "4.18.2", "license": "MIT", "status": "approved"},
        ]
        report = generate_report(results)
        assert "Dependency License Compliance Report" in report

    def test_report_lists_each_dep(self):
        """Report should mention every dependency."""
        results = [
            {"name": "express", "version": "4.18.2", "license": "MIT", "status": "approved"},
            {"name": "lodash", "version": "4.17.21", "license": "GPL-3.0", "status": "denied"},
        ]
        report = generate_report(results)
        assert "express" in report
        assert "lodash" in report

    def test_report_shows_status(self):
        """Report should show APPROVED, DENIED, UNKNOWN status labels."""
        results = [
            {"name": "a", "version": "1.0", "license": "MIT", "status": "approved"},
            {"name": "b", "version": "1.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "c", "version": "1.0", "license": None, "status": "unknown"},
        ]
        report = generate_report(results)
        assert "APPROVED" in report
        assert "DENIED" in report
        assert "UNKNOWN" in report

    def test_report_summary_counts(self):
        """Report should include summary with counts."""
        results = [
            {"name": "a", "version": "1.0", "license": "MIT", "status": "approved"},
            {"name": "b", "version": "1.0", "license": "MIT", "status": "approved"},
            {"name": "c", "version": "1.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "d", "version": "1.0", "license": None, "status": "unknown"},
        ]
        report = generate_report(results)
        assert "Approved: 2" in report
        assert "Denied: 1" in report
        assert "Unknown: 1" in report

    def test_report_empty_results(self):
        """Report for empty results should still have a header and zero counts."""
        report = generate_report([])
        assert "Dependency License Compliance Report" in report
        assert "Approved: 0" in report

    def test_report_exit_code_denied(self):
        """Should indicate failure when denied deps exist."""
        results = [
            {"name": "b", "version": "1.0", "license": "GPL-3.0", "status": "denied"},
        ]
        report = generate_report(results)
        assert "FAIL" in report

    def test_report_exit_code_clean(self):
        """Should indicate pass when no denied deps exist."""
        results = [
            {"name": "a", "version": "1.0", "license": "MIT", "status": "approved"},
        ]
        report = generate_report(results)
        assert "PASS" in report
