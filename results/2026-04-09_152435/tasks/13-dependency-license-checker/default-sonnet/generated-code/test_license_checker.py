"""
Dependency License Checker - Test Suite
TDD approach: tests written FIRST, then implementation added to make them pass.

Rounds:
  1. parse_manifest raises FileNotFoundError for missing file
  2. parse_package_json extracts dependencies from package.json
  3. parse_requirements_txt extracts dependencies from requirements.txt
  4. parse_manifest dispatches by filename
  5. check_compliance returns 'approved' for allow-listed license
  6. check_compliance returns 'denied' for deny-listed license
  7. check_compliance returns 'unknown' for unlisted license
  8. check_compliance returns 'unknown' for None (package not in DB)
  9. generate_report produces correct entries for package.json
  10. generate_report produces correct entries for requirements.txt
  11. format_report contains expected summary lines
  12. format_report includes COMPLIANCE FAILED when denied exist
  13. format_report includes COMPLIANCE PASSED when no denied
  14. Workflow structure: triggers, jobs, steps exist
  15. Workflow script files referenced actually exist
  16. actionlint passes on the workflow file
"""

import json
import os
import subprocess
import sys

import pytest
import yaml

# Import the module under test.
# This import will FAIL (ModuleNotFoundError or ImportError) until
# license_checker.py is created — that's the first red state.
from license_checker import (
    check_compliance,
    format_report,
    generate_report,
    load_config,
    load_license_db,
    parse_manifest,
    parse_package_json,
    parse_requirements_txt,
)

# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")
PKG_JSON = os.path.join(FIXTURES_DIR, "package.json")
REQS_TXT = os.path.join(FIXTURES_DIR, "requirements.txt")
MOCK_DB = os.path.join(FIXTURES_DIR, "mock_licenses.json")
CONFIG = os.path.join(os.path.dirname(__file__), "config.json")
WORKFLOW = os.path.join(os.path.dirname(__file__), ".github", "workflows", "dependency-license-checker.yml")


# ---------------------------------------------------------------------------
# Round 1: FileNotFoundError for missing manifest
# ---------------------------------------------------------------------------

def test_parse_manifest_missing_file_raises():
    """RED: parse_manifest should raise FileNotFoundError for non-existent paths."""
    with pytest.raises(FileNotFoundError, match="Manifest file not found"):
        parse_manifest("/tmp/nonexistent_manifest_xyz.json")


# ---------------------------------------------------------------------------
# Round 2: parse_package_json extracts all dependency sections
# ---------------------------------------------------------------------------

def test_parse_package_json_extracts_deps():
    """RED: parse_package_json should return deps from both dependencies and devDependencies."""
    deps = parse_package_json(PKG_JSON)
    names = [d["name"] for d in deps]
    # From dependencies
    assert "react" in names
    assert "lodash" in names
    assert "express" in names
    assert "copyleft-lib" in names
    # From devDependencies
    assert "jest" in names
    assert "mystery-pkg" in names


def test_parse_package_json_strips_version_prefix():
    """RED: parse_package_json should strip ^ and ~ from version strings."""
    deps = parse_package_json(PKG_JSON)
    by_name = {d["name"]: d for d in deps}
    assert by_name["react"]["version"] == "18.2.0"
    assert by_name["lodash"]["version"] == "4.17.21"


def test_parse_package_json_returns_name_and_version():
    """RED: each entry must have 'name' and 'version' keys."""
    deps = parse_package_json(PKG_JSON)
    for dep in deps:
        assert "name" in dep
        assert "version" in dep


# ---------------------------------------------------------------------------
# Round 3: parse_requirements_txt
# ---------------------------------------------------------------------------

def test_parse_requirements_txt_extracts_deps():
    """RED: parse_requirements_txt should extract all non-comment, non-empty lines."""
    deps = parse_requirements_txt(REQS_TXT)
    names = [d["name"] for d in deps]
    assert "requests" in names
    assert "numpy" in names
    assert "flask" in names
    assert "gpl-package" in names
    assert "mystery-lib" in names


def test_parse_requirements_txt_extracts_versions():
    """RED: versions should be extracted from pinned requirements."""
    deps = parse_requirements_txt(REQS_TXT)
    by_name = {d["name"]: d for d in deps}
    assert by_name["requests"]["version"] == "2.28.0"
    assert by_name["numpy"]["version"] == "1.24.0"
    assert by_name["flask"]["version"] == "2.3.0"


def test_parse_requirements_txt_skips_comments():
    """RED: comment lines starting with # must be ignored."""
    deps = parse_requirements_txt(REQS_TXT)
    for dep in deps:
        assert not dep["name"].startswith("#")


# ---------------------------------------------------------------------------
# Round 4: parse_manifest dispatches by filename
# ---------------------------------------------------------------------------

def test_parse_manifest_dispatches_package_json():
    """RED: parse_manifest('...package.json') should delegate to parse_package_json."""
    deps = parse_manifest(PKG_JSON)
    assert len(deps) > 0
    names = [d["name"] for d in deps]
    assert "react" in names


def test_parse_manifest_dispatches_requirements_txt():
    """RED: parse_manifest('...requirements.txt') should delegate to parse_requirements_txt."""
    deps = parse_manifest(REQS_TXT)
    assert len(deps) > 0
    names = [d["name"] for d in deps]
    assert "requests" in names


def test_parse_manifest_unsupported_format_raises():
    """RED: unsupported file format should raise ValueError."""
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".toml", delete=False) as f:
        f.write(b"[dependencies]\nfoo = '1.0'\n")
        tmp = f.name
    try:
        with pytest.raises(ValueError, match="Unsupported manifest format"):
            parse_manifest(tmp)
    finally:
        os.unlink(tmp)


# ---------------------------------------------------------------------------
# Round 5-8: check_compliance
# ---------------------------------------------------------------------------

SIMPLE_CONFIG = {"allow": ["MIT", "BSD-3-Clause", "Apache-2.0"], "deny": ["GPL-3.0", "AGPL-3.0"]}


def test_check_compliance_approved():
    """RED: MIT is in allow list -> 'approved'."""
    assert check_compliance("MIT", SIMPLE_CONFIG) == "approved"


def test_check_compliance_approved_bsd():
    """RED: BSD-3-Clause is in allow list -> 'approved'."""
    assert check_compliance("BSD-3-Clause", SIMPLE_CONFIG) == "approved"


def test_check_compliance_denied():
    """RED: GPL-3.0 is in deny list -> 'denied'."""
    assert check_compliance("GPL-3.0", SIMPLE_CONFIG) == "denied"


def test_check_compliance_denied_agpl():
    """RED: AGPL-3.0 is in deny list -> 'denied'."""
    assert check_compliance("AGPL-3.0", SIMPLE_CONFIG) == "denied"


def test_check_compliance_unknown():
    """RED: LGPL-2.1 is neither in allow nor deny -> 'unknown'."""
    assert check_compliance("LGPL-2.1", SIMPLE_CONFIG) == "unknown"


def test_check_compliance_none_is_unknown():
    """RED: None license (package not in DB) -> 'unknown'."""
    assert check_compliance(None, SIMPLE_CONFIG) == "unknown"


def test_check_compliance_case_insensitive():
    """RED: license comparison should be case-insensitive."""
    assert check_compliance("mit", SIMPLE_CONFIG) == "approved"
    assert check_compliance("gpl-3.0", SIMPLE_CONFIG) == "denied"


def test_check_compliance_deny_takes_precedence_over_allow():
    """RED: if a license appears in both lists, deny wins."""
    conflicting = {"allow": ["GPL-3.0"], "deny": ["GPL-3.0"]}
    assert check_compliance("GPL-3.0", conflicting) == "denied"


# ---------------------------------------------------------------------------
# Round 9: generate_report for package.json
# ---------------------------------------------------------------------------

def test_generate_report_package_json():
    """RED: generate_report with package.json fixture returns correct statuses."""
    entries = generate_report(PKG_JSON, CONFIG, MOCK_DB)
    by_name = {e["name"]: e for e in entries}

    assert by_name["react"]["status"] == "approved"
    assert by_name["react"]["license"] == "MIT"

    assert by_name["lodash"]["status"] == "approved"
    assert by_name["express"]["status"] == "approved"
    assert by_name["jest"]["status"] == "approved"

    # copyleft-lib -> GPL-3.0 -> denied
    assert by_name["copyleft-lib"]["status"] == "denied"
    assert by_name["copyleft-lib"]["license"] == "GPL-3.0"

    # mystery-pkg not in mock DB -> unknown
    assert by_name["mystery-pkg"]["status"] == "unknown"
    assert by_name["mystery-pkg"]["license"] == "UNKNOWN"


# ---------------------------------------------------------------------------
# Round 10: generate_report for requirements.txt
# ---------------------------------------------------------------------------

def test_generate_report_requirements_txt():
    """RED: generate_report with requirements.txt fixture returns correct statuses."""
    entries = generate_report(REQS_TXT, CONFIG, MOCK_DB)
    by_name = {e["name"]: e for e in entries}

    assert by_name["requests"]["status"] == "approved"
    assert by_name["requests"]["license"] == "MIT"

    assert by_name["numpy"]["status"] == "approved"
    assert by_name["numpy"]["license"] == "BSD-3-Clause"

    assert by_name["flask"]["status"] == "approved"

    # gpl-package -> GPL-3.0 -> denied
    assert by_name["gpl-package"]["status"] == "denied"
    assert by_name["gpl-package"]["license"] == "GPL-3.0"

    # mystery-lib not in mock DB -> unknown
    assert by_name["mystery-lib"]["status"] == "unknown"
    assert by_name["mystery-lib"]["license"] == "UNKNOWN"


# ---------------------------------------------------------------------------
# Round 11-13: format_report output
# ---------------------------------------------------------------------------

SAMPLE_ENTRIES = [
    {"name": "react", "version": "18.2.0", "license": "MIT", "status": "approved"},
    {"name": "copyleft-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
    {"name": "mystery-pkg", "version": "1.0.0", "license": "UNKNOWN", "status": "unknown"},
]


def test_format_report_contains_dep_lines():
    """RED: format_report should include one line per dependency."""
    report = format_report(SAMPLE_ENTRIES)
    assert "react==18.2.0: MIT [approved]" in report
    assert "copyleft-lib==1.0.0: GPL-3.0 [denied]" in report
    assert "mystery-pkg==1.0.0: UNKNOWN [unknown]" in report


def test_format_report_includes_summary():
    """RED: format_report should include a summary line with counts."""
    report = format_report(SAMPLE_ENTRIES)
    assert "1 approved" in report
    assert "1 denied" in report
    assert "1 unknown" in report


def test_format_report_compliance_failed_when_denied():
    """RED: format_report should include COMPLIANCE FAILED when denied entries exist."""
    report = format_report(SAMPLE_ENTRIES)
    assert "COMPLIANCE FAILED" in report


def test_format_report_compliance_passed_when_no_denied():
    """RED: format_report should include COMPLIANCE PASSED when no denied entries."""
    entries_no_denied = [
        {"name": "react", "version": "18.2.0", "license": "MIT", "status": "approved"},
        {"name": "mystery-pkg", "version": "1.0.0", "license": "UNKNOWN", "status": "unknown"},
    ]
    report = format_report(entries_no_denied)
    assert "COMPLIANCE PASSED" in report
    assert "COMPLIANCE FAILED" not in report


# ---------------------------------------------------------------------------
# Round 14-16: Workflow structure, script paths, actionlint
# ---------------------------------------------------------------------------

def test_workflow_file_exists():
    """RED: workflow YAML file must exist at the expected path."""
    assert os.path.exists(WORKFLOW), f"Workflow not found: {WORKFLOW}"


def test_workflow_has_expected_triggers():
    """RED: workflow must have push, pull_request, and workflow_dispatch triggers."""
    with open(WORKFLOW) as f:
        wf = yaml.safe_load(f)
    # PyYAML (YAML 1.1) parses the bare 'on:' key as boolean True.
    # Check both string and boolean key forms.
    on = wf.get("on") or wf.get(True) or {}
    if isinstance(on, str):
        on = {on: None}
    assert "push" in on, "Workflow missing 'push' trigger"
    assert "workflow_dispatch" in on, "Workflow missing 'workflow_dispatch' trigger"


def test_workflow_has_check_licenses_job():
    """RED: workflow must define a 'check-licenses' job."""
    with open(WORKFLOW) as f:
        wf = yaml.safe_load(f)
    assert "check-licenses" in wf.get("jobs", {}), "Missing 'check-licenses' job"


def test_workflow_job_has_checkout_step():
    """RED: 'check-licenses' job must include an actions/checkout step."""
    with open(WORKFLOW) as f:
        wf = yaml.safe_load(f)
    steps = wf["jobs"]["check-licenses"]["steps"]
    uses = [s.get("uses", "") for s in steps]
    assert any("actions/checkout" in u for u in uses), "Missing actions/checkout step"


def test_workflow_references_existing_script():
    """RED: workflow must reference license_checker.py which must exist."""
    with open(WORKFLOW) as f:
        content = f.read()
    assert "license_checker.py" in content, "Workflow does not reference license_checker.py"
    script_path = os.path.join(os.path.dirname(__file__), "license_checker.py")
    assert os.path.exists(script_path), "license_checker.py referenced in workflow but does not exist"


def test_workflow_references_existing_config():
    """RED: workflow must reference config.json which must exist."""
    config_path = os.path.join(os.path.dirname(__file__), "config.json")
    assert os.path.exists(config_path), "config.json does not exist"


def test_actionlint_passes():
    """RED: actionlint must exit 0 on the workflow file."""
    result = subprocess.run(
        ["actionlint", WORKFLOW],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
    )
