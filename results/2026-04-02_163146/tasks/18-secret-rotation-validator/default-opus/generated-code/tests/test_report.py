"""
TDD Cycle 3: Report Generation
===============================
RED:  Write tests for generate_report() grouping secrets by urgency.
GREEN: Implement generate_report() that iterates configs and classifies each.
REFACTOR: Extract RotationReport dataclass for clean grouping.

The report generator takes a list of SecretConfigs and produces a
RotationReport with secrets bucketed into expired/warning/ok lists.
"""
import unittest
import sys
import os
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import (
    SecretConfig, generate_report, EXPIRED, WARNING, OK,
)


# --- Test Fixtures ---
# A realistic set of mock secrets with varying rotation states.
# Reference date: 2026-04-01

FIXTURES = [
    SecretConfig("DB_PASSWORD",      date(2025, 12, 1),  90, ["api", "worker"]),       # expired (121 days ago)
    SecretConfig("API_KEY",          date(2026, 3, 1),   30, ["frontend"]),             # expired (31 days ago)
    SecretConfig("JWT_SECRET",       date(2026, 1, 15),  90, ["auth-service"]),         # warning (76 days, 14 left)
    SecretConfig("SMTP_PASSWORD",    date(2026, 3, 20),  30, ["email-service"]),        # warning (12 days, 18 left → actually ok if 14-day window)
    SecretConfig("REDIS_TOKEN",      date(2026, 3, 28),  90, ["cache-service"]),        # ok (4 days, 86 left)
    SecretConfig("S3_ACCESS_KEY",    date(2026, 3, 30),  365, ["backup-service"]),      # ok (2 days, 363 left)
]

REF_DATE = date(2026, 4, 1)


class TestGenerateReport(unittest.TestCase):
    """Test that generate_report correctly groups secrets by urgency."""

    def test_report_groups_expired_secrets(self):
        """Expired secrets should end up in the expired list."""
        report = generate_report(FIXTURES, warning_window_days=14, reference_date=REF_DATE)
        expired_names = [s.config.name for s in report.expired]
        self.assertIn("DB_PASSWORD", expired_names)
        self.assertIn("API_KEY", expired_names)
        self.assertEqual(len(report.expired), 2)

    def test_report_groups_warning_secrets(self):
        """Secrets within the warning window should be in the warning list."""
        report = generate_report(FIXTURES, warning_window_days=14, reference_date=REF_DATE)
        warning_names = [s.config.name for s in report.warning]
        self.assertIn("JWT_SECRET", warning_names)

    def test_report_groups_ok_secrets(self):
        """Secrets safely within their rotation period should be ok."""
        report = generate_report(FIXTURES, warning_window_days=14, reference_date=REF_DATE)
        ok_names = [s.config.name for s in report.ok]
        self.assertIn("REDIS_TOKEN", ok_names)
        self.assertIn("S3_ACCESS_KEY", ok_names)

    def test_report_total_counts_match(self):
        """Total of all groups should equal total input secrets."""
        report = generate_report(FIXTURES, warning_window_days=14, reference_date=REF_DATE)
        total = len(report.expired) + len(report.warning) + len(report.ok)
        self.assertEqual(total, len(FIXTURES))

    def test_report_with_empty_input(self):
        """An empty config list should produce an empty report."""
        report = generate_report([], warning_window_days=14, reference_date=REF_DATE)
        self.assertEqual(len(report.expired), 0)
        self.assertEqual(len(report.warning), 0)
        self.assertEqual(len(report.ok), 0)

    def test_report_preserves_metadata(self):
        """Report should store the reference date and warning window."""
        report = generate_report(FIXTURES, warning_window_days=7, reference_date=REF_DATE)
        self.assertEqual(report.reference_date, REF_DATE)
        self.assertEqual(report.warning_window_days, 7)

    def test_wider_warning_window_catches_more(self):
        """Increasing the warning window should shift secrets from ok → warning."""
        narrow = generate_report(FIXTURES, warning_window_days=7, reference_date=REF_DATE)
        wide = generate_report(FIXTURES, warning_window_days=30, reference_date=REF_DATE)
        # A wider window should have at least as many warnings
        self.assertGreaterEqual(len(wide.warning), len(narrow.warning))


if __name__ == "__main__":
    unittest.main()
