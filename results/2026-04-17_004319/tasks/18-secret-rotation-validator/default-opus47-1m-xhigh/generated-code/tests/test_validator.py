# Unit tests for the secret rotation validator, written TDD-style.
# The red/green cycles below are commented to show the evolution:
# each test block was added, observed failing, then passing.
#
# NOTE: the primary "tests must pass" harness for this task runs everything
# through GitHub Actions via `act` (see test_harness.py). These pytest-based
# unit tests are the TDD artifacts from building the validator library.

from datetime import date
import json
import subprocess
import sys
from pathlib import Path

import pytest

# The module under test.
from validator import (
    Secret,
    classify_secret,
    build_report,
    render_markdown,
    render_json,
    parse_config,
    ValidationError,
)

ROOT = Path(__file__).resolve().parent.parent


# -- classification -----------------------------------------------------------

def _secret(**overrides):
    base = dict(
        name="api-key",
        last_rotated=date(2026, 1, 17),
        rotation_policy_days=90,
        required_by=["svc-a"],
    )
    base.update(overrides)
    return Secret(**base)


def test_classify_ok_when_far_from_expiry():
    # 2026-01-17 + 90d = 2026-04-17, reference 2026-02-01 => 75d until expiry
    status = classify_secret(_secret(), reference_date=date(2026, 2, 1), warning_days=14)
    assert status.severity == "ok"
    assert status.days_until_expiry == 75
    assert status.days_overdue == 0


def test_classify_warning_when_inside_window():
    # expiry 2026-04-17, reference 2026-04-10 => 7 days left, within 14-day window
    status = classify_secret(_secret(), reference_date=date(2026, 4, 10), warning_days=14)
    assert status.severity == "warning"
    assert status.days_until_expiry == 7


def test_classify_expired_when_past_expiry():
    # expiry 2026-04-17, reference 2026-04-20 => 3 days overdue
    status = classify_secret(_secret(), reference_date=date(2026, 4, 20), warning_days=14)
    assert status.severity == "expired"
    assert status.days_overdue == 3


def test_boundary_exactly_at_expiry_is_warning_not_expired():
    # On the expiry day itself, there are 0 days left — still valid but at the edge.
    status = classify_secret(_secret(), reference_date=date(2026, 4, 17), warning_days=14)
    assert status.severity == "warning"
    assert status.days_until_expiry == 0


def test_boundary_day_after_expiry_is_expired():
    status = classify_secret(_secret(), reference_date=date(2026, 4, 18), warning_days=14)
    assert status.severity == "expired"
    assert status.days_overdue == 1


# -- parsing ------------------------------------------------------------------

def test_parse_config_valid():
    data = {
        "secrets": [
            {
                "name": "api-key",
                "last_rotated": "2026-01-17",
                "rotation_policy_days": 90,
                "required_by": ["svc-a", "svc-b"],
            }
        ]
    }
    secrets = parse_config(data)
    assert len(secrets) == 1
    assert secrets[0].name == "api-key"
    assert secrets[0].last_rotated == date(2026, 1, 17)
    assert secrets[0].rotation_policy_days == 90
    assert secrets[0].required_by == ["svc-a", "svc-b"]


def test_parse_config_missing_secrets_key():
    with pytest.raises(ValidationError, match="secrets"):
        parse_config({})


def test_parse_config_bad_date_format():
    data = {"secrets": [{"name": "x", "last_rotated": "not-a-date",
                         "rotation_policy_days": 30, "required_by": []}]}
    with pytest.raises(ValidationError, match="last_rotated"):
        parse_config(data)


def test_parse_config_negative_policy_days():
    data = {"secrets": [{"name": "x", "last_rotated": "2026-01-01",
                         "rotation_policy_days": 0, "required_by": []}]}
    with pytest.raises(ValidationError, match="rotation_policy_days"):
        parse_config(data)


# -- report building ----------------------------------------------------------

def test_build_report_groups_by_severity():
    secrets = [
        _secret(name="fresh", last_rotated=date(2026, 4, 10)),        # ok
        _secret(name="soon", last_rotated=date(2026, 1, 25)),         # warning: expiry 2026-04-25, ref=4-17 => 8d left
        _secret(name="old", last_rotated=date(2025, 10, 1)),          # expired
    ]
    report = build_report(secrets, reference_date=date(2026, 4, 17), warning_days=14)
    assert {s["name"] for s in report["expired"]} == {"old"}
    assert {s["name"] for s in report["warning"]} == {"soon"}
    assert {s["name"] for s in report["ok"]} == {"fresh"}
    assert report["summary"] == {
        "expired_count": 1,
        "warning_count": 1,
        "ok_count": 1,
        "total": 3,
    }


def test_expired_entries_sorted_by_most_overdue_first():
    secrets = [
        _secret(name="a", last_rotated=date(2025, 12, 1)),  # expiry 2026-03-01 => overdue 47d at ref 2026-04-17
        _secret(name="b", last_rotated=date(2025, 6, 1)),   # expiry 2025-08-30 => overdue much more
    ]
    report = build_report(secrets, reference_date=date(2026, 4, 17), warning_days=14)
    names = [s["name"] for s in report["expired"]]
    assert names == ["b", "a"]


# -- rendering ----------------------------------------------------------------

def test_render_json_is_valid_and_contains_summary():
    report = build_report([_secret()], reference_date=date(2026, 4, 17), warning_days=14)
    out = render_json(report)
    parsed = json.loads(out)
    assert parsed["summary"]["total"] == 1


def test_render_markdown_has_sections_and_counts():
    secrets = [
        _secret(name="old", last_rotated=date(2025, 1, 1)),
        _secret(name="fresh", last_rotated=date(2026, 4, 15)),
    ]
    report = build_report(secrets, reference_date=date(2026, 4, 17), warning_days=14)
    md = render_markdown(report)
    assert "# Secret Rotation Report" in md
    assert "## Expired" in md
    assert "## OK" in md
    assert "| old |" in md
    assert "| fresh |" in md
    # Summary counts should appear.
    assert "Expired: 1" in md
    assert "OK: 1" in md


def test_render_markdown_skips_empty_sections_cleanly():
    # All OK -- no Expired or Warning sections should be emitted.
    secrets = [_secret(name="fresh", last_rotated=date(2026, 4, 15))]
    report = build_report(secrets, reference_date=date(2026, 4, 17), warning_days=14)
    md = render_markdown(report)
    assert "No expired secrets" in md
    assert "No warnings" in md


# -- CLI integration ----------------------------------------------------------

def test_cli_runs_against_fixture_and_emits_json(tmp_path):
    config = {
        "secrets": [
            {"name": "api-key", "last_rotated": "2026-01-17",
             "rotation_policy_days": 90, "required_by": ["svc-a"]}
        ]
    }
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps(config))
    result = subprocess.run(
        [sys.executable, str(ROOT / "validator.py"),
         "--config", str(cfg),
         "--warning-days", "14",
         "--reference-date", "2026-04-17",
         "--format", "json"],
        capture_output=True, text=True, check=True,
    )
    parsed = json.loads(result.stdout)
    assert parsed["reference_date"] == "2026-04-17"
    assert parsed["warning_days"] == 14
    assert parsed["summary"]["total"] == 1


def test_cli_exits_nonzero_on_bad_config(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text("not-json{")
    result = subprocess.run(
        [sys.executable, str(ROOT / "validator.py"),
         "--config", str(bad), "--warning-days", "14"],
        capture_output=True, text=True,
    )
    assert result.returncode != 0
    assert "error" in result.stderr.lower() or "invalid" in result.stderr.lower()
