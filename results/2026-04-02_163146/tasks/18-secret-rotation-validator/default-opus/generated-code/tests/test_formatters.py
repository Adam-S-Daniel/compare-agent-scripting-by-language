"""
TDD Cycle 4: Output Formatters (JSON and Markdown)
===================================================
RED:  Write tests for format_json() and format_markdown() output structure.
GREEN: Implement formatters that transform RotationReport → string.
REFACTOR: Extract _status_to_dict helper, DRY up markdown table rendering.

We test that:
- JSON output is valid JSON with the expected structure.
- Markdown output contains the expected table headers, rows, and sections.
"""
import unittest
import json
import sys
import os
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import (
    SecretConfig, generate_report, format_json, format_markdown,
)

# Reuse the same fixtures for consistency
FIXTURES = [
    SecretConfig("DB_PASSWORD",   date(2025, 12, 1),  90, ["api", "worker"]),
    SecretConfig("API_KEY",       date(2026, 3, 1),   30, ["frontend"]),
    SecretConfig("JWT_SECRET",    date(2026, 1, 15),  90, ["auth-service"]),
    SecretConfig("REDIS_TOKEN",   date(2026, 3, 28),  90, ["cache-service"]),
]

REF_DATE = date(2026, 4, 1)


class TestFormatJson(unittest.TestCase):
    """Test JSON output format."""

    def setUp(self):
        self.report = generate_report(FIXTURES, warning_window_days=14, reference_date=REF_DATE)
        self.json_str = format_json(self.report)

    def test_output_is_valid_json(self):
        """The output must be parseable JSON."""
        data = json.loads(self.json_str)
        self.assertIsInstance(data, dict)

    def test_json_has_metadata_section(self):
        """JSON output should include a metadata section."""
        data = json.loads(self.json_str)
        self.assertIn("metadata", data)
        meta = data["metadata"]
        self.assertEqual(meta["reference_date"], "2026-04-01")
        self.assertEqual(meta["warning_window_days"], 14)
        self.assertEqual(meta["total_secrets"], 4)

    def test_json_has_secrets_grouped_by_urgency(self):
        """JSON should have secrets.expired, secrets.warning, secrets.ok."""
        data = json.loads(self.json_str)
        self.assertIn("secrets", data)
        for group in ["expired", "warning", "ok"]:
            self.assertIn(group, data["secrets"])
            self.assertIsInstance(data["secrets"][group], list)

    def test_json_secret_entry_fields(self):
        """Each secret entry should have all expected fields."""
        data = json.loads(self.json_str)
        # Check first expired entry
        expired = data["secrets"]["expired"]
        self.assertTrue(len(expired) > 0)
        entry = expired[0]
        expected_fields = {
            "name", "status", "last_rotated", "rotation_policy_days",
            "days_since_rotation", "days_until_expiry", "required_by",
        }
        self.assertEqual(set(entry.keys()), expected_fields)

    def test_json_counts_match_lists(self):
        """Metadata counts should match the actual list lengths."""
        data = json.loads(self.json_str)
        meta = data["metadata"]
        secrets = data["secrets"]
        self.assertEqual(meta["expired_count"], len(secrets["expired"]))
        self.assertEqual(meta["warning_count"], len(secrets["warning"]))
        self.assertEqual(meta["ok_count"], len(secrets["ok"]))


class TestFormatMarkdown(unittest.TestCase):
    """Test Markdown output format."""

    def setUp(self):
        self.report = generate_report(FIXTURES, warning_window_days=14, reference_date=REF_DATE)
        self.md = format_markdown(self.report)

    def test_markdown_has_report_header(self):
        """Output should start with a report title."""
        self.assertIn("# Secret Rotation Report", self.md)

    def test_markdown_has_date(self):
        """Output should include the reference date."""
        self.assertIn("2026-04-01", self.md)

    def test_markdown_has_summary_table(self):
        """Output should include the summary counts table."""
        self.assertIn("| Status | Count |", self.md)
        self.assertIn("| Expired |", self.md)
        self.assertIn("| Warning |", self.md)
        self.assertIn("| OK |", self.md)

    def test_markdown_has_expired_section(self):
        """Expired secrets should appear under an Expired heading."""
        self.assertIn("## Expired", self.md)
        self.assertIn("DB_PASSWORD", self.md)

    def test_markdown_has_ok_section(self):
        """OK secrets should appear under an OK heading."""
        self.assertIn("## OK", self.md)
        self.assertIn("REDIS_TOKEN", self.md)

    def test_markdown_table_has_column_headers(self):
        """Detail tables should have the expected column headers."""
        self.assertIn("| Secret |", self.md)
        self.assertIn("Last Rotated", self.md)
        self.assertIn("Policy (days)", self.md)
        self.assertIn("Days Until Expiry", self.md)
        self.assertIn("Required By", self.md)

    def test_markdown_shows_service_names(self):
        """Services from required_by should appear in the table."""
        self.assertIn("api", self.md)
        self.assertIn("worker", self.md)

    def test_empty_report_still_has_header(self):
        """An empty report should still render the header and summary."""
        report = generate_report([], warning_window_days=14, reference_date=REF_DATE)
        md = format_markdown(report)
        self.assertIn("# Secret Rotation Report", md)
        self.assertIn("**Total secrets:** 0", md)


if __name__ == "__main__":
    unittest.main()
