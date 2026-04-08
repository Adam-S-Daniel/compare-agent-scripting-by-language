"""
Secret Rotation Validator - TDD Test Suite

Red/Green TDD approach:
1. Write a failing test
2. Write minimum code to pass
3. Refactor
4. Repeat
"""
import pytest
from datetime import date, timedelta


# === CYCLE 1: Secret expiry detection ===
# Test written BEFORE implementation exists (will fail on import)

from secret_rotation import Secret, classify_secret


class TestSecretExpiry:
    """Tests for classifying individual secrets by expiry status."""

    def test_expired_secret_is_classified_as_expired(self):
        # A secret last rotated 100 days ago with a 90-day policy is expired
        secret = Secret(
            name="db-password",
            last_rotated=date.today() - timedelta(days=100),
            rotation_policy_days=90,
            required_by=["api-service"],
        )
        status = classify_secret(secret, warning_days=14)
        assert status == "expired"

    def test_secret_expiring_soon_is_classified_as_warning(self):
        # A secret last rotated 80 days ago with a 90-day policy expires in 10 days
        # With a 14-day warning window, this should be "warning"
        secret = Secret(
            name="api-key",
            last_rotated=date.today() - timedelta(days=80),
            rotation_policy_days=90,
            required_by=["frontend"],
        )
        status = classify_secret(secret, warning_days=14)
        assert status == "warning"

    def test_healthy_secret_is_classified_as_ok(self):
        # A secret rotated yesterday with a 90-day policy is fine
        secret = Secret(
            name="jwt-secret",
            last_rotated=date.today() - timedelta(days=1),
            rotation_policy_days=90,
            required_by=["auth-service"],
        )
        status = classify_secret(secret, warning_days=14)
        assert status == "ok"

    def test_secret_expiring_exactly_on_warning_boundary_is_warning(self):
        # Expiry date is exactly warning_days away — should be "warning"
        secret = Secret(
            name="cert-key",
            last_rotated=date.today() - timedelta(days=76),
            rotation_policy_days=90,
            required_by=["tls-terminator"],
        )
        # Expires in 14 days exactly
        status = classify_secret(secret, warning_days=14)
        assert status == "warning"

    def test_secret_expiring_today_is_expired(self):
        # Expiry date is today (0 days left) — should be "expired"
        secret = Secret(
            name="temp-token",
            last_rotated=date.today() - timedelta(days=90),
            rotation_policy_days=90,
            required_by=["batch-job"],
        )
        status = classify_secret(secret, warning_days=14)
        assert status == "expired"

    def test_configurable_warning_window(self):
        # Same secret, different warning windows
        secret = Secret(
            name="oauth-secret",
            last_rotated=date.today() - timedelta(days=85),
            rotation_policy_days=90,
            required_by=["oauth-server"],
        )
        # 3 days left: with 7-day window → warning; with 2-day window → ok
        assert classify_secret(secret, warning_days=7) == "warning"
        assert classify_secret(secret, warning_days=2) == "ok"


# === CYCLE 2: Urgency grouping ===

from secret_rotation import generate_report


class TestUrgencyGrouping:
    """Tests for grouping secrets into urgency buckets."""

    def setup_method(self):
        """Fixture: a mixed set of secrets at various stages."""
        self.secrets = [
            Secret("expired-1", date.today() - timedelta(days=100), 90, ["svc-a"]),
            Secret("expired-2", date.today() - timedelta(days=95), 90, ["svc-b"]),
            Secret("warning-1", date.today() - timedelta(days=82), 90, ["svc-c"]),
            Secret("ok-1",      date.today() - timedelta(days=10),  90, ["svc-d"]),
            Secret("ok-2",      date.today() - timedelta(days=1),   90, ["svc-e"]),
        ]

    def test_report_has_three_urgency_groups(self):
        report = generate_report(self.secrets, warning_days=14)
        assert "expired" in report
        assert "warning" in report
        assert "ok" in report

    def test_expired_secrets_are_grouped_correctly(self):
        report = generate_report(self.secrets, warning_days=14)
        assert len(report["expired"]) == 2
        names = {s["name"] for s in report["expired"]}
        assert names == {"expired-1", "expired-2"}

    def test_warning_secrets_are_grouped_correctly(self):
        report = generate_report(self.secrets, warning_days=14)
        assert len(report["warning"]) == 1
        assert report["warning"][0]["name"] == "warning-1"

    def test_ok_secrets_are_grouped_correctly(self):
        report = generate_report(self.secrets, warning_days=14)
        assert len(report["ok"]) == 2

    def test_report_entry_includes_days_until_expiry(self):
        report = generate_report(self.secrets, warning_days=14)
        # expired-1: 100 days old, 90-day policy → -10 days remaining
        entry = next(e for e in report["expired"] if e["name"] == "expired-1")
        assert entry["days_remaining"] == -10

    def test_report_entry_includes_required_by(self):
        report = generate_report(self.secrets, warning_days=14)
        entry = next(e for e in report["ok"] if e["name"] == "ok-1")
        assert entry["required_by"] == ["svc-d"]


# === CYCLE 3: Markdown output format ===

from secret_rotation import format_markdown


class TestMarkdownOutput:
    """Tests for rendering the report as a Markdown table."""

    def setup_method(self):
        # Minimal report fixture
        self.report = {
            "expired": [
                {"name": "db-pass", "days_remaining": -5, "required_by": ["api"], "expiry_date": "2026-04-03"},
            ],
            "warning": [
                {"name": "api-key", "days_remaining": 7, "required_by": ["web", "mobile"], "expiry_date": "2026-04-15"},
            ],
            "ok": [
                {"name": "jwt",     "days_remaining": 60, "required_by": ["auth"],  "expiry_date": "2026-06-07"},
            ],
        }

    def test_markdown_contains_section_headers(self):
        md = format_markdown(self.report)
        assert "## Expired" in md
        assert "## Warning" in md
        assert "## OK" in md

    def test_markdown_contains_table_headers(self):
        md = format_markdown(self.report)
        assert "| Name |" in md
        assert "| Days Remaining |" in md
        assert "| Required By |" in md
        assert "| Expiry Date |" in md

    def test_markdown_contains_secret_names(self):
        md = format_markdown(self.report)
        assert "db-pass" in md
        assert "api-key" in md
        assert "jwt" in md

    def test_markdown_empty_section_shows_none_message(self):
        report = {"expired": [], "warning": [], "ok": [{"name": "x", "days_remaining": 30, "required_by": [], "expiry_date": "2026-05-08"}]}
        md = format_markdown(report)
        assert "No expired secrets" in md
        assert "No warning secrets" in md


# === CYCLE 4: JSON output format ===

from secret_rotation import format_json
import json


class TestJsonOutput:
    """Tests for rendering the report as JSON."""

    def setup_method(self):
        self.report = {
            "expired": [
                {"name": "old-key", "days_remaining": -20, "required_by": ["svc"], "expiry_date": "2026-03-19"},
            ],
            "warning": [],
            "ok": [],
        }

    def test_json_output_is_valid_json(self):
        output = format_json(self.report)
        parsed = json.loads(output)  # must not raise
        assert isinstance(parsed, dict)

    def test_json_output_has_all_urgency_keys(self):
        parsed = json.loads(format_json(self.report))
        assert "expired" in parsed
        assert "warning" in parsed
        assert "ok" in parsed

    def test_json_output_preserves_secret_data(self):
        parsed = json.loads(format_json(self.report))
        assert parsed["expired"][0]["name"] == "old-key"
        assert parsed["expired"][0]["days_remaining"] == -20

    def test_json_output_includes_metadata(self):
        parsed = json.loads(format_json(self.report))
        # Top-level metadata: generated_at, summary counts
        assert "metadata" in parsed
        assert parsed["metadata"]["total_expired"] == 1
        assert parsed["metadata"]["total_warning"] == 0
        assert parsed["metadata"]["total_ok"] == 0
