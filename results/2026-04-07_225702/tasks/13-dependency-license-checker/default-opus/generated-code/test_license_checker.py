# Test suite for dependency license checker.
# Using red/green TDD: each test is written to fail first, then made to pass.

import pytest
import json
from license_checker import (
    parse_manifest, LicenseLookup, LicenseConfig,
    check_compliance, generate_report, load_config, main,
)


# --- Cycle 1: Parse package.json ---

class TestParsePackageJson:
    """Parse a package.json file and extract dependency name/version pairs."""

    def test_extracts_dependencies(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({
            "name": "my-app",
            "dependencies": {
                "express": "^4.18.0",
                "lodash": "~4.17.21"
            }
        }))
        deps = parse_manifest(str(pkg))
        assert deps == [
            {"name": "express", "version": "^4.18.0"},
            {"name": "lodash", "version": "~4.17.21"},
        ]

    def test_includes_dev_dependencies(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({
            "dependencies": {"react": "18.2.0"},
            "devDependencies": {"jest": "^29.0.0"}
        }))
        deps = parse_manifest(str(pkg))
        names = [d["name"] for d in deps]
        assert "react" in names
        assert "jest" in names

    def test_empty_dependencies(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "empty"}))
        deps = parse_manifest(str(pkg))
        assert deps == []


# --- Cycle 2: Parse requirements.txt ---

class TestParseRequirementsTxt:
    """Parse a requirements.txt and extract dependency name/version pairs."""

    def test_pinned_versions(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("requests==2.31.0\nflask==3.0.0\n")
        deps = parse_manifest(str(req))
        assert deps == [
            {"name": "requests", "version": "2.31.0"},
            {"name": "flask", "version": "3.0.0"},
        ]

    def test_various_specifiers(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("numpy>=1.24\nscipy~=1.11.0\npandas\n")
        deps = parse_manifest(str(req))
        assert deps == [
            {"name": "numpy", "version": ">=1.24"},
            {"name": "scipy", "version": "~=1.11.0"},
            {"name": "pandas", "version": "*"},
        ]

    def test_skips_comments_and_blanks(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("# comment\n\nrequests==2.0\n  # indented comment\n")
        deps = parse_manifest(str(req))
        assert len(deps) == 1
        assert deps[0]["name"] == "requests"


# --- Cycle 3: Error handling ---

class TestManifestErrors:
    """Graceful errors for missing files, bad JSON, unsupported formats."""

    def test_file_not_found(self):
        with pytest.raises(FileNotFoundError, match="Manifest not found"):
            parse_manifest("/nonexistent/package.json")

    def test_invalid_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text("{bad json")
        with pytest.raises(ValueError, match="Invalid JSON"):
            parse_manifest(str(pkg))

    def test_unsupported_format(self, tmp_path):
        f = tmp_path / "Gemfile"
        f.write_text("gem 'rails'")
        with pytest.raises(ValueError, match="Unsupported manifest format"):
            parse_manifest(str(f))


# --- Cycle 4: License lookup (mocked) ---

class TestLicenseLookup:
    """LicenseLookup returns a license string for a given package name.
    We use a mock registry so tests don't hit the network."""

    def test_known_package(self):
        mock_registry = {
            "express": "MIT",
            "lodash": "MIT",
            "react": "MIT",
        }
        lookup = LicenseLookup(registry=mock_registry)
        assert lookup.get_license("express") == "MIT"

    def test_unknown_package_returns_none(self):
        lookup = LicenseLookup(registry={})
        assert lookup.get_license("unknown-pkg") is None

    def test_case_insensitive_lookup(self):
        lookup = LicenseLookup(registry={"Flask": "BSD-3-Clause"})
        assert lookup.get_license("flask") == "BSD-3-Clause"


# --- Cycle 5: Compliance checking against allow/deny lists ---

class TestCheckCompliance:
    """check_compliance classifies each dependency as approved/denied/unknown
    based on the license config allow-list and deny-list."""

    def setup_method(self):
        """Shared mock registry and config for compliance tests."""
        self.registry = {
            "express": "MIT",
            "lodash": "MIT",
            "evil-lib": "GPL-3.0",
            "mystery": "WTFPL",
        }
        self.lookup = LicenseLookup(registry=self.registry)
        self.config = LicenseConfig(
            allowed=["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"],
            denied=["GPL-3.0", "AGPL-3.0"],
        )

    def test_approved_dependency(self):
        deps = [{"name": "express", "version": "^4.18.0"}]
        report = check_compliance(deps, self.lookup, self.config)
        assert report[0]["status"] == "approved"
        assert report[0]["license"] == "MIT"

    def test_denied_dependency(self):
        deps = [{"name": "evil-lib", "version": "1.0.0"}]
        report = check_compliance(deps, self.lookup, self.config)
        assert report[0]["status"] == "denied"
        assert report[0]["license"] == "GPL-3.0"

    def test_unknown_license_not_in_registry(self):
        """Package not found in registry at all -> unknown."""
        deps = [{"name": "no-such-pkg", "version": "0.0.1"}]
        report = check_compliance(deps, self.lookup, self.config)
        assert report[0]["status"] == "unknown"
        assert report[0]["license"] is None

    def test_unknown_license_not_in_allow_or_deny(self):
        """License found but not in allow-list or deny-list -> unknown."""
        deps = [{"name": "mystery", "version": "1.0.0"}]
        report = check_compliance(deps, self.lookup, self.config)
        assert report[0]["status"] == "unknown"
        assert report[0]["license"] == "WTFPL"

    def test_multiple_dependencies(self):
        deps = [
            {"name": "express", "version": "^4.18.0"},
            {"name": "evil-lib", "version": "1.0.0"},
            {"name": "no-such-pkg", "version": "0.0.1"},
        ]
        report = check_compliance(deps, self.lookup, self.config)
        statuses = [r["status"] for r in report]
        assert statuses == ["approved", "denied", "unknown"]


# --- Cycle 6: Report generation ---

class TestGenerateReport:
    """generate_report produces a human-readable compliance report and
    a structured JSON output."""

    def test_text_report_contains_all_statuses(self):
        results = [
            {"name": "express", "version": "^4.18.0", "license": "MIT", "status": "approved"},
            {"name": "evil-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "mystery", "version": "2.0", "license": None, "status": "unknown"},
        ]
        text = generate_report(results, fmt="text")
        assert "express" in text
        assert "APPROVED" in text
        assert "DENIED" in text
        assert "UNKNOWN" in text

    def test_json_report_structure(self):
        results = [
            {"name": "express", "version": "^4.18.0", "license": "MIT", "status": "approved"},
        ]
        output = generate_report(results, fmt="json")
        data = json.loads(output)
        assert "dependencies" in data
        assert "summary" in data
        assert data["summary"]["approved"] == 1
        assert data["summary"]["denied"] == 0
        assert data["summary"]["unknown"] == 0

    def test_json_summary_counts(self):
        results = [
            {"name": "a", "version": "1", "license": "MIT", "status": "approved"},
            {"name": "b", "version": "1", "license": "MIT", "status": "approved"},
            {"name": "c", "version": "1", "license": "GPL-3.0", "status": "denied"},
            {"name": "d", "version": "1", "license": None, "status": "unknown"},
        ]
        data = json.loads(generate_report(results, fmt="json"))
        assert data["summary"]["total"] == 4
        assert data["summary"]["approved"] == 2
        assert data["summary"]["denied"] == 1
        assert data["summary"]["unknown"] == 1
        assert data["summary"]["compliant"] is False

    def test_compliant_when_no_denied(self):
        results = [
            {"name": "a", "version": "1", "license": "MIT", "status": "approved"},
        ]
        data = json.loads(generate_report(results, fmt="json"))
        assert data["summary"]["compliant"] is True


# --- Cycle 7: Config loading and end-to-end integration ---

class TestLoadConfig:
    """load_config reads a JSON config file with allowed/denied license lists."""

    def test_loads_config_from_json(self, tmp_path):
        cfg_file = tmp_path / "license-config.json"
        cfg_file.write_text(json.dumps({
            "allowed": ["MIT", "Apache-2.0"],
            "denied": ["GPL-3.0"],
        }))
        config = load_config(str(cfg_file))
        assert config.classify("MIT") == "approved"
        assert config.classify("GPL-3.0") == "denied"
        assert config.classify("ISC") == "unknown"

    def test_missing_config_file(self):
        with pytest.raises(FileNotFoundError, match="Config file not found"):
            load_config("/nonexistent/config.json")

    def test_invalid_config_json(self, tmp_path):
        cfg_file = tmp_path / "bad.json"
        cfg_file.write_text("not json")
        with pytest.raises(ValueError, match="Invalid JSON"):
            load_config(str(cfg_file))


class TestEndToEnd:
    """Full pipeline: manifest -> parse -> lookup -> check -> report."""

    def test_full_pipeline_package_json(self, tmp_path):
        # Set up a package.json
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({
            "dependencies": {
                "express": "^4.18.0",
                "left-pad": "1.0.0",
            },
            "devDependencies": {
                "gpl-tool": "2.0.0",
            }
        }))

        # Set up config
        cfg = tmp_path / "config.json"
        cfg.write_text(json.dumps({
            "allowed": ["MIT", "Apache-2.0"],
            "denied": ["GPL-3.0"],
        }))

        # Mock registry
        registry = {
            "express": "MIT",
            "left-pad": "MIT",
            "gpl-tool": "GPL-3.0",
        }

        # Run the pipeline
        deps = parse_manifest(str(pkg))
        config = load_config(str(cfg))
        lookup = LicenseLookup(registry=registry)
        results = check_compliance(deps, lookup, config)
        report_json = generate_report(results, fmt="json")
        report_text = generate_report(results, fmt="text")

        data = json.loads(report_json)
        assert data["summary"]["total"] == 3
        assert data["summary"]["approved"] == 2
        assert data["summary"]["denied"] == 1
        assert data["summary"]["compliant"] is False
        assert "gpl-tool" in report_text
        assert "DENIED" in report_text

    def test_full_pipeline_requirements_txt(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("flask==3.0.0\nrequests==2.31.0\nunknown-pkg==0.1\n")

        cfg = tmp_path / "config.json"
        cfg.write_text(json.dumps({
            "allowed": ["BSD-3-Clause", "Apache-2.0"],
            "denied": ["GPL-3.0"],
        }))

        registry = {
            "flask": "BSD-3-Clause",
            "requests": "Apache-2.0",
            # unknown-pkg not in registry
        }

        deps = parse_manifest(str(req))
        config = load_config(str(cfg))
        lookup = LicenseLookup(registry=registry)
        results = check_compliance(deps, lookup, config)
        data = json.loads(generate_report(results, fmt="json"))

        assert data["summary"]["total"] == 3
        assert data["summary"]["approved"] == 2
        assert data["summary"]["unknown"] == 1
        assert data["summary"]["compliant"] is True


# --- Cycle 8: CLI entry point ---

class TestCLI:
    """Test the main() CLI function."""

    def test_compliant_returns_zero(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"dependencies": {"express": "4.0"}}))
        cfg = tmp_path / "config.json"
        cfg.write_text(json.dumps({"allowed": ["MIT"], "denied": []}))
        reg = tmp_path / "registry.json"
        reg.write_text(json.dumps({"express": "MIT"}))

        rc = main([str(pkg), "--config", str(cfg), "--registry", str(reg)])
        assert rc == 0

    def test_non_compliant_returns_one(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"dependencies": {"bad": "1.0"}}))
        cfg = tmp_path / "config.json"
        cfg.write_text(json.dumps({"allowed": ["MIT"], "denied": ["GPL-3.0"]}))
        reg = tmp_path / "registry.json"
        reg.write_text(json.dumps({"bad": "GPL-3.0"}))

        rc = main([str(pkg), "--config", str(cfg), "--registry", str(reg)])
        assert rc == 1

    def test_error_returns_two(self, tmp_path):
        rc = main(["/nonexistent/package.json", "--config", "/nonexistent/cfg.json"])
        assert rc == 2
