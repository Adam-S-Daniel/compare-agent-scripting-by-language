"""
Secret Rotation Validator - TDD Tests
Red/Green TDD: write failing test first, implement minimum code to pass, refactor.
"""

import pytest
from datetime import date, timedelta
from secret_rotation import (
    Secret,
    RotationStatus,
    classify_secret,
    generate_report,
    format_markdown,
    format_json,
)


# --- Fixtures ---

def make_secret(name="db-password", last_rotated_days_ago=30, rotation_policy_days=90,
                services=None):
    """Helper to create a Secret with a last-rotated date relative to today."""
    last_rotated = date.today() - timedelta(days=last_rotated_days_ago)
    return Secret(
        name=name,
        last_rotated=last_rotated,
        rotation_policy_days=rotation_policy_days,
        required_by=services or ["auth-service"],
    )


# ============================================================
# RED: Test 1 - Secret data model
# ============================================================

class TestSecretModel:
    def test_secret_has_required_fields(self):
        """Secret must have name, last_rotated, rotation_policy_days, required_by."""
        s = Secret(
            name="api-key",
            last_rotated=date(2025, 1, 1),
            rotation_policy_days=30,
            required_by=["payment-service", "email-service"],
        )
        assert s.name == "api-key"
        assert s.last_rotated == date(2025, 1, 1)
        assert s.rotation_policy_days == 30
        assert s.required_by == ["payment-service", "email-service"]

    def test_secret_expiry_date(self):
        """Secret expiry date = last_rotated + rotation_policy_days."""
        s = Secret(
            name="api-key",
            last_rotated=date(2025, 1, 1),
            rotation_policy_days=30,
            required_by=[],
        )
        assert s.expiry_date == date(2025, 1, 31)

    def test_secret_days_until_expiry(self):
        """days_until_expiry is negative when already expired."""
        # Expired 10 days ago: last_rotated = today - 40, policy = 30
        last_rotated = date.today() - timedelta(days=40)
        s = Secret(name="old-key", last_rotated=last_rotated,
                   rotation_policy_days=30, required_by=[])
        assert s.days_until_expiry < 0

    def test_secret_days_until_expiry_future(self):
        """days_until_expiry is positive when not yet expired."""
        last_rotated = date.today() - timedelta(days=10)
        s = Secret(name="fresh-key", last_rotated=last_rotated,
                   rotation_policy_days=30, required_by=[])
        assert s.days_until_expiry == 20


# ============================================================
# RED: Test 2 - RotationStatus enum
# ============================================================

class TestRotationStatus:
    def test_status_values_exist(self):
        """RotationStatus must have EXPIRED, WARNING, OK values."""
        assert RotationStatus.EXPIRED
        assert RotationStatus.WARNING
        assert RotationStatus.OK


# ============================================================
# RED: Test 3 - classify_secret
# ============================================================

class TestClassifySecret:
    def test_classify_expired(self):
        """Secret past its expiry date is EXPIRED."""
        s = make_secret(last_rotated_days_ago=100, rotation_policy_days=90)
        assert classify_secret(s, warning_days=14) == RotationStatus.EXPIRED

    def test_classify_warning(self):
        """Secret expiring within warning_days is WARNING."""
        # Expires in 7 days: last_rotated = today - 83, policy = 90
        s = make_secret(last_rotated_days_ago=83, rotation_policy_days=90)
        assert classify_secret(s, warning_days=14) == RotationStatus.WARNING

    def test_classify_ok(self):
        """Secret with plenty of time left is OK."""
        s = make_secret(last_rotated_days_ago=10, rotation_policy_days=90)
        assert classify_secret(s, warning_days=14) == RotationStatus.OK

    def test_classify_expiring_exactly_on_warning_boundary(self):
        """Secret expiring in exactly warning_days days is WARNING (inclusive)."""
        # Expires in exactly 14 days
        s = make_secret(last_rotated_days_ago=76, rotation_policy_days=90)
        assert classify_secret(s, warning_days=14) == RotationStatus.WARNING

    def test_classify_expired_today(self):
        """Secret expiring today (days_until_expiry == 0) counts as EXPIRED."""
        s = make_secret(last_rotated_days_ago=90, rotation_policy_days=90)
        assert classify_secret(s, warning_days=14) == RotationStatus.EXPIRED

    def test_classify_custom_warning_window(self):
        """Warning window is configurable."""
        # Expires in 30 days; with warning_days=7 it should be OK
        s = make_secret(last_rotated_days_ago=60, rotation_policy_days=90)
        assert classify_secret(s, warning_days=7) == RotationStatus.OK
        # With warning_days=31 it should be WARNING
        assert classify_secret(s, warning_days=31) == RotationStatus.WARNING


# ============================================================
# RED: Test 4 - generate_report
# ============================================================

class TestGenerateReport:
    def _make_secrets(self):
        return [
            make_secret("expired-key", last_rotated_days_ago=100, rotation_policy_days=90,
                        services=["auth"]),
            make_secret("warn-key", last_rotated_days_ago=83, rotation_policy_days=90,
                        services=["api"]),
            make_secret("ok-key", last_rotated_days_ago=10, rotation_policy_days=90,
                        services=["frontend"]),
        ]

    def test_report_has_three_groups(self):
        """Report groups secrets into expired, warning, ok."""
        report = generate_report(self._make_secrets(), warning_days=14)
        assert "expired" in report
        assert "warning" in report
        assert "ok" in report

    def test_report_expired_group(self):
        """Expired secrets are in the expired group."""
        report = generate_report(self._make_secrets(), warning_days=14)
        assert len(report["expired"]) == 1
        assert report["expired"][0].name == "expired-key"

    def test_report_warning_group(self):
        """Warning secrets are in the warning group."""
        report = generate_report(self._make_secrets(), warning_days=14)
        assert len(report["warning"]) == 1
        assert report["warning"][0].name == "warn-key"

    def test_report_ok_group(self):
        """OK secrets are in the ok group."""
        report = generate_report(self._make_secrets(), warning_days=14)
        assert len(report["ok"]) == 1
        assert report["ok"][0].name == "ok-key"

    def test_report_empty_groups_when_no_secrets(self):
        """Empty input produces empty groups."""
        report = generate_report([], warning_days=14)
        assert report["expired"] == []
        assert report["warning"] == []
        assert report["ok"] == []

    def test_report_all_expired(self):
        """All secrets can be expired."""
        secrets = [
            make_secret("key-a", last_rotated_days_ago=200, rotation_policy_days=90),
            make_secret("key-b", last_rotated_days_ago=150, rotation_policy_days=90),
        ]
        report = generate_report(secrets, warning_days=14)
        assert len(report["expired"]) == 2
        assert report["warning"] == []
        assert report["ok"] == []


# ============================================================
# RED: Test 5 - format_json
# ============================================================

class TestFormatJson:
    def test_json_output_is_string(self):
        """format_json returns a string."""
        secrets = [make_secret("key", last_rotated_days_ago=10, rotation_policy_days=90)]
        report = generate_report(secrets, warning_days=14)
        result = format_json(report)
        assert isinstance(result, str)

    def test_json_output_is_valid_json(self):
        """format_json returns valid JSON."""
        import json
        secrets = [make_secret("key", last_rotated_days_ago=10, rotation_policy_days=90)]
        report = generate_report(secrets, warning_days=14)
        result = format_json(report)
        parsed = json.loads(result)  # must not raise
        assert isinstance(parsed, dict)

    def test_json_contains_groups(self):
        """JSON output contains expired, warning, ok keys."""
        import json
        secrets = [
            make_secret("expired-key", last_rotated_days_ago=100, rotation_policy_days=90),
            make_secret("ok-key", last_rotated_days_ago=5, rotation_policy_days=90),
        ]
        report = generate_report(secrets, warning_days=14)
        parsed = json.loads(format_json(report))
        assert "expired" in parsed
        assert "warning" in parsed
        assert "ok" in parsed

    def test_json_secret_fields(self):
        """Each secret entry in JSON has name, last_rotated, expiry_date, days_until_expiry, required_by."""
        import json
        secrets = [make_secret("my-key", last_rotated_days_ago=100, rotation_policy_days=90,
                               services=["svc-a"])]
        report = generate_report(secrets, warning_days=14)
        parsed = json.loads(format_json(report))
        entry = parsed["expired"][0]
        assert entry["name"] == "my-key"
        assert "last_rotated" in entry
        assert "expiry_date" in entry
        assert "days_until_expiry" in entry
        assert entry["required_by"] == ["svc-a"]


# ============================================================
# RED: Test 6 - format_markdown
# ============================================================

class TestFormatMarkdown:
    def test_markdown_output_is_string(self):
        """format_markdown returns a string."""
        secrets = [make_secret("key", last_rotated_days_ago=10, rotation_policy_days=90)]
        report = generate_report(secrets, warning_days=14)
        result = format_markdown(report)
        assert isinstance(result, str)

    def test_markdown_contains_section_headers(self):
        """Markdown output contains section headers for each urgency level."""
        secrets = [
            make_secret("expired-key", last_rotated_days_ago=100, rotation_policy_days=90),
        ]
        report = generate_report(secrets, warning_days=14)
        result = format_markdown(report)
        assert "Expired" in result or "EXPIRED" in result
        assert "Warning" in result or "WARNING" in result
        assert "OK" in result or "Ok" in result

    def test_markdown_contains_table_headers(self):
        """Markdown tables have column headers."""
        secrets = [make_secret("key", last_rotated_days_ago=100, rotation_policy_days=90)]
        report = generate_report(secrets, warning_days=14)
        result = format_markdown(report)
        # Standard markdown table header separator
        assert "|" in result
        assert "---" in result

    def test_markdown_contains_secret_name(self):
        """Secret names appear in the markdown output."""
        secrets = [make_secret("super-secret-db", last_rotated_days_ago=5, rotation_policy_days=90)]
        report = generate_report(secrets, warning_days=14)
        result = format_markdown(report)
        assert "super-secret-db" in result

    def test_markdown_empty_group_shows_none(self):
        """Empty groups are noted in the markdown (not just absent)."""
        secrets = [make_secret("ok-key", last_rotated_days_ago=5, rotation_policy_days=90)]
        report = generate_report(secrets, warning_days=14)
        result = format_markdown(report)
        # Should mention that expired/warning sections are empty or have no entries
        assert "None" in result or "none" in result or "no " in result.lower() or "empty" in result.lower()
