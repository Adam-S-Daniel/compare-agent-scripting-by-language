"""
TDD test suite for the dependency license checker.

Each `test_...` function documents one red/green TDD cycle. We write the test
first, confirm it fails, then implement just enough to make it pass.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

# Ensure the project root is importable when pytest is invoked from anywhere.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import license_checker as lc  # noqa: E402


# ---------------------------------------------------------------------------
# TDD cycle 1: parse requirements.txt
# ---------------------------------------------------------------------------

def test_parse_requirements_txt_basic():
    """Simple `name==version` lines produce a list of (name, version) pairs."""
    content = "requests==2.31.0\nflask==3.0.0\n"
    assert lc.parse_requirements_txt(content) == [
        ("requests", "2.31.0"),
        ("flask", "3.0.0"),
    ]


def test_parse_requirements_txt_ignores_blanks_and_comments():
    """Blank lines and `#` comments are skipped."""
    content = "# a comment\n\nrequests==2.31.0\n  # indented\n"
    assert lc.parse_requirements_txt(content) == [("requests", "2.31.0")]


def test_parse_requirements_txt_supports_unpinned():
    """A dependency without `==` gets a version of `unknown`."""
    content = "requests\nflask==3.0.0\n"
    assert lc.parse_requirements_txt(content) == [
        ("requests", "unknown"),
        ("flask", "3.0.0"),
    ]


def test_parse_requirements_txt_strips_inline_comments():
    """Inline comments after a dependency are stripped."""
    content = "requests==2.31.0  # HTTP client\n"
    assert lc.parse_requirements_txt(content) == [("requests", "2.31.0")]


# ---------------------------------------------------------------------------
# TDD cycle 2: parse package.json
# ---------------------------------------------------------------------------

def test_parse_package_json_merges_dependencies_and_dev():
    """`dependencies` and `devDependencies` are both included; versions preserved."""
    payload = {
        "name": "demo",
        "dependencies": {"lodash": "^4.17.21"},
        "devDependencies": {"jest": "29.7.0"},
    }
    result = lc.parse_package_json(json.dumps(payload))
    assert sorted(result) == [("jest", "29.7.0"), ("lodash", "^4.17.21")]


def test_parse_package_json_empty_object_yields_empty_list():
    assert lc.parse_package_json("{}") == []


def test_parse_package_json_invalid_json_raises_value_error():
    with pytest.raises(ValueError, match="invalid package.json"):
        lc.parse_package_json("not-json")


# ---------------------------------------------------------------------------
# TDD cycle 3: license lookup (mockable)
# ---------------------------------------------------------------------------

def test_license_lookup_reads_from_mock_mapping():
    """The default lookup consults a dict; this is how tests inject data."""
    mapping = {"requests": "Apache-2.0", "flask": "BSD-3-Clause"}
    lookup = lc.make_mock_lookup(mapping)
    assert lookup("requests", "2.31.0") == "Apache-2.0"
    assert lookup("flask", "3.0.0") == "BSD-3-Clause"


def test_license_lookup_returns_none_for_unknown_package():
    """Unknown packages yield `None` so the classifier can mark them UNKNOWN."""
    lookup = lc.make_mock_lookup({"requests": "Apache-2.0"})
    assert lookup("mystery-lib", "1.0.0") is None


# ---------------------------------------------------------------------------
# TDD cycle 4: classify license
# ---------------------------------------------------------------------------

def test_classify_license_approved_when_in_allow_list():
    assert lc.classify_license("Apache-2.0", ["Apache-2.0", "MIT"], ["GPL-3.0"]) == "approved"


def test_classify_license_denied_when_in_deny_list():
    assert lc.classify_license("GPL-3.0", ["Apache-2.0"], ["GPL-3.0"]) == "denied"


def test_classify_license_unknown_when_license_missing():
    assert lc.classify_license(None, ["Apache-2.0"], ["GPL-3.0"]) == "unknown"


def test_classify_license_unknown_when_license_not_listed():
    """Licenses on neither list are unknown, not implicitly approved."""
    assert lc.classify_license("WTFPL", ["Apache-2.0"], ["GPL-3.0"]) == "unknown"


def test_classify_license_deny_wins_over_allow():
    """If a license somehow appears on both lists, deny takes precedence
    (fail-safe default for compliance)."""
    assert lc.classify_license("MIT", ["MIT"], ["MIT"]) == "denied"


# ---------------------------------------------------------------------------
# TDD cycle 5: generate compliance report
# ---------------------------------------------------------------------------

def test_generate_report_produces_entry_per_dependency():
    deps = [("requests", "2.31.0"), ("evil-lib", "0.1.0"), ("mystery", "1.0.0")]
    lookup = lc.make_mock_lookup({
        "requests": "Apache-2.0",
        "evil-lib": "GPL-3.0",
    })
    report = lc.generate_report(
        deps,
        lookup=lookup,
        allow_list=["Apache-2.0", "MIT"],
        deny_list=["GPL-3.0"],
    )
    assert report["summary"] == {"approved": 1, "denied": 1, "unknown": 1, "total": 3}
    by_name = {entry["name"]: entry for entry in report["dependencies"]}
    assert by_name["requests"]["status"] == "approved"
    assert by_name["requests"]["license"] == "Apache-2.0"
    assert by_name["evil-lib"]["status"] == "denied"
    assert by_name["mystery"]["status"] == "unknown"
    assert by_name["mystery"]["license"] is None


def test_generate_report_overall_status_fails_when_any_denied():
    deps = [("evil-lib", "1.0.0")]
    lookup = lc.make_mock_lookup({"evil-lib": "GPL-3.0"})
    report = lc.generate_report(deps, lookup=lookup, allow_list=[], deny_list=["GPL-3.0"])
    assert report["overall"] == "fail"


def test_generate_report_overall_status_passes_when_all_approved():
    deps = [("requests", "2.31.0")]
    lookup = lc.make_mock_lookup({"requests": "MIT"})
    report = lc.generate_report(deps, lookup=lookup, allow_list=["MIT"], deny_list=["GPL-3.0"])
    assert report["overall"] == "pass"


def test_generate_report_overall_warns_when_unknown_but_none_denied():
    """If nothing is denied but some licenses are unknown, we warn (not fail).
    Teams usually want to investigate unknowns, not block the build on them."""
    deps = [("mystery", "1.0.0")]
    lookup = lc.make_mock_lookup({})
    report = lc.generate_report(deps, lookup=lookup, allow_list=["MIT"], deny_list=["GPL-3.0"])
    assert report["overall"] == "warn"


# ---------------------------------------------------------------------------
# TDD cycle 6: CLI entry point
# ---------------------------------------------------------------------------

SCRIPT = ROOT / "license_checker.py"


def _run_cli(args, cwd):
    """Helper: run the CLI, returning (rc, stdout, stderr)."""
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_reports_all_approved(tmp_path):
    """CLI reads a manifest + config, prints JSON, exits 0 when all approved."""
    (tmp_path / "requirements.txt").write_text("requests==2.31.0\nflask==3.0.0\n")
    (tmp_path / "licenses.json").write_text(json.dumps({
        "allow": ["Apache-2.0", "BSD-3-Clause"],
        "deny": ["GPL-3.0"],
        "mock_licenses": {
            "requests": "Apache-2.0",
            "flask": "BSD-3-Clause",
        },
    }))
    rc, stdout, _ = _run_cli(
        ["--manifest", "requirements.txt", "--config", "licenses.json"],
        cwd=tmp_path,
    )
    assert rc == 0, stdout
    data = json.loads(stdout)
    assert data["overall"] == "pass"
    assert data["summary"] == {"approved": 2, "denied": 0, "unknown": 0, "total": 2}


def test_cli_exit_code_2_when_any_denied(tmp_path):
    """A denied license is a compliance failure, so the CLI exits non-zero."""
    (tmp_path / "requirements.txt").write_text("evil==1.0.0\n")
    (tmp_path / "licenses.json").write_text(json.dumps({
        "allow": ["MIT"],
        "deny": ["GPL-3.0"],
        "mock_licenses": {"evil": "GPL-3.0"},
    }))
    rc, stdout, _ = _run_cli(
        ["--manifest", "requirements.txt", "--config", "licenses.json"],
        cwd=tmp_path,
    )
    assert rc == 2, stdout
    data = json.loads(stdout)
    assert data["overall"] == "fail"


def test_cli_exit_code_1_when_unknown(tmp_path):
    """Unknown-only (no denied) is a warning — exit code 1."""
    (tmp_path / "requirements.txt").write_text("mystery==1.0.0\n")
    (tmp_path / "licenses.json").write_text(json.dumps({
        "allow": ["MIT"],
        "deny": ["GPL-3.0"],
        "mock_licenses": {},
    }))
    rc, _, _ = _run_cli(
        ["--manifest", "requirements.txt", "--config", "licenses.json"],
        cwd=tmp_path,
    )
    assert rc == 1


def test_cli_supports_package_json(tmp_path):
    """CLI auto-detects package.json vs requirements.txt from the filename."""
    (tmp_path / "package.json").write_text(json.dumps({
        "name": "demo",
        "dependencies": {"lodash": "^4.17.21"},
    }))
    (tmp_path / "licenses.json").write_text(json.dumps({
        "allow": ["MIT"],
        "deny": [],
        "mock_licenses": {"lodash": "MIT"},
    }))
    rc, stdout, _ = _run_cli(
        ["--manifest", "package.json", "--config", "licenses.json"],
        cwd=tmp_path,
    )
    assert rc == 0, stdout
    assert json.loads(stdout)["overall"] == "pass"


def test_cli_missing_manifest_prints_clear_error(tmp_path):
    """Missing manifest yields a friendly error, not a Python traceback."""
    (tmp_path / "licenses.json").write_text('{"allow":[],"deny":[],"mock_licenses":{}}')
    rc, _, stderr = _run_cli(
        ["--manifest", "does-not-exist.txt", "--config", "licenses.json"],
        cwd=tmp_path,
    )
    assert rc != 0
    assert "does-not-exist.txt" in stderr
    assert "Traceback" not in stderr


def test_cli_unsupported_manifest_format(tmp_path):
    """Unsupported manifest extensions produce a clear error message."""
    (tmp_path / "Gemfile").write_text("gem 'rails'\n")
    (tmp_path / "licenses.json").write_text('{"allow":[],"deny":[],"mock_licenses":{}}')
    rc, _, stderr = _run_cli(
        ["--manifest", "Gemfile", "--config", "licenses.json"],
        cwd=tmp_path,
    )
    assert rc != 0
    assert "unsupported" in stderr.lower()
