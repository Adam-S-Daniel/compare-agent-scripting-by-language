"""
TDD Tests for Secret Rotation Validator

Red/Green TDD methodology:
  1. Write a FAILING test (RED)
  2. Write minimum code to make it pass (GREEN)
  3. Refactor

Each TDD cycle is labeled below. All tests use a fixed REFERENCE_DATE=2024-01-15
so results are deterministic regardless of when tests run.
"""

import json
import os
import pytest
from datetime import date

# The module under test — imported after it's created (GREEN phase)
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import (
    load_secrets,
    calculate_secret_status,
    analyze_secrets,
    format_markdown,
    format_json,
)

# Fixed reference date keeps tests deterministic across time
REFERENCE_DATE = date(2024, 1, 15)

# ---------------------------------------------------------------------------
# Fixtures — mock data used across test cycles
# ---------------------------------------------------------------------------

# last_rotated: 2023-09-01, rotation_days: 90
# days_since = 136, days_until = -46  →  EXPIRED
EXPIRED_SECRET = {
    "name": "db-password",
    "last_rotated": "2023-09-01",
    "rotation_days": 90,
    "required_by": ["backend-api", "worker"],
}

# last_rotated: 2023-12-20, rotation_days: 30
# days_since = 26, days_until = 4  →  WARNING (within 30-day window)
WARNING_SECRET = {
    "name": "api-key",
    "last_rotated": "2023-12-20",
    "rotation_days": 30,
    "required_by": ["frontend"],
}

# last_rotated: 2024-01-01, rotation_days: 90
# days_since = 14, days_until = 76  →  OK
OK_SECRET = {
    "name": "jwt-secret",
    "last_rotated": "2024-01-01",
    "rotation_days": 90,
    "required_by": ["auth-service"],
}

MIXED_SECRETS = [EXPIRED_SECRET, WARNING_SECRET, OK_SECRET]


# ===========================================================================
# TDD Cycle 1: calculate_secret_status
# RED: these fail because the function doesn't exist yet
# GREEN: implement calculate_secret_status
# ===========================================================================

class TestCalculateSecretStatus:
    """Unit tests for per-secret status calculation."""

    def test_expired_secret_gets_expired_status(self):
        """136 days since rotation, 90-day policy → expired."""
        result = calculate_secret_status(EXPIRED_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["status"] == "expired"

    def test_expired_secret_days_until_expiry_is_negative(self):
        """Overdue secrets must report negative days_until_expiry."""
        result = calculate_secret_status(EXPIRED_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["days_until_expiry"] < 0

    def test_warning_secret_gets_warning_status(self):
        """4 days until expiry, 30-day warning window → warning."""
        result = calculate_secret_status(WARNING_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["status"] == "warning"

    def test_ok_secret_gets_ok_status(self):
        """76 days until expiry, 30-day warning window → ok."""
        result = calculate_secret_status(OK_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["status"] == "ok"

    def test_days_since_rotation_is_correct(self):
        """2024-01-15 minus 2023-09-01 = 136 days."""
        result = calculate_secret_status(EXPIRED_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["days_since_rotation"] == 136

    def test_days_until_expiry_is_correct(self):
        """90 - 136 = -46 days until expiry."""
        result = calculate_secret_status(EXPIRED_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["days_until_expiry"] == -46

    def test_warning_window_is_configurable(self):
        """Wider warning window should catch secrets not caught by narrow one."""
        # OK secret with narrow window: 76 days until expiry > 10-day window
        narrow = calculate_secret_status(OK_SECRET, warning_days=10, reference_date=REFERENCE_DATE)
        assert narrow["status"] == "ok"

        # Same secret with very wide window: 76 days until expiry < 80-day window
        wide = calculate_secret_status(OK_SECRET, warning_days=80, reference_date=REFERENCE_DATE)
        assert wide["status"] == "warning"

    def test_secret_expiring_exactly_on_boundary_is_warning(self):
        """A secret expiring in exactly warning_days days should be 'warning'."""
        boundary_secret = {
            "name": "boundary",
            "last_rotated": "2023-12-16",  # 30 days before 2024-01-15
            "rotation_days": 30,           # expires exactly on reference date
            "required_by": [],
        }
        result = calculate_secret_status(boundary_secret, warning_days=30, reference_date=REFERENCE_DATE)
        # days_until_expiry = 30 - 30 = 0, which is <= warning_days → warning
        assert result["status"] == "warning"

    def test_missing_required_field_raises_value_error(self):
        """Secrets missing required fields should raise a clear ValueError."""
        bad = {"name": "missing-rotation", "last_rotated": "2024-01-01"}
        with pytest.raises(ValueError, match="rotation_days"):
            calculate_secret_status(bad, warning_days=30, reference_date=REFERENCE_DATE)

    def test_invalid_date_format_raises_value_error(self):
        """Wrong date format should raise ValueError with the secret name."""
        bad = {"name": "bad-date", "last_rotated": "01/15/2024", "rotation_days": 30}
        with pytest.raises(ValueError, match="bad-date"):
            calculate_secret_status(bad, warning_days=30, reference_date=REFERENCE_DATE)

    def test_original_fields_preserved_in_result(self):
        """Result must include all original secret fields."""
        result = calculate_secret_status(OK_SECRET, warning_days=30, reference_date=REFERENCE_DATE)
        assert result["name"] == "jwt-secret"
        assert result["required_by"] == ["auth-service"]
        assert result["rotation_days"] == 90

    def test_today_used_when_reference_date_is_none(self):
        """When reference_date is None, today's date is used (smoke test)."""
        # Just verify it doesn't crash; we can't assert exact values without mocking date.today()
        fresh_secret = {
            "name": "always-fresh",
            "last_rotated": date.today().isoformat(),
            "rotation_days": 90,
            "required_by": [],
        }
        result = calculate_secret_status(fresh_secret, warning_days=30, reference_date=None)
        assert result["status"] == "ok"


# ===========================================================================
# TDD Cycle 2: analyze_secrets (batch analysis)
# RED: fails because analyze_secrets doesn't exist yet
# GREEN: implement analyze_secrets using calculate_secret_status
# ===========================================================================

class TestAnalyzeSecrets:
    """Unit tests for batch analysis and grouping by urgency."""

    def test_result_has_three_urgency_groups(self):
        """Result dict must have 'expired', 'warning', 'ok' keys."""
        result = analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)
        assert set(result.keys()) == {"expired", "warning", "ok"}

    def test_expired_secret_lands_in_expired_group(self):
        result = analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)
        names = [s["name"] for s in result["expired"]]
        assert "db-password" in names

    def test_warning_secret_lands_in_warning_group(self):
        result = analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)
        names = [s["name"] for s in result["warning"]]
        assert "api-key" in names

    def test_ok_secret_lands_in_ok_group(self):
        result = analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)
        names = [s["name"] for s in result["ok"]]
        assert "jwt-secret" in names

    def test_empty_input_returns_empty_groups(self):
        result = analyze_secrets([], warning_days=30, reference_date=REFERENCE_DATE)
        assert result == {"expired": [], "warning": [], "ok": []}

    def test_all_secrets_accounted_for(self):
        """Total count across groups must equal input count."""
        result = analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)
        total = len(result["expired"]) + len(result["warning"]) + len(result["ok"])
        assert total == len(MIXED_SECRETS)

    def test_single_ok_secret(self):
        result = analyze_secrets([OK_SECRET], warning_days=30, reference_date=REFERENCE_DATE)
        assert len(result["expired"]) == 0
        assert len(result["warning"]) == 0
        assert len(result["ok"]) == 1


# ===========================================================================
# TDD Cycle 3: format_markdown output
# RED: fails because format_markdown doesn't exist yet
# GREEN: implement format_markdown
# ===========================================================================

class TestFormatMarkdown:
    """Unit tests for markdown report generation."""

    @pytest.fixture
    def analysis(self):
        return analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)

    def test_contains_report_header(self, analysis):
        assert "# Secret Rotation Report" in format_markdown(analysis)

    def test_contains_expired_section(self, analysis):
        assert "## EXPIRED" in format_markdown(analysis)

    def test_contains_warning_section(self, analysis):
        assert "## WARNING" in format_markdown(analysis)

    def test_contains_ok_section(self, analysis):
        assert "## OK" in format_markdown(analysis)

    def test_summary_shows_correct_total(self, analysis):
        assert "**Total secrets:** 3" in format_markdown(analysis)

    def test_summary_shows_expired_count(self, analysis):
        assert "**Expired:** 1" in format_markdown(analysis)

    def test_summary_shows_warning_count(self, analysis):
        assert "**Warning:** 1" in format_markdown(analysis)

    def test_summary_shows_ok_count(self, analysis):
        assert "**OK:** 1" in format_markdown(analysis)

    def test_contains_secret_names(self, analysis):
        md = format_markdown(analysis)
        assert "db-password" in md
        assert "api-key" in md
        assert "jwt-secret" in md

    def test_contains_table_headers(self, analysis):
        md = format_markdown(analysis)
        assert "| Name |" in md
        assert "| Last Rotated |" in md
        assert "| Days Since Rotation |" in md
        assert "| Days Until Expiry |" in md

    def test_empty_section_shows_placeholder(self):
        """When a group is empty, a placeholder message should appear."""
        analysis = analyze_secrets([OK_SECRET], warning_days=30, reference_date=REFERENCE_DATE)
        md = format_markdown(analysis)
        assert "_No secrets in this category._" in md

    def test_expired_secret_shows_overdue_label(self, analysis):
        """Overdue secrets should make their status clear in the table."""
        md = format_markdown(analysis)
        assert "OVERDUE" in md


# ===========================================================================
# TDD Cycle 4: format_json output
# RED: fails because format_json doesn't exist yet
# GREEN: implement format_json
# ===========================================================================

class TestFormatJson:
    """Unit tests for JSON report generation."""

    @pytest.fixture
    def analysis(self):
        return analyze_secrets(MIXED_SECRETS, warning_days=30, reference_date=REFERENCE_DATE)

    def test_output_is_valid_json(self, analysis):
        result = format_json(analysis)
        parsed = json.loads(result)  # raises if invalid
        assert isinstance(parsed, dict)

    def test_summary_section_exists(self, analysis):
        parsed = json.loads(format_json(analysis))
        assert "summary" in parsed

    def test_summary_total_is_correct(self, analysis):
        parsed = json.loads(format_json(analysis))
        assert parsed["summary"]["total"] == 3

    def test_summary_expired_count(self, analysis):
        parsed = json.loads(format_json(analysis))
        assert parsed["summary"]["expired"] == 1

    def test_summary_warning_count(self, analysis):
        parsed = json.loads(format_json(analysis))
        assert parsed["summary"]["warning"] == 1

    def test_summary_ok_count(self, analysis):
        parsed = json.loads(format_json(analysis))
        assert parsed["summary"]["ok"] == 1

    def test_secrets_grouped_by_urgency(self, analysis):
        parsed = json.loads(format_json(analysis))
        assert "secrets" in parsed
        assert set(parsed["secrets"].keys()) == {"expired", "warning", "ok"}

    def test_expired_group_has_correct_secret(self, analysis):
        parsed = json.loads(format_json(analysis))
        names = [s["name"] for s in parsed["secrets"]["expired"]]
        assert "db-password" in names

    def test_ok_group_has_correct_secret(self, analysis):
        parsed = json.loads(format_json(analysis))
        names = [s["name"] for s in parsed["secrets"]["ok"]]
        assert "jwt-secret" in names


# ===========================================================================
# TDD Cycle 5: load_secrets (file I/O)
# RED: fails because load_secrets doesn't exist yet
# GREEN: implement load_secrets
# ===========================================================================

class TestLoadSecrets:
    """Unit tests for loading secrets from JSON files."""

    def test_load_valid_json_file(self, tmp_path):
        data = [{"name": "test", "last_rotated": "2024-01-01", "rotation_days": 90}]
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps(data))
        result = load_secrets(str(p))
        assert len(result) == 1
        assert result[0]["name"] == "test"

    def test_nonexistent_file_raises_file_not_found(self):
        with pytest.raises(FileNotFoundError, match="not found"):
            load_secrets("/nonexistent/path/secrets.json")

    def test_invalid_json_raises_value_error(self, tmp_path):
        p = tmp_path / "bad.json"
        p.write_text("not { valid json")
        with pytest.raises(ValueError, match="Invalid JSON"):
            load_secrets(str(p))

    def test_non_array_json_raises_value_error(self, tmp_path):
        p = tmp_path / "wrong.json"
        p.write_text('{"name": "not-an-array"}')
        with pytest.raises(ValueError, match="JSON array"):
            load_secrets(str(p))

    def test_empty_array_is_valid(self, tmp_path):
        p = tmp_path / "empty.json"
        p.write_text("[]")
        result = load_secrets(str(p))
        assert result == []
