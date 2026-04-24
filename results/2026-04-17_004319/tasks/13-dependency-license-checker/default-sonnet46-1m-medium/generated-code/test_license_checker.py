# TDD: Tests written FIRST (RED phase). Each test group follows the cycle:
# 1. Write failing test
# 2. Implement minimum code to pass (GREEN)
# 3. Refactor
#
# The license_checker module is mocked at the lookup layer so no real
# network/pip calls are needed. All license lookups use MOCK_LICENSE_DB.

import json
import os
import subprocess
import sys
import tempfile
import shutil
import pytest
import yaml  # only used in workflow structure tests

# ── RED: import will fail until license_checker.py is created ─────────────────
import license_checker as lc


# ═══════════════════════════════════════════════════════════════════
# Group 1: Manifest parsing
# ═══════════════════════════════════════════════════════════════════

class TestParsePackageJson:
    """RED: written before parse_manifest() existed."""

    def test_parses_dependencies(self, tmp_path):
        manifest = {
            "name": "my-project",
            "dependencies": {"requests": "2.28.0", "flask": "2.3.0"},
        }
        p = tmp_path / "package.json"
        p.write_text(json.dumps(manifest))
        deps = lc.parse_manifest(str(p))
        assert deps == {"requests": "2.28.0", "flask": "2.3.0"}

    def test_parses_dev_dependencies(self, tmp_path):
        manifest = {
            "dependencies": {"requests": "2.28.0"},
            "devDependencies": {"pytest": "7.4.0"},
        }
        p = tmp_path / "package.json"
        p.write_text(json.dumps(manifest))
        deps = lc.parse_manifest(str(p))
        assert "requests" in deps
        assert "pytest" in deps

    def test_missing_file_raises(self):
        with pytest.raises(FileNotFoundError):
            lc.parse_manifest("/nonexistent/package.json")

    def test_invalid_json_raises(self, tmp_path):
        p = tmp_path / "package.json"
        p.write_text("{ not valid json }")
        with pytest.raises(ValueError, match="Invalid JSON"):
            lc.parse_manifest(str(p))


class TestParseRequirementsTxt:
    """RED: written before requirements.txt parsing existed."""

    def test_parses_pinned_versions(self, tmp_path):
        p = tmp_path / "requirements.txt"
        p.write_text("requests==2.28.0\nnumpy==1.24.0\n")
        deps = lc.parse_manifest(str(p))
        assert deps == {"requests": "2.28.0", "numpy": "1.24.0"}

    def test_parses_unpinned(self, tmp_path):
        p = tmp_path / "requirements.txt"
        p.write_text("flask\ndjango>=3.0\n")
        deps = lc.parse_manifest(str(p))
        assert "flask" in deps
        assert "django" in deps

    def test_skips_comments_and_blanks(self, tmp_path):
        p = tmp_path / "requirements.txt"
        p.write_text("# comment\n\nrequests==2.28.0\n")
        deps = lc.parse_manifest(str(p))
        assert deps == {"requests": "2.28.0"}

    def test_unsupported_format_raises(self, tmp_path):
        p = tmp_path / "Cargo.toml"
        p.write_text("[dependencies]\n")
        with pytest.raises(ValueError, match="Unsupported manifest"):
            lc.parse_manifest(str(p))


# ═══════════════════════════════════════════════════════════════════
# Group 2: Config loading
# ═══════════════════════════════════════════════════════════════════

class TestLoadConfig:
    """RED: written before load_config() existed."""

    def test_loads_allow_and_deny_lists(self, tmp_path):
        cfg = {"allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"]}
        p = tmp_path / "config.json"
        p.write_text(json.dumps(cfg))
        result = lc.load_config(str(p))
        assert result["allow"] == ["MIT", "Apache-2.0"]
        assert result["deny"] == ["GPL-3.0"]

    def test_missing_config_raises(self):
        with pytest.raises(FileNotFoundError):
            lc.load_config("/nonexistent/config.json")

    def test_invalid_config_raises(self, tmp_path):
        p = tmp_path / "config.json"
        p.write_text("{}")
        with pytest.raises(ValueError, match="allow.*deny"):
            lc.load_config(str(p))


# ═══════════════════════════════════════════════════════════════════
# Group 3: License lookup (mocked)
# ═══════════════════════════════════════════════════════════════════

class TestLookupLicense:
    """RED: written before lookup_license() existed. Uses MOCK_LICENSE_DB."""

    def test_known_package_returns_license(self):
        license_ = lc.lookup_license("requests", lc.MOCK_LICENSE_DB)
        assert license_ == "Apache-2.0"

    def test_unknown_package_returns_none(self):
        license_ = lc.lookup_license("mystery-package-xyz", lc.MOCK_LICENSE_DB)
        assert license_ is None

    def test_gpl_package(self):
        license_ = lc.lookup_license("gpl-lib", lc.MOCK_LICENSE_DB)
        assert license_ == "GPL-3.0"


# ═══════════════════════════════════════════════════════════════════
# Group 4: License status classification
# ═══════════════════════════════════════════════════════════════════

class TestClassifyLicense:
    """RED: written before classify_license() existed."""

    def setup_method(self):
        self.config = {"allow": ["MIT", "Apache-2.0", "BSD-3-Clause"], "deny": ["GPL-3.0", "AGPL-3.0"]}

    def test_approved_license(self):
        assert lc.classify_license("MIT", self.config) == "approved"

    def test_denied_license(self):
        assert lc.classify_license("GPL-3.0", self.config) == "denied"

    def test_unknown_license(self):
        assert lc.classify_license("Proprietary", self.config) == "unknown"

    def test_none_license_is_unknown(self):
        assert lc.classify_license(None, self.config) == "unknown"


# ═══════════════════════════════════════════════════════════════════
# Group 5: Report generation
# ═══════════════════════════════════════════════════════════════════

class TestGenerateReport:
    """RED: written before generate_report() existed."""

    def setup_method(self):
        self.config = {
            "allow": ["MIT", "Apache-2.0", "BSD-3-Clause", "BSD-2-Clause", "ISC"],
            "deny": ["GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1"],
        }

    def test_all_approved(self):
        deps = {"requests": "2.28.0", "flask": "2.3.0", "pytest": "7.4.0"}
        report = lc.generate_report(deps, self.config, lc.MOCK_LICENSE_DB)
        # generate_report sorts deps alphabetically
        assert report["approved"] == ["flask (BSD-3-Clause)", "pytest (MIT)", "requests (Apache-2.0)"]
        assert report["denied"] == []
        assert report["unknown"] == []
        assert report["summary"]["approved"] == 3
        assert report["summary"]["denied"] == 0
        assert report["summary"]["unknown"] == 0
        assert report["status"] == "PASS"

    def test_with_denied(self):
        deps = {"requests": "2.28.0", "gpl-lib": "1.0.0", "numpy": "1.24.0"}
        report = lc.generate_report(deps, self.config, lc.MOCK_LICENSE_DB)
        assert "gpl-lib (GPL-3.0)" in report["denied"]
        assert report["summary"]["denied"] == 1
        assert report["status"] == "FAIL"

    def test_with_unknown(self):
        deps = {"flask": "2.3.0", "mystery-package": "0.1.0"}
        report = lc.generate_report(deps, self.config, lc.MOCK_LICENSE_DB)
        assert "mystery-package (unknown)" in report["unknown"]
        assert report["summary"]["unknown"] == 1
        # unknown alone does not fail
        assert report["status"] == "PASS"

    def test_empty_deps(self):
        report = lc.generate_report({}, self.config, lc.MOCK_LICENSE_DB)
        assert report["summary"]["approved"] == 0
        assert report["status"] == "PASS"


# ═══════════════════════════════════════════════════════════════════
# Group 6: Report formatting
# ═══════════════════════════════════════════════════════════════════

class TestFormatReport:
    """RED: written before format_report() existed."""

    def test_format_contains_approved(self):
        report = {
            "approved": ["requests (Apache-2.0)"],
            "denied": [],
            "unknown": [],
            "summary": {"approved": 1, "denied": 0, "unknown": 0},
            "status": "PASS",
        }
        text = lc.format_report(report, "package.json")
        assert "APPROVED: requests (Apache-2.0)" in text
        assert "Summary: 1 approved, 0 denied, 0 unknown" in text
        assert "Status: PASS" in text

    def test_format_contains_denied(self):
        report = {
            "approved": [],
            "denied": ["gpl-lib (GPL-3.0)"],
            "unknown": [],
            "summary": {"approved": 0, "denied": 1, "unknown": 0},
            "status": "FAIL",
        }
        text = lc.format_report(report, "package.json")
        assert "DENIED: gpl-lib (GPL-3.0)" in text
        assert "Status: FAIL" in text

    def test_format_contains_unknown(self):
        report = {
            "approved": [],
            "denied": [],
            "unknown": ["mystery-package (unknown)"],
            "summary": {"approved": 0, "denied": 0, "unknown": 1},
            "status": "PASS",
        }
        text = lc.format_report(report, "package.json")
        assert "UNKNOWN: mystery-package (unknown)" in text


# ═══════════════════════════════════════════════════════════════════
# Group 7: Workflow structure tests
# ═══════════════════════════════════════════════════════════════════

WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__),
    ".github", "workflows", "dependency-license-checker.yml",
)


class TestWorkflowStructure:
    """Validates the GitHub Actions workflow file structure."""

    def test_workflow_file_exists(self):
        assert os.path.isfile(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_yaml_is_valid(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert wf is not None

    def test_workflow_has_push_trigger(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "push" in wf["on"], "Workflow must trigger on push"

    def test_workflow_has_workflow_dispatch(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "workflow_dispatch" in wf["on"]

    def test_workflow_has_check_licenses_job(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "check-licenses" in wf["jobs"]

    def test_workflow_references_license_checker_script(self):
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        assert "license_checker.py" in content

    def test_workflow_references_existing_files(self):
        base = os.path.dirname(__file__)
        assert os.path.isfile(os.path.join(base, "license_checker.py"))
        assert os.path.isfile(os.path.join(base, "config", "license_config.json"))

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"
