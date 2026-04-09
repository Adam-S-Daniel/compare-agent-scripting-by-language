"""
Tests for the dependency license checker.
Written using red/green TDD: each test was written before the implementation.
All tests run through the GitHub Actions workflow via act.
"""

import json
import pytest
from license_checker import parse_manifest, lookup_licenses, check_compliance, generate_report


# --- TDD Cycle 1: Parse package.json ---

class TestParsePackageJson:
    """Test parsing of package.json manifest files."""

    def test_parse_package_json_extracts_dependencies(self, tmp_path):
        """Should extract dependency names and versions from package.json."""
        manifest = tmp_path / "package.json"
        manifest.write_text(json.dumps({
            "name": "test-project",
            "dependencies": {
                "express": "^4.18.0",
                "lodash": "~4.17.21"
            },
            "devDependencies": {
                "jest": "^29.0.0"
            }
        }))
        result = parse_manifest(str(manifest))
        assert result == [
            {"name": "express", "version": "^4.18.0"},
            {"name": "lodash", "version": "~4.17.21"},
            {"name": "jest", "version": "^29.0.0"},
        ]

    def test_parse_package_json_no_dev_deps(self, tmp_path):
        """Should handle package.json with no devDependencies."""
        manifest = tmp_path / "package.json"
        manifest.write_text(json.dumps({
            "name": "test-project",
            "dependencies": {"express": "^4.18.0"}
        }))
        result = parse_manifest(str(manifest))
        assert result == [{"name": "express", "version": "^4.18.0"}]

    def test_parse_package_json_empty_deps(self, tmp_path):
        """Should return empty list when no dependencies exist."""
        manifest = tmp_path / "package.json"
        manifest.write_text(json.dumps({"name": "test-project"}))
        result = parse_manifest(str(manifest))
        assert result == []


# --- TDD Cycle 2: Parse requirements.txt ---

class TestParseRequirementsTxt:
    """Test parsing of requirements.txt manifest files."""

    def test_parse_requirements_with_pinned_versions(self, tmp_path):
        """Should extract pinned dependencies from requirements.txt."""
        manifest = tmp_path / "requirements.txt"
        manifest.write_text("flask==2.3.0\nrequests==2.31.0\n")
        result = parse_manifest(str(manifest))
        assert result == [
            {"name": "flask", "version": "==2.3.0"},
            {"name": "requests", "version": "==2.31.0"},
        ]

    def test_parse_requirements_with_various_specifiers(self, tmp_path):
        """Should handle >=, ~=, and bare names."""
        manifest = tmp_path / "requirements.txt"
        manifest.write_text("django>=4.0\nnumpy~=1.24\npandas\n")
        result = parse_manifest(str(manifest))
        assert result == [
            {"name": "django", "version": ">=4.0"},
            {"name": "numpy", "version": "~=1.24"},
            {"name": "pandas", "version": "*"},
        ]

    def test_parse_requirements_ignores_comments_and_blanks(self, tmp_path):
        """Should skip comment lines and blank lines."""
        manifest = tmp_path / "requirements.txt"
        manifest.write_text("# this is a comment\nflask==2.3.0\n\n# another comment\nrequests==2.31.0\n")
        result = parse_manifest(str(manifest))
        assert result == [
            {"name": "flask", "version": "==2.3.0"},
            {"name": "requests", "version": "==2.31.0"},
        ]


# --- TDD Cycle 3: License lookup with mock resolver ---

class TestLookupLicenses:
    """Test license resolution using a mock resolver function."""

    def test_lookup_returns_licenses_from_resolver(self):
        """Should call the resolver for each dep and attach the license."""
        deps = [
            {"name": "express", "version": "^4.18.0"},
            {"name": "lodash", "version": "~4.17.21"},
        ]
        mock_resolver = lambda name, version: {"express": "MIT", "lodash": "MIT"}[name]

        result = lookup_licenses(deps, license_resolver=mock_resolver)
        assert result == [
            {"name": "express", "version": "^4.18.0", "license": "MIT"},
            {"name": "lodash", "version": "~4.17.21", "license": "MIT"},
        ]

    def test_lookup_unknown_when_resolver_returns_none(self):
        """Should use 'Unknown' when the resolver returns None."""
        deps = [{"name": "mystery-pkg", "version": "1.0.0"}]
        mock_resolver = lambda name, version: None

        result = lookup_licenses(deps, license_resolver=mock_resolver)
        assert result == [
            {"name": "mystery-pkg", "version": "1.0.0", "license": "Unknown"},
        ]

    def test_lookup_unknown_when_no_resolver(self):
        """Should default all licenses to 'Unknown' when no resolver provided."""
        deps = [{"name": "flask", "version": "==2.3.0"}]
        result = lookup_licenses(deps)
        assert result == [
            {"name": "flask", "version": "==2.3.0", "license": "Unknown"},
        ]


# --- TDD Cycle 4: Compliance checking against allow/deny lists ---

class TestCheckCompliance:
    """Test checking dependency licenses against allow/deny configuration."""

    def test_approved_license_on_allow_list(self):
        """License on the allow list should be marked 'approved'."""
        deps = [{"name": "express", "version": "^4.18.0", "license": "MIT"}]
        config = {"allowed_licenses": ["MIT", "Apache-2.0"], "denied_licenses": ["GPL-3.0"]}
        result = check_compliance(deps, config)
        assert result[0]["status"] == "approved"

    def test_denied_license_on_deny_list(self):
        """License on the deny list should be marked 'denied'."""
        deps = [{"name": "gpl-pkg", "version": "1.0.0", "license": "GPL-3.0"}]
        config = {"allowed_licenses": ["MIT"], "denied_licenses": ["GPL-3.0"]}
        result = check_compliance(deps, config)
        assert result[0]["status"] == "denied"

    def test_unknown_license_not_on_either_list(self):
        """License not on either list should be marked 'unknown'."""
        deps = [{"name": "obscure-pkg", "version": "1.0.0", "license": "WTFPL"}]
        config = {"allowed_licenses": ["MIT"], "denied_licenses": ["GPL-3.0"]}
        result = check_compliance(deps, config)
        assert result[0]["status"] == "unknown"

    def test_unknown_license_string(self):
        """Dep with 'Unknown' license (unresolved) should be marked 'unknown'."""
        deps = [{"name": "mystery", "version": "1.0.0", "license": "Unknown"}]
        config = {"allowed_licenses": ["MIT"], "denied_licenses": ["GPL-3.0"]}
        result = check_compliance(deps, config)
        assert result[0]["status"] == "unknown"

    def test_deny_list_takes_precedence(self):
        """If a license appears on both lists, deny takes precedence."""
        deps = [{"name": "tricky", "version": "1.0.0", "license": "GPL-3.0"}]
        config = {"allowed_licenses": ["GPL-3.0"], "denied_licenses": ["GPL-3.0"]}
        result = check_compliance(deps, config)
        assert result[0]["status"] == "denied"

    def test_multiple_deps_mixed_statuses(self):
        """Should correctly classify a mix of approved, denied, unknown deps."""
        deps = [
            {"name": "express", "version": "^4.18.0", "license": "MIT"},
            {"name": "gpl-pkg", "version": "1.0.0", "license": "GPL-3.0"},
            {"name": "obscure", "version": "2.0.0", "license": "WTFPL"},
        ]
        config = {"allowed_licenses": ["MIT", "Apache-2.0"], "denied_licenses": ["GPL-3.0"]}
        result = check_compliance(deps, config)
        assert result[0]["status"] == "approved"
        assert result[1]["status"] == "denied"
        assert result[2]["status"] == "unknown"


# --- TDD Cycle 5: Report generation ---

class TestGenerateReport:
    """Test compliance report generation."""

    def test_report_contains_header(self):
        """Report should start with a header line."""
        results = []
        report = generate_report(results)
        assert "Dependency License Compliance Report" in report

    def test_report_lists_each_dependency(self):
        """Report should list each dependency with its license and status."""
        results = [
            {"name": "express", "version": "^4.18.0", "license": "MIT", "status": "approved"},
            {"name": "gpl-pkg", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
        ]
        report = generate_report(results)
        assert "express" in report
        assert "MIT" in report
        assert "APPROVED" in report
        assert "gpl-pkg" in report
        assert "GPL-3.0" in report
        assert "DENIED" in report

    def test_report_shows_summary_counts(self):
        """Report should include summary counts of approved/denied/unknown."""
        results = [
            {"name": "a", "version": "1.0", "license": "MIT", "status": "approved"},
            {"name": "b", "version": "1.0", "license": "MIT", "status": "approved"},
            {"name": "c", "version": "1.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "d", "version": "1.0", "license": "Unknown", "status": "unknown"},
        ]
        report = generate_report(results)
        assert "Approved: 2" in report
        assert "Denied: 1" in report
        assert "Unknown: 1" in report
        assert "Total: 4" in report

    def test_report_shows_pass_when_no_denied(self):
        """Report should indicate PASS when no denied dependencies."""
        results = [
            {"name": "a", "version": "1.0", "license": "MIT", "status": "approved"},
        ]
        report = generate_report(results)
        assert "PASS" in report

    def test_report_shows_fail_when_denied_present(self):
        """Report should indicate FAIL when any denied dependency exists."""
        results = [
            {"name": "a", "version": "1.0", "license": "GPL-3.0", "status": "denied"},
        ]
        report = generate_report(results)
        assert "FAIL" in report


# --- TDD Cycle 6: Error handling ---

class TestErrorHandling:
    """Test graceful error handling for bad input."""

    def test_parse_nonexistent_file(self):
        """Should raise FileNotFoundError for missing files."""
        with pytest.raises(FileNotFoundError, match="Manifest file not found"):
            parse_manifest("/nonexistent/package.json")

    def test_parse_unsupported_format(self, tmp_path):
        """Should raise ValueError for unsupported manifest formats."""
        manifest = tmp_path / "Gemfile"
        manifest.write_text("source 'https://rubygems.org'\n")
        with pytest.raises(ValueError, match="Unsupported manifest format"):
            parse_manifest(str(manifest))

    def test_parse_malformed_json(self, tmp_path):
        """Should raise ValueError for invalid JSON in package.json."""
        manifest = tmp_path / "package.json"
        manifest.write_text("{not valid json}")
        with pytest.raises(ValueError, match="Invalid JSON"):
            parse_manifest(str(manifest))

    def test_load_config_missing_file(self):
        """Should raise FileNotFoundError for missing config."""
        from license_checker import load_config
        with pytest.raises(FileNotFoundError, match="Config file not found"):
            load_config("/nonexistent/config.json")

    def test_load_config_valid(self, tmp_path):
        """Should load and return config dict from valid JSON."""
        from license_checker import load_config
        cfg = tmp_path / "config.json"
        cfg.write_text(json.dumps({"allowed_licenses": ["MIT"], "denied_licenses": ["GPL-3.0"]}))
        result = load_config(str(cfg))
        assert result["allowed_licenses"] == ["MIT"]
        assert result["denied_licenses"] == ["GPL-3.0"]
