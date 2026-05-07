# Tests for the secret-rotation validator.
#
# Approach: we keep "today" and the warning window injectable into every
# entry point so tests are deterministic. All fixtures live inline as plain
# dicts/lists; on-disk fixtures are written to tmp_path so the test suite
# stays hermetic.

from datetime import date

import pytest

from rotation_validator import (
    Secret,
    classify,
    classify_all,
    load_secrets,
    render_json,
    render_markdown,
    summarize,
)


# --- classify() ---------------------------------------------------------

def test_classify_ok_when_age_well_below_policy():
    s = Secret(
        name="api-key",
        last_rotated=date(2026, 5, 1),
        policy_days=90,
        services=["web"],
    )
    assert classify(s, today=date(2026, 5, 7), warning_days=14) == "ok"


def test_classify_warning_when_within_window():
    # Policy 30 days, last rotated 2026-04-15 -> due 2026-05-15.
    # On 2026-05-07 with a 14-day window, it lands in "warning".
    s = Secret(
        name="db-password",
        last_rotated=date(2026, 4, 15),
        policy_days=30,
        services=["api"],
    )
    assert classify(s, today=date(2026, 5, 7), warning_days=14) == "warning"


def test_classify_expired_when_past_due():
    s = Secret(
        name="legacy-token",
        last_rotated=date(2025, 1, 1),
        policy_days=90,
        services=["batch"],
    )
    assert classify(s, today=date(2026, 5, 7), warning_days=14) == "expired"


def test_classify_warning_at_exact_boundary():
    # Due in exactly `warning_days` days: still inside the window.
    s = Secret(
        name="edge",
        last_rotated=date(2026, 4, 23),
        policy_days=28,  # due 2026-05-21, exactly 14 days from 2026-05-07
        services=["x"],
    )
    assert classify(s, today=date(2026, 5, 7), warning_days=14) == "warning"


def test_classify_expired_on_due_date():
    # Due today is treated as expired (must rotate by end of policy).
    s = Secret(
        name="due-today",
        last_rotated=date(2026, 4, 7),
        policy_days=30,
        services=["x"],
    )
    assert classify(s, today=date(2026, 5, 7), warning_days=14) == "expired"


# --- classify_all() & summarize() ---------------------------------------

@pytest.fixture
def mixed_secrets():
    return [
        Secret("api-key", date(2026, 5, 1), 90, ["web"]),          # ok
        Secret("db-password", date(2026, 4, 15), 30, ["api"]),     # warning
        Secret("legacy-token", date(2025, 1, 1), 90, ["batch"]),   # expired
        Secret("oauth", date(2026, 3, 1), 60, ["auth", "web"]),    # expired (due 2026-04-30)
    ]


def test_classify_all_buckets_secrets_correctly(mixed_secrets):
    result = classify_all(mixed_secrets, today=date(2026, 5, 7), warning_days=14)
    assert [s.name for s in result["ok"]] == ["api-key"]
    assert [s.name for s in result["warning"]] == ["db-password"]
    assert sorted(s.name for s in result["expired"]) == ["legacy-token", "oauth"]


def test_summarize_counts(mixed_secrets):
    result = classify_all(mixed_secrets, today=date(2026, 5, 7), warning_days=14)
    summary = summarize(result)
    assert summary == {"expired": 2, "warning": 1, "ok": 1, "total": 4}


# --- load_secrets() -----------------------------------------------------

def test_load_secrets_from_json_file(tmp_path):
    p = tmp_path / "secrets.json"
    p.write_text(
        '[{"name":"k","last_rotated":"2026-05-01","policy_days":90,'
        '"services":["web"]}]'
    )
    secrets = load_secrets(str(p))
    assert len(secrets) == 1
    assert secrets[0].name == "k"
    assert secrets[0].last_rotated == date(2026, 5, 1)
    assert secrets[0].policy_days == 90
    assert secrets[0].services == ["web"]


def test_load_secrets_missing_file_raises_helpful_error(tmp_path):
    with pytest.raises(FileNotFoundError, match="Secrets config not found"):
        load_secrets(str(tmp_path / "nope.json"))


def test_load_secrets_invalid_json_raises_helpful_error(tmp_path):
    p = tmp_path / "bad.json"
    p.write_text("{not json")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_secrets(str(p))


def test_load_secrets_missing_required_field_raises(tmp_path):
    p = tmp_path / "missing.json"
    p.write_text('[{"name": "k", "last_rotated": "2026-01-01"}]')
    with pytest.raises(ValueError, match="missing required field"):
        load_secrets(str(p))


def test_load_secrets_invalid_date_format_raises(tmp_path):
    p = tmp_path / "bad-date.json"
    p.write_text(
        '[{"name":"k","last_rotated":"not-a-date","policy_days":30,"services":[]}]'
    )
    with pytest.raises(ValueError, match="Invalid last_rotated date"):
        load_secrets(str(p))


def test_load_secrets_negative_policy_raises(tmp_path):
    p = tmp_path / "bad-policy.json"
    p.write_text(
        '[{"name":"k","last_rotated":"2026-01-01","policy_days":-1,"services":[]}]'
    )
    with pytest.raises(ValueError, match="policy_days must be positive"):
        load_secrets(str(p))


# --- render_markdown() --------------------------------------------------

def test_render_markdown_groups_by_urgency(mixed_secrets):
    grouped = classify_all(mixed_secrets, today=date(2026, 5, 7), warning_days=14)
    md = render_markdown(grouped, today=date(2026, 5, 7), warning_days=14)

    # Header + summary
    assert "# Secret Rotation Report" in md
    assert "Generated for 2026-05-07" in md
    assert "warning window: 14 days" in md
    assert "**Total:** 4" in md
    assert "**Expired:** 2" in md
    assert "**Warning:** 1" in md
    assert "**OK:** 1" in md

    # Sections in urgency order
    expired_idx = md.index("## Expired")
    warning_idx = md.index("## Warning")
    ok_idx = md.index("## OK")
    assert expired_idx < warning_idx < ok_idx

    # Table header columns
    assert "| Name | Last Rotated | Policy (days) | Due | Days Overdue / Until Due | Services |" in md

    # Specific rows
    assert "| legacy-token |" in md
    assert "| db-password |" in md
    assert "| api-key |" in md


def test_render_markdown_handles_empty_buckets():
    grouped = {"expired": [], "warning": [], "ok": []}
    md = render_markdown(grouped, today=date(2026, 5, 7), warning_days=14)
    # Empty sections still render with a placeholder so the structure stays
    # predictable for downstream parsers.
    assert "_None_" in md
    assert "**Total:** 0" in md


# --- render_json() ------------------------------------------------------

def test_render_json_structure(mixed_secrets):
    import json

    grouped = classify_all(mixed_secrets, today=date(2026, 5, 7), warning_days=14)
    out = render_json(grouped, today=date(2026, 5, 7), warning_days=14)
    payload = json.loads(out)

    assert payload["generated_for"] == "2026-05-07"
    assert payload["warning_days"] == 14
    assert payload["summary"] == {"expired": 2, "warning": 1, "ok": 1, "total": 4}

    assert {s["name"] for s in payload["expired"]} == {"legacy-token", "oauth"}
    assert payload["warning"][0]["name"] == "db-password"
    assert payload["ok"][0]["name"] == "api-key"

    # Each entry carries the derived due_date and days_until_due fields so
    # consumers don't have to recompute them.
    legacy = next(s for s in payload["expired"] if s["name"] == "legacy-token")
    assert legacy["due_date"] == "2025-04-01"
    assert legacy["days_until_due"] == -401
    assert legacy["services"] == ["batch"]
