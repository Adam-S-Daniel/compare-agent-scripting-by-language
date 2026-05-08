"""
TDD tests for secret_rotation_validator.py.

Red/Green cycle:
  1. These tests were written FIRST (all fail — module does not exist).
  2. secret_rotation_validator.py was written to make them pass.
  3. Refactored for clarity; tests remain unchanged.

Reference date used throughout: 2026-05-08.
Fixture secrets (relative to that date):
  API_KEY_PROD    last=2026-02-01 policy=90d  → expiry=2026-05-02  days_left=-6   EXPIRED
  WEBHOOK_SECRET  last=2026-03-01 policy=60d  → expiry=2026-04-30  days_left=-8   EXPIRED
  JWT_SECRET      last=2026-03-25 policy=50d  → expiry=2026-05-14  days_left=6    WARNING
  DB_PASSWORD     last=2026-04-25 policy=90d  → expiry=2026-07-24  days_left=77   OK
  OAUTH_SECRET    last=2026-04-30 policy=365d → expiry=2027-04-30  days_left=357  OK
"""

import json
import os
from datetime import date, timedelta

import pytest

# This import fails (RED) until secret_rotation_validator.py is created (GREEN).
from secret_rotation_validator import (
    load_secrets,
    check_secret_status,
    generate_report,
    format_markdown,
    format_json,
)

REFERENCE_DATE = date(2026, 5, 8)
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "..", "fixtures")


# ── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def mixed_secrets():
    path = os.path.join(FIXTURES_DIR, "secrets_mixed.json")
    return load_secrets(path)

@pytest.fixture
def mixed_report(mixed_secrets):
    return generate_report(mixed_secrets, REFERENCE_DATE, warning_days=14)


# ── load_secrets ─────────────────────────────────────────────────────────────

def test_load_secrets_returns_list():
    path = os.path.join(FIXTURES_DIR, "secrets_mixed.json")
    secrets = load_secrets(path)
    assert isinstance(secrets, list)
    assert len(secrets) == 5

def test_load_secrets_has_required_fields():
    path = os.path.join(FIXTURES_DIR, "secrets_mixed.json")
    secrets = load_secrets(path)
    for s in secrets:
        assert "name" in s
        assert "last_rotated" in s
        assert "rotation_days" in s
        assert "required_by" in s

def test_load_secrets_file_not_found():
    with pytest.raises(FileNotFoundError):
        load_secrets("/nonexistent/path/secrets.json")

def test_load_secrets_invalid_json(tmp_path):
    bad_file = tmp_path / "bad.json"
    bad_file.write_text("not json {{{")
    with pytest.raises(ValueError, match="[Ii]nvalid JSON"):
        load_secrets(str(bad_file))


# ── check_secret_status ───────────────────────────────────────────────────────

def test_expired_secret_is_identified():
    secret = {
        "name": "API_KEY_PROD",
        "last_rotated": "2026-02-01",
        "rotation_days": 90,
        "required_by": ["payment-service"],
    }
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=14)
    assert result["urgency"] == "expired"
    assert result["days_until_expiry"] == -6

def test_warning_secret_is_identified():
    secret = {
        "name": "JWT_SECRET",
        "last_rotated": "2026-03-25",
        "rotation_days": 50,
        "required_by": ["auth-service"],
    }
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=14)
    assert result["urgency"] == "warning"
    assert result["days_until_expiry"] == 6

def test_ok_secret_is_identified():
    secret = {
        "name": "DB_PASSWORD",
        "last_rotated": "2026-04-25",
        "rotation_days": 90,
        "required_by": ["db-service"],
    }
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=14)
    assert result["urgency"] == "ok"
    assert result["days_until_expiry"] == 77

def test_secret_expiring_exactly_at_warning_boundary_is_warning():
    # A secret expiring in exactly warning_days days is still "warning".
    secret = {
        "name": "EDGE_CASE",
        "last_rotated": "2026-04-10",
        "rotation_days": 30,
        "required_by": [],
    }
    # expiry = 2026-05-10, days_until = 2 (well within 14-day window)
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=14)
    assert result["urgency"] == "warning"

def test_secret_expiring_today_is_warning():
    # Expires today — 0 days left — still "warning" not "expired".
    secret = {
        "name": "EXPIRES_TODAY",
        "last_rotated": (REFERENCE_DATE - timedelta(days=30)).isoformat(),
        "rotation_days": 30,
        "required_by": [],
    }
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=14)
    assert result["urgency"] == "warning"
    assert result["days_until_expiry"] == 0

def test_secret_expired_yesterday_is_expired():
    secret = {
        "name": "EXPIRED_YESTERDAY",
        "last_rotated": (REFERENCE_DATE - timedelta(days=31)).isoformat(),
        "rotation_days": 30,
        "required_by": [],
    }
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=14)
    assert result["urgency"] == "expired"
    assert result["days_until_expiry"] == -1

def test_result_includes_expiry_date():
    secret = {
        "name": "API_KEY_PROD",
        "last_rotated": "2026-02-01",
        "rotation_days": 90,
        "required_by": [],
    }
    result = check_secret_status(secret, REFERENCE_DATE)
    assert result["expiry_date"] == "2026-05-02"

def test_custom_warning_window_changes_classification():
    # With a 3-day warning window, 6 days left → OK.
    secret = {
        "name": "JWT_SECRET",
        "last_rotated": "2026-03-25",
        "rotation_days": 50,
        "required_by": [],
    }
    result = check_secret_status(secret, REFERENCE_DATE, warning_days=3)
    assert result["urgency"] == "ok"


# ── generate_report ───────────────────────────────────────────────────────────

def test_report_groups_secrets_by_urgency(mixed_report):
    assert len(mixed_report["expired"]) == 2
    assert len(mixed_report["warning"]) == 1
    assert len(mixed_report["ok"]) == 2

def test_report_summary_counts(mixed_report):
    summary = mixed_report["summary"]
    assert summary["total"] == 5
    assert summary["expired_count"] == 2
    assert summary["warning_count"] == 1
    assert summary["ok_count"] == 2

def test_report_expired_names(mixed_report):
    names = {s["name"] for s in mixed_report["expired"]}
    assert "API_KEY_PROD" in names
    assert "WEBHOOK_SECRET" in names

def test_report_warning_names(mixed_report):
    names = {s["name"] for s in mixed_report["warning"]}
    assert "JWT_SECRET" in names

def test_report_ok_names(mixed_report):
    names = {s["name"] for s in mixed_report["ok"]}
    assert "DB_PASSWORD" in names
    assert "OAUTH_CLIENT_SECRET" in names

def test_report_all_ok_fixture():
    path = os.path.join(FIXTURES_DIR, "secrets_all_ok.json")
    secrets = load_secrets(path)
    report = generate_report(secrets, REFERENCE_DATE)
    assert report["summary"]["expired_count"] == 0
    assert report["summary"]["warning_count"] == 0
    assert report["summary"]["ok_count"] == len(secrets)

def test_report_all_expired_fixture():
    path = os.path.join(FIXTURES_DIR, "secrets_all_expired.json")
    secrets = load_secrets(path)
    report = generate_report(secrets, REFERENCE_DATE)
    assert report["summary"]["expired_count"] == len(secrets)
    assert report["summary"]["ok_count"] == 0


# ── format_markdown ───────────────────────────────────────────────────────────

def test_format_markdown_contains_table_header(mixed_report):
    md = format_markdown(mixed_report)
    assert "| Status |" in md
    assert "| Secret Name |" in md

def test_format_markdown_contains_expired_label(mixed_report):
    md = format_markdown(mixed_report)
    assert "EXPIRED" in md

def test_format_markdown_contains_warning_label(mixed_report):
    md = format_markdown(mixed_report)
    assert "WARNING" in md

def test_format_markdown_contains_secret_names(mixed_report):
    md = format_markdown(mixed_report)
    assert "API_KEY_PROD" in md
    assert "JWT_SECRET" in md
    assert "DB_PASSWORD" in md

def test_format_markdown_contains_summary(mixed_report):
    md = format_markdown(mixed_report)
    assert "2 expired" in md.lower() or "expired_count" in md or "expired: 2" in md.lower() or "2" in md


# ── format_json ───────────────────────────────────────────────────────────────

def test_format_json_is_valid_json(mixed_report):
    output = format_json(mixed_report)
    parsed = json.loads(output)
    assert isinstance(parsed, dict)

def test_format_json_has_urgency_groups(mixed_report):
    parsed = json.loads(format_json(mixed_report))
    assert "expired" in parsed
    assert "warning" in parsed
    assert "ok" in parsed

def test_format_json_expired_count_matches(mixed_report):
    parsed = json.loads(format_json(mixed_report))
    assert len(parsed["expired"]) == 2
    assert parsed["summary"]["expired_count"] == 2
