"""TDD tests for the secret rotation validator.

Each test was written red-first; the implementation in validator.py was added
incrementally to satisfy these tests.
"""

import io
import json
import os
import subprocess
import sys
from datetime import date

import pytest

# Make the project root importable.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from validator import (
    classify_secret,
    classify_all,
    load_config,
    render_json,
    render_markdown,
    SecretValidationError,
)


# ---------- classify_secret: the core decision function ----------

def test_classify_secret_expired_when_past_rotation_policy():
    secret = {
        "name": "db-password",
        "last_rotated": "2026-01-01",
        "rotation_policy_days": 30,
        "required_by": ["api"],
    }
    today = date(2026, 5, 1)  # 120 days later, policy is 30 -> expired
    result = classify_secret(secret, warning_days=7, today=today)
    assert result["status"] == "expired"
    assert result["days_until_expiry"] == 30 - 120  # -90
    assert result["name"] == "db-password"


def test_classify_secret_warning_when_within_window():
    secret = {
        "name": "stripe-key",
        "last_rotated": "2026-04-01",
        "rotation_policy_days": 40,
        "required_by": ["billing"],
    }
    # 30 days elapsed, policy 40 -> 10 days left. warning_days=14 -> warning.
    today = date(2026, 5, 1)
    result = classify_secret(secret, warning_days=14, today=today)
    assert result["status"] == "warning"
    assert result["days_until_expiry"] == 10


def test_classify_secret_ok_when_far_from_expiry():
    secret = {
        "name": "internal-token",
        "last_rotated": "2026-04-25",
        "rotation_policy_days": 90,
        "required_by": ["worker"],
    }
    today = date(2026, 5, 1)  # 6 days elapsed, 84 left
    result = classify_secret(secret, warning_days=7, today=today)
    assert result["status"] == "ok"
    assert result["days_until_expiry"] == 84


def test_classify_secret_boundary_zero_days_left_is_warning_not_expired():
    """A secret with exactly 0 days until expiry hasn't yet rotated past the window."""
    secret = {
        "name": "boundary",
        "last_rotated": "2026-04-01",
        "rotation_policy_days": 30,
        "required_by": ["svc"],
    }
    today = date(2026, 5, 1)  # exactly 30 days
    result = classify_secret(secret, warning_days=7, today=today)
    assert result["status"] == "warning"
    assert result["days_until_expiry"] == 0


# ---------- classify_all: groups by urgency ----------

def test_classify_all_groups_results_by_urgency():
    config = {
        "secrets": [
            {"name": "a", "last_rotated": "2026-01-01", "rotation_policy_days": 30, "required_by": ["x"]},  # expired
            {"name": "b", "last_rotated": "2026-04-01", "rotation_policy_days": 35, "required_by": ["y"]},  # warning (4 days left)
            {"name": "c", "last_rotated": "2026-04-25", "rotation_policy_days": 90, "required_by": ["z"]},  # ok
        ]
    }
    today = date(2026, 5, 1)
    grouped = classify_all(config, warning_days=7, today=today)
    assert [s["name"] for s in grouped["expired"]] == ["a"]
    assert [s["name"] for s in grouped["warning"]] == ["b"]
    assert [s["name"] for s in grouped["ok"]] == ["c"]


# ---------- error handling ----------

def test_classify_secret_rejects_missing_field():
    secret = {"name": "broken", "rotation_policy_days": 30, "required_by": ["x"]}
    with pytest.raises(SecretValidationError) as exc:
        classify_secret(secret, warning_days=7, today=date(2026, 5, 1))
    assert "last_rotated" in str(exc.value)


def test_classify_secret_rejects_bad_date():
    secret = {
        "name": "broken",
        "last_rotated": "not-a-date",
        "rotation_policy_days": 30,
        "required_by": ["x"],
    }
    with pytest.raises(SecretValidationError) as exc:
        classify_secret(secret, warning_days=7, today=date(2026, 5, 1))
    assert "broken" in str(exc.value)


def test_load_config_rejects_missing_file(tmp_path):
    with pytest.raises(SecretValidationError):
        load_config(str(tmp_path / "nope.json"))


def test_load_config_rejects_invalid_json(tmp_path):
    p = tmp_path / "bad.json"
    p.write_text("{not json")
    with pytest.raises(SecretValidationError):
        load_config(str(p))


# ---------- output formats ----------

def test_render_markdown_contains_grouped_table():
    grouped = {
        "expired": [{"name": "a", "days_until_expiry": -10, "rotation_policy_days": 30,
                     "last_rotated": "2026-01-01", "required_by": ["x"]}],
        "warning": [{"name": "b", "days_until_expiry": 4, "rotation_policy_days": 35,
                     "last_rotated": "2026-04-01", "required_by": ["y"]}],
        "ok": [{"name": "c", "days_until_expiry": 84, "rotation_policy_days": 90,
                "last_rotated": "2026-04-25", "required_by": ["z"]}],
    }
    md = render_markdown(grouped)
    # Section headers
    assert "## Expired (1)" in md
    assert "## Warning (1)" in md
    assert "## OK (1)" in md
    # Markdown table header
    assert "| Name | Last Rotated |" in md
    # Each secret name appears
    for n in ("a", "b", "c"):
        assert f"| {n} |" in md


def test_render_markdown_handles_empty_groups():
    grouped = {"expired": [], "warning": [], "ok": []}
    md = render_markdown(grouped)
    assert "## Expired (0)" in md
    assert "_No secrets in this group._" in md


def test_render_json_is_valid_json_and_round_trips():
    grouped = {
        "expired": [],
        "warning": [{"name": "b", "days_until_expiry": 4, "rotation_policy_days": 35,
                     "last_rotated": "2026-04-01", "required_by": ["y"]}],
        "ok": [],
    }
    out = render_json(grouped)
    parsed = json.loads(out)
    assert parsed["warning"][0]["name"] == "b"
    assert parsed["summary"]["warning"] == 1
    assert parsed["summary"]["expired"] == 0


# ---------- CLI integration (still goes through the script's main()) ----------

def _run_cli(*args, fixture):
    """Run validator.py as a subprocess. Fixture is written to a tmp file."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    script = os.path.join(here, "validator.py")
    return subprocess.run(
        [sys.executable, script, *args],
        capture_output=True,
        text=True,
        cwd=here,
    )


def test_cli_exits_nonzero_when_expired_secrets_present(tmp_path):
    cfg = tmp_path / "secrets.json"
    cfg.write_text(json.dumps({"secrets": [
        {"name": "a", "last_rotated": "2026-01-01", "rotation_policy_days": 30, "required_by": ["x"]},
    ]}))
    r = _run_cli("--config", str(cfg), "--today", "2026-05-01", "--format", "json", fixture=cfg)
    assert r.returncode == 2, r.stderr
    parsed = json.loads(r.stdout)
    assert parsed["summary"]["expired"] == 1


def test_cli_exits_zero_when_all_ok(tmp_path):
    cfg = tmp_path / "secrets.json"
    cfg.write_text(json.dumps({"secrets": [
        {"name": "c", "last_rotated": "2026-04-25", "rotation_policy_days": 90, "required_by": ["z"]},
    ]}))
    r = _run_cli("--config", str(cfg), "--today", "2026-05-01", "--format", "markdown", fixture=cfg)
    assert r.returncode == 0, r.stderr
    assert "## OK (1)" in r.stdout
