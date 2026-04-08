"""Tests for the secret rotation validator — written test-first (red/green TDD).

TDD approach: each test class was written FIRST (RED), then the corresponding
production code was added to make it pass (GREEN), then refactored as needed.
"""

import json
import unittest
from datetime import date


# -- Shared test fixtures --

MOCK_SECRETS = [
    {
        "name": "DB_PASSWORD",
        "last_rotated": "2026-01-01",
        "rotation_days": 90,
        "required_by": ["api-server", "worker"],
    },
    {
        "name": "API_KEY",
        "last_rotated": "2026-01-15",
        "rotation_days": 90,
        "required_by": ["gateway"],
    },
    {
        "name": "TLS_CERT",
        "last_rotated": "2026-04-01",
        "rotation_days": 90,
        "required_by": ["nginx", "cdn"],
    },
    {
        "name": "OAUTH_SECRET",
        "last_rotated": "2026-03-01",
        "rotation_days": 60,
        "required_by": ["auth-service"],
    },
]

# Fixed "today" so tests are deterministic
TODAY = date(2026, 4, 11)


class TestClassifySecret(unittest.TestCase):
    """RED: classify_secret should return 'expired', 'warning', or 'ok'."""

    def test_expired_secret(self):
        from rotation_validator import classify_secret
        # Last rotated 100 days ago, policy is 90 days, warning window 7 days
        result = classify_secret(
            last_rotated=date(2026, 1, 1),
            rotation_days=90,
            warning_days=7,
            today=date(2026, 4, 11),
        )
        self.assertEqual(result, "expired")

    def test_warning_secret(self):
        from rotation_validator import classify_secret
        # Last rotated 86 days ago, policy 90, warning 7 → within warning window
        result = classify_secret(
            last_rotated=date(2026, 1, 15),
            rotation_days=90,
            warning_days=7,
            today=date(2026, 4, 11),
        )
        self.assertEqual(result, "warning")

    def test_ok_secret(self):
        from rotation_validator import classify_secret
        # Last rotated 10 days ago, policy 90, warning 7 → ok
        result = classify_secret(
            last_rotated=date(2026, 4, 1),
            rotation_days=90,
            warning_days=7,
            today=date(2026, 4, 11),
        )
        self.assertEqual(result, "ok")

    def test_exact_expiry_boundary(self):
        """Secret expiring exactly today is expired."""
        from rotation_validator import classify_secret
        result = classify_secret(
            last_rotated=date(2026, 1, 11),
            rotation_days=90,
            warning_days=7,
            today=date(2026, 4, 11),
        )
        self.assertEqual(result, "expired")

    def test_exact_warning_boundary(self):
        """Secret entering warning window exactly today is warning."""
        from rotation_validator import classify_secret
        # Expires on April 18, warning starts April 11
        result = classify_secret(
            last_rotated=date(2026, 1, 18),
            rotation_days=90,
            warning_days=7,
            today=date(2026, 4, 11),
        )
        self.assertEqual(result, "warning")


class TestValidateSecrets(unittest.TestCase):
    """RED: validate_secrets processes a list of secret dicts and groups them by urgency."""

    def test_groups_by_urgency(self):
        from rotation_validator import validate_secrets
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        # DB_PASSWORD: rotated Jan 1, 90d policy → expired Apr 1 → expired
        # API_KEY: rotated Jan 15, 90d policy → expires Apr 15, warning starts Apr 8 → warning
        # TLS_CERT: rotated Apr 1, 90d policy → expires Jun 30 → ok
        # OAUTH_SECRET: rotated Mar 1, 60d policy → expired Apr 30, warning Apr 23 → ok
        self.assertEqual(len(report["expired"]), 1)
        self.assertEqual(report["expired"][0]["name"], "DB_PASSWORD")
        self.assertEqual(len(report["warning"]), 1)
        self.assertEqual(report["warning"][0]["name"], "API_KEY")
        self.assertEqual(len(report["ok"]), 2)

    def test_includes_days_until_expiry(self):
        from rotation_validator import validate_secrets
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        # DB_PASSWORD expired 10 days ago → days_until_expiry = -10
        self.assertEqual(report["expired"][0]["days_until_expiry"], -10)
        # API_KEY expires in 4 days
        self.assertEqual(report["warning"][0]["days_until_expiry"], 4)

    def test_includes_required_by(self):
        from rotation_validator import validate_secrets
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        self.assertEqual(report["expired"][0]["required_by"], ["api-server", "worker"])

    def test_custom_warning_window(self):
        """A larger warning window should catch more secrets."""
        from rotation_validator import validate_secrets
        report = validate_secrets(MOCK_SECRETS, warning_days=30, today=TODAY)
        # With 30-day window, OAUTH_SECRET (expires Apr 30) enters warning too
        warning_names = [s["name"] for s in report["warning"]]
        self.assertIn("API_KEY", warning_names)
        self.assertIn("OAUTH_SECRET", warning_names)

    def test_empty_input(self):
        from rotation_validator import validate_secrets
        report = validate_secrets([], warning_days=7, today=TODAY)
        self.assertEqual(report, {"expired": [], "warning": [], "ok": []})


class TestFormatMarkdown(unittest.TestCase):
    """RED: format_markdown should produce a markdown table grouped by urgency."""

    def test_contains_headers(self):
        from rotation_validator import validate_secrets, format_markdown
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        md = format_markdown(report)
        self.assertIn("## Expired", md)
        self.assertIn("## Warning", md)
        self.assertIn("## OK", md)

    def test_contains_secret_names(self):
        from rotation_validator import validate_secrets, format_markdown
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        md = format_markdown(report)
        self.assertIn("DB_PASSWORD", md)
        self.assertIn("API_KEY", md)
        self.assertIn("TLS_CERT", md)

    def test_table_has_pipe_separators(self):
        from rotation_validator import validate_secrets, format_markdown
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        md = format_markdown(report)
        # Markdown tables use | separators
        self.assertIn("|", md)

    def test_empty_section_shows_none(self):
        """When a section is empty, say so instead of showing a blank table."""
        from rotation_validator import validate_secrets, format_markdown
        # All secrets are ok with these fixtures
        ok_secrets = [MOCK_SECRETS[2]]  # TLS_CERT, ok
        report = validate_secrets(ok_secrets, warning_days=7, today=TODAY)
        md = format_markdown(report)
        # Expired section should indicate nothing
        self.assertIn("None", md.split("## Warning")[0])


class TestFormatJson(unittest.TestCase):
    """RED: format_json should produce valid JSON matching the report structure."""

    def test_valid_json(self):
        from rotation_validator import validate_secrets, format_json
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        output = format_json(report)
        parsed = json.loads(output)
        self.assertIn("expired", parsed)
        self.assertIn("warning", parsed)
        self.assertIn("ok", parsed)

    def test_json_has_correct_counts(self):
        from rotation_validator import validate_secrets, format_json
        report = validate_secrets(MOCK_SECRETS, warning_days=7, today=TODAY)
        parsed = json.loads(format_json(report))
        self.assertEqual(len(parsed["expired"]), 1)
        self.assertEqual(len(parsed["warning"]), 1)
        self.assertEqual(len(parsed["ok"]), 2)


class TestErrorHandling(unittest.TestCase):
    """RED: graceful error handling for invalid input."""

    def test_invalid_date_format(self):
        from rotation_validator import validate_secrets
        bad_secrets = [{"name": "BAD", "last_rotated": "not-a-date",
                        "rotation_days": 90, "required_by": []}]
        with self.assertRaises(ValueError) as ctx:
            validate_secrets(bad_secrets, warning_days=7, today=TODAY)
        self.assertIn("BAD", str(ctx.exception))

    def test_missing_required_field(self):
        from rotation_validator import validate_secrets
        bad_secrets = [{"name": "INCOMPLETE"}]
        with self.assertRaises(ValueError) as ctx:
            validate_secrets(bad_secrets, warning_days=7, today=TODAY)
        self.assertIn("INCOMPLETE", str(ctx.exception))

    def test_negative_rotation_days(self):
        from rotation_validator import validate_secrets
        bad_secrets = [{"name": "NEG", "last_rotated": "2026-01-01",
                        "rotation_days": -5, "required_by": []}]
        with self.assertRaises(ValueError) as ctx:
            validate_secrets(bad_secrets, warning_days=7, today=TODAY)
        self.assertIn("NEG", str(ctx.exception))


class TestLoadConfig(unittest.TestCase):
    """RED: load_config should parse a JSON file into a list of secret dicts."""

    def test_load_from_file(self):
        import tempfile, os
        from rotation_validator import load_config
        data = json.dumps({"secrets": MOCK_SECRETS, "warning_days": 14})
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write(data)
            f.flush()
            config = load_config(f.name)
        os.unlink(f.name)
        self.assertEqual(len(config["secrets"]), 4)
        self.assertEqual(config["warning_days"], 14)

    def test_missing_file(self):
        from rotation_validator import load_config
        with self.assertRaises(FileNotFoundError):
            load_config("/nonexistent/path.json")

    def test_invalid_json(self):
        import tempfile, os
        from rotation_validator import load_config
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("{not valid json")
            f.flush()
            path = f.name
        with self.assertRaises(ValueError) as ctx:
            load_config(path)
        self.assertIn("Invalid JSON", str(ctx.exception))
        os.unlink(path)


if __name__ == "__main__":
    unittest.main()
