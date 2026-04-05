"""
Dependency License Checker - Test Suite

TDD methodology: each test was written FIRST (red), then the minimal code
to make it pass was added (green), then refactored. Tests are organized by
the TDD cycle in which they were introduced.

We use Python's built-in unittest (no external dependencies needed) and
mock the license lookup to keep tests fast and deterministic.
"""
import unittest
import json
import os
import tempfile
from unittest.mock import MagicMock

from license_checker import (
    parse_manifest,
    check_license,
    generate_report,
    LicenseConfig,
    ComplianceReport,
    DependencyInfo,
)


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 1: Parse package.json to extract dependencies
# RED:  wrote tests below; no parse_manifest function existed
# GREEN: implemented parse_manifest to read JSON and extract deps
# ═══════════════════════════════════════════════════════════════════════

class TestParsePackageJson(unittest.TestCase):
    """Parse package.json files and extract dependency name/version pairs."""

    def _write_temp(self, content: str, suffix: str = "package.json") -> str:
        """Helper: write content to a temp file, return its path."""
        f = tempfile.NamedTemporaryFile(mode="w", suffix=suffix, delete=False)
        f.write(content)
        f.close()
        return f.name

    def test_extracts_dependencies_and_devdependencies(self):
        """Both dependencies and devDependencies should be extracted."""
        path = self._write_temp(json.dumps({
            "name": "my-app",
            "dependencies": {
                "express": "^4.18.0",
                "lodash": "~4.17.21",
            },
            "devDependencies": {
                "jest": "^29.0.0",
            },
        }))
        try:
            result = parse_manifest(path)
            self.assertEqual(result, [
                DependencyInfo(name="express", version="^4.18.0"),
                DependencyInfo(name="lodash", version="~4.17.21"),
                DependencyInfo(name="jest", version="^29.0.0"),
            ])
        finally:
            os.unlink(path)

    def test_empty_package_json_returns_empty_list(self):
        """No dependencies key at all → empty list, no crash."""
        path = self._write_temp(json.dumps({"name": "bare", "version": "1.0.0"}))
        try:
            self.assertEqual(parse_manifest(path), [])
        finally:
            os.unlink(path)

    def test_only_regular_dependencies(self):
        """Should work when devDependencies is absent."""
        path = self._write_temp(json.dumps({
            "dependencies": {"react": "^18.2.0"},
        }))
        try:
            self.assertEqual(parse_manifest(path), [
                DependencyInfo(name="react", version="^18.2.0"),
            ])
        finally:
            os.unlink(path)

    def test_file_not_found_raises(self):
        """A missing file should raise FileNotFoundError with a clear message."""
        with self.assertRaises(FileNotFoundError) as ctx:
            parse_manifest("/nonexistent/package.json")
        self.assertIn("not found", str(ctx.exception).lower())

    def test_invalid_json_raises(self):
        """Malformed JSON should raise ValueError with a helpful message."""
        path = self._write_temp("{not valid json!!!")
        try:
            with self.assertRaises(ValueError) as ctx:
                parse_manifest(path)
            self.assertIn("parse", str(ctx.exception).lower())
        finally:
            os.unlink(path)


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 2: Parse requirements.txt
# RED:  wrote tests; parse_manifest only handled JSON
# GREEN: added requirements.txt detection and line parsing
# ═══════════════════════════════════════════════════════════════════════

class TestParseRequirementsTxt(unittest.TestCase):
    """Parse requirements.txt files (pip format)."""

    def _write_temp(self, content: str, suffix: str = "requirements.txt") -> str:
        f = tempfile.NamedTemporaryFile(mode="w", suffix=suffix, delete=False)
        f.write(content)
        f.close()
        return f.name

    def test_extracts_pinned_versions(self):
        path = self._write_temp("requests==2.31.0\nflask==3.0.0\n")
        try:
            result = parse_manifest(path)
            self.assertEqual(result, [
                DependencyInfo(name="requests", version="==2.31.0"),
                DependencyInfo(name="flask", version="==3.0.0"),
            ])
        finally:
            os.unlink(path)

    def test_extracts_range_versions(self):
        path = self._write_temp("numpy>=1.24,<2.0\npandas~=2.0.0\n")
        try:
            result = parse_manifest(path)
            self.assertEqual(result, [
                DependencyInfo(name="numpy", version=">=1.24,<2.0"),
                DependencyInfo(name="pandas", version="~=2.0.0"),
            ])
        finally:
            os.unlink(path)

    def test_skips_comments_and_blanks(self):
        path = self._write_temp("# this is a comment\n\nrequests==2.31.0\n  \n")
        try:
            result = parse_manifest(path)
            self.assertEqual(result, [
                DependencyInfo(name="requests", version="==2.31.0"),
            ])
        finally:
            os.unlink(path)

    def test_handles_no_version_specifier(self):
        """A bare package name (no ==/>=/etc.) gets version '*'."""
        path = self._write_temp("requests\n")
        try:
            result = parse_manifest(path)
            self.assertEqual(result, [
                DependencyInfo(name="requests", version="*"),
            ])
        finally:
            os.unlink(path)

    def test_skips_option_lines(self):
        """Lines starting with - (like -e, --index-url) should be skipped."""
        path = self._write_temp(
            "--index-url https://pypi.org/simple\n"
            "-e git+https://example.com#egg=foo\n"
            "requests==2.31.0\n"
        )
        try:
            result = parse_manifest(path)
            self.assertEqual(result, [
                DependencyInfo(name="requests", version="==2.31.0"),
            ])
        finally:
            os.unlink(path)


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 3: License configuration (allow-list / deny-list)
# RED:  wrote tests; LicenseConfig didn't exist
# GREEN: implemented LicenseConfig dataclass with validation
# ═══════════════════════════════════════════════════════════════════════

class TestLicenseConfig(unittest.TestCase):
    """LicenseConfig holds allow/deny lists and classifies licenses."""

    def test_create_config_with_allow_and_deny(self):
        config = LicenseConfig(
            allowed=["MIT", "Apache-2.0", "BSD-3-Clause"],
            denied=["GPL-3.0", "AGPL-3.0"],
        )
        self.assertEqual(config.allowed, ["MIT", "Apache-2.0", "BSD-3-Clause"])
        self.assertEqual(config.denied, ["GPL-3.0", "AGPL-3.0"])

    def test_classify_allowed_license(self):
        config = LicenseConfig(allowed=["MIT"], denied=["GPL-3.0"])
        self.assertEqual(config.classify("MIT"), "approved")

    def test_classify_denied_license(self):
        config = LicenseConfig(allowed=["MIT"], denied=["GPL-3.0"])
        self.assertEqual(config.classify("GPL-3.0"), "denied")

    def test_classify_unknown_license(self):
        """A license on neither list should be 'unknown'."""
        config = LicenseConfig(allowed=["MIT"], denied=["GPL-3.0"])
        self.assertEqual(config.classify("WTFPL"), "unknown")

    def test_classify_is_case_insensitive(self):
        config = LicenseConfig(allowed=["MIT"], denied=["GPL-3.0"])
        self.assertEqual(config.classify("mit"), "approved")
        self.assertEqual(config.classify("gpl-3.0"), "denied")

    def test_empty_lists_means_all_unknown(self):
        config = LicenseConfig(allowed=[], denied=[])
        self.assertEqual(config.classify("MIT"), "unknown")

    def test_from_dict(self):
        """LicenseConfig.from_dict should parse a plain dict (e.g. from JSON)."""
        data = {
            "allowed": ["MIT", "Apache-2.0"],
            "denied": ["GPL-3.0"],
        }
        config = LicenseConfig.from_dict(data)
        self.assertEqual(config.allowed, ["MIT", "Apache-2.0"])
        self.assertEqual(config.denied, ["GPL-3.0"])

    def test_from_dict_defaults_to_empty(self):
        config = LicenseConfig.from_dict({})
        self.assertEqual(config.allowed, [])
        self.assertEqual(config.denied, [])


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 4: Check a single dependency's license (with mock lookup)
# RED:  wrote tests; check_license didn't exist
# GREEN: implemented check_license accepting a lookup callable
# ═══════════════════════════════════════════════════════════════════════

class TestCheckLicense(unittest.TestCase):
    """check_license looks up a dep's license and classifies it."""

    def setUp(self):
        self.config = LicenseConfig(
            allowed=["MIT", "Apache-2.0"],
            denied=["GPL-3.0"],
        )
        # Mock lookup: returns a known license for the dependency name
        self.mock_lookup = MagicMock(side_effect=lambda name, version: {
            "express": "MIT",
            "lodash": "MIT",
            "leftpad": "GPL-3.0",
            "obscure-lib": "WTFPL",
        }.get(name))

    def test_approved_dependency(self):
        dep = DependencyInfo(name="express", version="^4.18.0")
        result = check_license(dep, self.config, self.mock_lookup)
        self.assertEqual(result["name"], "express")
        self.assertEqual(result["version"], "^4.18.0")
        self.assertEqual(result["license"], "MIT")
        self.assertEqual(result["status"], "approved")

    def test_denied_dependency(self):
        dep = DependencyInfo(name="leftpad", version="1.0.0")
        result = check_license(dep, self.config, self.mock_lookup)
        self.assertEqual(result["license"], "GPL-3.0")
        self.assertEqual(result["status"], "denied")

    def test_unknown_license(self):
        dep = DependencyInfo(name="obscure-lib", version="0.1.0")
        result = check_license(dep, self.config, self.mock_lookup)
        self.assertEqual(result["license"], "WTFPL")
        self.assertEqual(result["status"], "unknown")

    def test_lookup_returns_none(self):
        """When the lookup can't find license info, status should be 'unknown'."""
        dep = DependencyInfo(name="mystery-pkg", version="1.0.0")
        result = check_license(dep, self.config, self.mock_lookup)
        self.assertIsNone(result["license"])
        self.assertEqual(result["status"], "unknown")

    def test_lookup_raises_error_gracefully(self):
        """If the lookup function throws, we handle it gracefully."""
        failing_lookup = MagicMock(side_effect=Exception("network error"))
        dep = DependencyInfo(name="express", version="^4.18.0")
        result = check_license(dep, self.config, failing_lookup)
        self.assertIsNone(result["license"])
        self.assertEqual(result["status"], "unknown")
        self.assertIn("network error", result.get("error", ""))


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 5: Generate a full compliance report
# RED:  wrote tests; generate_report didn't exist
# GREEN: implemented generate_report orchestrating parse → check → report
# ═══════════════════════════════════════════════════════════════════════

class TestGenerateReport(unittest.TestCase):
    """generate_report ties everything together into a ComplianceReport."""

    def setUp(self):
        self.config = LicenseConfig(
            allowed=["MIT", "Apache-2.0", "BSD-3-Clause"],
            denied=["GPL-3.0", "AGPL-3.0"],
        )
        # Deterministic mock lookup
        self.license_db = {
            "express": "MIT",
            "lodash": "MIT",
            "leftpad": "GPL-3.0",
            "unknown-pkg": None,
        }
        self.mock_lookup = MagicMock(
            side_effect=lambda name, version: self.license_db.get(name)
        )

    def _make_manifest(self, deps: dict) -> str:
        """Helper: write a package.json to a temp file, return path."""
        f = tempfile.NamedTemporaryFile(
            mode="w", suffix="package.json", delete=False
        )
        json.dump({"dependencies": deps}, f)
        f.close()
        return f.name

    def test_report_with_mixed_statuses(self):
        path = self._make_manifest({
            "express": "^4.18.0",
            "leftpad": "1.0.0",
            "unknown-pkg": "0.0.1",
        })
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            self.assertIsInstance(report, ComplianceReport)
            self.assertEqual(len(report.dependencies), 3)

            # Check summary counts
            self.assertEqual(report.summary["approved"], 1)
            self.assertEqual(report.summary["denied"], 1)
            self.assertEqual(report.summary["unknown"], 1)
            self.assertEqual(report.summary["total"], 3)
        finally:
            os.unlink(path)

    def test_report_all_approved(self):
        path = self._make_manifest({"express": "^4.18.0", "lodash": "^4.17.0"})
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            self.assertEqual(report.summary["approved"], 2)
            self.assertEqual(report.summary["denied"], 0)
            self.assertEqual(report.summary["unknown"], 0)
            self.assertTrue(report.is_compliant)
        finally:
            os.unlink(path)

    def test_report_not_compliant_when_denied_present(self):
        path = self._make_manifest({"leftpad": "1.0.0"})
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            self.assertFalse(report.is_compliant)
        finally:
            os.unlink(path)

    def test_report_not_compliant_when_unknown_present(self):
        """Unknown licenses should also flag as non-compliant (conservative)."""
        path = self._make_manifest({"unknown-pkg": "0.0.1"})
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            self.assertFalse(report.is_compliant)
        finally:
            os.unlink(path)

    def test_report_empty_manifest(self):
        path = self._make_manifest({})
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            self.assertEqual(report.summary["total"], 0)
            self.assertTrue(report.is_compliant)
        finally:
            os.unlink(path)

    def test_report_to_dict(self):
        """Report should be serializable to a dict (for JSON output)."""
        path = self._make_manifest({"express": "^4.18.0"})
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            d = report.to_dict()
            self.assertIn("dependencies", d)
            self.assertIn("summary", d)
            self.assertIn("is_compliant", d)
            self.assertEqual(d["is_compliant"], True)
        finally:
            os.unlink(path)

    def test_report_to_json_string(self):
        """Report should render as valid JSON."""
        path = self._make_manifest({"express": "^4.18.0"})
        try:
            report = generate_report(path, self.config, self.mock_lookup)
            json_str = report.to_json()
            parsed = json.loads(json_str)
            self.assertEqual(parsed["summary"]["total"], 1)
        finally:
            os.unlink(path)


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 6: Built-in mock license lookup for testing/demo purposes
# RED:  wrote tests; mock_license_lookup didn't exist
# GREEN: added a default mock lookup with realistic data
# ═══════════════════════════════════════════════════════════════════════

class TestMockLicenseLookup(unittest.TestCase):
    """The built-in mock lookup returns realistic license data."""

    def test_known_packages_return_licenses(self):
        from license_checker import mock_license_lookup

        self.assertEqual(mock_license_lookup("express", "^4.18.0"), "MIT")
        self.assertEqual(mock_license_lookup("react", "^18.0.0"), "MIT")
        self.assertEqual(mock_license_lookup("flask", "3.0.0"), "BSD-3-Clause")
        self.assertEqual(mock_license_lookup("requests", "2.31.0"), "Apache-2.0")

    def test_unknown_package_returns_none(self):
        from license_checker import mock_license_lookup

        self.assertIsNone(mock_license_lookup("totally-unknown-pkg", "1.0.0"))

    def test_gpl_packages(self):
        from license_checker import mock_license_lookup

        self.assertEqual(mock_license_lookup("readline", "1.0.0"), "GPL-3.0")


# ═══════════════════════════════════════════════════════════════════════
# TDD Cycle 7: End-to-end integration using config file
# RED:  wrote tests; no config file loading existed
# GREEN: added load_config + full integration path
# ═══════════════════════════════════════════════════════════════════════

class TestEndToEnd(unittest.TestCase):
    """Full integration: config file + manifest → compliance report."""

    def test_full_pipeline_package_json(self):
        from license_checker import load_config, mock_license_lookup

        # Write a config file
        config_data = {
            "allowed": ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC"],
            "denied": ["GPL-3.0", "AGPL-3.0"],
        }
        config_file = tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        )
        json.dump(config_data, config_file)
        config_file.close()

        # Write a package.json manifest
        manifest_data = {
            "dependencies": {
                "express": "^4.18.0",
                "lodash": "^4.17.21",
            },
            "devDependencies": {
                "jest": "^29.0.0",
            },
        }
        manifest_file = tempfile.NamedTemporaryFile(
            mode="w", suffix="package.json", delete=False
        )
        json.dump(manifest_data, manifest_file)
        manifest_file.close()

        try:
            config = load_config(config_file.name)
            report = generate_report(
                manifest_file.name, config, mock_license_lookup
            )

            self.assertEqual(report.summary["total"], 3)
            # express=MIT (approved), lodash=MIT (approved), jest=MIT (approved)
            self.assertEqual(report.summary["approved"], 3)
            self.assertTrue(report.is_compliant)
        finally:
            os.unlink(config_file.name)
            os.unlink(manifest_file.name)

    def test_full_pipeline_requirements_txt(self):
        from license_checker import load_config, mock_license_lookup

        config = LicenseConfig(
            allowed=["MIT", "Apache-2.0", "BSD-3-Clause"],
            denied=["GPL-3.0"],
        )

        manifest = tempfile.NamedTemporaryFile(
            mode="w", suffix="requirements.txt", delete=False
        )
        manifest.write("requests==2.31.0\nflask==3.0.0\nreadline==1.0.0\n")
        manifest.close()

        try:
            report = generate_report(manifest.name, config, mock_license_lookup)
            self.assertEqual(report.summary["total"], 3)
            # requests=Apache-2.0 (approved), flask=BSD-3-Clause (approved),
            # readline=GPL-3.0 (denied)
            self.assertEqual(report.summary["approved"], 2)
            self.assertEqual(report.summary["denied"], 1)
            self.assertFalse(report.is_compliant)
        finally:
            os.unlink(manifest.name)

    def test_config_file_not_found(self):
        from license_checker import load_config

        with self.assertRaises(FileNotFoundError):
            load_config("/nonexistent/config.json")

    def test_config_file_invalid_json(self):
        from license_checker import load_config

        f = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        f.write("{invalid json")
        f.close()
        try:
            with self.assertRaises(ValueError):
                load_config(f.name)
        finally:
            os.unlink(f.name)


if __name__ == "__main__":
    unittest.main()
