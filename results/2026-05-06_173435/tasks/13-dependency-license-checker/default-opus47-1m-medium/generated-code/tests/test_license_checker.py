"""TDD test suite for license_checker.

Each test was written first (red), code added next (green), then refactored.
Tests cover: manifest parsing, license lookup mocking, allow/deny enforcement,
unknown handling, report generation, error handling, and CLI integration.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from license_checker import (  # noqa: E402
    LicenseChecker,
    Status,
    check_dependencies,
    generate_report,
    load_config,
    parse_manifest,
)


# --- parse_manifest -----------------------------------------------------

def test_parse_manifest_package_json(tmp_path):
    manifest = tmp_path / "package.json"
    manifest.write_text(json.dumps({
        "dependencies": {"left-pad": "1.3.0", "react": "^18.0.0"},
        "devDependencies": {"jest": "29.0.0"},
    }))
    deps = parse_manifest(str(manifest))
    assert deps == {"left-pad": "1.3.0", "react": "^18.0.0", "jest": "29.0.0"}


def test_parse_manifest_requirements_txt(tmp_path):
    manifest = tmp_path / "requirements.txt"
    manifest.write_text(
        "# comment line\n"
        "requests==2.31.0\n"
        "flask>=2.0\n"
        "\n"
        "numpy~=1.24\n"
    )
    deps = parse_manifest(str(manifest))
    assert deps == {"requests": "2.31.0", "flask": ">=2.0", "numpy": "~=1.24"}


def test_parse_manifest_missing_file_raises(tmp_path):
    with pytest.raises(FileNotFoundError) as excinfo:
        parse_manifest(str(tmp_path / "nope.json"))
    assert "nope.json" in str(excinfo.value)


def test_parse_manifest_invalid_json_raises(tmp_path):
    manifest = tmp_path / "package.json"
    manifest.write_text("{not valid json")
    with pytest.raises(ValueError) as excinfo:
        parse_manifest(str(manifest))
    assert "package.json" in str(excinfo.value)


def test_parse_manifest_unsupported_extension(tmp_path):
    manifest = tmp_path / "Cargo.lock"
    manifest.write_text("anything")
    with pytest.raises(ValueError) as excinfo:
        parse_manifest(str(manifest))
    assert "Unsupported manifest" in str(excinfo.value)


# --- load_config --------------------------------------------------------

def test_load_config_reads_allow_and_deny(tmp_path):
    cfg_path = tmp_path / "policy.json"
    cfg_path.write_text(json.dumps({
        "allow": ["MIT", "Apache-2.0"],
        "deny": ["GPL-3.0"],
    }))
    cfg = load_config(str(cfg_path))
    # Stored normalized to upper-case for case-insensitive matching.
    assert cfg.allow == {"MIT", "APACHE-2.0"}
    assert cfg.deny == {"GPL-3.0"}


def test_load_config_normalizes_case(tmp_path):
    """License names are case-insensitive (MIT == mit)."""
    cfg_path = tmp_path / "policy.json"
    cfg_path.write_text(json.dumps({"allow": ["mit"], "deny": ["gpl-3.0"]}))
    cfg = load_config(str(cfg_path))
    assert "MIT" in cfg.allow
    assert "GPL-3.0" in cfg.deny


# --- LicenseChecker (uses a mock lookup) --------------------------------

def test_check_dependency_approved_when_license_in_allow():
    """Approved: license found in allow-list."""
    lookup = {"left-pad": "MIT"}.get
    checker = LicenseChecker(allow={"MIT"}, deny=set(), lookup=lookup)
    result = checker.check("left-pad", "1.3.0")
    assert result.status == Status.APPROVED
    assert result.license == "MIT"


def test_check_dependency_denied_when_license_in_deny():
    lookup = {"some-pkg": "GPL-3.0"}.get
    checker = LicenseChecker(allow={"MIT"}, deny={"GPL-3.0"}, lookup=lookup)
    result = checker.check("some-pkg", "1.0.0")
    assert result.status == Status.DENIED


def test_check_dependency_unknown_when_no_license_returned():
    """Unknown: lookup returns None."""
    lookup = lambda name: None
    checker = LicenseChecker(allow={"MIT"}, deny=set(), lookup=lookup)
    result = checker.check("mystery", "0.1")
    assert result.status == Status.UNKNOWN
    assert result.license is None


def test_check_dependency_unknown_when_license_not_in_either_list():
    """License known but matches neither list -> unknown status."""
    lookup = {"weirdpkg": "WTFPL"}.get
    checker = LicenseChecker(allow={"MIT"}, deny={"GPL-3.0"}, lookup=lookup)
    result = checker.check("weirdpkg", "1.0")
    assert result.status == Status.UNKNOWN
    assert result.license == "WTFPL"


def test_check_dependency_deny_takes_precedence_over_allow():
    """If a license is in both lists, deny wins (fail-safe)."""
    lookup = {"pkg": "MIT"}.get
    checker = LicenseChecker(allow={"MIT"}, deny={"MIT"}, lookup=lookup)
    result = checker.check("pkg", "1.0")
    assert result.status == Status.DENIED


# --- check_dependencies -------------------------------------------------

def test_check_dependencies_returns_one_result_per_dep():
    deps = {"a": "1.0", "b": "2.0", "c": "3.0"}
    lookup = {"a": "MIT", "b": "GPL-3.0"}.get  # c is unknown
    results = check_dependencies(
        deps, allow={"MIT"}, deny={"GPL-3.0"}, lookup=lookup
    )
    by_name = {r.name: r for r in results}
    assert by_name["a"].status == Status.APPROVED
    assert by_name["b"].status == Status.DENIED
    assert by_name["c"].status == Status.UNKNOWN


# --- generate_report ----------------------------------------------------

def test_generate_report_text_lists_each_dependency():
    from license_checker import Result
    results = [
        Result("a", "1.0", "MIT", Status.APPROVED),
        Result("b", "2.0", "GPL-3.0", Status.DENIED),
        Result("c", "3.0", None, Status.UNKNOWN),
    ]
    text = generate_report(results, fmt="text")
    assert "a@1.0" in text
    assert "MIT" in text
    assert "APPROVED" in text
    assert "b@2.0" in text
    assert "DENIED" in text
    assert "c@3.0" in text
    assert "UNKNOWN" in text


def test_generate_report_includes_summary_counts():
    from license_checker import Result
    results = [
        Result("a", "1", "MIT", Status.APPROVED),
        Result("b", "1", "MIT", Status.APPROVED),
        Result("c", "1", "GPL-3.0", Status.DENIED),
        Result("d", "1", None, Status.UNKNOWN),
    ]
    text = generate_report(results, fmt="text")
    assert "approved: 2" in text.lower()
    assert "denied: 1" in text.lower()
    assert "unknown: 1" in text.lower()


def test_generate_report_json_format():
    from license_checker import Result
    results = [Result("a", "1.0", "MIT", Status.APPROVED)]
    payload = json.loads(generate_report(results, fmt="json"))
    assert payload["summary"]["approved"] == 1
    assert payload["dependencies"][0]["name"] == "a"
    assert payload["dependencies"][0]["status"] == "approved"


# --- CLI integration ----------------------------------------------------

def _make_fixture(tmp_path, manifest_name, manifest_content, policy):
    manifest = tmp_path / manifest_name
    if isinstance(manifest_content, dict):
        manifest.write_text(json.dumps(manifest_content))
    else:
        manifest.write_text(manifest_content)
    policy_file = tmp_path / "policy.json"
    policy_file.write_text(json.dumps(policy))
    return manifest, policy_file


def _run_cli(*args, cwd=None):
    """Run the CLI as a subprocess so we exercise __main__ wiring."""
    return subprocess.run(
        [sys.executable, str(ROOT / "license_checker.py"), *args],
        capture_output=True, text=True, cwd=cwd,
    )


def test_cli_exits_zero_when_all_approved(tmp_path):
    manifest, policy = _make_fixture(
        tmp_path, "package.json",
        {"dependencies": {"left-pad": "1.3.0"}},
        {"allow": ["MIT"], "deny": ["GPL-3.0"]},
    )
    proc = _run_cli(
        "--manifest", str(manifest),
        "--config", str(policy),
        "--mock-licenses", json.dumps({"left-pad": "MIT"}),
    )
    assert proc.returncode == 0, proc.stderr
    assert "APPROVED" in proc.stdout


def test_cli_exits_nonzero_when_denied(tmp_path):
    manifest, policy = _make_fixture(
        tmp_path, "package.json",
        {"dependencies": {"badpkg": "1.0"}},
        {"allow": ["MIT"], "deny": ["GPL-3.0"]},
    )
    proc = _run_cli(
        "--manifest", str(manifest),
        "--config", str(policy),
        "--mock-licenses", json.dumps({"badpkg": "GPL-3.0"}),
    )
    assert proc.returncode != 0
    assert "DENIED" in proc.stdout


def test_cli_json_output(tmp_path):
    manifest, policy = _make_fixture(
        tmp_path, "requirements.txt",
        "requests==2.31.0\n",
        {"allow": ["Apache-2.0"], "deny": []},
    )
    proc = _run_cli(
        "--manifest", str(manifest),
        "--config", str(policy),
        "--format", "json",
        "--mock-licenses", json.dumps({"requests": "Apache-2.0"}),
    )
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["summary"]["approved"] == 1


def test_cli_friendly_error_for_missing_manifest(tmp_path):
    policy = tmp_path / "p.json"
    policy.write_text(json.dumps({"allow": [], "deny": []}))
    proc = _run_cli(
        "--manifest", str(tmp_path / "missing.json"),
        "--config", str(policy),
    )
    assert proc.returncode != 0
    assert "missing.json" in (proc.stderr + proc.stdout)
