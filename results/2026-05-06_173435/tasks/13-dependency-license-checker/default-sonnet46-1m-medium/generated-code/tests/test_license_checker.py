# Tests for dependency license checker.
# TDD approach: tests are written before implementation, then we make them pass.
#
# Test cases cover:
# 1. Parsing package.json manifests
# 2. Parsing requirements.txt manifests
# 3. Mocked license lookups
# 4. Allow-list / deny-list classification
# 5. Full compliance report generation
# 6. GitHub Actions workflow structure validation

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest
import yaml

# Add parent dir to path so we can import license_checker
sys.path.insert(0, str(Path(__file__).parent.parent))

import license_checker as lc

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"
WORKFLOW_PATH = Path(__file__).parent.parent / ".github" / "workflows" / "dependency-license-checker.yml"


# --- Fixture data used in tests ---

MOCK_LICENSE_DB = {
    "express": "MIT",
    "axios": "MIT",
    "lodash": "MIT",
    "react": "MIT",
    "gpl-lib": "GPL-3.0",
    "copyleft-pkg": "AGPL-3.0",
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "mystery-pkg": None,  # unknown license
}

LICENSE_CONFIG = {
    "allow": ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
    "deny": ["GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1"],
}


# ============================================================
# RED PHASE 1: Parse package.json
# ============================================================

class TestParsePackageJson:
    def test_extracts_production_dependencies(self):
        pkg = {
            "name": "test-app",
            "dependencies": {
                "express": "^4.18.0",
                "axios": "^1.4.0",
            }
        }
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(pkg, f)
            tmp_path = f.name
        try:
            deps = lc.parse_package_json(tmp_path)
            assert ("express", "^4.18.0") in deps
            assert ("axios", "^1.4.0") in deps
            assert len(deps) == 2
        finally:
            os.unlink(tmp_path)

    def test_includes_dev_dependencies_when_requested(self):
        pkg = {
            "dependencies": {"express": "^4.18.0"},
            "devDependencies": {"jest": "^29.0.0"},
        }
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(pkg, f)
            tmp_path = f.name
        try:
            deps = lc.parse_package_json(tmp_path, include_dev=True)
            names = [d[0] for d in deps]
            assert "express" in names
            assert "jest" in names
        finally:
            os.unlink(tmp_path)

    def test_excludes_dev_dependencies_by_default(self):
        pkg = {
            "dependencies": {"express": "^4.18.0"},
            "devDependencies": {"jest": "^29.0.0"},
        }
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(pkg, f)
            tmp_path = f.name
        try:
            deps = lc.parse_package_json(tmp_path)
            names = [d[0] for d in deps]
            assert "express" in names
            assert "jest" not in names
        finally:
            os.unlink(tmp_path)

    def test_handles_missing_dependencies_section(self):
        pkg = {"name": "no-deps"}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(pkg, f)
            tmp_path = f.name
        try:
            deps = lc.parse_package_json(tmp_path)
            assert deps == []
        finally:
            os.unlink(tmp_path)

    def test_raises_on_invalid_json(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("not valid json {{{")
            tmp_path = f.name
        try:
            with pytest.raises(ValueError, match="Invalid JSON"):
                lc.parse_package_json(tmp_path)
        finally:
            os.unlink(tmp_path)

    def test_raises_on_missing_file(self):
        with pytest.raises(FileNotFoundError):
            lc.parse_package_json("/nonexistent/path/package.json")


# ============================================================
# RED PHASE 2: Parse requirements.txt
# ============================================================

class TestParseRequirementsTxt:
    def test_extracts_pinned_versions(self):
        content = "requests==2.31.0\nflask==3.0.0\nnumpy==1.24.0\n"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write(content)
            tmp_path = f.name
        try:
            deps = lc.parse_requirements_txt(tmp_path)
            assert ("requests", "2.31.0") in deps
            assert ("flask", "3.0.0") in deps
            assert ("numpy", "1.24.0") in deps
        finally:
            os.unlink(tmp_path)

    def test_skips_comments_and_blank_lines(self):
        content = "# This is a comment\n\nrequests==2.31.0\n# another comment\nflask==3.0.0\n"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write(content)
            tmp_path = f.name
        try:
            deps = lc.parse_requirements_txt(tmp_path)
            assert len(deps) == 2
        finally:
            os.unlink(tmp_path)

    def test_handles_version_ranges(self):
        # requirements.txt can have >= or ~= style constraints
        content = "requests>=2.0.0\nflask~=3.0\n"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write(content)
            tmp_path = f.name
        try:
            deps = lc.parse_requirements_txt(tmp_path)
            names = [d[0] for d in deps]
            assert "requests" in names
            assert "flask" in names
        finally:
            os.unlink(tmp_path)

    def test_handles_package_with_no_version(self):
        content = "requests\nflask==3.0.0\n"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write(content)
            tmp_path = f.name
        try:
            deps = lc.parse_requirements_txt(tmp_path)
            names_versions = {d[0]: d[1] for d in deps}
            assert "requests" in names_versions
            assert names_versions["requests"] == ""  # no version constraint
            assert names_versions["flask"] == "3.0.0"
        finally:
            os.unlink(tmp_path)

    def test_raises_on_missing_file(self):
        with pytest.raises(FileNotFoundError):
            lc.parse_requirements_txt("/nonexistent/requirements.txt")


# ============================================================
# RED PHASE 3: License lookup (mocked)
# ============================================================

class TestLicenseLookup:
    def test_returns_license_from_mock_db(self):
        result = lc.lookup_license("express", MOCK_LICENSE_DB)
        assert result == "MIT"

    def test_returns_none_for_unknown_package(self):
        result = lc.lookup_license("mystery-pkg", MOCK_LICENSE_DB)
        assert result is None

    def test_returns_none_for_package_not_in_db(self):
        result = lc.lookup_license("totally-unknown-package", MOCK_LICENSE_DB)
        assert result is None

    def test_lookup_is_case_insensitive_on_package_name(self):
        result = lc.lookup_license("Express", MOCK_LICENSE_DB)
        assert result == "MIT"


# ============================================================
# RED PHASE 4: License classification (allow/deny/unknown)
# ============================================================

class TestClassifyLicense:
    def test_approved_when_in_allow_list(self):
        status = lc.classify_license("MIT", LICENSE_CONFIG)
        assert status == "approved"

    def test_approved_for_apache(self):
        status = lc.classify_license("Apache-2.0", LICENSE_CONFIG)
        assert status == "approved"

    def test_denied_when_in_deny_list(self):
        status = lc.classify_license("GPL-3.0", LICENSE_CONFIG)
        assert status == "denied"

    def test_denied_for_agpl(self):
        status = lc.classify_license("AGPL-3.0", LICENSE_CONFIG)
        assert status == "denied"

    def test_unknown_when_not_in_either_list(self):
        status = lc.classify_license("Unlicense", LICENSE_CONFIG)
        assert status == "unknown"

    def test_unknown_when_license_is_none(self):
        status = lc.classify_license(None, LICENSE_CONFIG)
        assert status == "unknown"


# ============================================================
# RED PHASE 5: Full report generation
# ============================================================

class TestGenerateReport:
    def test_report_contains_all_dependencies(self):
        deps = [("express", "^4.18.0"), ("gpl-lib", "1.0.0"), ("mystery-pkg", "2.0.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        assert len(report["dependencies"]) == 3

    def test_report_classifies_approved_correctly(self):
        deps = [("express", "^4.18.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        dep = report["dependencies"][0]
        assert dep["name"] == "express"
        assert dep["version"] == "^4.18.0"
        assert dep["license"] == "MIT"
        assert dep["status"] == "approved"

    def test_report_classifies_denied_correctly(self):
        deps = [("gpl-lib", "1.0.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        dep = report["dependencies"][0]
        assert dep["status"] == "denied"
        assert dep["license"] == "GPL-3.0"

    def test_report_classifies_unknown_correctly(self):
        deps = [("mystery-pkg", "2.0.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        dep = report["dependencies"][0]
        assert dep["status"] == "unknown"
        assert dep["license"] is None

    def test_report_summary_counts(self):
        deps = [
            ("express", "^4.18.0"),   # MIT -> approved
            ("axios", "^1.4.0"),       # MIT -> approved
            ("gpl-lib", "1.0.0"),      # GPL-3.0 -> denied
            ("mystery-pkg", "2.0.0"),  # None -> unknown
        ]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        assert report["summary"]["approved"] == 2
        assert report["summary"]["denied"] == 1
        assert report["summary"]["unknown"] == 1
        assert report["summary"]["total"] == 4

    def test_report_pass_when_no_denied(self):
        deps = [("express", "^4.18.0"), ("axios", "^1.4.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        assert report["passed"] is True

    def test_report_fail_when_denied_present(self):
        deps = [("express", "^4.18.0"), ("gpl-lib", "1.0.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        assert report["passed"] is False


# ============================================================
# RED PHASE 6: Report formatting
# ============================================================

class TestFormatReport:
    def test_format_includes_header(self):
        deps = [("express", "^4.18.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        output = lc.format_report(report)
        assert "Dependency License Compliance Report" in output

    def test_format_shows_approved_status(self):
        deps = [("express", "^4.18.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        output = lc.format_report(report)
        assert "express" in output
        assert "MIT" in output
        assert "approved" in output.lower()

    def test_format_shows_denied_status(self):
        deps = [("gpl-lib", "1.0.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        output = lc.format_report(report)
        assert "gpl-lib" in output
        assert "GPL-3.0" in output
        assert "denied" in output.lower()

    def test_format_shows_summary_line(self):
        deps = [
            ("express", "^4.18.0"),
            ("gpl-lib", "1.0.0"),
            ("mystery-pkg", "2.0.0"),
        ]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        output = lc.format_report(report)
        assert "1 approved" in output
        assert "1 denied" in output
        assert "1 unknown" in output

    def test_format_shows_pass_or_fail_verdict(self):
        deps = [("express", "^4.18.0")]
        report = lc.generate_report(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        output = lc.format_report(report)
        assert "PASSED" in output or "FAILED" in output


# ============================================================
# RED PHASE 7: CLI entrypoint
# ============================================================

class TestCliEntrypoint:
    def test_cli_with_package_json(self):
        """Test running license_checker.py as a CLI with a package.json."""
        pkg = {
            "dependencies": {
                "express": "^4.18.0",
                "gpl-lib": "1.0.0",
            }
        }
        config = LICENSE_CONFIG
        mock_db = MOCK_LICENSE_DB

        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = os.path.join(tmp, "package.json")
            config_path = os.path.join(tmp, "license_config.json")
            mock_db_path = os.path.join(tmp, "mock_licenses.json")

            with open(manifest_path, "w") as f:
                json.dump(pkg, f)
            with open(config_path, "w") as f:
                json.dump(config, f)
            with open(mock_db_path, "w") as f:
                json.dump(mock_db, f)

            checker_path = str(Path(__file__).parent.parent / "license_checker.py")
            result = subprocess.run(
                [sys.executable, checker_path,
                 "--manifest", manifest_path,
                 "--config", config_path,
                 "--mock-db", mock_db_path],
                capture_output=True, text=True
            )
            assert "express" in result.stdout
            assert "MIT" in result.stdout
            assert "approved" in result.stdout.lower()
            assert "gpl-lib" in result.stdout
            assert "denied" in result.stdout.lower()

    def test_cli_exits_nonzero_on_denied_dependencies(self):
        """CLI should exit with code 1 when denied licenses are found."""
        pkg = {"dependencies": {"gpl-lib": "1.0.0"}}
        config = LICENSE_CONFIG
        mock_db = MOCK_LICENSE_DB

        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = os.path.join(tmp, "package.json")
            config_path = os.path.join(tmp, "license_config.json")
            mock_db_path = os.path.join(tmp, "mock_licenses.json")

            with open(manifest_path, "w") as f:
                json.dump(pkg, f)
            with open(config_path, "w") as f:
                json.dump(config, f)
            with open(mock_db_path, "w") as f:
                json.dump(mock_db, f)

            checker_path = str(Path(__file__).parent.parent / "license_checker.py")
            result = subprocess.run(
                [sys.executable, checker_path,
                 "--manifest", manifest_path,
                 "--config", config_path,
                 "--mock-db", mock_db_path],
                capture_output=True, text=True
            )
            assert result.returncode == 1

    def test_cli_exits_zero_when_all_approved(self):
        """CLI should exit with code 0 when all licenses are approved or unknown."""
        pkg = {"dependencies": {"express": "^4.18.0"}}
        config = LICENSE_CONFIG
        mock_db = MOCK_LICENSE_DB

        with tempfile.TemporaryDirectory() as tmp:
            manifest_path = os.path.join(tmp, "package.json")
            config_path = os.path.join(tmp, "license_config.json")
            mock_db_path = os.path.join(tmp, "mock_licenses.json")

            with open(manifest_path, "w") as f:
                json.dump(pkg, f)
            with open(config_path, "w") as f:
                json.dump(config, f)
            with open(mock_db_path, "w") as f:
                json.dump(mock_db, f)

            checker_path = str(Path(__file__).parent.parent / "license_checker.py")
            result = subprocess.run(
                [sys.executable, checker_path,
                 "--manifest", manifest_path,
                 "--config", config_path,
                 "--mock-db", mock_db_path],
                capture_output=True, text=True
            )
            assert result.returncode == 0


# ============================================================
# Workflow structure tests
# ============================================================

class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert WORKFLOW_PATH.exists(), f"Workflow not found at {WORKFLOW_PATH}"

    def test_workflow_is_valid_yaml(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert wf is not None

    def test_workflow_has_push_trigger(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # yaml.safe_load parses `on:` as True (YAML 1.1 boolean) — check both keys
        triggers = wf.get("on", wf.get(True, {})) or {}
        assert "push" in triggers

    def test_workflow_has_workflow_dispatch_trigger(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        triggers = wf.get("on", wf.get(True, {})) or {}
        assert "workflow_dispatch" in triggers

    def test_workflow_has_license_check_job(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "license-check" in wf.get("jobs", {})

    def test_workflow_uses_checkout_action(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        steps = wf["jobs"]["license-check"]["steps"]
        uses = [s.get("uses", "") for s in steps]
        assert any("actions/checkout" in u for u in uses)

    def test_workflow_references_license_checker_script(self):
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        assert "license_checker.py" in content

    def test_script_file_exists(self):
        script_path = Path(__file__).parent.parent / "license_checker.py"
        assert script_path.exists(), "license_checker.py not found"

    @pytest.mark.skipif(
        shutil.which("actionlint") is None,
        reason="actionlint not installed in this environment",
    )
    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True, text=True
        )
        assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"
