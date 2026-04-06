"""
TDD Cycle 5: Bulk Loading from JSON
====================================
RED:  Write tests for load_secrets_from_json() which parses a JSON string
      containing multiple secret configs at once.
GREEN: Implement load_secrets_from_json with aggregate error reporting.
REFACTOR: Collect all errors rather than failing on the first one.

This tests the "front door" — loading a complete JSON config file and
getting back validated SecretConfig objects (or meaningful errors).
"""
import unittest
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import load_secrets_from_json


class TestBulkLoadingValid(unittest.TestCase):
    """Test loading valid JSON arrays of secrets."""

    def test_load_single_secret(self):
        data = json.dumps([{
            "name": "DB_PASSWORD",
            "last_rotated": "2026-01-15",
            "rotation_policy_days": 90,
            "required_by": ["api"],
        }])
        configs = load_secrets_from_json(data)
        self.assertEqual(len(configs), 1)
        self.assertEqual(configs[0].name, "DB_PASSWORD")

    def test_load_multiple_secrets(self):
        data = json.dumps([
            {"name": "SECRET_A", "last_rotated": "2026-01-01", "rotation_policy_days": 30, "required_by": ["svc-a"]},
            {"name": "SECRET_B", "last_rotated": "2026-02-01", "rotation_policy_days": 60, "required_by": ["svc-b"]},
            {"name": "SECRET_C", "last_rotated": "2026-03-01", "rotation_policy_days": 90, "required_by": ["svc-c"]},
        ])
        configs = load_secrets_from_json(data)
        self.assertEqual(len(configs), 3)
        names = [c.name for c in configs]
        self.assertEqual(names, ["SECRET_A", "SECRET_B", "SECRET_C"])

    def test_load_empty_array(self):
        configs = load_secrets_from_json("[]")
        self.assertEqual(len(configs), 0)


class TestBulkLoadingErrors(unittest.TestCase):
    """Test error handling for malformed JSON input."""

    def test_invalid_json_raises_error(self):
        """Completely invalid JSON should raise ValueError."""
        with self.assertRaises(ValueError) as ctx:
            load_secrets_from_json("{not valid json")
        self.assertIn("json", str(ctx.exception).lower())

    def test_non_array_json_raises_error(self):
        """A JSON object (not array) should raise ValueError."""
        with self.assertRaises(ValueError) as ctx:
            load_secrets_from_json('{"name": "SECRET"}')
        self.assertIn("array", str(ctx.exception).lower())

    def test_single_invalid_entry_reports_index(self):
        """An invalid entry should mention its index in the error."""
        data = json.dumps([
            {"name": "GOOD", "last_rotated": "2026-01-01", "rotation_policy_days": 30, "required_by": ["svc"]},
            {"name": "BAD"},  # missing fields
        ])
        with self.assertRaises(ValueError) as ctx:
            load_secrets_from_json(data)
        self.assertIn("index 1", str(ctx.exception).lower())

    def test_multiple_invalid_entries_report_all_errors(self):
        """All validation errors should be collected and reported together."""
        data = json.dumps([
            {"name": "BAD_1"},         # missing fields
            {"name": "BAD_2"},         # missing fields
            {"name": "GOOD", "last_rotated": "2026-01-01", "rotation_policy_days": 30, "required_by": ["svc"]},
        ])
        with self.assertRaises(ValueError) as ctx:
            load_secrets_from_json(data)
        error_msg = str(ctx.exception)
        self.assertIn("index 0", error_msg.lower())
        self.assertIn("index 1", error_msg.lower())


if __name__ == "__main__":
    unittest.main()
