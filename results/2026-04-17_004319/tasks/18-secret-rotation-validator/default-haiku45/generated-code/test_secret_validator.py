import pytest
import json
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from secret_validator import Secret, SecretValidator, RotationReport, Urgency


class TestSecretCreation:
    """Test creating and validating Secret objects."""

    def test_secret_creation_basic(self):
        """FAILING TEST: Create a basic secret with required fields."""
        secret = Secret(
            name="db_password",
            last_rotated=datetime(2026, 4, 10),
            rotation_policy_days=30,
            required_by=["service-a", "service-b"]
        )
        assert secret.name == "db_password"
        assert secret.last_rotated == datetime(2026, 4, 10)
        assert secret.rotation_policy_days == 30
        assert secret.required_by == ["service-a", "service-b"]

    def test_secret_is_expired(self):
        """FAILING TEST: Identify expired secrets."""
        expired_secret = Secret(
            name="old_key",
            last_rotated=datetime(2026, 3, 10),
            rotation_policy_days=30,
            required_by=["app"]
        )
        assert expired_secret.is_expired() is True

    def test_secret_is_not_expired(self):
        """FAILING TEST: Identify non-expired secrets."""
        fresh_secret = Secret(
            name="new_key",
            last_rotated=datetime.now(),
            rotation_policy_days=30,
            required_by=["app"]
        )
        assert fresh_secret.is_expired() is False


class TestSecretValidator:
    """Test the SecretValidator class."""

    def test_validator_creation(self):
        """FAILING TEST: Create validator with warning window."""
        validator = SecretValidator(warning_window_days=7)
        assert validator.warning_window_days == 7

    def test_get_secrets_by_urgency(self):
        """FAILING TEST: Categorize secrets by urgency."""
        validator = SecretValidator(warning_window_days=7)

        expired = Secret("expired_key", datetime(2026, 3, 1), 30, ["app"])
        warning = Secret("warning_key", datetime(2026, 4, 15), 7, ["app"])
        ok = Secret("ok_key", datetime(2026, 4, 18), 30, ["app"])

        validator.add_secret(expired)
        validator.add_secret(warning)
        validator.add_secret(ok)

        report = validator.generate_report()
        assert report.expired_count == 1
        assert report.warning_count == 1
        assert report.ok_count == 1


class TestRotationReport:
    """Test report generation."""

    def test_markdown_output(self):
        """FAILING TEST: Generate markdown table output."""
        validator = SecretValidator(warning_window_days=7)
        validator.add_secret(Secret("key1", datetime(2026, 3, 1), 30, ["app"]))

        report = validator.generate_report()
        markdown = report.to_markdown()

        assert "| Secret" in markdown
        assert "key1" in markdown
        assert "EXPIRED" in markdown

    def test_json_output(self):
        """FAILING TEST: Generate JSON output."""
        validator = SecretValidator(warning_window_days=7)
        validator.add_secret(Secret("key1", datetime(2026, 3, 1), 30, ["app"]))

        report = validator.generate_report()
        json_str = report.to_json()

        assert "key1" in json_str
        assert "expired" in json_str


class TestComplexScenarios:
    """Test realistic secret rotation scenarios."""

    def test_mixed_urgency_secrets(self):
        """Test handling multiple secrets with different urgencies."""
        validator = SecretValidator(warning_window_days=7)

        # Expired (more than 30 days old)
        validator.add_secret(Secret("api_key_old", datetime(2026, 3, 1), 30, ["api"]))

        # Warning (7 days or less until expiry)
        validator.add_secret(Secret("db_pass_soon", datetime(2026, 4, 14), 7, ["db"]))

        # OK (more than 7 days until expiry)
        validator.add_secret(Secret("ssl_cert", datetime(2026, 4, 10), 30, ["web"]))

        report = validator.generate_report()

        assert report.expired_count >= 1
        assert report.ok_count >= 1

    def test_multiple_services_dependency(self):
        """Test secrets required by multiple services."""
        validator = SecretValidator(warning_window_days=7)
        validator.add_secret(
            Secret(
                "shared_key",
                datetime(2026, 3, 15),
                30,
                ["service-a", "service-b", "service-c"]
            )
        )

        report = validator.generate_report()
        markdown = report.to_markdown()

        assert "service-a" in markdown
        assert "service-b" in markdown
        assert "service-c" in markdown

    def test_days_until_expiry_calculation(self):
        """Test accurate expiry countdown."""
        secret = Secret("key", datetime(2026, 4, 12), 7, ["app"])
        as_of = datetime(2026, 4, 17)

        days_left = secret.days_until_expiry(as_of)
        assert days_left == 2

    def test_warning_window_boundary(self):
        """Test secrets at the warning window boundary."""
        validator = SecretValidator(warning_window_days=7)

        # Exactly at warning boundary (7 days left)
        secret_at_boundary = Secret("boundary_key", datetime(2026, 4, 12), 7, ["app"])
        as_of = datetime(2026, 4, 19)

        urgency = secret_at_boundary.get_urgency(validator.warning_window_days, as_of)
        assert urgency == Urgency.WARNING


class TestCLI:
    """Test CLI functionality."""

    def test_cli_with_mixed_fixture(self):
        """Test CLI with mixed urgency secrets."""
        result = subprocess.run(
            ["python3", "secret_validator_cli.py", "fixtures_mixed.json", "--output-format", "markdown"],
            capture_output=True,
            text=True
        )

        output = result.stdout
        assert "api_key_old" in output
        assert "EXPIRED" in output

    def test_cli_json_output(self):
        """Test CLI JSON output format."""
        result = subprocess.run(
            ["python3", "secret_validator_cli.py", "fixtures_mixed.json", "--output-format", "json"],
            capture_output=True,
            text=True
        )

        output = result.stdout
        data = json.loads(output)

        assert "summary" in data
        assert "by_urgency" in data
        assert "EXPIRED" in data["by_urgency"]

    def test_cli_missing_config_file(self):
        """Test CLI error handling for missing config file."""
        result = subprocess.run(
            ["python3", "secret_validator_cli.py", "nonexistent.json"],
            capture_output=True,
            text=True
        )

        assert result.returncode != 0
        assert "not found" in result.stderr
