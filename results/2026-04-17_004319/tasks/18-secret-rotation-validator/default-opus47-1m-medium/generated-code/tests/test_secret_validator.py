"""Tests for the secret rotation validator.

Built using red/green TDD: each test was written before the implementation
that satisfies it. We use a fixed "today" date (2026-04-17) so tests are
deterministic regardless of the actual calendar date when they run.
"""
import json
from datetime import date

import pytest

from secret_validator import (
    Secret,
    classify_secret,
    classify_secrets,
    load_secrets,
    render_json,
    render_markdown,
    validate,
)

# A stable reference date so tests don't drift over time.
TODAY = date(2026, 4, 17)


# --- Secret model & classification -----------------------------------------

def test_secret_has_days_until_due():
    """A secret rotated 10 days ago with a 30-day policy is due in 20 days."""
    s = Secret(
        name="db-password",
        last_rotated=date(2026, 4, 7),
        rotation_days=30,
        services=["api"],
    )
    assert s.days_until_due(TODAY) == 20


def test_classify_expired():
    """Secrets past their rotation policy are 'expired'."""
    s = Secret("k", date(2026, 1, 1), 30, ["svc"])
    assert classify_secret(s, TODAY, warning_days=7) == "expired"


def test_classify_warning():
    """Secrets due within the warning window are 'warning'."""
    # Last rotated 25 days ago, policy 30 days -> 5 days remaining,
    # within a 7-day warning window.
    s = Secret("k", date(2026, 3, 23), 30, ["svc"])
    assert classify_secret(s, TODAY, warning_days=7) == "warning"


def test_classify_ok():
    """Secrets safely outside the warning window are 'ok'."""
    s = Secret("k", date(2026, 4, 10), 30, ["svc"])  # 23 days remaining
    assert classify_secret(s, TODAY, warning_days=7) == "ok"


def test_classify_secrets_groups_by_urgency():
    """classify_secrets returns three buckets, ordered by urgency within each."""
    secrets = [
        Secret("ok-key", date(2026, 4, 10), 30, ["svc"]),
        Secret("expired-key", date(2026, 1, 1), 30, ["svc"]),
        Secret("warn-key", date(2026, 3, 23), 30, ["svc"]),
    ]
    result = classify_secrets(secrets, TODAY, warning_days=7)
    assert [s.name for s in result["expired"]] == ["expired-key"]
    assert [s.name for s in result["warning"]] == ["warn-key"]
    assert [s.name for s in result["ok"]] == ["ok-key"]


# --- Loading from JSON config ----------------------------------------------

def test_load_secrets_from_json(tmp_path):
    """load_secrets parses a JSON config into Secret objects."""
    cfg = tmp_path / "secrets.json"
    cfg.write_text(json.dumps({
        "secrets": [
            {
                "name": "api-token",
                "last_rotated": "2026-03-01",
                "rotation_days": 60,
                "services": ["web", "worker"],
            }
        ]
    }))
    secrets = load_secrets(str(cfg))
    assert len(secrets) == 1
    assert secrets[0].name == "api-token"
    assert secrets[0].last_rotated == date(2026, 3, 1)
    assert secrets[0].rotation_days == 60
    assert secrets[0].services == ["web", "worker"]


def test_load_secrets_missing_file():
    """A clear error is raised when the config file is missing."""
    with pytest.raises(FileNotFoundError, match="not found"):
        load_secrets("/nonexistent/path/secrets.json")


def test_load_secrets_invalid_json(tmp_path):
    """Malformed JSON is reported with a helpful message."""
    cfg = tmp_path / "bad.json"
    cfg.write_text("{ not valid json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_secrets(str(cfg))


def test_load_secrets_missing_required_field(tmp_path):
    """Missing required fields are reported, naming the offending secret."""
    cfg = tmp_path / "incomplete.json"
    cfg.write_text(json.dumps({
        "secrets": [{"name": "broken", "rotation_days": 30}]
    }))
    with pytest.raises(ValueError, match="broken.*last_rotated"):
        load_secrets(str(cfg))


# --- Rendering -------------------------------------------------------------

def test_render_json_includes_summary_and_groups():
    """JSON output includes counts and the three urgency groups."""
    secrets = [
        Secret("expired-key", date(2026, 1, 1), 30, ["svc"]),
        Secret("warn-key", date(2026, 3, 23), 30, ["svc"]),
        Secret("ok-key", date(2026, 4, 10), 30, ["svc"]),
    ]
    output = render_json(secrets, TODAY, warning_days=7)
    data = json.loads(output)
    assert data["summary"] == {"expired": 1, "warning": 1, "ok": 1}
    assert data["expired"][0]["name"] == "expired-key"
    assert data["expired"][0]["days_overdue"] >= 1
    assert data["warning"][0]["name"] == "warn-key"
    assert data["ok"][0]["name"] == "ok-key"


def test_render_markdown_has_table_per_group():
    """Markdown output has a heading and table for each non-empty group."""
    secrets = [
        Secret("expired-key", date(2026, 1, 1), 30, ["api"]),
        Secret("ok-key", date(2026, 4, 10), 30, ["api"]),
    ]
    md = render_markdown(secrets, TODAY, warning_days=7)
    # Headings for non-empty groups
    assert "## Expired" in md
    assert "## OK" in md
    # The expired secret name appears in the table
    assert "expired-key" in md
    # Standard markdown table separator row
    assert "|---" in md or "| ---" in md


def test_render_markdown_omits_empty_groups():
    """Groups with no secrets are not rendered."""
    secrets = [Secret("ok-only", date(2026, 4, 10), 30, ["svc"])]
    md = render_markdown(secrets, TODAY, warning_days=7)
    assert "## Expired" not in md
    assert "## Warning" not in md
    assert "## OK" in md


# --- High-level validate() entry point -------------------------------------

def test_validate_json_format(tmp_path):
    """validate() produces JSON output when format='json'."""
    cfg = tmp_path / "s.json"
    cfg.write_text(json.dumps({
        "secrets": [
            {"name": "exp", "last_rotated": "2026-01-01",
             "rotation_days": 30, "services": ["a"]},
        ]
    }))
    output = validate(str(cfg), format="json", warning_days=7, today=TODAY)
    data = json.loads(output)
    assert data["summary"]["expired"] == 1


def test_validate_markdown_format(tmp_path):
    """validate() produces markdown output when format='markdown'."""
    cfg = tmp_path / "s.json"
    cfg.write_text(json.dumps({
        "secrets": [
            {"name": "exp", "last_rotated": "2026-01-01",
             "rotation_days": 30, "services": ["a"]},
        ]
    }))
    output = validate(str(cfg), format="markdown", warning_days=7, today=TODAY)
    assert "## Expired" in output
    assert "exp" in output


def test_validate_unknown_format_raises(tmp_path):
    """An unsupported format value produces a meaningful error."""
    cfg = tmp_path / "s.json"
    cfg.write_text(json.dumps({"secrets": []}))
    with pytest.raises(ValueError, match="format"):
        validate(str(cfg), format="xml", warning_days=7, today=TODAY)
