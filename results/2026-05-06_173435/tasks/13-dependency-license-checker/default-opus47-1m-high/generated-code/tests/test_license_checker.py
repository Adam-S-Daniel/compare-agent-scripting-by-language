"""Tests for the dependency license checker.

Each test follows red/green TDD: written failing first, then implemented.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from license_checker import (
    LicenseLookupError,
    ManifestParseError,
    check_compliance,
    generate_report,
    parse_manifest,
)


# ---------------------------------------------------------------------------
# parse_manifest: package.json
# ---------------------------------------------------------------------------

def test_parse_package_json_extracts_deps_and_versions(tmp_path: Path) -> None:
    """A package.json with deps + devDeps should yield a flat name->version map."""
    manifest = tmp_path / "package.json"
    manifest.write_text(json.dumps({
        "name": "demo",
        "version": "1.0.0",
        "dependencies": {"left-pad": "^1.3.0", "lodash": "4.17.21"},
        "devDependencies": {"jest": "^29.0.0"},
    }))
    deps = parse_manifest(str(manifest))
    assert deps == {
        "left-pad": "^1.3.0",
        "lodash": "4.17.21",
        "jest": "^29.0.0",
    }


def test_parse_package_json_with_no_deps_returns_empty(tmp_path: Path) -> None:
    manifest = tmp_path / "package.json"
    manifest.write_text(json.dumps({"name": "x", "version": "0.0.1"}))
    assert parse_manifest(str(manifest)) == {}


# ---------------------------------------------------------------------------
# parse_manifest: requirements.txt
# ---------------------------------------------------------------------------

def test_parse_requirements_txt_handles_pinned_and_ranged(tmp_path: Path) -> None:
    manifest = tmp_path / "requirements.txt"
    manifest.write_text(
        "# top-level deps\n"
        "requests==2.31.0\n"
        "flask>=2.0.0\n"
        "numpy~=1.26.0\n"
        "\n"
        "  # indented comment\n"
        "click  # has trailing comment\n"
    )
    deps = parse_manifest(str(manifest))
    assert deps == {
        "requests": "2.31.0",
        "flask": ">=2.0.0",
        "numpy": "~=1.26.0",
        "click": "*",  # unpinned -> "*"
    }


# ---------------------------------------------------------------------------
# parse_manifest: error handling
# ---------------------------------------------------------------------------

def test_parse_manifest_missing_file_raises(tmp_path: Path) -> None:
    with pytest.raises(ManifestParseError, match="not found"):
        parse_manifest(str(tmp_path / "nope.json"))


def test_parse_manifest_unsupported_extension(tmp_path: Path) -> None:
    f = tmp_path / "deps.xml"
    f.write_text("<deps/>")
    with pytest.raises(ManifestParseError, match="[Uu]nsupported"):
        parse_manifest(str(f))


def test_parse_manifest_malformed_json(tmp_path: Path) -> None:
    f = tmp_path / "package.json"
    f.write_text("{not json")
    with pytest.raises(ManifestParseError, match="[Ii]nvalid JSON"):
        parse_manifest(str(f))


# ---------------------------------------------------------------------------
# check_compliance with mocked license lookup
# ---------------------------------------------------------------------------

def _fake_lookup(table: dict[str, str]):
    """Build a fake license lookup function from a name->license dict."""
    def _lookup(name: str, version: str) -> str | None:
        return table.get(name)
    return _lookup


def test_check_compliance_classifies_approved_denied_unknown() -> None:
    deps = {"lodash": "4.17.21", "evil-pkg": "1.0.0", "obscure": "0.1.0"}
    licenses = {"lodash": "MIT", "evil-pkg": "GPL-3.0"}  # obscure -> None
    config = {
        "allow": ["MIT", "Apache-2.0", "BSD-3-Clause"],
        "deny": ["GPL-3.0", "AGPL-3.0"],
    }
    report = check_compliance(deps, config, lookup_license=_fake_lookup(licenses))
    by_name = {entry["name"]: entry for entry in report}
    assert by_name["lodash"]["status"] == "approved"
    assert by_name["lodash"]["license"] == "MIT"
    assert by_name["evil-pkg"]["status"] == "denied"
    assert by_name["obscure"]["status"] == "unknown"
    assert by_name["obscure"]["license"] is None


def test_check_compliance_license_not_in_allow_or_deny_is_unknown() -> None:
    """A license that doesn't match either list is unknown (conservative)."""
    deps = {"weird": "1.0.0"}
    licenses = {"weird": "WTFPL"}
    config = {"allow": ["MIT"], "deny": ["GPL-3.0"]}
    report = check_compliance(deps, config, lookup_license=_fake_lookup(licenses))
    assert report[0]["status"] == "unknown"
    assert report[0]["license"] == "WTFPL"


def test_check_compliance_deny_takes_precedence_over_allow() -> None:
    """If a license is somehow in both lists, deny wins (fail-closed)."""
    deps = {"x": "1.0.0"}
    config = {"allow": ["MIT"], "deny": ["MIT"]}
    report = check_compliance(
        {"x": "1.0.0"}, config, lookup_license=_fake_lookup({"x": "MIT"})
    )
    assert report[0]["status"] == "denied"


def test_check_compliance_lookup_error_marks_unknown() -> None:
    """A lookup that raises LicenseLookupError should not crash the run."""
    def _flaky(name: str, version: str) -> str | None:
        raise LicenseLookupError("registry unreachable")

    report = check_compliance(
        {"a": "1.0.0"}, {"allow": ["MIT"], "deny": []}, lookup_license=_flaky
    )
    assert report[0]["status"] == "unknown"
    assert "registry unreachable" in (report[0].get("error") or "")


def test_check_compliance_is_case_insensitive_on_license_id() -> None:
    """License IDs (SPDX) are case-insensitive in practice."""
    config = {"allow": ["mit"], "deny": ["gpl-3.0"]}
    report = check_compliance(
        {"a": "1.0.0", "b": "1.0.0"},
        config,
        lookup_license=_fake_lookup({"a": "MIT", "b": "GPL-3.0"}),
    )
    by_name = {e["name"]: e for e in report}
    assert by_name["a"]["status"] == "approved"
    assert by_name["b"]["status"] == "denied"


# ---------------------------------------------------------------------------
# generate_report
# ---------------------------------------------------------------------------

def test_generate_report_text_summary_lists_all_statuses() -> None:
    entries = [
        {"name": "lodash", "version": "4.17.21", "license": "MIT", "status": "approved"},
        {"name": "evil", "version": "1.0.0", "license": "GPL-3.0", "status": "denied"},
        {"name": "obscure", "version": "0.1.0", "license": None, "status": "unknown"},
    ]
    text = generate_report(entries, fmt="text")
    assert "lodash" in text and "MIT" in text and "approved" in text
    assert "evil" in text and "GPL-3.0" in text and "denied" in text
    assert "obscure" in text and "unknown" in text
    # Summary line with counts
    assert "approved=1" in text
    assert "denied=1" in text
    assert "unknown=1" in text


def test_generate_report_json_is_parseable_and_round_trips() -> None:
    entries = [
        {"name": "lodash", "version": "4.17.21", "license": "MIT", "status": "approved"},
    ]
    out = generate_report(entries, fmt="json")
    parsed = json.loads(out)
    assert parsed["summary"] == {"approved": 1, "denied": 0, "unknown": 0}
    assert parsed["dependencies"] == entries


def test_generate_report_unknown_format_raises() -> None:
    with pytest.raises(ValueError, match="[Uu]nknown format"):
        generate_report([], fmt="xml")


# ---------------------------------------------------------------------------
# CLI integration: end-to-end against fixtures (still in-process via main())
# ---------------------------------------------------------------------------

def test_cli_main_writes_report_and_returns_exit_code(tmp_path: Path) -> None:
    """End-to-end: build a manifest + config and assert the CLI behavior."""
    from license_checker import main

    manifest = tmp_path / "package.json"
    manifest.write_text(json.dumps({
        "dependencies": {"lodash": "4.17.21", "evil": "1.0.0"},
    }))
    config = tmp_path / "licenses.json"
    config.write_text(json.dumps({
        "allow": ["MIT"],
        "deny": ["GPL-3.0"],
        # Built-in mock license database for deterministic tests
        "mock_licenses": {"lodash": "MIT", "evil": "GPL-3.0"},
    }))
    out_file = tmp_path / "report.json"
    rc = main([
        "--manifest", str(manifest),
        "--config", str(config),
        "--format", "json",
        "--output", str(out_file),
    ])
    assert rc == 1  # any denied dep -> non-zero exit code
    parsed = json.loads(out_file.read_text())
    statuses = {d["name"]: d["status"] for d in parsed["dependencies"]}
    assert statuses == {"lodash": "approved", "evil": "denied"}


def test_cli_main_returns_zero_when_all_approved(tmp_path: Path) -> None:
    from license_checker import main

    manifest = tmp_path / "requirements.txt"
    manifest.write_text("requests==2.31.0\n")
    config = tmp_path / "cfg.json"
    config.write_text(json.dumps({
        "allow": ["Apache-2.0"],
        "deny": ["GPL-3.0"],
        "mock_licenses": {"requests": "Apache-2.0"},
    }))
    rc = main([
        "--manifest", str(manifest),
        "--config", str(config),
        "--format", "text",
    ])
    assert rc == 0
