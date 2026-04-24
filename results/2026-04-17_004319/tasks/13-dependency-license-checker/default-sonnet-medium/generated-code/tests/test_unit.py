"""
Dependency License Checker — Unit Tests (TDD)

TDD order:
  1. Parse package.json        → implement parse_package_json
  2. Parse requirements.txt    → implement parse_requirements_txt
  3. parse_manifest dispatch   → implement parse_manifest
  4. License lookup (mock DB)  → implement lookup_license
  5. Status classification     → implement check_license_status
  6. Dependency checking       → implement check_dependencies
  7. Report formatting         → implement format_report
  8. Error handling            → validate error paths

These tests are run both locally and inside the GitHub Actions workflow.
"""
import json
import pytest
from pathlib import Path


# ============================================================
# STEP 1: Parse package.json
# Written first — fails until parse_package_json is implemented
# ============================================================

def test_parse_package_json_extracts_dependencies(tmp_path):
    """dependencies and devDependencies are both extracted."""
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({
        "name": "test",
        "dependencies": {"react": "18.0.0", "lodash": "4.17.21"},
        "devDependencies": {"jest": "29.0.0"},
    }))
    from license_checker import parse_package_json
    deps = parse_package_json(str(pkg))
    assert deps == {"react": "18.0.0", "lodash": "4.17.21", "jest": "29.0.0"}


def test_parse_package_json_strips_semver_prefixes(tmp_path):
    """Range prefixes like ^ and ~ are stripped from version strings."""
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({
        "dependencies": {"react": "^18.2.0", "lodash": "~4.17.21"},
    }))
    from license_checker import parse_package_json
    deps = parse_package_json(str(pkg))
    assert deps["react"] == "18.2.0"
    assert deps["lodash"] == "4.17.21"


def test_parse_package_json_empty_returns_empty(tmp_path):
    """package.json with no dependency sections → empty dict."""
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"name": "test", "version": "1.0.0"}))
    from license_checker import parse_package_json
    assert parse_package_json(str(pkg)) == {}


def test_parse_package_json_invalid_json_raises(tmp_path):
    """Invalid JSON raises an error."""
    pkg = tmp_path / "package.json"
    pkg.write_text("not json {{")
    from license_checker import parse_package_json
    with pytest.raises(Exception):
        parse_package_json(str(pkg))


# ============================================================
# STEP 2: Parse requirements.txt
# Written second — fails until parse_requirements_txt is implemented
# ============================================================

def test_parse_requirements_txt_pin_operator(tmp_path):
    """== operator extracts name and version."""
    req = tmp_path / "requirements.txt"
    req.write_text("requests==2.28.0\nflask==2.3.2\n")
    from license_checker import parse_requirements_txt
    deps = parse_requirements_txt(str(req))
    assert deps == {"requests": "2.28.0", "flask": "2.3.2"}


def test_parse_requirements_txt_skips_comments_and_blanks(tmp_path):
    """Comments (#) and blank lines are ignored."""
    req = tmp_path / "requirements.txt"
    req.write_text("# a comment\n\nrequests==2.28.0\n")
    from license_checker import parse_requirements_txt
    deps = parse_requirements_txt(str(req))
    assert deps == {"requests": "2.28.0"}


def test_parse_requirements_txt_no_version_becomes_wildcard(tmp_path):
    """Package with no version specifier gets '*'."""
    req = tmp_path / "requirements.txt"
    req.write_text("requests\n")
    from license_checker import parse_requirements_txt
    deps = parse_requirements_txt(str(req))
    assert deps == {"requests": "*"}


def test_parse_requirements_txt_gte_operator(tmp_path):
    """>=operator extracts the lower-bound version."""
    req = tmp_path / "requirements.txt"
    req.write_text("flask>=2.3.0\n")
    from license_checker import parse_requirements_txt
    deps = parse_requirements_txt(str(req))
    assert deps["flask"] == "2.3.0"


# ============================================================
# STEP 3: parse_manifest dispatch
# ============================================================

def test_parse_manifest_routes_by_filename_package_json(tmp_path):
    """parse_manifest dispatches to package.json parser."""
    pkg = tmp_path / "package.json"
    pkg.write_text(json.dumps({"dependencies": {"foo": "1.0.0"}}))
    from license_checker import parse_manifest
    deps = parse_manifest(str(pkg))
    assert "foo" in deps


def test_parse_manifest_routes_by_filename_requirements_txt(tmp_path):
    """parse_manifest dispatches to requirements.txt parser."""
    req = tmp_path / "requirements.txt"
    req.write_text("foo==1.0.0\n")
    from license_checker import parse_manifest
    deps = parse_manifest(str(req))
    assert "foo" in deps


def test_parse_manifest_unsupported_format_raises_value_error(tmp_path):
    """Unsupported manifest format raises ValueError with 'Unsupported' in message."""
    f = tmp_path / "Pipfile"
    f.write_text("[packages]")
    from license_checker import parse_manifest
    with pytest.raises(ValueError, match="Unsupported"):
        parse_manifest(str(f))


# ============================================================
# STEP 4: License lookup against mock database
# ============================================================

def test_lookup_license_exact_version_key_wins():
    """name@version key takes priority over name-only key."""
    from license_checker import lookup_license
    db = {"react@18.0.0": "MIT", "react": "Apache-2.0"}
    assert lookup_license("react", "18.0.0", db) == "MIT"


def test_lookup_license_name_only_fallback():
    """Falls back to name-only key when exact version is absent."""
    from license_checker import lookup_license
    db = {"react": "MIT"}
    assert lookup_license("react", "18.0.0", db) == "MIT"


def test_lookup_license_not_found_returns_none():
    """Returns None when package is not in the database."""
    from license_checker import lookup_license
    assert lookup_license("mystery-pkg", "1.0.0", {}) is None


# ============================================================
# STEP 5: License status classification
# ============================================================

def test_check_status_approved_when_on_allow_list():
    from license_checker import check_license_status
    assert check_license_status("MIT", ["MIT", "Apache-2.0"], ["GPL-3.0"]) == "approved"


def test_check_status_denied_when_on_deny_list():
    from license_checker import check_license_status
    assert check_license_status("GPL-3.0", ["MIT"], ["GPL-3.0"]) == "denied"


def test_check_status_unknown_when_not_in_either_list():
    from license_checker import check_license_status
    assert check_license_status("CUSTOM", ["MIT"], ["GPL-3.0"]) == "unknown"


def test_check_status_unknown_when_license_is_none():
    """None (lookup failed) → unknown."""
    from license_checker import check_license_status
    assert check_license_status(None, ["MIT"], ["GPL-3.0"]) == "unknown"


def test_check_status_deny_list_beats_allow_list():
    """Deny list takes precedence — same license in both → denied."""
    from license_checker import check_license_status
    assert check_license_status("MIT", ["MIT"], ["MIT"]) == "denied"


# ============================================================
# STEP 6: check_dependencies — full list processing
# ============================================================

def test_check_dependencies_results_sorted_by_name():
    """Results are sorted alphabetically by package name."""
    from license_checker import check_dependencies
    deps = {"zebra": "1.0.0", "alpha": "2.0.0"}
    db = {"zebra": "MIT", "alpha": "MIT"}
    results = check_dependencies(deps, ["MIT"], [], db)
    assert results[0]["name"] == "alpha"
    assert results[1]["name"] == "zebra"


def test_check_dependencies_result_fields():
    """Each result has name, version, license, status fields."""
    from license_checker import check_dependencies
    results = check_dependencies({"react": "18.0.0"}, ["MIT"], [], {"react": "MIT"})
    r = results[0]
    assert r["name"] == "react"
    assert r["version"] == "18.0.0"
    assert r["license"] == "MIT"
    assert r["status"] == "approved"


def test_check_dependencies_unknown_license_string_not_none():
    """Unknown license field shows string 'unknown', not None."""
    from license_checker import check_dependencies
    results = check_dependencies({"mystery": "1.0.0"}, ["MIT"], [], {})
    assert results[0]["license"] == "unknown"
    assert results[0]["status"] == "unknown"


# ============================================================
# STEP 7: Report formatting
# ============================================================

def test_format_report_passed_with_no_denied():
    """Report shows COMPLIANCE CHECK PASSED when no denied packages."""
    from license_checker import format_report
    results = [
        {"name": "react", "version": "18.0.0", "license": "MIT", "status": "approved"},
    ]
    output = format_report(results)
    assert "COMPLIANCE CHECK PASSED" in output
    assert "1 approved" in output
    assert "0 denied" in output
    assert "0 unknown" in output


def test_format_report_failed_with_denied():
    """Report shows COMPLIANCE CHECK FAILED when any package is denied."""
    from license_checker import format_report
    results = [
        {"name": "gpl-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
    ]
    output = format_report(results)
    assert "COMPLIANCE CHECK FAILED" in output
    assert "1 denied" in output


def test_format_report_lists_all_dependencies():
    """Every dependency appears in the report with its status."""
    from license_checker import format_report
    results = [
        {"name": "react", "version": "18.0.0", "license": "MIT", "status": "approved"},
        {"name": "gpl-lib", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
        {"name": "mystery", "version": "2.0.0", "license": "unknown", "status": "unknown"},
    ]
    output = format_report(results)
    assert "react" in output and "APPROVED" in output
    assert "gpl-lib" in output and "DENIED" in output
    assert "mystery" in output and "UNKNOWN" in output


# ============================================================
# STEP 8: Error handling
# ============================================================

def test_parse_manifest_missing_file_raises():
    """Missing manifest file raises FileNotFoundError."""
    from license_checker import parse_manifest
    with pytest.raises(Exception):
        parse_manifest("/nonexistent/package.json")


def test_main_missing_args_returns_nonzero():
    """main() with too few args returns exit code 1."""
    from license_checker import main
    assert main([]) == 1


def test_main_missing_manifest_returns_nonzero(tmp_path):
    """main() with nonexistent manifest returns exit code 1."""
    cfg = tmp_path / "config.json"
    cfg.write_text(json.dumps({"allow": ["MIT"], "deny": []}))
    from license_checker import main
    assert main(["/nonexistent/package.json", str(cfg)]) == 1
