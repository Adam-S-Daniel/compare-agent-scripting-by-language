"""
TDD Cycle 1: Secret Configuration Parsing & Validation
=======================================================
RED:  Write tests for parsing valid/invalid secret config dicts.
GREEN: Implement parse_secret_config with field validation.
REFACTOR: Extract REQUIRED_FIELDS constant, clean up error messages.

These tests verify that raw dict data (as would come from JSON) is correctly
parsed into SecretConfig objects, and that missing/invalid fields produce
clear, actionable error messages.
"""
import unittest
import sys
import os
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import SecretConfig, parse_secret_config


class TestParseValidConfig(unittest.TestCase):
    """Test that well-formed data parses correctly."""

    def test_parse_valid_secret_config(self):
        """A complete, valid config dict should produce a SecretConfig."""
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 90,
            "required_by": ["api-service", "worker-service"],
        }
        config = parse_secret_config(data)
        self.assertEqual(config.name, "DB_PASSWORD")
        self.assertEqual(config.last_rotated, date(2026, 1, 15))
        self.assertEqual(config.rotation_policy_days, 90)
        self.assertEqual(config.required_by, ["api-service", "worker-service"])

    def test_parse_config_with_empty_required_by(self):
        """A secret with no dependent services is valid (empty list)."""
        data = {
            "name": "ORPHAN_KEY",
            "last_rotated": "2026-03-01",
            "rotation_policy_days": 30,
            "required_by": [],
        }
        config = parse_secret_config(data)
        self.assertEqual(config.required_by, [])


class TestParseInvalidConfig(unittest.TestCase):
    """Test that invalid data produces clear error messages."""

    def test_missing_name_raises_error(self):
        """Missing 'name' field should raise ValueError mentioning the field."""
        data = {
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 90,
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError) as ctx:
            parse_secret_config(data)
        self.assertIn("name", str(ctx.exception).lower())

    def test_missing_last_rotated_raises_error(self):
        data = {
            "name": "DB_PASSWORD",
            "rotation_policy_days": 90,
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError) as ctx:
            parse_secret_config(data)
        self.assertIn("last_rotated", str(ctx.exception).lower())

    def test_missing_rotation_policy_raises_error(self):
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError) as ctx:
            parse_secret_config(data)
        self.assertIn("rotation_policy_days", str(ctx.exception).lower())

    def test_missing_required_by_raises_error(self):
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 90,
        }
        with self.assertRaises(ValueError) as ctx:
            parse_secret_config(data)
        self.assertIn("required_by", str(ctx.exception).lower())

    def test_invalid_date_format_raises_error(self):
        """A malformed date string should mention 'date' in the error."""
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "not-a-date",
            "rotation_policy_days": 90,
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError) as ctx:
            parse_secret_config(data)
        self.assertIn("date", str(ctx.exception).lower())

    def test_negative_rotation_policy_raises_error(self):
        """Rotation policy must be positive."""
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": -5,
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError) as ctx:
            parse_secret_config(data)
        self.assertIn("rotation_policy_days", str(ctx.exception).lower())

    def test_zero_rotation_policy_raises_error(self):
        """Zero-day rotation policy makes no sense — should be rejected."""
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 0,
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError):
            parse_secret_config(data)

    def test_empty_name_raises_error(self):
        """An empty or whitespace-only name should be rejected."""
        data = {
            "name": "   ",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 90,
            "required_by": ["api-service"],
        }
        with self.assertRaises(ValueError):
            parse_secret_config(data)

    def test_required_by_not_list_raises_error(self):
        """required_by must be a list, not a string."""
        data = {
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 90,
            "required_by": "api-service",  # should be a list
        }
        with self.assertRaises(ValueError):
            parse_secret_config(data)


if __name__ == "__main__":
    unittest.main()
