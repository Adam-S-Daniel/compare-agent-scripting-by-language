"""Tests for the secret rotation validator.

Tests are written first (red), then code is made to pass (green).
Each test exercises a discrete piece of behavior so the module grows
incrementally via TDD.
"""
from __future__ import annotations

import json
from datetime import date, timedelta

import pytest

from secret_rotation import (
    Secret,
    classify_secret,
    classify_secrets,
    load_secrets,
    render_json,
    render_markdown,
    validate,
)


# ---------- Fixtures ------------------------------------------------------

@pytest.fixture
def today() -> date:
    return date(2026, 4, 20)


@pytest.fixture
def sample_secrets(today):
    """Three secrets covering each urgency bucket."""
    return [
        Secret(
            name="db-password",
            last_rotated=today - timedelta(days=120),  # expired (policy 90)
            rotation_policy_days=90,
            required_by=["api", "worker"],
        ),
        Secret(
            name="stripe-key",
            last_rotated=today - timedelta(days=25),  # warning (policy 30, warn 7)
            rotation_policy_days=30,
            required_by=["billing"],
        ),
        Secret(
            name="aws-access-key",
            last_rotated=today - timedelta(days=10),  # ok (policy 180)
            rotation_policy_days=180,
            required_by=["deploy"],
        ),
    ]


# ---------- classify_secret ----------------------------------------------

def test_classify_expired_secret(today):
    s = Secret("s1", today - timedelta(days=100), 90, ["svc"])
    result = classify_secret(s, today=today, warning_days=7)
    assert result["urgency"] == "expired"
    assert result["days_overdue"] == 10


def test_classify_warning_secret(today):
    s = Secret("s2", today - timedelta(days=25), 30, ["svc"])
    result = classify_secret(s, today=today, warning_days=7)
    assert result["urgency"] == "warning"
    assert result["days_until_rotation"] == 5


def test_classify_ok_secret(today):
    s = Secret("s3", today - timedelta(days=10), 180, ["svc"])
    result = classify_secret(s, today=today, warning_days=7)
    assert result["urgency"] == "ok"
    assert result["days_until_rotation"] == 170


def test_classify_exactly_on_boundary_is_expired(today):
    # last_rotated exactly rotation_policy_days ago => 0 days until => expired
    s = Secret("boundary", today - timedelta(days=30), 30, ["svc"])
    result = classify_secret(s, today=today, warning_days=7)
    assert result["urgency"] == "expired"
    assert result["days_overdue"] == 0


# ---------- classify_secrets (grouping) ----------------------------------

def test_classify_secrets_groups_by_urgency(sample_secrets, today):
    grouped = classify_secrets(sample_secrets, today=today, warning_days=7)
    assert [s["name"] for s in grouped["expired"]] == ["db-password"]
    assert [s["name"] for s in grouped["warning"]] == ["stripe-key"]
    assert [s["name"] for s in grouped["ok"]] == ["aws-access-key"]


# ---------- load_secrets (JSON parsing & validation) ---------------------

def test_load_secrets_from_json_file(tmp_path):
    p = tmp_path / "s.json"
    p.write_text(json.dumps([
        {
            "name": "k1",
            "last_rotated": "2026-01-01",
            "rotation_policy_days": 30,
            "required_by": ["a"],
        }
    ]))
    secrets = load_secrets(str(p))
    assert len(secrets) == 1
    assert secrets[0].name == "k1"
    assert secrets[0].last_rotated == date(2026, 1, 1)


def test_load_secrets_missing_file_raises_meaningful_error(tmp_path):
    with pytest.raises(FileNotFoundError) as exc:
        load_secrets(str(tmp_path / "nope.json"))
    assert "nope.json" in str(exc.value)


def test_load_secrets_invalid_json_raises_meaningful_error(tmp_path):
    p = tmp_path / "bad.json"
    p.write_text("{not json")
    with pytest.raises(ValueError) as exc:
        load_secrets(str(p))
    assert "bad.json" in str(exc.value)


def test_load_secrets_missing_required_field_raises(tmp_path):
    p = tmp_path / "missing.json"
    p.write_text(json.dumps([{"name": "k1"}]))  # missing other fields
    with pytest.raises(ValueError) as exc:
        load_secrets(str(p))
    assert "last_rotated" in str(exc.value) or "rotation_policy_days" in str(exc.value)


# ---------- render_markdown ----------------------------------------------

def test_render_markdown_contains_sections(sample_secrets, today):
    grouped = classify_secrets(sample_secrets, today=today, warning_days=7)
    md = render_markdown(grouped)
    assert "# Secret Rotation Report" in md
    assert "## Expired (1)" in md
    assert "## Warning (1)" in md
    assert "## OK (1)" in md
    assert "| Name | Last Rotated" in md
    assert "db-password" in md
    assert "stripe-key" in md


def test_render_markdown_empty_section_still_shown(today):
    grouped = classify_secrets([], today=today, warning_days=7)
    md = render_markdown(grouped)
    assert "## Expired (0)" in md
    assert "_None_" in md


# ---------- render_json --------------------------------------------------

def test_render_json_is_valid_and_structured(sample_secrets, today):
    grouped = classify_secrets(sample_secrets, today=today, warning_days=7)
    out = render_json(grouped)
    parsed = json.loads(out)
    assert set(parsed.keys()) == {"expired", "warning", "ok", "summary"}
    assert parsed["summary"]["expired"] == 1
    assert parsed["summary"]["warning"] == 1
    assert parsed["summary"]["ok"] == 1


# ---------- validate (end-to-end via fixture file) -----------------------

def test_validate_end_to_end_markdown(tmp_path, today):
    p = tmp_path / "s.json"
    data = [
        {
            "name": "db",
            "last_rotated": (today - timedelta(days=120)).isoformat(),
            "rotation_policy_days": 90,
            "required_by": ["api"],
        },
        {
            "name": "ok-key",
            "last_rotated": today.isoformat(),
            "rotation_policy_days": 90,
            "required_by": ["svc"],
        },
    ]
    p.write_text(json.dumps(data))
    out = validate(
        str(p), warning_days=7, output_format="markdown", today=today
    )
    assert "## Expired (1)" in out
    assert "db" in out


def test_validate_end_to_end_json(tmp_path, today):
    p = tmp_path / "s.json"
    p.write_text(json.dumps([
        {
            "name": "db",
            "last_rotated": (today - timedelta(days=120)).isoformat(),
            "rotation_policy_days": 90,
            "required_by": ["api"],
        }
    ]))
    out = validate(str(p), warning_days=7, output_format="json", today=today)
    parsed = json.loads(out)
    assert parsed["summary"]["expired"] == 1


def test_validate_rejects_unknown_format(tmp_path, today):
    p = tmp_path / "s.json"
    p.write_text("[]")
    with pytest.raises(ValueError) as exc:
        validate(str(p), warning_days=7, output_format="xml", today=today)
    assert "xml" in str(exc.value)
