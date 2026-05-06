"""
Test suite for dependency license checker using red/green TDD.

Each test starts as failing (red), then implementation is added to make it pass (green).
"""

import pytest
import json
import tempfile
from pathlib import Path
from dependency_license_checker import (
    Dependency,
    LicenseConfig,
    LicenseLookup,
    ManifestParser,
    ComplianceChecker,
)


class TestDependencyModel:
    """Test the Dependency data class."""

    def test_dependency_creation(self):
        """RED: Test that we can create a Dependency object."""
        dep = Dependency(name="lodash", version="4.17.21")
        assert dep.name == "lodash"
        assert dep.version == "4.17.21"


class TestLicenseConfig:
    """Test the LicenseConfig data class."""

    def test_license_config_creation(self):
        """RED: Test that we can create a LicenseConfig object."""
        config = LicenseConfig(
            allow_list=["MIT", "Apache-2.0"],
            deny_list=["GPL-3.0"]
        )
        assert config.allow_list == ["MIT", "Apache-2.0"]
        assert config.deny_list == ["GPL-3.0"]


class TestLicenseLookup:
    """Test the mock license lookup service."""

    def test_empty_license_lookup(self):
        """RED: Test license lookup with no data returns None."""
        lookup = LicenseLookup()
        assert lookup.get_license("express", "4.18.2") is None

    def test_license_lookup_with_data(self):
        """RED: Test license lookup with mock data returns license."""
        license_map = {
            "express": "MIT",
            "lodash": "MIT"
        }
        lookup = LicenseLookup(license_map)
        assert lookup.get_license("express", "4.18.2") == "MIT"
        assert lookup.get_license("lodash", "4.17.21") == "MIT"

    def test_license_lookup_missing_dependency(self):
        """RED: Test license lookup for unknown dependency returns None."""
        license_map = {"express": "MIT"}
        lookup = LicenseLookup(license_map)
        assert lookup.get_license("unknown-package", "1.0.0") is None


class TestManifestParserPackageJson:
    """Test parsing of package.json manifests."""

    def test_parse_package_json_basic(self):
        """RED: Test basic parsing of package.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "package.json"
            manifest_file.write_text(json.dumps({
                "name": "test-app",
                "dependencies": {
                    "express": "4.18.2"
                }
            }))

            deps = ManifestParser.parse_package_json(manifest_file)
            assert len(deps) == 1
            assert deps[0].name == "express"
            assert deps[0].version == "4.18.2"

    def test_parse_package_json_with_dev_dependencies(self):
        """RED: Test parsing package.json with dev dependencies."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "package.json"
            manifest_file.write_text(json.dumps({
                "name": "test-app",
                "dependencies": {
                    "express": "4.18.2",
                    "lodash": "4.17.21"
                },
                "devDependencies": {
                    "jest": "29.5.0"
                }
            }))

            deps = ManifestParser.parse_package_json(manifest_file)
            assert len(deps) == 3
            names = {d.name for d in deps}
            assert names == {"express", "lodash", "jest"}

    def test_parse_package_json_file_not_found(self):
        """RED: Test that missing file raises ValueError."""
        with pytest.raises(ValueError, match="File not found"):
            ManifestParser.parse_package_json(Path("/nonexistent/package.json"))

    def test_parse_package_json_invalid_json(self):
        """RED: Test that invalid JSON raises ValueError."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "package.json"
            manifest_file.write_text("{invalid json}")

            with pytest.raises(ValueError, match="Invalid JSON"):
                ManifestParser.parse_package_json(manifest_file)


class TestManifestParserRequirementsTxt:
    """Test parsing of requirements.txt manifests."""

    def test_parse_requirements_txt_basic(self):
        """RED: Test basic parsing of requirements.txt."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "requirements.txt"
            manifest_file.write_text("requests==2.28.2\ndjango>=4.0\n")

            deps = ManifestParser.parse_requirements_txt(manifest_file)
            assert len(deps) == 2
            assert deps[0].name == "requests"
            assert deps[0].version == "2.28.2"
            assert deps[1].name == "django"
            assert deps[1].version == "4.0"

    def test_parse_requirements_txt_with_comments(self):
        """RED: Test that comments are ignored."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "requirements.txt"
            manifest_file.write_text(
                "# This is a comment\n"
                "requests==2.28.2\n"
                "# Another comment\n"
                "flask~=2.2.0\n"
            )

            deps = ManifestParser.parse_requirements_txt(manifest_file)
            assert len(deps) == 2
            assert deps[0].name == "requests"
            assert deps[1].name == "flask"

    def test_parse_requirements_txt_empty_lines(self):
        """RED: Test that empty lines are skipped."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "requirements.txt"
            manifest_file.write_text(
                "requests==2.28.2\n"
                "\n"
                "django>=4.0\n"
            )

            deps = ManifestParser.parse_requirements_txt(manifest_file)
            assert len(deps) == 2

    def test_parse_requirements_txt_various_operators(self):
        """RED: Test parsing with different version operators."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_file = Path(tmpdir) / "requirements.txt"
            manifest_file.write_text(
                "package1==1.0.0\n"
                "package2>=2.0.0\n"
                "package3<=3.0.0\n"
                "package4~=4.0.0\n"
            )

            deps = ManifestParser.parse_requirements_txt(manifest_file)
            assert len(deps) == 4
            assert deps[0].version == "1.0.0"
            assert deps[1].version == "2.0.0"
            assert deps[2].version == "3.0.0"
            assert deps[3].version == "4.0.0"

    def test_parse_requirements_txt_file_not_found(self):
        """RED: Test that missing file raises ValueError."""
        with pytest.raises(ValueError, match="File not found"):
            ManifestParser.parse_requirements_txt(Path("/nonexistent/requirements.txt"))


class TestComplianceChecker:
    """Test the compliance checking logic."""

    def test_check_approved_dependency(self):
        """RED: Test that approved licenses are correctly identified."""
        config = LicenseConfig(
            allow_list=["MIT", "Apache-2.0"],
            deny_list=["GPL-3.0"]
        )
        lookup = LicenseLookup({"express": "MIT"})
        checker = ComplianceChecker(config, lookup)

        dep = Dependency(name="express", version="4.18.2")
        status, license_name = checker.check_dependency(dep)

        assert status == "approved"
        assert license_name == "MIT"

    def test_check_denied_dependency(self):
        """RED: Test that denied licenses are correctly identified."""
        config = LicenseConfig(
            allow_list=["MIT"],
            deny_list=["GPL-3.0"]
        )
        lookup = LicenseLookup({"gpl-package": "GPL-3.0"})
        checker = ComplianceChecker(config, lookup)

        dep = Dependency(name="gpl-package", version="1.0.0")
        status, license_name = checker.check_dependency(dep)

        assert status == "denied"
        assert license_name == "GPL-3.0"

    def test_check_unknown_dependency(self):
        """RED: Test that unknown licenses are correctly identified."""
        config = LicenseConfig(
            allow_list=["MIT"],
            deny_list=["GPL-3.0"]
        )
        lookup = LicenseLookup({"unknown": "Proprietary"})
        checker = ComplianceChecker(config, lookup)

        dep = Dependency(name="unknown", version="1.0.0")
        status, license_name = checker.check_dependency(dep)

        assert status == "unknown"
        assert license_name == "Proprietary"

    def test_check_missing_license_info(self):
        """RED: Test that missing license info returns unknown."""
        config = LicenseConfig(
            allow_list=["MIT"],
            deny_list=[]
        )
        lookup = LicenseLookup({})
        checker = ComplianceChecker(config, lookup)

        dep = Dependency(name="no-license", version="1.0.0")
        status, license_name = checker.check_dependency(dep)

        assert status == "unknown"
        assert license_name is None


class TestComplianceReport:
    """Test report generation."""

    def test_generate_report_basic(self):
        """RED: Test basic report generation."""
        config = LicenseConfig(
            allow_list=["MIT"],
            deny_list=["GPL-3.0"]
        )
        license_map = {
            "express": "MIT",
            "gpl-package": "GPL-3.0"
        }
        lookup = LicenseLookup(license_map)
        checker = ComplianceChecker(config, lookup)

        dependencies = [
            Dependency(name="express", version="4.18.2"),
            Dependency(name="gpl-package", version="1.0.0"),
            Dependency(name="unknown", version="1.0.0")
        ]

        report = checker.generate_report(dependencies)

        assert "Dependency License Compliance Report" in report
        assert "APPROVED" in report
        assert "DENIED" in report
        assert "UNKNOWN" in report
        assert "express" in report
        assert "gpl-package" in report
        assert "unknown" in report

    def test_generate_report_has_summary(self):
        """RED: Test that report includes summary counts."""
        config = LicenseConfig(
            allow_list=["MIT"],
            deny_list=[]
        )
        license_map = {"express": "MIT"}
        lookup = LicenseLookup(license_map)
        checker = ComplianceChecker(config, lookup)

        dependencies = [
            Dependency(name="express", version="4.18.2")
        ]

        report = checker.generate_report(dependencies)

        assert "SUMMARY" in report
        assert "Total approved:" in report
        assert "Total denied:" in report
        assert "Total unknown:" in report

    def test_generate_report_correct_counts(self):
        """RED: Test that report shows correct category counts."""
        config = LicenseConfig(
            allow_list=["MIT"],
            deny_list=["GPL-3.0"]
        )
        license_map = {
            "pkg1": "MIT",
            "pkg2": "GPL-3.0",
            "pkg3": "Unknown-License"
        }
        lookup = LicenseLookup(license_map)
        checker = ComplianceChecker(config, lookup)

        dependencies = [
            Dependency(name="pkg1", version="1.0.0"),
            Dependency(name="pkg2", version="1.0.0"),
            Dependency(name="pkg3", version="1.0.0")
        ]

        report = checker.generate_report(dependencies)

        # Parse counts from report
        assert "APPROVED (1)" in report
        assert "DENIED (1)" in report
        assert "UNKNOWN (1)" in report


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
