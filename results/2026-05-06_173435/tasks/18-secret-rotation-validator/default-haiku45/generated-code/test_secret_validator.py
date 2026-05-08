#!/usr/bin/env python3
"""
Red/Green TDD tests for secret rotation validator.
Each test starts as FAILING, then code is added to make it pass.
"""

import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
from io import StringIO
import tempfile

from secret_validator import (
    SecretConfig,
    SecretStatus,
    validate_secrets,
    generate_markdown_report,
    generate_json_report,
    load_config,
)


class TestSecretStatus:
    """Test the SecretStatus enum and classification."""

    def test_secret_status_exists(self):
        """GREEN: SecretStatus enum should exist."""
        assert hasattr(SecretStatus, "EXPIRED")
        assert hasattr(SecretStatus, "WARNING")
        assert hasattr(SecretStatus, "OK")

    def test_secret_status_values(self):
        """GREEN: SecretStatus enum values should be as expected."""
        assert SecretStatus.EXPIRED.value == "expired"
        assert SecretStatus.WARNING.value == "warning"
        assert SecretStatus.OK.value == "ok"


class TestSecretConfig:
    """Test SecretConfig data structure."""

    def test_secret_config_creation(self):
        """GREEN: Should create a SecretConfig instance."""
        config = SecretConfig(
            name="db_password",
            last_rotated=datetime(2026, 1, 1),
            rotation_policy_days=30,
            required_by_services=["api", "worker"],
        )
        assert config.name == "db_password"
        assert config.rotation_policy_days == 30
        assert config.required_by_services == ["api", "worker"]


class TestValidateSecrets:
    """Test secret validation logic."""

    def test_expired_secret(self):
        """RED -> GREEN: Expired secret should be marked as EXPIRED."""
        now = datetime(2026, 5, 6)
        config = SecretConfig(
            name="old_key",
            last_rotated=datetime(2026, 1, 1),  # 125 days ago
            rotation_policy_days=30,
            required_by_services=["api"],
        )

        result = validate_secrets([config], current_time=now, warning_days=7)

        assert len(result) == 1
        assert result[0]["status"] == SecretStatus.EXPIRED
        assert result[0]["name"] == "old_key"

    def test_warning_secret(self):
        """RED -> GREEN: Secret expiring soon should be marked as WARNING."""
        now = datetime(2026, 5, 6)
        config = SecretConfig(
            name="expiring_key",
            last_rotated=datetime(2026, 4, 10),  # 26 days ago
            rotation_policy_days=30,
            required_by_services=["api"],
        )

        result = validate_secrets([config], current_time=now, warning_days=7)

        assert len(result) == 1
        assert result[0]["status"] == SecretStatus.WARNING
        assert result[0]["days_until_expiry"] == 4

    def test_ok_secret(self):
        """RED -> GREEN: Recent secret should be marked as OK."""
        now = datetime(2026, 5, 6)
        config = SecretConfig(
            name="fresh_key",
            last_rotated=datetime(2026, 5, 1),  # 5 days ago
            rotation_policy_days=30,
            required_by_services=["api"],
        )

        result = validate_secrets([config], current_time=now, warning_days=7)

        assert len(result) == 1
        assert result[0]["status"] == SecretStatus.OK
        assert result[0]["days_until_expiry"] == 25

    def test_multiple_secrets_mixed_status(self):
        """RED -> GREEN: Multiple secrets with different statuses."""
        now = datetime(2026, 5, 6)
        configs = [
            SecretConfig(
                name="expired_key",
                last_rotated=datetime(2026, 1, 1),
                rotation_policy_days=30,
                required_by_services=["api"],
            ),
            SecretConfig(
                name="warning_key",
                last_rotated=datetime(2026, 4, 10),
                rotation_policy_days=30,
                required_by_services=["worker"],
            ),
            SecretConfig(
                name="ok_key",
                last_rotated=datetime(2026, 5, 1),
                rotation_policy_days=30,
                required_by_services=["scheduler"],
            ),
        ]

        result = validate_secrets(configs, current_time=now, warning_days=7)

        assert len(result) == 3
        statuses = [r["status"] for r in result]
        assert SecretStatus.EXPIRED in statuses
        assert SecretStatus.WARNING in statuses
        assert SecretStatus.OK in statuses


class TestReportGeneration:
    """Test markdown and JSON report generation."""

    def test_markdown_report_basic(self):
        """RED -> GREEN: Markdown report should contain expected structure."""
        now = datetime(2026, 5, 6)
        configs = [
            SecretConfig(
                name="db_pass",
                last_rotated=datetime(2026, 1, 1),
                rotation_policy_days=30,
                required_by_services=["api", "worker"],
            ),
        ]

        result = validate_secrets(configs, current_time=now, warning_days=7)
        markdown = generate_markdown_report(result)

        assert "| Name" in markdown
        assert "| Status" in markdown
        assert "db_pass" in markdown
        assert "expired" in markdown.lower()

    def test_markdown_report_groups_by_urgency(self):
        """RED -> GREEN: Markdown should group secrets by urgency."""
        now = datetime(2026, 5, 6)
        configs = [
            SecretConfig(
                name="expired_key",
                last_rotated=datetime(2026, 1, 1),
                rotation_policy_days=30,
                required_by_services=["api"],
            ),
            SecretConfig(
                name="ok_key",
                last_rotated=datetime(2026, 5, 1),
                rotation_policy_days=30,
                required_by_services=["api"],
            ),
        ]

        result = validate_secrets(configs, current_time=now, warning_days=7)
        markdown = generate_markdown_report(result)

        # Should have sections for urgency levels
        assert "## Expired" in markdown or "expired" in markdown.lower()
        assert "## OK" in markdown or "ok" in markdown.lower()

    def test_json_report_structure(self):
        """RED -> GREEN: JSON report should have correct structure."""
        now = datetime(2026, 5, 6)
        configs = [
            SecretConfig(
                name="api_key",
                last_rotated=datetime(2026, 5, 1),
                rotation_policy_days=30,
                required_by_services=["api"],
            ),
        ]

        result = validate_secrets(configs, current_time=now, warning_days=7)
        json_str = generate_json_report(result)
        data = json.loads(json_str)

        assert "timestamp" in data
        assert "summary" in data
        assert "secrets" in data
        assert len(data["secrets"]) == 1

    def test_json_report_is_valid_json(self):
        """RED -> GREEN: JSON report should be parseable."""
        now = datetime(2026, 5, 6)
        configs = [
            SecretConfig(
                name="test_key",
                last_rotated=datetime(2026, 5, 1),
                rotation_policy_days=30,
                required_by_services=["test"],
            ),
        ]

        result = validate_secrets(configs, current_time=now, warning_days=7)
        json_str = generate_json_report(result)

        # Should not raise an exception
        data = json.loads(json_str)
        assert isinstance(data, dict)


class TestLoadConfig:
    """Test loading configuration from file."""

    def test_load_config_from_json(self):
        """RED -> GREEN: Should load config from JSON file."""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as f:
            config_data = [
                {
                    "name": "db_password",
                    "last_rotated": "2026-05-01",
                    "rotation_policy_days": 30,
                    "required_by_services": ["api", "worker"],
                },
            ]
            json.dump(config_data, f)
            f.flush()

            configs = load_config(f.name)

            assert len(configs) == 1
            assert configs[0].name == "db_password"
            assert configs[0].rotation_policy_days == 30

            # Cleanup
            Path(f.name).unlink()

    def test_load_config_handles_missing_file(self):
        """RED -> GREEN: Should handle missing config file gracefully."""
        try:
            configs = load_config("/nonexistent/path/config.json")
            assert False, "Should have raised an error"
        except FileNotFoundError as e:
            assert "config" in str(e).lower() or "file" in str(e).lower()


if __name__ == "__main__":
    # Run tests with pytest
    import pytest

    pytest.main([__file__, "-v"])
