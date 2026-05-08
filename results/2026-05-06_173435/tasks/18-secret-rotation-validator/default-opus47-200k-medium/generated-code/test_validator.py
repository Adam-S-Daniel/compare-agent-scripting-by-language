"""TDD tests for the secret rotation validator.

Each secret has: name, last_rotated (ISO date), policy_days, services.
Given a `now` reference date and a `warn_days` threshold:
  - expired: now - last_rotated > policy_days
  - warning: policy_days - (now - last_rotated) <= warn_days  (and not expired)
  - ok: otherwise
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

from validator import (
    Secret,
    classify,
    render_json,
    render_markdown,
    load_secrets,
    ValidatorError,
)

HERE = Path(__file__).parent


# --- classify --------------------------------------------------------------

def _secret(name, last, policy, services=("svc",)):
    return Secret(name=name, last_rotated=last, policy_days=policy, services=list(services))


def test_classify_marks_expired_secret():
    s = _secret("db", "2026-01-01", policy=30)
    out = classify([s], now="2026-05-08", warn_days=7)
    assert out["expired"][0].name == "db"
    assert out["warning"] == [] and out["ok"] == []


def test_classify_marks_warning_within_window():
    # 25 days since rotation, policy 30 -> 5 days remaining; warn_days=7 -> warning
    s = _secret("api", "2026-04-13", policy=30)
    out = classify([s], now="2026-05-08", warn_days=7)
    assert out["warning"][0].name == "api"
    assert out["expired"] == [] and out["ok"] == []


def test_classify_marks_ok_when_outside_window():
    # 5 days since rotation, policy 30 -> 25 days remaining; warn_days=7 -> ok
    s = _secret("ok-key", "2026-05-03", policy=30)
    out = classify([s], now="2026-05-08", warn_days=7)
    assert out["ok"][0].name == "ok-key"
    assert out["expired"] == [] and out["warning"] == []


def test_classify_sorts_expired_by_most_overdue_first():
    a = _secret("a", "2026-04-01", policy=10)  # 27 overdue
    b = _secret("b", "2026-04-20", policy=10)  # 8 overdue
    out = classify([b, a], now="2026-05-08", warn_days=7)
    assert [s.name for s in out["expired"]] == ["a", "b"]


# --- load_secrets ----------------------------------------------------------

def test_load_secrets_parses_valid_json(tmp_path):
    p = tmp_path / "c.json"
    p.write_text(json.dumps({
        "secrets": [
            {"name": "db", "last_rotated": "2026-04-01", "policy_days": 30,
             "services": ["api", "worker"]},
        ]
    }))
    secrets = load_secrets(p)
    assert secrets[0].name == "db"
    assert secrets[0].services == ["api", "worker"]


def test_load_secrets_raises_on_missing_field(tmp_path):
    p = tmp_path / "bad.json"
    p.write_text(json.dumps({"secrets": [{"name": "x"}]}))
    with pytest.raises(ValidatorError, match="missing"):
        load_secrets(p)


def test_load_secrets_raises_on_bad_date(tmp_path):
    p = tmp_path / "bad.json"
    p.write_text(json.dumps({"secrets": [
        {"name": "x", "last_rotated": "yesterday", "policy_days": 30, "services": []}
    ]}))
    with pytest.raises(ValidatorError, match="last_rotated"):
        load_secrets(p)


# --- renderers -------------------------------------------------------------

def test_render_json_has_three_buckets():
    s = _secret("db", "2026-01-01", policy=30)
    report = classify([s], now="2026-05-08", warn_days=7)
    out = render_json(report, now="2026-05-08")
    parsed = json.loads(out)
    assert set(parsed["buckets"]) == {"expired", "warning", "ok"}
    assert parsed["generated_at"] == "2026-05-08"
    assert parsed["buckets"]["expired"][0]["name"] == "db"
    assert parsed["buckets"]["expired"][0]["days_overdue"] == 97


def test_render_markdown_groups_by_urgency():
    expired = _secret("db", "2026-01-01", policy=30)
    warning = _secret("api", "2026-04-13", policy=30)
    ok = _secret("good", "2026-05-03", policy=30)
    report = classify([expired, warning, ok], now="2026-05-08", warn_days=7)
    md = render_markdown(report, now="2026-05-08")
    # Headers + table rows for each bucket present
    assert "## Expired" in md and "## Warning" in md and "## OK" in md
    assert "| db |" in md
    assert "| api |" in md
    assert "| good |" in md
    # Markdown table header
    assert "| Name | Last Rotated | Policy (days) | Days Remaining | Services |" in md


def test_render_markdown_shows_empty_section_message():
    report = classify([], now="2026-05-08", warn_days=7)
    md = render_markdown(report, now="2026-05-08")
    assert "_none_" in md


# --- CLI -------------------------------------------------------------------

def test_cli_outputs_json(tmp_path):
    cfg = tmp_path / "c.json"
    cfg.write_text(json.dumps({
        "secrets": [
            {"name": "db", "last_rotated": "2026-01-01", "policy_days": 30, "services": ["api"]},
            {"name": "api", "last_rotated": "2026-04-13", "policy_days": 30, "services": ["api"]},
            {"name": "good", "last_rotated": "2026-05-03", "policy_days": 30, "services": ["api"]},
        ]
    }))
    r = subprocess.run(
        [sys.executable, str(HERE / "validator.py"),
         "--config", str(cfg), "--now", "2026-05-08", "--warn-days", "7",
         "--format", "json"],
        capture_output=True, text=True, check=True,
    )
    parsed = json.loads(r.stdout)
    names = lambda b: [s["name"] for s in parsed["buckets"][b]]
    assert names("expired") == ["db"]
    assert names("warning") == ["api"]
    assert names("ok") == ["good"]


def test_cli_outputs_markdown(tmp_path):
    cfg = tmp_path / "c.json"
    cfg.write_text(json.dumps({"secrets": [
        {"name": "db", "last_rotated": "2026-01-01", "policy_days": 30, "services": ["api"]},
    ]}))
    r = subprocess.run(
        [sys.executable, str(HERE / "validator.py"),
         "--config", str(cfg), "--now", "2026-05-08", "--warn-days", "7",
         "--format", "markdown"],
        capture_output=True, text=True, check=True,
    )
    assert "## Expired" in r.stdout
    assert "| db |" in r.stdout


def test_cli_exits_2_when_expired_present_and_fail_flag_set(tmp_path):
    cfg = tmp_path / "c.json"
    cfg.write_text(json.dumps({"secrets": [
        {"name": "db", "last_rotated": "2026-01-01", "policy_days": 30, "services": ["x"]},
    ]}))
    r = subprocess.run(
        [sys.executable, str(HERE / "validator.py"),
         "--config", str(cfg), "--now", "2026-05-08", "--warn-days", "7",
         "--format", "json", "--fail-on-expired"],
        capture_output=True, text=True,
    )
    assert r.returncode == 2


def test_cli_reports_missing_config(tmp_path):
    r = subprocess.run(
        [sys.executable, str(HERE / "validator.py"),
         "--config", str(tmp_path / "nope.json"), "--now", "2026-05-08",
         "--warn-days", "7", "--format", "json"],
        capture_output=True, text=True,
    )
    assert r.returncode != 0
    assert "not found" in r.stderr.lower() or "no such" in r.stderr.lower()
