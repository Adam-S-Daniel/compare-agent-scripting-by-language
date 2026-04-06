"""
Dependency License Checker - TDD Tests
=======================================

Uses Python's standard-library unittest so no external packages are required.
Run with:  python3 -m unittest test_license_checker -v
       or: python3 test_license_checker.py

Approach:
- Red/Green TDD: write failing test, write minimum code to pass, refactor
- Mock license lookups so tests don't need network access
- Test fixtures use tempfile.TemporaryDirectory (no pytest needed)
- Coverage: manifest parsing, license classification, report generation, config loading
"""

import json
import tempfile
import unittest
from pathlib import Path

# The module under test — import all public API
from license_checker import (
    parse_package_json,
    parse_requirements_txt,
    check_license,
    generate_report,
    load_config,
    LicenseStatus,
)

# ---------------------------------------------------------------------------
# Shared test data
# ---------------------------------------------------------------------------

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

SAMPLE_REQUIREMENTS_TXT = """\
# Production dependencies
requests==2.31.0
flask==3.0.0
# Dev tools
pytest==7.4.0
"""

LICENSE_CONFIG = {
    "allow": ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
    "deny": ["GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1"],
}

# Mock license database keyed by package name → SPDX identifier (None = unknown)
MOCK_LICENSE_DB = {
    "express":     "MIT",
    "lodash":      "MIT",
    "jest":        "MIT",
    "requests":    "Apache-2.0",
    "flask":       "BSD-3-Clause",
    "pytest":      "MIT",
    "gpl-lib":     "GPL-3.0",
    "unknown-pkg": None,
}


def mock_lookup(package_name: str) -> str | None:
    """Simulated license registry — returns license SPDX ID or None."""
    return MOCK_LICENSE_DB.get(package_name)


# ---------------------------------------------------------------------------
# Helper: create a temp directory for each test
# ---------------------------------------------------------------------------

class _TmpDirMixin:
    """Mixin that gives each test its own TemporaryDirectory."""

    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self._tmpdir.name)

    def tearDown(self):
        self._tmpdir.cleanup()


# ===========================================================================
# RED → GREEN Test 1: parse_package_json
# ===========================================================================

class TestParsePackageJson(_TmpDirMixin, unittest.TestCase):
    """parse_package_json extracts {name: version} from a package.json file."""

    def _write_pkg(self, data: dict) -> Path:
        p = self.tmp_path / "package.json"
        p.write_text(json.dumps(data))
        return p

    def test_extracts_production_dependencies(self):
        """Should return {name: version} for all prod deps."""
        path = self._write_pkg(SAMPLE_PACKAGE_JSON)
        deps = parse_package_json(path)
        self.assertEqual(deps, {"express": "^4.18.2", "lodash": "4.17.21"})

    def test_ignores_dev_dependencies_by_default(self):
        """Dev deps should NOT appear when include_dev=False (the default)."""
        path = self._write_pkg(SAMPLE_PACKAGE_JSON)
        deps = parse_package_json(path)
        self.assertNotIn("jest", deps)

    def test_includes_dev_dependencies_when_requested(self):
        """With include_dev=True all deps should be returned."""
        path = self._write_pkg(SAMPLE_PACKAGE_JSON)
        deps = parse_package_json(path, include_dev=True)
        self.assertIn("jest", deps)
        self.assertEqual(deps["jest"], "^29.0.0")

    def test_handles_missing_file(self):
        """Missing file should raise FileNotFoundError with a clear message."""
        with self.assertRaises(FileNotFoundError) as ctx:
            parse_package_json(self.tmp_path / "nonexistent.json")
        self.assertIn("not found", str(ctx.exception))

    def test_handles_invalid_json(self):
        """Malformed JSON should raise ValueError with a clear message."""
        bad = self.tmp_path / "package.json"
        bad.write_text("{ not valid json }")
        with self.assertRaises(ValueError) as ctx:
            parse_package_json(bad)
        self.assertIn("Invalid JSON", str(ctx.exception))

    def test_handles_empty_dependencies(self):
        """package.json with no 'dependencies' key returns empty dict."""
        path = self._write_pkg({"name": "empty-pkg"})
        deps = parse_package_json(path)
        self.assertEqual(deps, {})


# ===========================================================================
# RED → GREEN Test 2: parse_requirements_txt
# ===========================================================================

class TestParseRequirementsTxt(_TmpDirMixin, unittest.TestCase):
    """parse_requirements_txt extracts {name: version} from requirements.txt."""

    def _write_req(self, content: str) -> Path:
        p = self.tmp_path / "requirements.txt"
        p.write_text(content)
        return p

    def test_extracts_pinned_versions(self):
        """Pinned (==) versions should be extracted as plain version strings."""
        path = self._write_req(SAMPLE_REQUIREMENTS_TXT)
        deps = parse_requirements_txt(path)
        self.assertEqual(deps["requests"], "2.31.0")
        self.assertEqual(deps["flask"],    "3.0.0")
        self.assertEqual(deps["pytest"],   "7.4.0")

    def test_skips_comments_and_blank_lines(self):
        """Lines starting with '#' and blank lines must be ignored."""
        path = self._write_req(SAMPLE_REQUIREMENTS_TXT)
        deps = parse_requirements_txt(path)
        for key in deps:
            self.assertFalse(key.startswith("#"))

    def test_handles_packages_without_version(self):
        """Packages listed without a version specifier should be included."""
        path = self._write_req("requests\nflask>=2.0\n")
        deps = parse_requirements_txt(path)
        self.assertIn("requests", deps)
        self.assertIn("flask", deps)

    def test_handles_missing_file(self):
        with self.assertRaises(FileNotFoundError) as ctx:
            parse_requirements_txt(self.tmp_path / "requirements.txt")
        self.assertIn("not found", str(ctx.exception))


# ===========================================================================
# RED → GREEN Test 3: check_license
# ===========================================================================

class TestCheckLicense(unittest.TestCase):
    """check_license classifies a single dependency license."""

    def test_approved_license(self):
        """MIT is in the allow-list → APPROVED."""
        result = check_license("express", "MIT", LICENSE_CONFIG)
        self.assertEqual(result, LicenseStatus.APPROVED)

    def test_denied_license(self):
        """GPL-3.0 is in the deny-list → DENIED."""
        result = check_license("gpl-lib", "GPL-3.0", LICENSE_CONFIG)
        self.assertEqual(result, LicenseStatus.DENIED)

    def test_unknown_license(self):
        """A license not in either list → UNKNOWN."""
        result = check_license("mystery-pkg", "Proprietary", LICENSE_CONFIG)
        self.assertEqual(result, LicenseStatus.UNKNOWN)

    def test_none_license_is_unknown(self):
        """No license info (None) → UNKNOWN."""
        result = check_license("unknown-pkg", None, LICENSE_CONFIG)
        self.assertEqual(result, LicenseStatus.UNKNOWN)

    def test_deny_takes_precedence_is_not_needed(self):
        """Sanity: a license that is only in deny → DENIED, not UNKNOWN."""
        result = check_license("pkg", "AGPL-3.0", LICENSE_CONFIG)
        self.assertEqual(result, LicenseStatus.DENIED)


# ===========================================================================
# RED → GREEN Test 4: generate_report
# ===========================================================================

class TestGenerateReport(unittest.TestCase):
    """generate_report builds the full compliance report via a mock lookup."""

    def test_report_contains_all_packages(self):
        deps = {"express": "^4.18.2", "lodash": "4.17.21"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        self.assertIn("express", report["results"])
        self.assertIn("lodash",  report["results"])

    def test_approved_package_entry(self):
        deps = {"express": "^4.18.2"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        entry = report["results"]["express"]
        self.assertEqual(entry["license"], "MIT")
        self.assertEqual(entry["status"],  LicenseStatus.APPROVED.value)

    def test_denied_package_entry(self):
        deps = {"gpl-lib": "1.0.0"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        entry = report["results"]["gpl-lib"]
        self.assertEqual(entry["license"], "GPL-3.0")
        self.assertEqual(entry["status"],  LicenseStatus.DENIED.value)

    def test_unknown_package_entry(self):
        deps = {"unknown-pkg": "0.1.0"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        entry = report["results"]["unknown-pkg"]
        self.assertIsNone(entry["license"])
        self.assertEqual(entry["status"], LicenseStatus.UNKNOWN.value)

    def test_report_summary_counts(self):
        """Summary section should correctly count each status bucket."""
        deps = {
            "express":     "^4.18.2",   # MIT        → APPROVED
            "gpl-lib":     "1.0.0",     # GPL-3.0    → DENIED
            "unknown-pkg": "0.1.0",     # None       → UNKNOWN
        }
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        summary = report["summary"]
        self.assertEqual(summary["approved"], 1)
        self.assertEqual(summary["denied"],   1)
        self.assertEqual(summary["unknown"],  1)
        self.assertEqual(summary["total"],    3)

    def test_passes_when_no_denied(self):
        """Overall pass when every package is APPROVED or UNKNOWN."""
        deps = {"express": "^4.18.2", "lodash": "4.17.21"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        self.assertTrue(report["passed"])

    def test_fails_when_denied_exists(self):
        """Overall fail when at least one package is DENIED."""
        deps = {"express": "^4.18.2", "gpl-lib": "1.0.0"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        self.assertFalse(report["passed"])

    def test_version_preserved_in_entry(self):
        """Each result entry should record the version from the manifest."""
        deps = {"express": "^4.18.2"}
        report = generate_report(deps, LICENSE_CONFIG, mock_lookup)
        self.assertEqual(report["results"]["express"]["version"], "^4.18.2")

    def test_empty_deps_gives_passing_report(self):
        """An empty manifest should produce a passing report with all zeros."""
        report = generate_report({}, LICENSE_CONFIG, mock_lookup)
        self.assertTrue(report["passed"])
        self.assertEqual(report["summary"]["total"], 0)


# ===========================================================================
# RED → GREEN Test 5: load_config
# ===========================================================================

class TestLoadConfig(_TmpDirMixin, unittest.TestCase):
    """load_config reads and validates the JSON config file."""

    def test_loads_valid_config(self):
        cfg = self.tmp_path / "license-config.json"
        cfg.write_text(json.dumps(LICENSE_CONFIG))
        config = load_config(cfg)
        self.assertEqual(config["allow"], LICENSE_CONFIG["allow"])
        self.assertEqual(config["deny"],  LICENSE_CONFIG["deny"])

    def test_missing_config_raises_file_not_found(self):
        with self.assertRaises(FileNotFoundError) as ctx:
            load_config(self.tmp_path / "missing.json")
        self.assertIn("not found", str(ctx.exception))

    def test_config_missing_deny_raises_value_error(self):
        """Config missing the 'deny' key should raise ValueError."""
        cfg = self.tmp_path / "bad-config.json"
        cfg.write_text(json.dumps({"allow": ["MIT"]}))
        with self.assertRaises(ValueError) as ctx:
            load_config(cfg)
        self.assertIn("'deny'", str(ctx.exception))

    def test_config_missing_allow_raises_value_error(self):
        """Config missing the 'allow' key should raise ValueError."""
        cfg = self.tmp_path / "bad-config2.json"
        cfg.write_text(json.dumps({"deny": ["GPL-3.0"]}))
        with self.assertRaises(ValueError) as ctx:
            load_config(cfg)
        self.assertIn("'allow'", str(ctx.exception))

    def test_invalid_json_raises_value_error(self):
        cfg = self.tmp_path / "bad.json"
        cfg.write_text("not json at all")
        with self.assertRaises(ValueError) as ctx:
            load_config(cfg)
        self.assertIn("Invalid JSON", str(ctx.exception))


# ===========================================================================
# Integration: end-to-end with a package.json fixture
# ===========================================================================

class TestIntegrationPackageJson(_TmpDirMixin, unittest.TestCase):
    """Full pipeline: parse package.json → generate compliance report."""

    def test_full_pipeline_package_json(self):
        # Write a package.json with a mix of approved, denied, and unknown deps
        manifest = self.tmp_path / "package.json"
        manifest.write_text(json.dumps({
            "name": "integration-app",
            "dependencies": {
                "express":     "^4.18.2",   # MIT     → APPROVED
                "gpl-lib":     "1.0.0",     # GPL-3.0 → DENIED
                "unknown-pkg": "0.1.0",     # None    → UNKNOWN
            },
        }))
        cfg = self.tmp_path / "config.json"
        cfg.write_text(json.dumps(LICENSE_CONFIG))

        deps   = parse_package_json(manifest)
        config = load_config(cfg)
        report = generate_report(deps, config, mock_lookup)

        self.assertFalse(report["passed"])
        self.assertEqual(report["summary"]["approved"], 1)
        self.assertEqual(report["summary"]["denied"],   1)
        self.assertEqual(report["summary"]["unknown"],  1)

    def test_full_pipeline_requirements_txt(self):
        # All packages in SAMPLE_REQUIREMENTS_TXT are MIT/Apache → all approved
        req = self.tmp_path / "requirements.txt"
        req.write_text(SAMPLE_REQUIREMENTS_TXT)
        cfg = self.tmp_path / "config.json"
        cfg.write_text(json.dumps(LICENSE_CONFIG))

        deps   = parse_requirements_txt(req)
        config = load_config(cfg)
        report = generate_report(deps, config, mock_lookup)

        self.assertTrue(report["passed"])
        self.assertEqual(report["summary"]["denied"], 0)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    unittest.main(verbosity=2)
