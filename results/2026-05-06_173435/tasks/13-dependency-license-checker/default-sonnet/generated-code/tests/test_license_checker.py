"""
Dependency License Checker — Test Suite

TDD order:
  RED   → write the test (it fails because nothing exists yet)
  GREEN → write minimum code to pass
  REFACTOR → clean up without breaking tests

Each test class follows one conceptual piece of functionality.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

# Allow importing from the project root
sys.path.insert(0, str(Path(__file__).parent.parent))

from license_checker import (
    check_compliance,
    generate_report,
    lookup_license,
    parse_manifest,
    parse_package_json,
    parse_requirements_txt,
)

# ---------------------------------------------------------------------------
# Shared test data (designed up-front before writing any production code)
# ---------------------------------------------------------------------------

SAMPLE_PACKAGE_JSON = {
    "name": "test-project",
    "version": "1.0.0",
    "dependencies": {
        "express": "^4.18.0",
        "react": "^18.0.0",
        "some-gpl-lib": "^1.0.0",
        "unknown-pkg": "^0.1.0",
    },
    "devDependencies": {
        "jest": "^29.0.0",
    },
}

SAMPLE_REQUIREMENTS = """\
# Python dependencies
requests==2.28.0
django>=4.2.0
some-gpl==1.0.0
no-version-pkg
"""

# Mock license DB: package name → SPDX license id
MOCK_LICENSE_DB = {
    "express": "MIT",
    "react": "MIT",
    "jest": "MIT",
    "lodash": "MIT",
    "some-gpl-lib": "GPL-3.0",
    "requests": "Apache-2.0",
    "django": "BSD-3-Clause",
    "some-gpl": "GPL-2.0",
}

LICENSE_CONFIG = {
    "allow_list": ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"],
    "deny_list": ["GPL-2.0", "GPL-3.0", "AGPL-3.0"],
}


# ---------------------------------------------------------------------------
# RED #1 — parse_package_json  (written before any implementation exists)
# ---------------------------------------------------------------------------

class TestParsePackageJson:
    """Parse package.json and return [{name, version}, ...]."""

    def test_extracts_dependency_names(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_package_json(str(pkg))
        names = {d["name"] for d in deps}

        assert "express" in names
        assert "react" in names
        assert "some-gpl-lib" in names
        assert "unknown-pkg" in names

    def test_strips_version_specifiers(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_package_json(str(pkg))
        dep_map = {d["name"]: d["version"] for d in deps}

        # ^ prefix must be removed
        assert dep_map["express"] == "4.18.0"
        assert dep_map["react"] == "18.0.0"

    def test_empty_manifest_returns_empty_list(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "test", "version": "1.0.0"}))

        assert parse_package_json(str(pkg)) == []

    def test_includes_dev_dependencies(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_package_json(str(pkg))
        names = {d["name"] for d in deps}
        assert "jest" in names


# ---------------------------------------------------------------------------
# RED #2 — parse_requirements_txt
# ---------------------------------------------------------------------------

class TestParseRequirementsTxt:
    """Parse requirements.txt and return [{name, version}, ...]."""

    def test_extracts_names(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text(SAMPLE_REQUIREMENTS)

        deps = parse_requirements_txt(str(req))
        names = {d["name"] for d in deps}

        assert "requests" in names
        assert "django" in names
        assert "some-gpl" in names

    def test_extracts_pinned_versions(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text(SAMPLE_REQUIREMENTS)

        deps = parse_requirements_txt(str(req))
        dep_map = {d["name"]: d["version"] for d in deps}

        assert dep_map["requests"] == "2.28.0"
        assert dep_map["django"] == "4.2.0"

    def test_skips_comments_and_blank_lines(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("# comment\n\nrequests==2.28.0\n")

        deps = parse_requirements_txt(str(req))
        assert len(deps) == 1
        assert deps[0]["name"] == "requests"

    def test_handles_package_without_version(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("some-package\n")

        deps = parse_requirements_txt(str(req))
        assert len(deps) == 1
        assert deps[0]["name"] == "some-package"


# ---------------------------------------------------------------------------
# RED #3 — parse_manifest  (auto-detect format by filename)
# ---------------------------------------------------------------------------

class TestParseManifest:

    def test_dispatches_to_package_json_parser(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps(SAMPLE_PACKAGE_JSON))

        deps = parse_manifest(str(pkg))
        assert len(deps) > 0

    def test_dispatches_to_requirements_txt_parser(self, tmp_path):
        req = tmp_path / "requirements.txt"
        req.write_text("requests==2.28.0\n")

        deps = parse_manifest(str(req))
        assert len(deps) > 0

    def test_raises_on_unsupported_format(self, tmp_path):
        gemfile = tmp_path / "Gemfile"
        gemfile.write_text("gem 'rails'\n")

        with pytest.raises(ValueError, match="Unsupported"):
            parse_manifest(str(gemfile))


# ---------------------------------------------------------------------------
# RED #4 — lookup_license  (mock DB lookup)
# ---------------------------------------------------------------------------

class TestLookupLicense:

    def test_returns_license_for_known_package(self):
        assert lookup_license("express", MOCK_LICENSE_DB) == "MIT"

    def test_returns_none_for_unknown_package(self):
        assert lookup_license("mystery-pkg", MOCK_LICENSE_DB) is None

    def test_empty_db_always_returns_none(self):
        assert lookup_license("express", {}) is None


# ---------------------------------------------------------------------------
# RED #5 — check_compliance  (classify each dep against allow/deny lists)
# ---------------------------------------------------------------------------

class TestCheckCompliance:

    def test_approved_when_license_in_allow_list(self):
        deps = [{"name": "express", "version": "4.18.0"}]
        results = check_compliance(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)

        assert results[0]["status"] == "approved"
        assert results[0]["license"] == "MIT"

    def test_denied_when_license_in_deny_list(self):
        deps = [{"name": "some-gpl-lib", "version": "1.0.0"}]
        results = check_compliance(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)

        assert results[0]["status"] == "denied"
        assert results[0]["license"] == "GPL-3.0"

    def test_unknown_when_package_not_in_db(self):
        deps = [{"name": "mystery-pkg", "version": "0.1.0"}]
        results = check_compliance(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)

        assert results[0]["status"] == "unknown"
        assert results[0]["license"] == "UNKNOWN"

    def test_unknown_when_license_not_in_either_list(self):
        # MPL-2.0 is neither allowed nor denied → unknown
        db = {"some-pkg": "MPL-2.0"}
        deps = [{"name": "some-pkg", "version": "1.0.0"}]
        results = check_compliance(deps, db, LICENSE_CONFIG)

        assert results[0]["status"] == "unknown"

    def test_mixed_compliance_result(self):
        deps = [
            {"name": "express", "version": "4.18.0"},      # MIT → approved
            {"name": "some-gpl-lib", "version": "1.0.0"},  # GPL-3.0 → denied
            {"name": "mystery-pkg", "version": "0.1.0"},   # not in DB → unknown
        ]
        results = check_compliance(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)
        statuses = {r["name"]: r["status"] for r in results}

        assert statuses["express"] == "approved"
        assert statuses["some-gpl-lib"] == "denied"
        assert statuses["mystery-pkg"] == "unknown"

    def test_preserves_input_order(self):
        deps = [
            {"name": "express", "version": "4.18.0"},
            {"name": "react", "version": "18.0.0"},
        ]
        results = check_compliance(deps, MOCK_LICENSE_DB, LICENSE_CONFIG)

        assert results[0]["name"] == "express"
        assert results[1]["name"] == "react"


# ---------------------------------------------------------------------------
# RED #6 — generate_report  (formatted compliance report)
# ---------------------------------------------------------------------------

class TestGenerateReport:

    def _make_results(self):
        return [
            {"name": "express", "version": "4.18.0", "license": "MIT", "status": "approved"},
            {"name": "some-gpl-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
            {"name": "mystery", "version": "0.1.0", "license": "UNKNOWN", "status": "unknown"},
        ]

    def test_report_contains_package_names(self):
        report = generate_report(self._make_results())
        assert "express" in report
        assert "some-gpl-lib" in report

    def test_report_contains_status_labels(self):
        report = generate_report(self._make_results())
        assert "APPROVED" in report
        assert "DENIED" in report
        assert "UNKNOWN" in report

    def test_report_shows_summary_counts(self):
        report = generate_report(self._make_results())
        assert "1 approved" in report
        assert "1 denied" in report
        assert "1 unknown" in report

    def test_report_overall_compliant(self):
        results = [
            {"name": "express", "version": "4.18.0", "license": "MIT", "status": "approved"},
        ]
        assert "COMPLIANT" in generate_report(results)
        assert "NON-COMPLIANT" not in generate_report(results)

    def test_report_overall_non_compliant_when_denied(self):
        results = [
            {"name": "some-gpl-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
        ]
        report = generate_report(results)
        assert "NON-COMPLIANT" in report

    def test_report_lists_denied_section(self):
        report = generate_report(self._make_results())
        assert "DENIED PACKAGES" in report
        assert "some-gpl-lib@1.0.0" in report

    def test_report_lists_unknown_section(self):
        report = generate_report(self._make_results())
        assert "UNKNOWN LICENSES" in report


# ---------------------------------------------------------------------------
# Workflow Structure Tests — verify .yml before running act
# ---------------------------------------------------------------------------

WORKFLOW_PATH = Path(__file__).parent.parent / ".github" / "workflows" / "dependency-license-checker.yml"
PROJECT_ROOT  = Path(__file__).parent.parent


class TestWorkflowStructure:

    def test_workflow_file_exists(self):
        assert WORKFLOW_PATH.exists(), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_has_push_trigger(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # PyYAML parses the YAML `on:` key as the Python bool True
        triggers = wf.get("on") or wf.get(True, {})
        assert "push" in triggers

    def test_workflow_has_pull_request_trigger(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        triggers = wf.get("on") or wf.get(True, {})
        assert "pull_request" in triggers

    def test_workflow_has_at_least_one_job(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "jobs" in wf and len(wf["jobs"]) >= 1

    def test_workflow_has_checkout_step(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        all_steps = []
        for job in wf["jobs"].values():
            all_steps.extend(job.get("steps", []))
        uses_vals = [s.get("uses", "") for s in all_steps]
        assert any("actions/checkout" in u for u in uses_vals)

    def test_workflow_references_license_checker_script(self):
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        all_steps = []
        for job in wf["jobs"].values():
            all_steps.extend(job.get("steps", []))
        run_cmds = " ".join(s.get("run", "") for s in all_steps if "run" in s)
        assert "license_checker" in run_cmds

    def test_license_checker_script_exists(self):
        assert (PROJECT_ROOT / "license_checker.py").exists()

    def test_fixtures_directory_exists(self):
        assert (PROJECT_ROOT / "fixtures").is_dir()

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
        )
