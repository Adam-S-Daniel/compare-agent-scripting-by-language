"""
Tests for the secret rotation validator, written in red/green TDD style.

Each test targets one unit of behavior. During development each test was written
first and failed (red), the minimum code was added to pass (green), then the
code was refactored. The batch is kept together here for readability.
"""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path

import pytest

from secret_rotation import (
    classify_secret,
    classify_secrets,
    format_json_report,
    format_markdown,
    group_by_urgency,
    load_config,
    main,
    run,
    validate_config,
)


# ---------------------------------------------------------------------------
# classify_secret / classify_secrets
# ---------------------------------------------------------------------------

def _secret(name="db-password", last_rotated="2026-01-01", policy=90,
            required_by=None):
    return {
        "name": name,
        "last_rotated": last_rotated,
        "rotation_policy_days": policy,
        "required_by": required_by if required_by is not None else ["api"],
    }


def test_classify_expired_when_past_due():
    # last_rotated + policy (2026-01-01 + 90 = 2026-04-01) is before 2026-04-19
    result = classify_secret(_secret(), date(2026, 4, 19), warning_days=7)
    assert result["status"] == "expired"
    assert result["days_until_expiry"] < 0
    assert result["expires_on"] == "2026-04-01"


def test_classify_warning_when_within_window():
    # Expires 2026-04-25, current 2026-04-19, warning 7 -> WARNING (6 days left)
    secret = _secret(last_rotated="2026-01-25", policy=90)
    result = classify_secret(secret, date(2026, 4, 19), warning_days=7)
    assert result["status"] == "warning"
    assert result["days_until_expiry"] == 6


def test_classify_ok_when_outside_window():
    secret = _secret(last_rotated="2026-04-01", policy=90)
    result = classify_secret(secret, date(2026, 4, 19), warning_days=7)
    assert result["status"] == "ok"
    assert result["days_until_expiry"] == 72


def test_classify_boundary_exactly_on_warning_edge_is_warning():
    # 7 days until expiry with warning_days=7 -> WARNING (inclusive edge)
    secret = _secret(last_rotated="2026-01-26", policy=90)  # expires 2026-04-26
    result = classify_secret(secret, date(2026, 4, 19), warning_days=7)
    assert result["status"] == "warning"
    assert result["days_until_expiry"] == 7


def test_classify_secrets_preserves_order_and_fields():
    cfg = [_secret(name="a"), _secret(name="b")]
    classified = classify_secrets(cfg, date(2026, 4, 19), warning_days=7)
    assert [s["name"] for s in classified] == ["a", "b"]
    assert all("status" in s for s in classified)


# ---------------------------------------------------------------------------
# group_by_urgency
# ---------------------------------------------------------------------------

def test_group_by_urgency_partitions_into_three_buckets():
    classified = [
        {"name": "x", "status": "ok", "days_until_expiry": 30},
        {"name": "y", "status": "expired", "days_until_expiry": -2},
        {"name": "z", "status": "warning", "days_until_expiry": 3},
        {"name": "zz", "status": "warning", "days_until_expiry": 1},
    ]
    groups = group_by_urgency(classified)
    assert [s["name"] for s in groups["expired"]] == ["y"]
    # warnings sorted by days_until_expiry ascending (most urgent first)
    assert [s["name"] for s in groups["warning"]] == ["zz", "z"]
    assert [s["name"] for s in groups["ok"]] == ["x"]


# ---------------------------------------------------------------------------
# format_markdown
# ---------------------------------------------------------------------------

def test_format_markdown_contains_section_headers_and_counts():
    groups = {
        "expired": [{
            "name": "db", "last_rotated": "2025-01-01",
            "rotation_policy_days": 90, "expires_on": "2025-04-01",
            "days_until_expiry": -20, "required_by": ["api"],
            "status": "expired",
        }],
        "warning": [],
        "ok": [],
    }
    md = format_markdown(groups)
    assert "# Secret Rotation Report" in md
    assert "## EXPIRED (1)" in md
    assert "## WARNING (0)" in md
    assert "## OK (0)" in md
    # table row for db
    assert "| db |" in md
    assert "api" in md


def test_format_markdown_shows_none_placeholder_for_empty_group():
    groups = {"expired": [], "warning": [], "ok": []}
    md = format_markdown(groups)
    assert md.count("_None_") == 3


# ---------------------------------------------------------------------------
# format_json_report
# ---------------------------------------------------------------------------

def test_format_json_report_includes_summary_and_groups():
    groups = {
        "expired": [],
        "warning": [{"name": "w", "status": "warning", "days_until_expiry": 3,
                     "last_rotated": "2026-03-01", "rotation_policy_days": 30,
                     "expires_on": "2026-03-31", "required_by": ["svc"]}],
        "ok": [],
    }
    payload = json.loads(format_json_report(groups))
    assert payload["summary"] == {"expired": 0, "warning": 1, "ok": 0}
    assert payload["groups"]["warning"][0]["name"] == "w"


# ---------------------------------------------------------------------------
# load_config / validate_config
# ---------------------------------------------------------------------------

def test_load_config_reads_valid_json(tmp_path: Path):
    cfg_path = tmp_path / "c.json"
    cfg_path.write_text(json.dumps({"secrets": []}))
    assert load_config(cfg_path) == {"secrets": []}


def test_load_config_raises_for_missing_file(tmp_path: Path):
    with pytest.raises(FileNotFoundError) as exc:
        load_config(tmp_path / "nope.json")
    assert "not found" in str(exc.value).lower()


def test_load_config_raises_for_invalid_json(tmp_path: Path):
    cfg_path = tmp_path / "bad.json"
    cfg_path.write_text("{not json")
    with pytest.raises(ValueError) as exc:
        load_config(cfg_path)
    assert "invalid json" in str(exc.value).lower()


def test_validate_config_rejects_missing_secrets_list():
    with pytest.raises(ValueError):
        validate_config({})


def test_validate_config_rejects_incomplete_secret():
    bad = {"secrets": [{"name": "x"}]}
    with pytest.raises(ValueError) as exc:
        validate_config(bad)
    assert "missing" in str(exc.value).lower()


# ---------------------------------------------------------------------------
# run() end-to-end in process
# ---------------------------------------------------------------------------

def test_run_returns_markdown_and_groups(tmp_path: Path):
    cfg = {
        "current_date": "2026-04-19",
        "warning_days": 7,
        "format": "markdown",
        "secrets": [
            _secret(name="expired-key", last_rotated="2026-01-01", policy=30),
            _secret(name="warn-key", last_rotated="2026-01-25", policy=90),
            _secret(name="ok-key", last_rotated="2026-04-10", policy=60),
        ],
    }
    p = tmp_path / "s.json"
    p.write_text(json.dumps(cfg))
    report, groups = run(p, warning_days=None, output_format=None, current_date=None)
    assert "# Secret Rotation Report" in report
    assert len(groups["expired"]) == 1
    assert len(groups["warning"]) == 1
    assert len(groups["ok"]) == 1


def test_run_emits_valid_json_when_format_json(tmp_path: Path):
    cfg = {
        "current_date": "2026-04-19",
        "warning_days": 7,
        "format": "json",
        "secrets": [_secret(name="ok-key", last_rotated="2026-04-10", policy=60)],
    }
    p = tmp_path / "s.json"
    p.write_text(json.dumps(cfg))
    report, _ = run(p, warning_days=None, output_format=None, current_date=None)
    parsed = json.loads(report)
    assert parsed["summary"]["ok"] == 1


# ---------------------------------------------------------------------------
# main() CLI
# ---------------------------------------------------------------------------

def test_main_returns_1_when_any_secret_expired(tmp_path: Path, capsys):
    cfg = {
        "current_date": "2026-04-19", "warning_days": 7, "format": "markdown",
        "secrets": [_secret(name="rotten", last_rotated="2025-01-01", policy=30)],
    }
    p = tmp_path / "s.json"
    p.write_text(json.dumps(cfg))
    code = main(["--config", str(p)])
    out = capsys.readouterr().out
    assert code == 1
    assert "## EXPIRED (1)" in out


def test_main_returns_0_when_all_ok(tmp_path: Path, capsys):
    cfg = {
        "current_date": "2026-04-19", "warning_days": 7, "format": "markdown",
        "secrets": [_secret(name="fresh", last_rotated="2026-04-10", policy=90)],
    }
    p = tmp_path / "s.json"
    p.write_text(json.dumps(cfg))
    code = main(["--config", str(p)])
    out = capsys.readouterr().out
    assert code == 0
    assert "## OK (1)" in out


def test_main_returns_2_on_missing_file(tmp_path: Path, capsys):
    code = main(["--config", str(tmp_path / "missing.json")])
    err = capsys.readouterr().err
    assert code == 2
    assert "error" in err.lower()


def test_main_cli_flags_override_config(tmp_path: Path, capsys):
    cfg = {
        # Config says 2026-01-01 (everything fresh) and warning_days=7
        "current_date": "2026-01-01", "warning_days": 7, "format": "markdown",
        "secrets": [_secret(name="x", last_rotated="2025-10-01", policy=30)],
    }
    p = tmp_path / "s.json"
    p.write_text(json.dumps(cfg))
    # CLI overrides to a later date -> secret becomes expired
    code = main(["--config", str(p), "--current-date", "2026-04-19"])
    out = capsys.readouterr().out
    assert code == 1
    assert "## EXPIRED (1)" in out
